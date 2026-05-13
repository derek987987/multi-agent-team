#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/agent-roles.sh"

ROLE="${1:-}"
if [ "$#" -gt 0 ]; then
  shift
fi

SESSION=""
REASON="manual checkpoint"
PANE_LINES="${AGENT_CHECKPOINT_PANE_LINES:-180}"
STATE_FILE="$ROOT/agent-control/state/agents.jsonl"
RECOVERY_DIR="$ROOT/agent-control/state/agent-recovery"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") <role> [tmux-session] [--reason <text>] [--pane-lines <n>]

Writes a durable recovery packet for a role before compaction or relaunch.
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

if [ -z "$ROLE" ] || ! is_agent_role "$ROLE"; then
  usage
  exit 1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --reason)
      require_value "$1" "${2:-}"
      REASON="$2"
      shift 2
      ;;
    --pane-lines)
      require_value "$1" "${2:-}"
      PANE_LINES="$2"
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

case "$PANE_LINES" in
  ''|*[!0-9]*)
    printf "Pane line count must be a positive integer: %s\n" "$PANE_LINES" >&2
    exit 1
    ;;
esac

latest_state() {
  [ -f "$STATE_FILE" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r --arg role "$ROLE" --arg session "$SESSION" '
    select(.role == $role)
    | select($session == "" or (.session // "") == $session)
    | [
        (.session // ""),
        (.window // $role),
        (.status // ""),
        (.active_route // "none"),
        (.workdir // ""),
        (.target_project // ""),
        (.blocked_reason // ""),
        (.last_seen_at // "")
      ]
    | @tsv
  ' "$STATE_FILE" 2>/dev/null | tail -n 1
}

state_line="$(latest_state)"
if [ -n "$state_line" ]; then
  IFS=$'\t' read -r state_session window status active_route workdir target_project blocked_reason last_seen_at <<< "$state_line"
else
  state_session="$SESSION"
  window="$ROLE"
  status="unknown"
  active_route="none"
  workdir=""
  target_project=""
  blocked_reason=""
  last_seen_at=""
fi

SESSION="${SESSION:-$state_session}"
window="${window:-$ROLE}"
active_route="${active_route:-none}"
target_project="${target_project:-$(awk -F': ' '/^Path:/ { print $2; exit }' "$ROOT/agent-control/project-target.md" 2>/dev/null || true)}"
target_project="${target_project:-$ROOT}"

capture_pane_tail() {
  if [ -n "$SESSION" ] && command -v tmux >/dev/null 2>&1 && tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux capture-pane -p -t "$SESSION:$window" -S "-$PANE_LINES" 2>/dev/null || true
  fi
}

extract_inbox_route() {
  local route="$1"
  local inbox="$ROOT/agent-control/inbox/$ROLE.md"
  [ -f "$inbox" ] || return 0
  awk -v id="$route" '
    /^## / {
      if (in_route) exit
      in_route = ($2 == id)
    }
    in_route { print }
  ' "$inbox"
}

report_for_route() {
  local route="$1"
  local inbox="$ROOT/agent-control/inbox/$ROLE.md"
  local report=""
  if [ -f "$inbox" ]; then
    report="$(awk -v id="$route" '
      /^## / { in_route = ($2 == id) }
      in_route && /^Completion report:/ { sub(/^Completion report:[[:space:]]*/, ""); print; exit }
    ' "$inbox")"
  fi
  report="${report:-agent-control/routes/$route.md}"
  printf '%s' "$report"
}

git_status_for_target() {
  if [ -d "$target_project" ] && git -C "$target_project" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$target_project" status --short 2>/dev/null || true
  else
    printf 'Target project is not a git worktree or is unavailable.\n'
  fi
}

created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
stamp="$(date -u +"%Y%m%dT%H%M%SZ")"
mkdir -p "$RECOVERY_DIR"
rel_path="agent-control/state/agent-recovery/${stamp}-${ROLE}-$$.md"
checkpoint="$ROOT/$rel_path"
pane_tail="$(capture_pane_tail)"

{
  printf '# Agent Recovery Checkpoint\n\n'
  printf 'Created at: %s\n' "$created_at"
  printf 'Role: %s\n' "$ROLE"
  printf 'Session: %s\n' "${SESSION:-none}"
  printf 'Window: %s\n' "$window"
  printf 'Status: %s\n' "${status:-unknown}"
  printf 'Active route: %s\n' "$active_route"
  printf 'Reason: %s\n' "$REASON"
  printf 'Last seen at: %s\n' "${last_seen_at:-unknown}"
  printf 'Workdir: %s\n' "${workdir:-unknown}"
  printf 'Target project: %s\n' "$target_project"
  printf 'Blocked reason: %s\n' "${blocked_reason:-none}"
  printf '\n## Resume Prompt\n\n'
  printf 'You are resuming the `%s` role after a session recovery or context checkpoint. Read this checkpoint, then read the active route report and inbox packet from the shared source of truth. Continue the same route when Active route is not `none`; otherwise wait for routed work. Preserve decisions and progress in route reports before doing more implementation.\n' "$ROLE"
  printf '\n## Pane Evidence\n\n```text\n%s\n```\n' "$pane_tail"
  printf '\n## Active Inbox Packet\n\n'
  if [ "$active_route" != "none" ]; then
    printf '```markdown\n%s\n```\n' "$(extract_inbox_route "$active_route")"
  else
    printf 'No active route.\n'
  fi
  printf '\n## Active Route Report\n\n'
  if [ "$active_route" != "none" ]; then
    report="$(report_for_route "$active_route")"
    if [ -f "$ROOT/$report" ]; then
      printf 'Source: %s\n\n```markdown\n%s\n```\n' "$report" "$(cat "$ROOT/$report")"
    else
      printf 'Route report not found: %s\n' "$report"
    fi
  else
    printf 'No active route report.\n'
  fi
  printf '\n## Workflow State\n\n```markdown\n%s\n```\n' "$(cat "$ROOT/agent-control/workflow-state.md" 2>/dev/null || true)"
  printf '\n## Handoffs\n\n```markdown\n%s\n```\n' "$(cat "$ROOT/agent-control/handoffs.md" 2>/dev/null || true)"
  printf '\n## Target Git Status\n\n```text\n%s\n```\n' "$(git_status_for_target)"
} > "$checkpoint"

printf '{"created_at":"%s","role":"%s","session":"%s","window":"%s","active_route":"%s","reason":"%s","checkpoint":"%s"}\n' \
  "$(json_escape "$created_at")" \
  "$(json_escape "$ROLE")" \
  "$(json_escape "${SESSION:-}")" \
  "$(json_escape "$window")" \
  "$(json_escape "$active_route")" \
  "$(json_escape "$REASON")" \
  "$(json_escape "$rel_path")" >> "$RECOVERY_DIR/index.jsonl"

printf '%s\n' "$rel_path"
