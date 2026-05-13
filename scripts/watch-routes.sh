#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="${1:-agent-team}"
if [ "$#" -gt 0 ]; then
  shift
fi

MODE="--dry-run"
INTERVAL="${AGENT_TEAM_ROUTE_WATCH_INTERVAL:-5}"
ONCE=0
AUTO_RECOVER_STALE="${AGENT_TEAM_AUTO_RECOVER_STALE:-1}"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [tmux-session] [--send|--dry-run] [--interval <seconds>] [--once]

Polls role inboxes for queued routes and dispatches them to matching Codex tmux windows.
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
    --send|--dry-run)
      MODE="$1"
      shift
      ;;
    --interval)
      require_value "$1" "${2:-}"
      INTERVAL="${2:-}"
      shift 2
      ;;
    --once)
      ONCE=1
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

if [ "$INTERVAL" -lt 1 ]; then
  printf "Interval must be at least 1 second.\n" >&2
  exit 1
fi

printf "watch-routes: session=%s mode=%s interval=%ss\n" "$SESSION" "$MODE" "$INTERVAL"

scan_once() {
  if [ "$MODE" = "--send" ]; then
    if ! command -v tmux >/dev/null 2>&1; then
      printf "watch-routes: tmux is required for --send mode.\n" >&2
      return 1
    fi
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then
      printf "watch-routes: tmux session not found: %s\n" "$SESSION" >&2
      return 1
    fi
    "$ROOT/scripts/monitor-agent-sessions.sh" "$SESSION" --apply || true
  else
    "$ROOT/scripts/monitor-agent-sessions.sh" "$SESSION" --dry-run || true
  fi

  if [ "$AUTO_RECOVER_STALE" != "0" ]; then
    local recover_mode
    local recover_output
    recover_mode="--dry-run"
    if [ "$MODE" = "--send" ]; then
      recover_mode="--apply"
    fi
    recover_output="$(mktemp)"
    if "$ROOT/scripts/recover-stale-routes.sh" "$SESSION" "$recover_mode" >"$recover_output" 2>&1; then
      if ! grep -qx "No stale routes found for recovery." "$recover_output"; then
        cat "$recover_output"
      fi
    else
      cat "$recover_output" >&2
      printf "watch-routes: stale recovery pass failed; continuing dispatch scan\n" >&2
    fi
    rm -f "$recover_output"
  fi

  "$ROOT/scripts/dispatch-routes.sh" "$SESSION" "$MODE"
  printf "watch-routes: scan complete\n"
}

while true; do
  scan_once
  if [ "$ONCE" -eq 1 ]; then
    exit 0
  fi
  sleep "$INTERVAL"
done
