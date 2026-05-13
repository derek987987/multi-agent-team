#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="${1:-agent-team}"
if [ "$#" -gt 0 ]; then
  shift
fi

MODE="--dry-run"
AUTO_RECOVER="${AGENT_TEAM_AUTO_RECOVER_AGENTS:-1}"
RECOVERY_DIR="$ROOT/agent-control/state/agent-recovery"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [tmux-session] [--dry-run|--apply]

Detects stuck or context-pressured role sessions and performs file-backed
checkpoint/recovery actions when --apply is used.
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
    *)
      printf "Unexpected argument: %s\n" "$1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "$AUTO_RECOVER" = "0" ]; then
  exit 0
fi

command -v jq >/dev/null 2>&1 || exit 0
mkdir -p "$RECOVERY_DIR"

marker_matches() {
  local marker="$1"
  local pane_pid="$2"
  local active_route="$3"
  [ -f "$marker" ] || return 1
  grep -qx "pane_pid=$pane_pid" "$marker" 2>/dev/null &&
    grep -qx "active_route=$active_route" "$marker" 2>/dev/null
}

findings="$("$ROOT/scripts/detect-agent-health.sh" "$SESSION")"
[ -n "$findings" ] || exit 0

printf '%s\n' "$findings" |
while IFS= read -r finding; do
  [ -n "$finding" ] || continue
  role="$(printf '%s' "$finding" | jq -r '.role')"
  action="$(printf '%s' "$finding" | jq -r '.action')"
  kind="$(printf '%s' "$finding" | jq -r '.kind')"
  reason="$(printf '%s' "$finding" | jq -r '.reason')"
  active_route="$(printf '%s' "$finding" | jq -r '.active_route')"
  pane_pid="$(printf '%s' "$finding" | jq -r '.pane_pid')"

  case "$action" in
    repair-readiness)
      printf "monitor-agent-sessions: repair-readiness %s: %s\n" "$role" "$reason"
      if [ "$MODE" = "--apply" ]; then
        "$ROOT/scripts/repair-role-readiness.sh" "$SESSION" --quiet || true
      fi
      ;;
    compact-context)
      marker="$RECOVERY_DIR/$role.context-request"
      if marker_matches "$marker" "$pane_pid" "$active_route"; then
        printf "monitor-agent-sessions: compact-context already requested for %s route=%s\n" "$role" "$active_route"
        continue
      fi
      printf "monitor-agent-sessions: compact-context %s: %s\n" "$role" "$reason"
      if [ "$MODE" = "--apply" ]; then
        "$ROOT/scripts/recover-agent-session.sh" "$role" "$SESSION" --apply --action compact-context --reason "$kind: $reason" >/dev/null || true
      fi
      ;;
    relaunch-agent)
      marker="$RECOVERY_DIR/$role.relaunch-request"
      if marker_matches "$marker" "$pane_pid" "$active_route"; then
        printf "monitor-agent-sessions: relaunch already requested for %s route=%s\n" "$role" "$active_route"
        continue
      fi
      printf "monitor-agent-sessions: relaunch-agent %s: %s\n" "$role" "$reason"
      if [ "$MODE" = "--apply" ]; then
        "$ROOT/scripts/recover-agent-session.sh" "$role" "$SESSION" --apply --action relaunch-agent --reason "$kind: $reason" >/dev/null || true
      fi
      ;;
  esac
done
