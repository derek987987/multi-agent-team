#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="${1:-agent-team}"
if [ "$#" -gt 0 ]; then
  shift
fi

MODE="--dry-run"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [tmux-session] [--send|--dry-run]

Promotes final CTO review and final PM acceptance routes once all normal
task-board work and validation routes are complete. Human notification remains
blocked until these final agent-owned review artifacts exist.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --send|--dry-run)
      MODE="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf "Unexpected argument: %s\n" "$1" >&2
      usage
      exit 1
      ;;
  esac
done

python3 - "$ROOT" "$MODE" <<'PY'
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(sys.argv[1])
MODE = sys.argv[2]
APPLY = MODE == "--send"

ACTIVE_STATUSES = {
    "queued",
    "dispatching",
    "dispatched",
    "acknowledged",
    "in-progress",
    "blocked",
    "pending",
    "ready-for-review",
}


def read_text(path: pathlib.Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""


def parse_fields(text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        normalized = key.strip().lower().replace(" ", "_").replace("/", "_")
        if normalized:
            fields.setdefault(normalized, value.strip())
    return fields


def final_artifact_pending(relative: str) -> bool:
    path = ROOT / relative
    if not path.exists():
        return True
    body_lines = [
        line.strip()
        for line in read_text(path).splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    body = "\n".join(body_lines).strip().lower()
    return not body or body in {"pending", "pending."} or "tbd" in body


def route_records() -> list[tuple[str, str, str, str]]:
    records: list[tuple[str, str, str, str]] = []
    routes_dir = ROOT / "agent-control" / "routes"
    if not routes_dir.exists():
        return records
    for path in sorted(routes_dir.glob("R[0-9][0-9][0-9].md")):
        text = read_text(path)
        fields = parse_fields(text)
        route_id = fields.get("route_id") or path.stem
        title = path.stem
        lines = text.splitlines()
        first = lines[0] if lines else ""
        match = re.match(r"^#\s+R[0-9]+\s+-\s+(.+)$", first)
        if match:
            title = match.group(1).strip()
        status = fields.get("status", "").strip().lower()
        files = fields.get("files_or_modules", "") or fields.get("files___modules", "")
        records.append((route_id, title, status, files))
    return records


def active_routes() -> list[str]:
    active: list[str] = []
    for route_id, _title, status, _files in route_records():
        if status in ACTIVE_STATUSES or not status:
            active.append(f"{route_id}:{status or 'unknown'}")
    return active


def active_tasks() -> list[str]:
    text = read_text(ROOT / "agent-control" / "task-board.md")
    active: list[str] = []
    current = ""
    for line in text.splitlines():
        heading = re.match(r"^###\s+(T[0-9]+)\s+-\s*(.+)$", line.strip())
        if heading:
            current = f"{heading.group(1)} {heading.group(2)}"
            continue
        status = re.match(r"^Status:\s*(.+)$", line.strip(), re.IGNORECASE)
        if status and status.group(1).strip().lower() in ACTIVE_STATUSES:
            active.append(f"{current or 'unknown task'}:{status.group(1).strip().lower()}")
    return active


def route_exists_for(relative: str) -> bool:
    needle = relative.lower()
    for _route_id, title, status, files in route_records():
        haystack = f"{title}\n{files}".lower()
        if needle in haystack and status in ACTIVE_STATUSES:
            return True
    return False


def next_route_id() -> str:
    max_id = 0
    for path in (ROOT / "agent-control" / "routes").glob("R[0-9][0-9][0-9].md"):
        try:
            max_id = max(max_id, int(path.stem[1:]))
        except ValueError:
            pass
    return f"R{max_id + 1:03d}"


def project_target() -> str:
    text = read_text(ROOT / "agent-control" / "project-target.md")
    for line in text.splitlines():
        if line.startswith("Path:"):
            return line.split(":", 1)[1].strip()
    return str(ROOT)


def run_route(args: list[str]) -> None:
    if APPLY:
        subprocess.run([str(ROOT / "scripts" / "route-agent.sh"), *args], cwd=ROOT, check=True)
    else:
        print(f"promote-final-review-routes: would create {args[0]} for {args[1]} ({args[2]})")


def create_cto_route() -> None:
    run_route(
        [
            next_route_id(),
            "cto",
            "Final CTO Review",
            "FINAL-CTO",
            "--from",
            "orchestrator",
            "--priority",
            "P1",
            "--target-project",
            project_target(),
            "--files",
            "agent-control/final-cto-review.md",
            "--context",
            "All task-board work and validation routes are complete; use agent-control/prompts/final-cto-review.md.",
            "--instruction",
            "Run the final CTO review using agent-control/prompts/final-cto-review.md. Review architecture drift, missing requirements, risky shortcuts, and release-blocking technical debt. Write agent-control/final-cto-review.md, then complete this route.",
            "--expected-output",
            "agent-control/final-cto-review.md contains the final CTO review and any release-blocking architecture findings.",
            "--validation",
            "Command: sed -n '1,260p' agent-control/final-cto-review.md | Expected: final CTO review is no longer Pending/TBD and names release blockers or confirms none.",
        ]
    )


def create_pm_route() -> None:
    run_route(
        [
            next_route_id(),
            "pm",
            "Final PM Acceptance",
            "FINAL-PM",
            "--from",
            "orchestrator",
            "--priority",
            "P1",
            "--target-project",
            project_target(),
            "--files",
            "agent-control/final-acceptance.md",
            "--context",
            "Final CTO review is complete; use agent-control/prompts/final-acceptance.md plus validation and task-board evidence.",
            "--instruction",
            "Run the final PM acceptance review using agent-control/prompts/final-acceptance.md. Compare scope, completed items, incomplete items, known risks, and recommended next milestone. Write agent-control/final-acceptance.md, then complete this route.",
            "--expected-output",
            "agent-control/final-acceptance.md contains completed items, incomplete items, known risks, and recommended next milestone.",
            "--validation",
            "Command: sed -n '1,260p' agent-control/final-acceptance.md | Expected: final acceptance is no longer Pending/TBD and is ready for human ship/no-ship review.",
        ]
    )


if active_routes():
    print("promote-final-review-routes: open route found; skipping")
    raise SystemExit(0)

if active_tasks():
    print("promote-final-review-routes: open task found; skipping")
    raise SystemExit(0)

if final_artifact_pending("agent-control/final-cto-review.md"):
    if route_exists_for("agent-control/final-cto-review.md"):
        print("promote-final-review-routes: final CTO review route already active")
    else:
        create_cto_route()
    raise SystemExit(0)

if final_artifact_pending("agent-control/final-acceptance.md"):
    if route_exists_for("agent-control/final-acceptance.md"):
        print("promote-final-review-routes: final PM acceptance route already active")
    else:
        create_pm_route()
    raise SystemExit(0)

print("promote-final-review-routes: final reviews complete")
PY
