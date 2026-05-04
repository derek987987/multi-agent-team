#!/usr/bin/env python3
"""Local Agent Office dashboard server.

This serves the no-build visual-media frontend and exposes a small JSON API over
the repository's file-backed control plane.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import re
import subprocess
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    if not path.exists():
        return records
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            raw = line.strip()
            if not raw:
                continue
            try:
                value = json.loads(raw)
            except json.JSONDecodeError as exc:
                records.append(
                    {
                        "_parse_error": str(exc),
                        "_line": line_number,
                        "_source": str(path),
                    }
                )
                continue
            if isinstance(value, dict):
                records.append(value)
    return records


def latest_by(records: list[dict[str, Any]], key: str) -> dict[str, dict[str, Any]]:
    latest: dict[str, dict[str, Any]] = {}
    for record in records:
        value = str(record.get(key, "")).strip()
        if value:
            latest[value] = record
    return latest


def parse_field_block(text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in text.splitlines():
        if line.startswith("## "):
            break
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        fields[key.strip().lower().replace(" ", "_")] = value.strip()
    return fields


def parse_markdown_table(lines: list[str], heading: str) -> list[dict[str, str]]:
    in_section = False
    headers: list[str] = []
    rows: list[dict[str, str]] = []
    for line in lines:
        if line.strip() == f"## {heading}":
            in_section = True
            continue
        if in_section and line.startswith("## "):
            break
        if not in_section or not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if all(set(cell) <= {"-", " "} for cell in cells):
            continue
        if not headers:
            headers = [cell.lower().replace(" ", "_") for cell in cells]
            continue
        if len(cells) == len(headers):
            rows.append(dict(zip(headers, cells)))
    return rows


def parse_workflow_state(root: Path) -> dict[str, Any]:
    text = read_text(root / ".agents" / "workflow-state.md")
    lines = text.splitlines()
    workflow: dict[str, Any] = {
        "mode": "",
        "phase": "",
        "last_updated": "",
        "updated_by": "",
        "active_request": {},
        "open_routes": [],
        "blocked_tasks": [],
        "human_attention": "",
    }
    current_heading = ""
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("## "):
            current_heading = stripped[3:]
            continue
        if stripped.startswith("Mode:"):
            workflow["mode"] = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("Phase:"):
            workflow["phase"] = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("Last updated:"):
            value = stripped.split(":", 1)[1].strip()
            if not value and index + 1 < len(lines):
                value = lines[index + 1].strip()
            workflow["last_updated"] = value
        elif stripped.startswith("Updated by:"):
            value = stripped.split(":", 1)[1].strip()
            if not value and index + 1 < len(lines):
                value = lines[index + 1].strip()
            workflow["updated_by"] = value
        elif current_heading == "Active Request" and ":" in stripped:
            key, value = stripped.split(":", 1)
            workflow["active_request"][key.strip().lower().replace(" ", "_")] = value.strip()

    workflow["open_routes"] = parse_markdown_table(lines, "Open Routes")
    workflow["blocked_tasks"] = parse_markdown_table(lines, "Blocked Tasks")

    if "## Human Attention Needed" in text:
        tail = text.split("## Human Attention Needed", 1)[1]
        next_section = tail.split("\n## ", 1)[0]
        workflow["human_attention"] = next_section.strip()
    return workflow


def parse_route_reports(root: Path) -> dict[str, dict[str, Any]]:
    reports: dict[str, dict[str, Any]] = {}
    route_dir = root / ".agents" / "routes"
    if not route_dir.exists():
        return reports
    for path in sorted(route_dir.glob("R*.md")):
        if path.name == "README.md":
            continue
        text = read_text(path)
        route_id = path.stem
        fields = parse_field_block(text)
        route_id = fields.get("route_id") or route_id
        reports[route_id] = {
            "route_id": route_id,
            "from": fields.get("from", ""),
            "to": fields.get("to", ""),
            "status": fields.get("status", ""),
            "priority": fields.get("priority", ""),
            "related_task": fields.get("related_task", ""),
            "title": text.splitlines()[0].lstrip("# ").strip() if text else route_id,
            "report": f".agents/routes/{path.name}",
            "updated": fields.get("last_updated", ""),
            "context_refs": fields.get("context_refs", ""),
            "source": "route-report",
        }
    return reports


def read_profiles(root: Path) -> list[dict[str, Any]]:
    profiles = read_jsonl(root / ".agents" / "company" / "agent-profiles.jsonl")
    return [profile for profile in profiles if profile.get("role")]


def build_agents(root: Path) -> list[dict[str, Any]]:
    profiles = read_profiles(root)
    telemetry = latest_by(read_jsonl(root / ".agents" / "state" / "agents.jsonl"), "role")
    agents: list[dict[str, Any]] = []
    for profile in profiles:
        role = str(profile.get("role", ""))
        live = telemetry.get(role, {})
        has_live = bool(live)
        agent = {
            "role": role,
            "display_name": profile.get("display_name") or role.title(),
            "skills": profile.get("skills", []),
            "profile_path": profile.get("profile_path", ""),
            "memory_path": profile.get("memory_path", ""),
            "inbox_path": profile.get("inbox_path", f".agents/inbox/{role}.md"),
            "ownership_path": profile.get("ownership_path", ""),
            "profile_status": profile.get("status", ""),
            "load": profile.get("load", ""),
            "live": has_live,
            "status": live.get("status") if has_live else "offline",
            "session": live.get("session", ""),
            "window": live.get("window", role),
            "process_status": live.get("process_status", "unknown") if has_live else "unknown",
            "last_seen_at": live.get("last_seen_at", ""),
            "active_route": live.get("active_route", "none") if has_live else "none",
            "active_task": live.get("active_task", "none") if has_live else "none",
            "workdir": live.get("workdir", ""),
            "target_project": live.get("target_project", ""),
            "branch_or_worktree": live.get("branch_or_worktree", "none") if has_live else "none",
            "capacity": live.get("capacity", 1),
            "blocked_reason": live.get("blocked_reason", ""),
            "recovery_owner": live.get("recovery_owner", ""),
            "source": live.get("source", "profile-empty-telemetry") if has_live else "profile-empty-telemetry",
        }
        agents.append(agent)
    return agents


def build_routes(root: Path) -> list[dict[str, Any]]:
    route_records = latest_by(read_jsonl(root / ".agents" / "state" / "routes.jsonl"), "route_id")
    reports = parse_route_reports(root)
    merged: dict[str, dict[str, Any]] = {}
    for route_id, report in reports.items():
        merged[route_id] = dict(report)
    for route_id, record in route_records.items():
        merged.setdefault(route_id, {})
        merged[route_id].update(record)
        merged[route_id].setdefault("report", f".agents/routes/{route_id}.md")
        merged[route_id]["source"] = "routes-jsonl"
    return sorted(merged.values(), key=lambda item: str(item.get("route_id", "")))


def build_snapshot(root: Path) -> dict[str, Any]:
    return {
        "generated_at": utc_now(),
        "project_target": read_text(root / ".agents" / "project-target.md"),
        "profiles": read_profiles(root),
        "agents": build_agents(root),
        "routes": build_routes(root),
        "workflow": parse_workflow_state(root),
        "events": read_jsonl(root / ".agents" / "events.jsonl")[-40:],
        "sources": {
            "profiles": ".agents/company/agent-profiles.jsonl",
            "agents": ".agents/state/agents.jsonl",
            "routes": ".agents/state/routes.jsonl",
            "events": ".agents/events.jsonl",
            "workflow": ".agents/workflow-state.md",
            "route_reports": ".agents/routes/*.md",
        },
    }


def route_numbers(root: Path) -> set[int]:
    numbers: set[int] = set()
    def add_route_id(value: Any) -> None:
        match = re.fullmatch(r"R(\d{3,})", str(value or "").strip())
        if match:
            numbers.add(int(match.group(1)))

    for record in read_jsonl(root / ".agents" / "state" / "routes.jsonl"):
        add_route_id(record.get("route_id"))

    inbox_dir = root / ".agents" / "inbox"
    if inbox_dir.exists():
        for path in sorted(inbox_dir.glob("*.md")):
            for line in read_text(path).splitlines():
                heading = re.match(r"^##\s+(R\d{3,})\b", line)
                if heading:
                    add_route_id(heading.group(1))

    workflow = read_text(root / ".agents" / "workflow-state.md")
    for line in workflow.splitlines():
        table_route = re.match(r"^\|\s*(R\d{3,})\s*\|", line)
        if table_route:
            add_route_id(table_route.group(1))

    route_dir = root / ".agents" / "routes"
    if route_dir.exists():
        for path in sorted(route_dir.glob("R*.md")):
            if path.name == "README.md":
                continue
            add_route_id(path.stem)
    return numbers


def next_route_id(root: Path) -> str:
    numbers = route_numbers(root)
    next_number = max(numbers, default=0) + 1
    return f"R{next_number:03d}"


def selected_agent(snapshot: dict[str, Any], role: str) -> dict[str, Any] | None:
    for agent in snapshot["agents"]:
        if agent.get("role") == role:
            return agent
    return None


def create_orchestrator_prompt(root: Path, body: dict[str, Any]) -> tuple[int, dict[str, Any]]:
    role = str(body.get("role", "")).strip()
    message = str(body.get("message", "")).strip()
    if not message:
        return 400, {"error": "message is required"}
    if len(message) > 4000:
        return 400, {"error": "message must be 4000 characters or fewer"}

    snapshot = build_snapshot(root)
    agent = selected_agent(snapshot, role)
    if agent is None:
        return 400, {"error": "role must match .agents/company/agent-profiles.jsonl"}

    route_id = next_route_id(root)
    display_name = agent.get("display_name") or role
    active_route = str(agent.get("active_route") or "none")
    selected_status = str(agent.get("status") or "offline")
    blocked_reason = str(agent.get("blocked_reason") or "none")
    title = f"Agent Office prompt for {display_name}"
    context_refs = (
        ".agents/company/agent-profiles.jsonl; "
        ".agents/state/agents.jsonl; "
        ".agents/state/routes.jsonl; "
        ".agents/events.jsonl; "
        ".agents/workflow-state.md; "
        f"selected role={role}; "
        f"selected status={selected_status}; "
        f"selected active route={active_route}"
    )
    instruction = "\n".join(
        [
            "Human submitted this request from the Agent Office dashboard.",
            "",
            f"Selected role: {role}",
            f"Selected display name: {display_name}",
            f"Selected status: {selected_status}",
            f"Selected active route: {active_route}",
            f"Selected active task: {agent.get('active_task') or 'none'}",
            f"Selected blocked reason: {blocked_reason}",
            f"Selected last seen: {agent.get('last_seen_at') or 'none'}",
            "",
            "Prompt:",
            message,
            "",
            "Classify the request, update source-of-truth workflow files if needed, and route follow-up through .agents/* files. Keep Orchestrator as the routing authority.",
        ]
    )
    expected_output = (
        f".agents/routes/{route_id}.md report, plus any needed .agents/workflow-state.md, "
        ".agents/handoffs.md, or inbox route updates."
    )
    validation = "Run ./scripts/validate-route-state.sh and ./scripts/validate-structured-state.sh."
    command = [
        str(root / "scripts" / "route-agent.sh"),
        route_id,
        "orchestrator",
        title,
        "UI",
        "--from",
        "human-ui",
        "--context",
        context_refs,
        "--instruction",
        instruction,
        "--expected-output",
        expected_output,
        "--validation",
        validation,
    ]
    result = subprocess.run(command, cwd=root, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        return 500, {"error": "route creation failed", "stderr": result.stderr.strip()}
    return 201, {
        "route_id": route_id,
        "from": "human-ui",
        "to": "orchestrator",
        "title": title,
        "report": f".agents/routes/{route_id}.md",
        "inbox": ".agents/inbox/orchestrator.md",
        "workflow_state": ".agents/workflow-state.md",
        "stdout": result.stdout.strip(),
    }


class AgentOfficeHandler(BaseHTTPRequestHandler):
    server_version = "AgentOfficeDashboard/1.0"

    @property
    def root(self) -> Path:
        return self.server.root  # type: ignore[attr-defined]

    def log_message(self, format: str, *args: Any) -> None:
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] {self.address_string()} {format % args}")

    def send_json(self, status: int, payload: dict[str, Any]) -> None:
        data = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/api/snapshot":
            self.send_json(HTTPStatus.OK, build_snapshot(self.root))
            return
        if parsed.path == "/favicon.ico":
            self.send_response(HTTPStatus.NO_CONTENT)
            self.end_headers()
            return
        self.serve_static(parsed.path)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/api/orchestrator-prompt":
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        length = int(self.headers.get("Content-Length") or 0)
        if length > 128_000:
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "request body is too large"})
            return
        raw = self.rfile.read(length)
        try:
            body = json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "invalid JSON"})
            return
        if not isinstance(body, dict):
            self.send_json(HTTPStatus.BAD_REQUEST, {"error": "JSON object required"})
            return
        status, payload = create_orchestrator_prompt(self.root, body)
        self.send_json(status, payload)

    def safe_static_path(self, request_path: str) -> Path | None:
        path = unquote(request_path)
        if path in {"", "/"}:
            return self.root / "visual-media" / "index.html"
        if path == "/visual-media":
            return None
        relative = path.lstrip("/")
        candidate = (self.root / relative).resolve()
        try:
            candidate.relative_to(self.root)
        except ValueError:
            return None
        if candidate.is_dir():
            index = candidate / "index.html"
            return index if index.exists() else None
        return candidate

    def serve_static(self, request_path: str) -> None:
        if request_path == "/visual-media":
            self.send_response(HTTPStatus.MOVED_PERMANENTLY)
            self.send_header("Location", "/visual-media/")
            self.end_headers()
            return
        path = self.safe_static_path(request_path)
        if path is None or not path.exists() or not path.is_file():
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        content_type = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
        if path.suffix in {".md", ".jsonl", ".sh"}:
            content_type = "text/plain; charset=utf-8"
        data = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)


class AgentOfficeServer(ThreadingHTTPServer):
    def __init__(self, server_address: tuple[str, int], handler_class: type[BaseHTTPRequestHandler], root: Path):
        super().__init__(server_address, handler_class)
        self.root = root


def main() -> int:
    parser = argparse.ArgumentParser(description="Serve the Agent Office dashboard")
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not (root / "visual-media" / "index.html").exists():
        raise SystemExit(f"visual-media/index.html not found under {root}")

    server = AgentOfficeServer(("127.0.0.1", args.port), AgentOfficeHandler, root)
    print(f"Serving Agent Office dashboard at http://127.0.0.1:{args.port}/visual-media/")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Agent Office dashboard.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
