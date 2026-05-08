#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/agent-roles.sh"

SESSION="${1:-agent-team}"
if [ "$#" -gt 0 ]; then
  shift
fi

TIMEOUT="${AGENT_ROLE_READY_TIMEOUT:-180}"
INTERVAL="${AGENT_ROLE_READY_INTERVAL:-2}"
ROLES=("${AGENT_ROLES[@]}")
QUIET=0
MARK_READY=1
READY_DIR="$ROOT/agent-control/state/role-ready"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [tmux-session] [options]

Waits until role tmux panes are running Codex and the role session has emitted
its startup readiness marker: ROLE_READY <role>.

Options:
  --timeout <seconds>  Maximum wait. Default: \$AGENT_ROLE_READY_TIMEOUT or 180.
  --interval <seconds> Poll interval. Default: \$AGENT_ROLE_READY_INTERVAL or 2.
  --roles <list>       Comma-separated role list. Default: all roles.
  --quiet              Only print failures.
  --no-mark-ready      Do not update agent telemetry when a role is ready.
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

split_roles() {
  local value="$1"
  local item
  ROLES=()
  IFS=',' read -r -a ROLES <<< "$value"
  for item in "${ROLES[@]}"; do
    if ! is_agent_role "$item"; then
      printf "Unknown role: %s\n" "$item" >&2
      exit 1
    fi
  done
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --timeout)
      require_value "$1" "${2:-}"
      TIMEOUT="$2"
      shift 2
      ;;
    --interval)
      require_value "$1" "${2:-}"
      INTERVAL="$2"
      shift 2
      ;;
    --roles)
      require_value "$1" "${2:-}"
      split_roles "$2"
      shift 2
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    --no-mark-ready)
      MARK_READY=0
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

case "$TIMEOUT" in
  ''|*[!0-9]*)
    printf "Timeout must be a non-negative integer: %s\n" "$TIMEOUT" >&2
    exit 1
    ;;
esac

case "$INTERVAL" in
  ''|*[!0-9]*)
    printf "Interval must be a positive integer: %s\n" "$INTERVAL" >&2
    exit 1
    ;;
esac

if [ "$INTERVAL" -lt 1 ]; then
  printf "Interval must be at least 1 second.\n" >&2
  exit 1
fi

if ! command -v tmux >/dev/null 2>&1; then
  printf "tmux is required to wait for role sessions.\n" >&2
  exit 1
fi

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  printf "tmux session not found: %s\n" "$SESSION" >&2
  exit 1
fi

pane_info_for() {
  local role="$1"
  tmux list-panes -a -F '#S:#W #{pane_current_command} #{pane_dead} #{pane_pid}' 2>/dev/null |
    awk -v target="$SESSION:$role" '$1 == target { print $2 "\t" $3 "\t" $4; found = 1 } END { exit found ? 0 : 1 }'
}

role_is_ready() {
  local role="$1"
  local info
  local command
  local dead
  local pane_pid
  local capture

  if ! info="$(pane_info_for "$role")"; then
    return 1
  fi
  IFS=$'\t' read -r command dead pane_pid <<< "$info"
  if [ "$dead" != "0" ]; then
    return 1
  fi
  case "$command" in
    codex*) ;;
    *) return 1 ;;
  esac

  capture="$(tmux capture-pane -p -t "$SESSION:$role" -S -2000 2>/dev/null || true)"
  printf '%s\n' "$capture" | grep -Fq "ROLE_READY $role"
}

mark_ready() {
  local role="$1"
  local pane_pid
  local ready_at

  pane_pid="$(tmux list-panes -a -F '#S:#W #{pane_pid}' 2>/dev/null |
    awk -v target="$SESSION:$role" '$1 == target { print $2; found = 1 } END { exit found ? 0 : 1 }' || true)"
  ready_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$READY_DIR"
  {
    printf 'role=%s\n' "$role"
    printf 'session=%s\n' "$SESSION"
    printf 'window=%s\n' "$role"
    printf 'pane_pid=%s\n' "$pane_pid"
    printf 'ready_at=%s\n' "$ready_at"
  } > "$READY_DIR/$role.ready"

  [ "$MARK_READY" -eq 1 ] || return 0
  "$ROOT/scripts/update-agent-state.sh" "$role" \
    --session "$SESSION" \
    --window "$role" \
    --status available \
    --active-route none \
    --pid-or-command "tmux:$SESSION:$role" \
    --process-status alive >/dev/null
}

ready=()
pending=("${ROLES[@]}")
elapsed=0

if [ "$QUIET" -eq 0 ]; then
  printf "Waiting for Codex role readiness in session %s: %s\n" "$SESSION" "${ROLES[*]}"
fi

while true; do
  next_pending=()
  for role in "${pending[@]}"; do
    if role_is_ready "$role"; then
      mark_ready "$role"
      ready+=("$role")
      if [ "$QUIET" -eq 0 ]; then
        printf "Role ready: %s\n" "$role"
      fi
    else
      next_pending+=("$role")
    fi
  done
  pending=()
  if [ "${#next_pending[@]}" -gt 0 ]; then
    pending=("${next_pending[@]}")
  fi

  if [ "${#pending[@]}" -eq 0 ]; then
    if [ "$QUIET" -eq 0 ]; then
      printf "All Codex role sessions ready.\n"
    fi
    exit 0
  fi

  if [ "$elapsed" -ge "$TIMEOUT" ]; then
    printf "Timed out waiting for Codex role readiness after %ss: %s\n" "$TIMEOUT" "${pending[*]}" >&2
    exit 1
  fi

  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done
