#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/agent-roles.sh"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") <role> [options]

Options:
  --session <name>             tmux session name
  --window <name>              tmux window name
  --pid-or-command <value>     process id or launched command
  --process-status <value>     process state such as starting, alive, dead
  --status <value>             available, launching, dispatching, busy, blocked, offline
  --active-route <route-id>    active route id, or none
  --active-task <task-id>      active task id, or none
  --workdir <dir>              role working directory
  --target-project <dir>       coding project target path
  --branch-or-worktree <name>  current branch or worktree label
  --capacity <number>          max active routes
  --blocked-reason <text>      current blocker
  --recovery-owner <role>      owner for recovery/escalation
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

ROLE="${1:-}"
if [ -z "$ROLE" ]; then
  usage
  exit 1
fi
shift || true

if ! is_agent_role "$ROLE"; then
  printf "Unknown role: %s\n" "$ROLE" >&2
  usage
  exit 1
fi

CONFIG="$ROOT/.agents/agent-config/$ROLE.yaml"
SESSION="${AGENT_TEAM_SESSION:-}"
WINDOW="$ROLE"
PID_OR_COMMAND=""
PROCESS_STATUS=""
STATUS="available"
ACTIVE_ROUTE="none"
ACTIVE_TASK="none"
WORKDIR="$(pwd -P)"
TARGET_PROJECT="$(awk -F': ' '/^Path:/ { print $2; exit }' "$ROOT/.agents/project-target.md" 2>/dev/null || true)"
TARGET_PROJECT="${TARGET_PROJECT:-$ROOT}"
BRANCH_OR_WORKTREE=""
CAPACITY="$(awk -F':[[:space:]]*' '/^max_parallel_routes:/ { print $2; exit }' "$CONFIG" 2>/dev/null || true)"
CAPACITY="${CAPACITY:-1}"
BLOCKED_REASON=""
RECOVERY_OWNER="$(awk -F':[[:space:]]*' '/^escalation_owner:/ { print $2; exit }' "$CONFIG" 2>/dev/null || true)"
RECOVERY_OWNER="${RECOVERY_OWNER:-orchestrator}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --session)
      require_value "$1" "${2:-}"
      SESSION="$2"
      shift 2
      ;;
    --window)
      require_value "$1" "${2:-}"
      WINDOW="$2"
      shift 2
      ;;
    --pid-or-command)
      require_value "$1" "${2:-}"
      PID_OR_COMMAND="$2"
      shift 2
      ;;
    --process-status)
      require_value "$1" "${2:-}"
      PROCESS_STATUS="$2"
      shift 2
      ;;
    --status)
      require_value "$1" "${2:-}"
      STATUS="$2"
      shift 2
      ;;
    --active-route)
      require_value "$1" "${2:-}"
      ACTIVE_ROUTE="$2"
      shift 2
      ;;
    --active-task)
      require_value "$1" "${2:-}"
      ACTIVE_TASK="$2"
      shift 2
      ;;
    --workdir)
      require_value "$1" "${2:-}"
      WORKDIR="$2"
      shift 2
      ;;
    --target-project)
      require_value "$1" "${2:-}"
      TARGET_PROJECT="$2"
      shift 2
      ;;
    --branch-or-worktree)
      require_value "$1" "${2:-}"
      BRANCH_OR_WORKTREE="$2"
      shift 2
      ;;
    --capacity)
      require_value "$1" "${2:-}"
      CAPACITY="$2"
      shift 2
      ;;
    --blocked-reason)
      require_value "$1" "${2:-}"
      BLOCKED_REASON="$2"
      shift 2
      ;;
    --recovery-owner)
      require_value "$1" "${2:-}"
      RECOVERY_OWNER="$2"
      shift 2
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

case "$CAPACITY" in
  ''|*[!0-9]*)
    CAPACITY=1
    ;;
esac

if [ -d "$WORKDIR" ]; then
  WORKDIR="$(cd "$WORKDIR" && pwd)"
fi

if [ -d "$TARGET_PROJECT" ]; then
  TARGET_PROJECT="$(cd "$TARGET_PROJECT" && pwd)"
fi

if [ -z "$BRANCH_OR_WORKTREE" ] && git -C "$WORKDIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH_OR_WORKTREE="$(git -C "$WORKDIR" branch --show-current 2>/dev/null || true)"
fi
BRANCH_OR_WORKTREE="${BRANCH_OR_WORKTREE:-none}"

if [ -z "$PROCESS_STATUS" ] && [ -n "$SESSION" ] && command -v tmux >/dev/null 2>&1; then
  if tmux list-panes -a -F '#S:#W #{pane_dead}' 2>/dev/null | awk -v target="$SESSION:$WINDOW" '$1 == target && $2 == "0" { found = 1 } END { exit found ? 0 : 1 }'; then
    PROCESS_STATUS="alive"
  else
    PROCESS_STATUS="unknown"
  fi
fi
PROCESS_STATUS="${PROCESS_STATUS:-unknown}"

if [ -n "$RECOVERY_OWNER" ] && ! is_agent_role "$RECOVERY_OWNER"; then
  printf "Unknown recovery owner for %s: %s\n" "$ROLE" "$RECOVERY_OWNER" >&2
  exit 1
fi

UPDATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
STATE_FILE="$ROOT/.agents/state/agents.jsonl"
mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"

tmp="$(mktemp)"
grep -v "\"role\":\"$(json_escape "$ROLE")\"" "$STATE_FILE" > "$tmp" || true
printf '{"role":"%s","session":"%s","window":"%s","pid_or_command":"%s","process_status":"%s","status":"%s","last_seen_at":"%s","active_route":"%s","active_task":"%s","workdir":"%s","target_project":"%s","branch_or_worktree":"%s","capacity":%s,"blocked_reason":"%s","recovery_owner":"%s","source":"update-agent-state"}\n' \
  "$(json_escape "$ROLE")" \
  "$(json_escape "$SESSION")" \
  "$(json_escape "$WINDOW")" \
  "$(json_escape "$PID_OR_COMMAND")" \
  "$(json_escape "$PROCESS_STATUS")" \
  "$(json_escape "$STATUS")" \
  "$(json_escape "$UPDATED")" \
  "$(json_escape "$ACTIVE_ROUTE")" \
  "$(json_escape "$ACTIVE_TASK")" \
  "$(json_escape "$WORKDIR")" \
  "$(json_escape "$TARGET_PROJECT")" \
  "$(json_escape "$BRANCH_OR_WORKTREE")" \
  "$CAPACITY" \
  "$(json_escape "$BLOCKED_REASON")" \
  "$(json_escape "$RECOVERY_OWNER")" >> "$tmp"
mv "$tmp" "$STATE_FILE"
