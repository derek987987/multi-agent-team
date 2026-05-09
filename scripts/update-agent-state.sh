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

CONFIG="$ROOT/agent-control/agent-config/$ROLE.yaml"
STATE_FILE="$ROOT/agent-control/state/agents.jsonl"

previous_field() {
  local field="$1"
  [ -f "$STATE_FILE" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg role "$ROLE" --arg field "$field" 'select(.role == $role) | .[$field] // empty' "$STATE_FILE" 2>/dev/null | tail -n 1
  else
    awk -v role="\"role\":\"$ROLE\"" -v field="\"$field\":" '
      index($0, role) {
        pos = index($0, field)
        if (!pos) next
        value = substr($0, pos + length(field))
        sub(/^[[:space:]]*/, "", value)
        if (value ~ /^"/) {
          sub(/^"/, "", value)
          sub(/".*/, "", value)
        } else {
          sub(/[,}].*/, "", value)
        }
        latest = value
      }
      END { print latest }
    ' "$STATE_FILE"
  fi
}

PREV_SESSION="$(previous_field session)"
PREV_WINDOW="$(previous_field window)"
PREV_PID_OR_COMMAND="$(previous_field pid_or_command)"
PREV_PROCESS_STATUS="$(previous_field process_status)"
PREV_STATUS="$(previous_field status)"
PREV_ACTIVE_ROUTE="$(previous_field active_route)"
PREV_ACTIVE_TASK="$(previous_field active_task)"
PREV_WORKDIR="$(previous_field workdir)"
PREV_TARGET_PROJECT="$(previous_field target_project)"
PREV_BRANCH_OR_WORKTREE="$(previous_field branch_or_worktree)"
PREV_CAPACITY="$(previous_field capacity)"
PREV_RECOVERY_OWNER="$(previous_field recovery_owner)"

SESSION="${AGENT_TEAM_SESSION:-$PREV_SESSION}"
WINDOW="${PREV_WINDOW:-$ROLE}"
PID_OR_COMMAND="$PREV_PID_OR_COMMAND"
PROCESS_STATUS="$PREV_PROCESS_STATUS"
STATUS="${PREV_STATUS:-available}"
ACTIVE_ROUTE="${PREV_ACTIVE_ROUTE:-none}"
ACTIVE_TASK="${PREV_ACTIVE_TASK:-none}"
WORKDIR="${PREV_WORKDIR:-$(pwd -P)}"
TARGET_PROJECT="$(awk -F': ' '/^Path:/ { print $2; exit }' "$ROOT/agent-control/project-target.md" 2>/dev/null || true)"
TARGET_PROJECT="${TARGET_PROJECT:-$ROOT}"
BRANCH_OR_WORKTREE="$PREV_BRANCH_OR_WORKTREE"
CAPACITY="$(awk -F':[[:space:]]*' '/^max_parallel_routes:/ { print $2; exit }' "$CONFIG" 2>/dev/null || true)"
CAPACITY="${CAPACITY:-${PREV_CAPACITY:-1}}"
BLOCKED_REASON=""
RECOVERY_OWNER="$(awk -F':[[:space:]]*' '/^escalation_owner:/ { print $2; exit }' "$CONFIG" 2>/dev/null || true)"
RECOVERY_OWNER="${RECOVERY_OWNER:-${PREV_RECOVERY_OWNER:-orchestrator}}"

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
