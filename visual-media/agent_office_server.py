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
from urllib.parse import parse_qs, unquote, urlparse


ACTIVE_ROUTE_STATUSES = {"queued", "dispatching", "dispatched", "in-progress", "blocked"}
ROUTE_WATCH_LIMITS = {
    "queued": 120,
    "dispatching": 45,
    "dispatched": 60,
    "in-progress": 1800,
}
ROUTE_STALE_LIMITS = {
    "queued": 30 * 60,
    "dispatching": 30 * 60,
    "dispatched": 30 * 60,
    "in-progress": 4 * 60 * 60,
}


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_utc(value: Any) -> datetime | None:
    if not value:
        return None
    text = str(value).strip()
    try:
        if text.endswith("Z"):
            return datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        parsed = datetime.fromisoformat(text)
        if parsed.tzinfo is None:
            return parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    except ValueError:
        return None


def age_seconds(value: Any, now: datetime | None = None) -> int | None:
    parsed = parse_utc(value)
    if parsed is None:
        return None
    current = now or datetime.now(timezone.utc)
    return max(0, int((current - parsed).total_seconds()))


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
    text = read_text(root / "agent-control" / "workflow-state.md")
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
    route_dir = root / "agent-control" / "routes"
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
            "created": fields.get("created", ""),
            "attempt": fields.get("attempt", ""),
            "title": text.splitlines()[0].lstrip("# ").strip() if text else route_id,
            "report": f"agent-control/routes/{path.name}",
            "updated": fields.get("last_updated", ""),
            "context_refs": fields.get("context_refs", ""),
            "source": "route-report",
        }
    return reports


def read_profiles(root: Path) -> list[dict[str, Any]]:
    profiles = read_jsonl(root / "agent-control" / "company" / "agent-profiles.jsonl")
    return [profile for profile in profiles if profile.get("role")]


def tmux_pane_inventory() -> dict[str, dict[str, Any]]:
    try:
        result = subprocess.run(
            ["tmux", "list-panes", "-a", "-F", "#S\t#W\t#{pane_current_command}\t#{pane_dead}\t#{pane_pid}"],
            text=True,
            capture_output=True,
            timeout=1,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return {}
    if result.returncode != 0:
        return {}
    panes: dict[str, dict[str, Any]] = {}
    for line in result.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) != 5:
            continue
        session, window, command, dead, pane_pid = parts
        panes[f"{session}:{window}"] = {
            "session": session,
            "window": window,
            "command": command,
            "dead": dead == "1",
            "pane_pid": pane_pid,
        }
    return panes


def route_health(route: dict[str, Any], now: datetime | None = None) -> dict[str, Any]:
    status = str(route.get("status") or "").strip().lower()
    created_age = age_seconds(route.get("created"), now)
    updated_age = age_seconds(route.get("updated"), now)
    route_age = updated_age if updated_age is not None else created_age
    signals: list[str] = []
    severity = "ok"
    label = "Route moving"

    if status == "blocked":
        severity = "stuck"
        label = "Blocked route"
        signals.append("Route is blocked and needs recovery or a new owner.")
    elif status in {"done", "cancelled"}:
        label = "Route closed"
    elif status in ACTIVE_ROUTE_STATUSES:
        if route_age is None:
            severity = "watch"
            label = "Missing route timestamp"
            signals.append("Route has no parseable Created or Last updated timestamp.")
        else:
            stale_limit = ROUTE_STALE_LIMITS.get(status)
            watch_limit = ROUTE_WATCH_LIMITS.get(status)
            if stale_limit is not None and route_age > stale_limit:
                severity = "stuck"
                label = f"{status} route is stale"
                signals.append(f"Route has been {status} for {route_age}s; stale recovery should inspect it.")
            elif watch_limit is not None and route_age > watch_limit:
                severity = "watch"
                label = f"{status} route needs attention"
                signals.append(f"Route has been {status} for {route_age}s.")
            else:
                label = f"{status} route active"

    return {
        "severity": severity,
        "label": label,
        "signals": signals,
        "age_seconds": route_age,
        "created_age_seconds": created_age,
        "updated_age_seconds": updated_age,
        "watch_after_seconds": ROUTE_WATCH_LIMITS.get(status),
        "stale_after_seconds": ROUTE_STALE_LIMITS.get(status),
        "recovery_command": "./scripts/recover-stale-routes.sh --dry-run",
    }


def ready_marker_for(root: Path, role: str) -> dict[str, str]:
    marker = root / "agent-control" / "state" / "role-ready" / f"{role}.ready"
    values: dict[str, str] = {}
    if not marker.exists():
        return values
    for line in read_text(marker).splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def ready_marker_matches(marker: dict[str, str], pane: dict[str, Any] | None) -> bool:
    if not marker or not pane:
        return False
    return (
        marker.get("session") == pane.get("session")
        and marker.get("window") == pane.get("window")
        and marker.get("pane_pid") == pane.get("pane_pid")
    )


def pane_contains_role_ready(pane: dict[str, Any] | None, role: str) -> bool:
    if not pane or pane.get("dead"):
        return False
    session = str(pane.get("session") or "")
    window = str(pane.get("window") or "")
    if not session or not window:
        return False
    try:
        result = subprocess.run(
            ["tmux", "capture-pane", "-p", "-t", f"{session}:{window}", "-S", "-2000"],
            text=True,
            capture_output=True,
            timeout=1,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False
    return result.returncode == 0 and f"ROLE_READY {role}" in result.stdout


def agent_health(
    agent: dict[str, Any],
    route: dict[str, Any] | None,
    pane: dict[str, Any] | None,
    marker: dict[str, str],
    pane_ready: bool,
) -> dict[str, Any]:
    signals: list[str] = []
    severity = "ok"
    label = "Agent ready"
    status = str(agent.get("status") or "").lower()
    marker_matches = ready_marker_matches(marker, pane)

    if not agent.get("live"):
        severity = "watch"
        label = "No live telemetry"
        signals.append("No record exists in agent-control/state/agents.jsonl for this role.")
    elif not pane:
        severity = "stuck"
        label = "tmux pane missing"
        signals.append("Telemetry exists, but no matching tmux pane was found for this session/window.")
    elif pane.get("dead"):
        severity = "stuck"
        label = "tmux pane dead"
        signals.append("The role pane exists but tmux reports it as dead.")
    elif not marker_matches and not pane_ready:
        severity = "watch"
        label = "Readiness marker missing"
        signals.append("No persistent ROLE_READY marker matches the current tmux pane PID.")

    route_health_value = route.get("health") if route else None
    if route_health_value and route_health_value.get("severity") in {"watch", "stuck"}:
        route_severity = str(route_health_value.get("severity"))
        if route_severity == "stuck":
            severity = "stuck"
        elif severity == "ok":
            severity = "watch"
        label = str(route_health_value.get("label") or label)
        signals.extend(str(signal) for signal in route_health_value.get("signals", []))

    last_seen_age = age_seconds(agent.get("last_seen_at"))
    if status in {"launching", "dispatching"} and last_seen_age is not None and last_seen_age > 180:
        if severity == "ok":
            severity = "watch"
        label = f"{status} state is old"
        signals.append(f"Agent has been marked {status} for {last_seen_age}s.")

    blocked_reason = str(agent.get("blocked_reason") or "").strip()
    if blocked_reason and blocked_reason.lower() != "none":
        severity = "stuck"
        label = "Agent blocked"
        signals.append(blocked_reason)

    return {
        "severity": severity,
        "label": label,
        "signals": signals,
        "last_seen_age_seconds": last_seen_age,
        "ready_marker": bool(marker),
        "ready_marker_matches_pane": marker_matches,
        "role_ready_visible_in_pane": pane_ready,
    }


def build_agents(root: Path, routes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    profiles = read_profiles(root)
    telemetry = latest_by(read_jsonl(root / "agent-control" / "state" / "agents.jsonl"), "role")
    panes = tmux_pane_inventory()
    routes_by_id = {str(route.get("route_id")): route for route in routes}
    agents: list[dict[str, Any]] = []
    for profile in profiles:
        role = str(profile.get("role", ""))
        live = telemetry.get(role, {})
        has_live = bool(live)
        marker = ready_marker_for(root, role)
        session = live.get("session", "") or marker.get("session", "")
        window = live.get("window", role) or marker.get("window", role)
        pane = panes.get(f"{session}:{window}") if session else None
        active_route = live.get("active_route", "none") if has_live else "none"
        marker_matches = ready_marker_matches(marker, pane)
        pane_ready = marker_matches or pane_contains_role_ready(pane, role)
        agent = {
            "role": role,
            "display_name": profile.get("display_name") or role.title(),
            "skills": profile.get("skills", []),
            "profile_path": profile.get("profile_path", ""),
            "memory_path": profile.get("memory_path", ""),
            "inbox_path": profile.get("inbox_path", f"agent-control/inbox/{role}.md"),
            "ownership_path": profile.get("ownership_path", ""),
            "profile_status": profile.get("status", ""),
            "load": profile.get("load", ""),
            "live": has_live,
            "status": live.get("status") if has_live else "offline",
            "session": session,
            "window": window,
            "process_status": live.get("process_status", "unknown") if has_live else "unknown",
            "last_seen_at": live.get("last_seen_at", ""),
            "active_route": active_route,
            "active_task": live.get("active_task", "none") if has_live else "none",
            "workdir": live.get("workdir", ""),
            "target_project": live.get("target_project", ""),
            "branch_or_worktree": live.get("branch_or_worktree", "none") if has_live else "none",
            "capacity": live.get("capacity", 1),
            "blocked_reason": live.get("blocked_reason", ""),
            "recovery_owner": live.get("recovery_owner", ""),
            "source": live.get("source", "profile-empty-telemetry") if has_live else "profile-empty-telemetry",
            "pane": pane
            or {
                "session": session,
                "window": window,
                "command": "",
                "dead": None,
                "pane_pid": "",
            },
            "ready_marker": marker,
        }
        agent["health"] = agent_health(agent, routes_by_id.get(str(active_route)), pane, marker, pane_ready)
        agents.append(agent)
    return agents


def build_routes(root: Path) -> list[dict[str, Any]]:
    route_records = latest_by(read_jsonl(root / "agent-control" / "state" / "routes.jsonl"), "route_id")
    reports = parse_route_reports(root)
    merged: dict[str, dict[str, Any]] = {}
    for route_id, report in reports.items():
        merged[route_id] = dict(report)
    for route_id, record in route_records.items():
        merged.setdefault(route_id, {})
        merged[route_id].update(record)
        merged[route_id].setdefault("report", f"agent-control/routes/{route_id}.md")
        merged[route_id]["source"] = "routes-jsonl"
    routes = sorted(merged.values(), key=lambda item: str(item.get("route_id", "")))
    for route in routes:
        route["health"] = route_health(route)
    return routes


def build_health_summary(agents: list[dict[str, Any]], routes: list[dict[str, Any]]) -> dict[str, Any]:
    items: list[dict[str, Any]] = []
    for agent in agents:
        health = agent.get("health", {})
        if health.get("severity") in {"watch", "stuck"}:
            items.append(
                {
                    "kind": "agent",
                    "id": agent.get("role", ""),
                    "severity": health.get("severity", "watch"),
                    "label": health.get("label", ""),
                    "signals": health.get("signals", []),
                }
            )
    for route in routes:
        health = route.get("health", {})
        if health.get("severity") in {"watch", "stuck"}:
            items.append(
                {
                    "kind": "route",
                    "id": route.get("route_id", ""),
                    "severity": health.get("severity", "watch"),
                    "label": health.get("label", ""),
                    "signals": health.get("signals", []),
                }
            )
    return {
        "attention_count": len(items),
        "stuck_count": sum(1 for item in items if item.get("severity") == "stuck"),
        "watch_count": sum(1 for item in items if item.get("severity") == "watch"),
        "items": items[:20],
    }


def build_snapshot(root: Path) -> dict[str, Any]:
    routes = build_routes(root)
    agents = build_agents(root, routes)
    return {
        "generated_at": utc_now(),
        "project_target": read_text(root / "agent-control" / "project-target.md"),
        "profiles": read_profiles(root),
        "agents": agents,
        "routes": routes,
        "workflow": parse_workflow_state(root),
        "events": read_jsonl(root / "agent-control" / "events.jsonl")[-40:],
        "health": build_health_summary(agents, routes),
        "sources": {
            "profiles": "agent-control/company/agent-profiles.jsonl",
            "agents": "agent-control/state/agents.jsonl",
            "routes": "agent-control/state/routes.jsonl",
            "events": "agent-control/events.jsonl",
            "workflow": "agent-control/workflow-state.md",
            "route_reports": "agent-control/routes/*.md",
        },
    }


def route_numbers(root: Path) -> set[int]:
    numbers: set[int] = set()
    def add_route_id(value: Any) -> None:
        match = re.fullmatch(r"R(\d{3,})", str(value or "").strip())
        if match:
            numbers.add(int(match.group(1)))

    for record in read_jsonl(root / "agent-control" / "state" / "routes.jsonl"):
        add_route_id(record.get("route_id"))

    inbox_dir = root / "agent-control" / "inbox"
    if inbox_dir.exists():
        for path in sorted(inbox_dir.glob("*.md")):
            for line in read_text(path).splitlines():
                heading = re.match(r"^##\s+(R\d{3,})\b", line)
                if heading:
                    add_route_id(heading.group(1))

    workflow = read_text(root / "agent-control" / "workflow-state.md")
    for line in workflow.splitlines():
        table_route = re.match(r"^\|\s*(R\d{3,})\s*\|", line)
        if table_route:
            add_route_id(table_route.group(1))

    route_dir = root / "agent-control" / "routes"
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


def capture_agent_pane(root: Path, role: str, lines: int) -> tuple[int, dict[str, Any]]:
    snapshot = build_snapshot(root)
    agent = selected_agent(snapshot, role)
    if agent is None:
        return 400, {"error": "role must match agent-control/company/agent-profiles.jsonl"}
    session = str(agent.get("session") or "")
    window = str(agent.get("window") or role)
    if not session:
        return 200, {
            "role": role,
            "available": False,
            "message": "No tmux session is recorded for this agent.",
            "output": "",
        }
    pane = agent.get("pane") or {}
    if not pane.get("pane_pid"):
        return 200, {
            "role": role,
            "session": session,
            "window": window,
            "available": False,
            "message": f"No tmux pane found for {session}:{window}.",
            "output": "",
            "health": agent.get("health", {}),
        }
    if pane.get("dead"):
        return 200, {
            "role": role,
            "session": session,
            "window": window,
            "available": False,
            "message": f"tmux pane {session}:{window} is dead.",
            "output": "",
            "pane": pane,
            "health": agent.get("health", {}),
        }
    safe_lines = max(20, min(lines, 500))
    target = f"{session}:{window}"
    try:
        result = subprocess.run(
            ["tmux", "capture-pane", "-p", "-t", target, "-S", f"-{safe_lines}"],
            text=True,
            capture_output=True,
            timeout=2,
            check=False,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        return 200, {
            "role": role,
            "session": session,
            "window": window,
            "available": False,
            "message": f"Pane capture failed: {exc}",
            "output": "",
            "pane": pane,
            "health": agent.get("health", {}),
        }
    if result.returncode != 0:
        return 200, {
            "role": role,
            "session": session,
            "window": window,
            "available": False,
            "message": result.stderr.strip() or f"tmux capture failed for {target}.",
            "output": "",
            "pane": pane,
            "health": agent.get("health", {}),
        }
    return 200, {
        "role": role,
        "session": session,
        "window": window,
        "available": True,
        "captured_at": utc_now(),
        "line_limit": safe_lines,
        "output": result.stdout.rstrip(),
        "pane": pane,
        "health": agent.get("health", {}),
    }


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
        return 400, {"error": "role must match agent-control/company/agent-profiles.jsonl"}

    route_id = next_route_id(root)
    display_name = agent.get("display_name") or role
    active_route = str(agent.get("active_route") or "none")
    selected_status = str(agent.get("status") or "offline")
    blocked_reason = str(agent.get("blocked_reason") or "none")
    title = f"Agent Office prompt for {display_name}"
    context_refs = (
        "agent-control/company/agent-profiles.jsonl; "
        "agent-control/state/agents.jsonl; "
        "agent-control/state/routes.jsonl; "
        "agent-control/events.jsonl; "
        "agent-control/workflow-state.md; "
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
            "Classify the request, update source-of-truth workflow files if needed, and route follow-up through agent-control/* files. Keep Orchestrator as the routing authority.",
        ]
    )
    expected_output = (
        f"agent-control/routes/{route_id}.md report, plus any needed agent-control/workflow-state.md, "
        "agent-control/handoffs.md, or inbox route updates."
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
        "report": f"agent-control/routes/{route_id}.md",
        "inbox": "agent-control/inbox/orchestrator.md",
        "workflow_state": "agent-control/workflow-state.md",
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
        if parsed.path == "/api/agent-pane":
            query = parse_qs(parsed.query)
            role = str(query.get("role", [""])[0]).strip()
            line_value = str(query.get("lines", ["180"])[0]).strip()
            try:
                lines = int(line_value)
            except ValueError:
                lines = 180
            status, payload = capture_agent_pane(self.root, role, lines)
            self.send_json(status, payload)
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
