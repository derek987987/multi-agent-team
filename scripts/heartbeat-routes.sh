#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="${1:-agent-team}"
if [ "$#" -gt 0 ]; then
  shift
fi

MODE="--dry-run"
INTERVAL="${AGENT_TEAM_HEARTBEAT_INTERVAL:-30}"
ONCE=0
RECOVER_STALE="${AGENT_TEAM_AUTO_RECOVER_STALE:-1}"
DB_PATH="${AGENT_TEAM_DB_PATH:-$ROOT/agent-control/state/workflow.sqlite3}"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [tmux-session] [--dry-run|--send] [--interval <seconds>] [--once] [--recover-stale|--no-recover-stale]

Runs a heartbeat-style dispatch pass from the structured route store. Stale
route recovery runs before dispatch by default unless disabled.
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
    --dry-run|--send)
      MODE="$1"
      shift
      ;;
    --interval)
      require_value "$1" "${2:-}"
      INTERVAL="$2"
      shift 2
      ;;
    --once)
      ONCE=1
      shift
      ;;
    --recover-stale)
      RECOVER_STALE=1
      shift
      ;;
    --no-recover-stale)
      RECOVER_STALE=0
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

case "$INTERVAL" in
  ''|*[!0-9]*)
    printf "Interval must be a positive integer: %s\n" "$INTERVAL" >&2
    exit 1
    ;;
esac

"$ROOT/scripts/route-db.sh" init >/dev/null

scan_once() {
  printf "heartbeat-routes: session=%s mode=%s\n" "$SESSION" "$MODE"

  queued="$(sqlite3 -separator $'\t' "$DB_PATH" "SELECT route_id, to_role, title FROM routes WHERE status='queued' ORDER BY priority, created;")"
  if [ -n "$queued" ]; then
    while IFS=$'\t' read -r route role title; do
      [ -n "$route" ] || continue
      printf "queued route %s -> %s: %s\n" "$route" "$role" "$title"
    done <<< "$queued"
  else
    printf "queued route: none\n"
  fi

  if [ "$RECOVER_STALE" != "0" ]; then
    if [ "$MODE" = "--send" ]; then
      "$ROOT/scripts/monitor-agent-sessions.sh" "$SESSION" --apply || true
      "$ROOT/scripts/recover-stale-routes.sh" "$SESSION" --apply
    else
      "$ROOT/scripts/monitor-agent-sessions.sh" "$SESSION" --dry-run || true
      "$ROOT/scripts/recover-stale-routes.sh" "$SESSION" --dry-run
    fi
  fi

  "$ROOT/scripts/promote-ready-task-route.sh" "$SESSION" "$MODE"

  printf "dispatch-routes.sh %s %s\n" "$SESSION" "$MODE"
  if [ "$MODE" = "--send" ]; then
    "$ROOT/scripts/dispatch-routes.sh" "$SESSION" --send
    "$ROOT/scripts/check-project-completion-notification.sh" "$SESSION" --apply || true
  else
    "$ROOT/scripts/dispatch-routes.sh" "$SESSION" --dry-run
    "$ROOT/scripts/check-project-completion-notification.sh" "$SESSION" --dry-run || true
  fi
}

while true; do
  scan_once
  if [ "$ONCE" -eq 1 ]; then
    exit 0
  fi
  sleep "$INTERVAL"
done
