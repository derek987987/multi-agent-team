#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="agent-team"
MODE="--dry-run"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [tmux-session] [--dry-run|--apply]

Checks whether the project is ready for final human review and records a
deduplicated Orchestrator notification in agent-control/state/notifications.jsonl.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run|--apply)
      MODE="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      printf "Unexpected argument: %s\n" "$1" >&2
      usage
      exit 1
      ;;
    *)
      SESSION="$1"
      shift
      ;;
  esac
done

python3 - "$ROOT" "$SESSION" "$MODE" <<'PY'
import json
import pathlib
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone

ROOT = pathlib.Path(sys.argv[1])
SESSION = sys.argv[2]
MODE = sys.argv[3]
APPLY = MODE == "--apply"

NOTIFICATION_ID = "project-complete-ready-for-human"
FINAL_DECISION_SUBJECT_PREFIX = "final ship/no-ship"
ACTIVE_ROUTE_STATUSES = {
    "queued",
    "dispatching",
    "dispatched",
    "acknowledged",
    "in-progress",
    "blocked",
    "pending",
    "ready-for-review",
}
EVIDENCE_REFS = [
    "agent-control/final-cto-review.md",
    "agent-control/final-acceptance.md",
    "agent-control/validation-report.md",
    "agent-control/review-report.md",
    "agent-control/security-report.md",
]
FINAL_DECISION_STATUS = {"approved", "rejected"}


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_utc(value: object) -> datetime | None:
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


def read_text(path: pathlib.Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError:
        return ""


def read_jsonl(path: pathlib.Path) -> list[dict]:
    records: list[dict] = []
    if not path.exists():
        return records
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(record, dict):
            records.append(record)
    return records


def latest_by(records: list[dict], key: str) -> dict[str, dict]:
    latest: dict[str, dict] = {}
    for record in records:
        value = str(record.get(key) or "").strip()
        if value:
            latest[value] = record
    return latest


def parse_field_block(text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip().lower().replace(" ", "_")
        if key and re.fullmatch(r"[a-z0-9_/-]+", key):
            fields.setdefault(key, value.strip())
    return fields


def current_request_id() -> str:
    text = read_text(ROOT / "agent-control" / "workflow-state.md")
    match = re.search(r"^Request ID:[ \t]*(.*?)$", text, re.MULTILINE)
    value = match.group(1).strip() if match else ""
    return value or "current-request"


def active_routes() -> list[str]:
    routes: dict[str, str] = {}
    for route_id, record in latest_by(
        read_jsonl(ROOT / "agent-control" / "state" / "routes.jsonl"), "route_id"
    ).items():
        routes[route_id] = str(record.get("status") or "").strip().lower()

    route_dir = ROOT / "agent-control" / "routes"
    if route_dir.exists():
        for path in sorted(route_dir.glob("R*.md")):
            if path.name == "README.md":
                continue
            fields = parse_field_block(read_text(path))
            route_id = fields.get("route_id") or path.stem
            routes[route_id] = str(fields.get("status") or "").strip().lower()

    return [
        f"{route_id}:{status or 'unknown'}"
        for route_id, status in sorted(routes.items())
        if status in ACTIVE_ROUTE_STATUSES or not status
    ]


def active_tasks() -> list[str]:
    task_board = read_text(ROOT / "agent-control" / "task-board.md")
    active: list[str] = []
    current_task = ""
    for line in task_board.splitlines():
        heading = re.match(r"^###\s+([A-Za-z][0-9]+)\s+-\s*(.+)$", line.strip())
        if heading:
            current_task = f"{heading.group(1)} {heading.group(2)}"
            continue
        match = re.match(r"^Status:\s*(.+)$", line.strip(), re.IGNORECASE)
        if not match:
            continue
        status = match.group(1).strip().lower()
        if status in ACTIVE_ROUTE_STATUSES:
            active.append(f"{current_task or 'unknown task'}:{status}")
    return active


def latest_project_change_at() -> datetime | None:
    timestamps: list[datetime] = []

    for record in latest_by(
        read_jsonl(ROOT / "agent-control" / "state" / "routes.jsonl"), "route_id"
    ).values():
        for field in ("updated", "created"):
            parsed = parse_utc(record.get(field))
            if parsed is not None:
                timestamps.append(parsed)

    for relative in (
        "agent-control/task-board.md",
        "agent-control/final-cto-review.md",
        "agent-control/final-acceptance.md",
        "agent-control/validation-report.md",
        "agent-control/review-report.md",
        "agent-control/security-report.md",
    ):
        path = ROOT / relative
        if not path.exists():
            continue
        timestamps.append(datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc))

    return max(timestamps) if timestamps else None


def latest_final_decision() -> dict | None:
    request_id = current_request_id()
    subject_exact = f"{FINAL_DECISION_SUBJECT_PREFIX}:{request_id}"
    records = latest_by(read_jsonl(ROOT / "agent-control" / "approvals.jsonl"), "approval_id")
    latest: dict | None = None
    latest_at: datetime | None = None

    for record in records.values():
        if str(record.get("subject") or "").strip() != subject_exact:
            continue
        status = str(record.get("status") or "").strip().lower()
        if status not in FINAL_DECISION_STATUS:
            continue
        created = parse_utc(record.get("created"))
        if created is None:
            continue
        if latest_at is None or created > latest_at:
            latest = record
            latest_at = created

    return latest


def final_decision_is_current(record: dict | None) -> bool:
    if not record:
        return False
    created = parse_utc(record.get("created"))
    if created is None:
        return False
    latest_change = latest_project_change_at()
    if latest_change is None:
        return True
    return latest_change <= created + timedelta(seconds=1)


def final_artifact_missing_reason(path: pathlib.Path) -> str:
    if not path.exists():
        return f"missing {path.relative_to(ROOT)}"
    text = read_text(path)
    body_lines = [
        line.strip()
        for line in text.splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    body = "\n".join(body_lines).strip()
    normalized = body.lower()
    if not body:
        return f"{path.relative_to(ROOT)} has no review body"
    if normalized in {"pending", "pending."}:
        return f"{path.relative_to(ROOT)} is still pending"
    if "tbd" in normalized:
        return f"{path.relative_to(ROOT)} still contains TBD"
    return ""


def check_done_reason() -> str:
    result = subprocess.run(
        [str(ROOT / "scripts" / "check-done.sh")],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        cwd=str(ROOT),
        check=False,
    )
    if result.returncode == 0:
        return ""
    summary = " ".join(result.stdout.strip().split())
    return f"check-done failed: {summary or result.returncode}"


def health_reason() -> str:
    result = subprocess.run(
        [str(ROOT / "scripts" / "detect-agent-health.sh"), SESSION],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        cwd=str(ROOT),
        check=False,
    )
    output = result.stdout.strip()
    if result.returncode != 0:
        return f"agent health check failed: {' '.join(output.split()) or result.returncode}"
    if output:
        blocking_findings: list[str] = []
        passthrough_lines: list[str] = []
        for line in output.splitlines():
            stripped = line.strip()
            if not stripped:
                continue
            try:
                finding = json.loads(stripped)
            except json.JSONDecodeError:
                passthrough_lines.append(stripped)
                continue
            if not isinstance(finding, dict):
                passthrough_lines.append(stripped)
                continue
            severity = str(finding.get("severity") or "").strip().lower()
            active_route = str(finding.get("active_route") or "").strip().lower()
            # Idle watch-level findings are advisory cleanup. They should not block
            # the final human review notification once all routed work is done.
            if severity == "watch" and active_route in {"", "none"}:
                continue
            blocking_findings.append(stripped)
        if passthrough_lines:
            return f"agent health needs attention: {' '.join(' '.join(line.split()) for line in passthrough_lines)}"
        if blocking_findings:
            return f"agent health needs attention: {' '.join(' '.join(line.split()) for line in blocking_findings)}"
    return ""


def completion_reasons() -> list[str]:
    reasons: list[str] = []
    routes = active_routes()
    if routes:
        reasons.append("open routes: " + ", ".join(routes[:8]))
    tasks = active_tasks()
    if tasks:
        reasons.append("open tasks: " + ", ".join(tasks[:8]))
    for relative in ("agent-control/final-cto-review.md", "agent-control/final-acceptance.md"):
        reason = final_artifact_missing_reason(ROOT / relative)
        if reason:
            reasons.append(reason)
    done_reason = check_done_reason()
    if done_reason:
        reasons.append(done_reason)
    agent_reason = health_reason()
    if agent_reason:
        reasons.append(agent_reason)
    return reasons


def latest_notification_status(path: pathlib.Path) -> str:
    status = ""
    for record in read_jsonl(path):
        if record.get("notification_id") == NOTIFICATION_ID:
            status = str(record.get("status") or "")
    return status


def append_notification(path: pathlib.Path, status: str, message: str) -> None:
    now = utc_now()
    record = {
        "notification_id": NOTIFICATION_ID,
        "status": status,
        "severity": "action" if status == "active" else "info",
        "target_role": "orchestrator",
        "title": "Project ready for final human review",
        "message": message,
        "source": "check-project-completion-notification",
        "evidence_refs": EVIDENCE_REFS,
        "created": now,
        "updated": now,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, separators=(",", ":")) + "\n")


def update_human_attention(message: str) -> None:
    path = ROOT / "agent-control" / "workflow-state.md"
    text = read_text(path)
    if "## Human Attention Needed" not in text:
        text = text.rstrip() + "\n\n## Human Attention Needed\n\nNone.\n"
    head, tail = text.split("## Human Attention Needed", 1)
    if "\n## " in tail:
        current, rest = tail.split("\n## ", 1)
        next_section = "\n## " + rest
    else:
        current = tail
        next_section = ""
    replacement = f"## Human Attention Needed\n\n{message.strip()}\n"
    path.write_text(head.rstrip() + "\n\n" + replacement + next_section, encoding="utf-8")


def main() -> int:
    notification_path = ROOT / "agent-control" / "state" / "notifications.jsonl"
    notification_path.parent.mkdir(parents=True, exist_ok=True)
    notification_path.touch(exist_ok=True)

    reasons = completion_reasons()
    latest_status = latest_notification_status(notification_path)
    final_decision = latest_final_decision()
    active_message = (
        "Project ready for final human review. Agents report no open routes, "
        "blocking findings, or final acceptance gaps; human ship/no-ship attention is needed.\n\n"
        "Evidence refs:\n"
        + "\n".join(f"- {ref}" for ref in EVIDENCE_REFS)
    )

    if final_decision_is_current(final_decision):
        approval_id = str(final_decision.get("approval_id") or "").strip() or "unknown-approval"
        status = str(final_decision.get("status") or "").strip().lower() or "recorded"
        decision = str(final_decision.get("decision") or "").strip()
        detail = f"Final human decision already recorded: {approval_id} {status}"
        if decision:
            detail += f" ({decision})"
        if APPLY and latest_status == "active":
            append_notification(
                notification_path,
                "dismissed",
                "Project completion notification dismissed because final human decision is already recorded: "
                + detail,
            )
            update_human_attention("None.")
            print("Project completion notification dismissed because final human decision is already recorded.")
            return 0
        if APPLY:
            update_human_attention("None.")
            return 0
        print(detail + ".")
        return 0

    if not reasons:
        if APPLY:
            if latest_status != "active":
                append_notification(notification_path, "active", active_message)
                print("Project ready for final human review.")
            update_human_attention(active_message)
        else:
            print("Project ready for final human review.")
        return 0

    if APPLY and latest_status == "active":
        append_notification(
            notification_path,
            "dismissed",
            "Project completion notification dismissed because completion criteria no longer pass: "
            + "; ".join(reasons),
        )
        update_human_attention("None.")
        print("Project completion notification dismissed because criteria no longer pass.")
        return 0

    if APPLY:
        return 0

    print("Project completion notification not active:")
    for reason in reasons:
        print(f"- {reason}")
    return 0


raise SystemExit(main())
PY
