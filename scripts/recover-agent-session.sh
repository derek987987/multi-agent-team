#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/agent-roles.sh"

ROLE="${1:-}"
if [ "$#" -gt 0 ]; then
  shift
fi

SESSION=""
MODE="--dry-run"
ACTION="compact-context"
REASON="agent session recovery"
STATE_FILE="$ROOT/agent-control/state/agents.jsonl"
READY_TIMEOUT="${AGENT_TEAM_RECOVERY_READY_TIMEOUT:-120}"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") <role> [tmux-session] [--dry-run|--apply] [--action compact-context|relaunch-agent] [--reason <text>]

Creates a recovery checkpoint, then either asks the live agent to compact its
context into shared files or relaunches the role pane and sends a resume prompt.
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
    --dry-run|--apply)
      MODE="$1"
      shift
      ;;
    --action)
      require_value "$1" "${2:-}"
      ACTION="$2"
      shift 2
      ;;
    --reason)
      require_value "$1" "${2:-}"
      REASON="$2"
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

case "$ACTION" in
  compact-context|relaunch-agent) ;;
  *)
    printf "Unknown recovery action: %s\n" "$ACTION" >&2
    exit 1
    ;;
esac

json_field() {
  local field="$1"
  [ -f "$STATE_FILE" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r --arg role "$ROLE" --arg session "$SESSION" --arg field "$field" '
    select(.role == $role)
    | select($session == "" or (.session // "") == $session)
    | .[$field] // empty
  ' "$STATE_FILE" 2>/dev/null | tail -n 1
}

SESSION="${SESSION:-$(json_field session)}"
SESSION="${SESSION:-agent-team}"
WINDOW="$(json_field window)"
WINDOW="${WINDOW:-$ROLE}"
ACTIVE_ROUTE="$(json_field active_route)"
ACTIVE_ROUTE="${ACTIVE_ROUTE:-none}"
WORKDIR="$(json_field workdir)"
WORKDIR="${WORKDIR:-$ROOT}"
if [ -d "$WORKDIR" ]; then
  WORKDIR="$(cd "$WORKDIR" && pwd)"
fi

shell_join() {
  printf '%q ' "$@"
}

pane_pid_for() {
  command -v tmux >/dev/null 2>&1 || return 0
  tmux list-panes -a -F '#S:#W #{pane_pid}' 2>/dev/null |
    awk -v target="$SESSION:$WINDOW" '$1 == target { print $2; found = 1 } END { exit found ? 0 : 1 }' || true
}

send_message() {
  local message="$1"
  local buffer="agent-recovery-$ROLE-$$"
  local message_file
  message_file="$(mktemp)"
  printf '%s' "$message" > "$message_file"
  tmux load-buffer -b "$buffer" "$message_file"
  rm -f "$message_file"
  tmux send-keys -t "$SESSION:$WINDOW" C-u
  tmux paste-buffer -d -b "$buffer" -t "$SESSION:$WINDOW"
  tmux send-keys -t "$SESSION:$WINDOW" C-m
}

if [ "$MODE" = "--dry-run" ]; then
  printf "Would %s %s in %s:%s because %s\n" "$ACTION" "$ROLE" "$SESSION" "$WINDOW" "$REASON"
  exit 0
fi

checkpoint="$("$ROOT/scripts/checkpoint-agent-context.sh" "$ROLE" "$SESSION" --reason "$REASON")"
requested_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
mkdir -p "$ROOT/agent-control/state/agent-recovery"

if [ "$ACTION" = "compact-context" ]; then
  pane_pid="$(pane_pid_for)"
  prompt="$(cat <<EOF
CONTEXT CHECKPOINT REQUEST for $ROLE

Reason: $REASON
Recovery checkpoint: $checkpoint
Active route: $ACTIVE_ROUTE

Before doing more work, write a compact progress checkpoint to the active route report and any owned output files. Include completed work, current files touched, decisions made, blockers, validation already run, and the exact next action. If your client supports context compaction, compact only after the file-backed checkpoint is written. Reply exactly: ROLE_CONTEXT_CHECKPOINT $ROLE $ACTIVE_ROUTE
EOF
)"
  if command -v tmux >/dev/null 2>&1 && tmux has-session -t "$SESSION" 2>/dev/null; then
    send_message "$prompt"
  fi
  {
    printf 'role=%s\n' "$ROLE"
    printf 'session=%s\n' "$SESSION"
    printf 'window=%s\n' "$WINDOW"
    printf 'pane_pid=%s\n' "$pane_pid"
    printf 'active_route=%s\n' "$ACTIVE_ROUTE"
    printf 'checkpoint=%s\n' "$checkpoint"
    printf 'requested_at=%s\n' "$requested_at"
  } > "$ROOT/agent-control/state/agent-recovery/$ROLE.context-request"
  "$ROOT/scripts/log-event.sh" agent-context-checkpoint monitor-agent-sessions \
    "Requested context checkpoint for $ROLE" \
    "checkpoint=$checkpoint action=compact-context reason=$REASON" "$ACTIVE_ROUTE" >/dev/null || true
  printf "compact-context %s checkpoint=%s\n" "$ROLE" "$checkpoint"
  exit 0
fi

"$ROOT/scripts/update-agent-state.sh" "$ROLE" \
  --session "$SESSION" \
  --window "$WINDOW" \
  --status launching \
  --active-route "$ACTIVE_ROUTE" \
  --workdir "$WORKDIR" \
  --pid-or-command "codex-role.sh $ROLE" \
  --process-status starting >/dev/null || true

cmd="$(shell_join "$ROOT/scripts/codex-role.sh" "$ROLE" --workdir "$WORKDIR")"
if command -v tmux >/dev/null 2>&1 && tmux has-session -t "$SESSION" 2>/dev/null; then
  if tmux list-panes -a -F '#S:#W' 2>/dev/null | awk -v target="$SESSION:$WINDOW" '$1 == target { found = 1 } END { exit found ? 0 : 1 }'; then
    tmux respawn-pane -k -t "$SESSION:$WINDOW" -c "$WORKDIR" "$cmd"
  else
    tmux new-window -t "$SESSION" -c "$WORKDIR" -n "$WINDOW"
    tmux send-keys -t "$SESSION:$WINDOW" "$cmd" C-m
  fi

  "$ROOT/scripts/wait-for-agent-sessions.sh" "$SESSION" --timeout "$READY_TIMEOUT" --roles "$ROLE" --quiet >/dev/null 2>&1 || true
  prompt="$(cat <<EOF
RECOVERY RESUME for $ROLE

Reason: $REASON
Recovery checkpoint: $checkpoint
Active route before recovery: $ACTIVE_ROUTE

Read the checkpoint first, then continue from the shared source-of-truth files. If Active route is not none and the route is still assigned to you, continue that route and write progress back to the route report before doing more work. Do not ask the human to prompt another role; use handoffs and routes.
EOF
)"
  send_message "$prompt"
fi

{
  printf 'role=%s\n' "$ROLE"
  printf 'session=%s\n' "$SESSION"
  printf 'window=%s\n' "$WINDOW"
  printf 'active_route=%s\n' "$ACTIVE_ROUTE"
  printf 'checkpoint=%s\n' "$checkpoint"
  printf 'requested_at=%s\n' "$requested_at"
} > "$ROOT/agent-control/state/agent-recovery/$ROLE.relaunch-request"

"$ROOT/scripts/log-event.sh" agent-session-relaunch monitor-agent-sessions \
  "Relaunched agent session for $ROLE" \
  "checkpoint=$checkpoint reason=$REASON" "$ACTIVE_ROUTE" >/dev/null || true

printf "relaunch-agent %s checkpoint=%s\n" "$ROLE" "$checkpoint"
