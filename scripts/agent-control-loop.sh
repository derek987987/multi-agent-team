#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="${1:-agent-team}"
if [ "$#" -gt 0 ]; then
  shift
fi

MODE="--send"
INTERVAL="${AGENT_TEAM_CONTROL_LOOP_RESTART_INTERVAL:-5}"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [tmux-session] [--send|--dry-run]

Runs the always-on control loop used in the tmux control window. The loop keeps
agent-session monitoring, stale-route recovery, and route dispatch active.
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

case "$INTERVAL" in
  ''|*[!0-9]*)
    printf "Restart interval must be a positive integer: %s\n" "$INTERVAL" >&2
    exit 1
    ;;
esac

if [ "$INTERVAL" -lt 1 ]; then
  printf "Restart interval must be at least 1 second.\n" >&2
  exit 1
fi

printf "agent-control-loop: session=%s mode=%s restart=%ss\n" "$SESSION" "$MODE" "$INTERVAL"

while true; do
  if "$ROOT/scripts/watch-routes.sh" "$SESSION" "$MODE"; then
    status=0
  else
    status=$?
  fi
  printf "agent-control-loop: watch-routes exited with status %s; restarting in %ss\n" "$status" "$INTERVAL"
  sleep "$INTERVAL"
done
