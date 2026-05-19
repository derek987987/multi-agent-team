#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$SCRIPT_ROOT"
SESSION=""
STATUS=""
DECISION=""
ACTOR="human"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [tmux-session] --status approved|rejected --decision <text> [--actor <actor>]

Records the final human ship/no-ship decision for the current active request,
updates workflow state, and syncs the project-complete notification.
EOF
}

require_value() {
  local flag="$1"
  local value="${2:-}"
  if [ -z "$value" ]; then
    printf "%s requires a value.\n" "$flag" >&2
    exit 1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --status)
      require_value "$1" "${2:-}"
      STATUS="$2"
      shift 2
      ;;
    --decision)
      require_value "$1" "${2:-}"
      DECISION="$2"
      shift 2
      ;;
    --actor)
      require_value "$1" "${2:-}"
      ACTOR="$2"
      shift 2
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
      if [ -n "$SESSION" ]; then
        printf "Unexpected argument: %s\n" "$1" >&2
        usage
        exit 1
      fi
      SESSION="$1"
      shift
      ;;
  esac
done

case "$STATUS" in
  approved|rejected) ;;
  *)
    printf "Invalid status: %s\n" "$STATUS" >&2
    usage
    exit 1
    ;;
esac

if [ -z "$DECISION" ]; then
  usage
  exit 1
fi

SESSION="${SESSION:-agent-team}"

is_agent_team_root() {
  local candidate="$1"
  [ -n "$candidate" ] \
    && [ -f "$candidate/agent-control/workflow-state.md" ] \
    && [ -x "$candidate/scripts/record-approval.sh" ] \
    && [ -x "$candidate/scripts/check-project-completion-notification.sh" ]
}

resolve_session_root() {
  local session="$1"
  local candidate=""
  local window=""
  local instance_root="${AGENT_TEAM_INSTANCE_ROOT:-/Users/hay/Documents/agent-team-instances}"
  local session_stem="${session#agent-}"

  if [ -n "$session" ] && command -v tmux >/dev/null 2>&1 && tmux has-session -t "$session" 2>/dev/null; then
    for window in control office orchestrator; do
      candidate="$(tmux display-message -p -t "$session:$window" '#{pane_current_path}' 2>/dev/null || true)"
      if is_agent_team_root "$candidate"; then
        (cd "$candidate" && pwd)
        return 0
      fi
    done
  fi

  for candidate in "$instance_root/$session_stem-team" "$instance_root/$session-team"; do
    if is_agent_team_root "$candidate"; then
      (cd "$candidate" && pwd)
      return 0
    fi
  done

  return 1
}

if resolved_root="$(resolve_session_root "$SESSION")"; then
  ROOT="$resolved_root"
fi

approval_id="$(
  python3 - "$ROOT" <<'PY'
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
paths = [
    root / "agent-control" / "approvals.jsonl",
    root / "agent-control" / "state" / "approvals.jsonl",
]
max_value = 0
pattern = re.compile(r"^AP(\d+)$")

for path in paths:
    if not path.exists():
        continue
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(record, dict):
            continue
        match = pattern.match(str(record.get("approval_id") or "").strip())
        if match:
            max_value = max(max_value, int(match.group(1)))

print(f"AP{max_value + 1:03d}")
PY
)"

request_id="$(
  python3 - "$ROOT/agent-control/workflow-state.md" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8") if path.exists() else ""
match = re.search(r"^Request ID:[ \t]*(.*?)$", text, re.MULTILINE)
value = match.group(1).strip() if match else ""
print(value or "current-request")
PY
)"

subject="final ship/no-ship:${request_id}"
"$ROOT/scripts/record-approval.sh" "$approval_id" "$ACTOR" "$subject" "$STATUS" "$DECISION" >/dev/null

python3 - "$ROOT/agent-control/workflow-state.md" "$STATUS" "$DECISION" "$ACTOR" <<'PY'
from __future__ import annotations

import pathlib
import re
import sys
from datetime import datetime, timezone

path = pathlib.Path(sys.argv[1])
status = sys.argv[2]
decision = sys.argv[3]
actor = sys.argv[4]
text = path.read_text(encoding="utf-8") if path.exists() else ""
today = datetime.now(timezone.utc).strftime("%Y-%m-%d")


def replace_field(source: str, label: str, value: str) -> str:
    pattern = re.compile(rf"^{re.escape(label)}:.*$", re.MULTILINE)
    replacement = f"{label}: {value}"
    if pattern.search(source):
        return pattern.sub(replacement, source, count=1)
    return source


def replace_table_status(source: str, phase_name: str, value: str) -> str:
    pattern = re.compile(
        rf"^(\|\s*{re.escape(phase_name)}\s*\|\s*)([^|]+)(\|\s*[^|]+\|\s*.+)$",
        re.MULTILINE,
    )
    return pattern.sub(lambda m: f"{m.group(1)}{value} {m.group(3)}", source, count=1)


text = replace_field(path.read_text(encoding="utf-8") if path.exists() else "", "Last updated", today)
text = replace_field(text, "Updated by", actor)
text = replace_field(text, "Status", "ship-approved" if status == "approved" else "ship-rejected")
text = replace_table_status(text, "acceptance", "complete" if status == "approved" else "active")

human_attention = "None."
if "## Human Attention Needed" not in text:
    text = text.rstrip() + "\n\n## Human Attention Needed\n\nNone.\n"

head, tail = text.split("## Human Attention Needed", 1)
if "\n## " in tail:
    _, rest = tail.split("\n## ", 1)
    next_section = "\n## " + rest
else:
    next_section = ""

text = head.rstrip() + "\n\n## Human Attention Needed\n\n" + human_attention + "\n" + next_section
path.write_text(text, encoding="utf-8")
PY

"$ROOT/scripts/check-project-completion-notification.sh" "$SESSION" --apply >/dev/null

printf '%s\n' "$approval_id"
