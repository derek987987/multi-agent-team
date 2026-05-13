#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/agent-roles.sh"

SESSION="${1:-agent-team}"
PANE_LINES="${AGENT_HEALTH_PANE_LINES:-120}"
STATE_FILE="$ROOT/agent-control/state/agents.jsonl"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [tmux-session]

Emits JSONL health findings for role sessions that need prevention or recovery:
readiness telemetry drift, failed/dead panes, missing active panes, and context
pressure that should be checkpointed before a relaunch.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

if [ ! -f "$STATE_FILE" ] || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

pane_info_for() {
  local role="$1"
  command -v tmux >/dev/null 2>&1 || return 1
  tmux list-panes -a -F '#S:#W #{pane_current_command} #{pane_dead} #{pane_pid}' 2>/dev/null |
    awk -v target="$SESSION:$role" '$1 == target { print $2 "\t" $3 "\t" $4; found = 1 } END { exit found ? 0 : 1 }'
}

capture_pane_tail() {
  local role="$1"
  command -v tmux >/dev/null 2>&1 || return 0
  tmux capture-pane -p -t "$SESSION:$role" -S "-$PANE_LINES" 2>/dev/null || true
}

pane_indicates_failed_session() {
  local pane_tail="$1"
  printf '%s' "$pane_tail" | grep -Eiq \
    'stream disconnected|Transport error|error decoding response body|Timeout waiting for child|Falling back from WebSockets|Reconnecting[.][.][.] 5/5|network error'
}

pane_indicates_context_pressure() {
  local pane_tail="$1"
  printf '%s' "$pane_tail" | grep -Eiq \
    'context window warning|context window.*(full|limit|pressure)|[0-9]+%[[:space:]]+context left|context left|context remaining|remaining context|context.*exhaust|auto-compact|compaction'
}

first_matching_line() {
  local pane_tail="$1"
  local pattern="$2"
  printf '%s\n' "$pane_tail" | grep -Ei "$pattern" | head -n 1 || true
}

emit_finding() {
  local role="$1"
  local kind="$2"
  local severity="$3"
  local action="$4"
  local active_route="$5"
  local reason="$6"
  local session="$7"
  local window="$8"
  local pane_pid="$9"
  local evidence="${10:-}"

  printf '{"role":"%s","kind":"%s","severity":"%s","action":"%s","active_route":"%s","reason":"%s","session":"%s","window":"%s","pane_pid":"%s","evidence":"%s"}\n' \
    "$(json_escape "$role")" \
    "$(json_escape "$kind")" \
    "$(json_escape "$severity")" \
    "$(json_escape "$action")" \
    "$(json_escape "$active_route")" \
    "$(json_escape "$reason")" \
    "$(json_escape "$session")" \
    "$(json_escape "$window")" \
    "$(json_escape "$pane_pid")" \
    "$(json_escape "$evidence")"
}

jq -r --arg session "$SESSION" '
  select((.session // "") == $session)
  | [
      .role,
      (.window // .role),
      (.status // ""),
      (.active_route // "none"),
      (.blocked_reason // "")
    ]
  | @tsv
' "$STATE_FILE" 2>/dev/null |
while IFS=$'\t' read -r role window status active_route blocked_reason; do
  [ -n "$role" ] || continue
  is_agent_role "$role" || continue

  pane_info=""
  command=""
  dead=""
  pane_pid=""
  pane_tail=""
  pane_ready=0
  if pane_info="$(pane_info_for "$role")"; then
    IFS=$'\t' read -r command dead pane_pid <<< "$pane_info"
    pane_tail="$(capture_pane_tail "$role")"
    if printf '%s\n' "$pane_tail" | awk -v marker="ROLE_READY $role" '
      index($0, marker) && $0 !~ /exactly:/ && $0 !~ /^[[:space:]]*-/ { found = 1 }
      END { exit found ? 0 : 1 }
    '; then
      pane_ready=1
    fi
  fi

  normalized_status="$(printf '%s' "$status" | tr '[:upper:]' '[:lower:]')"
  normalized_reason="$(printf '%s' "$blocked_reason" | tr '[:upper:]' '[:lower:]')"

  if [ "$normalized_status" = "blocked" ] &&
    printf '%s' "$normalized_reason" | grep -Eiq 'startup|readiness|role_ready|transport fallback|no role_ready marker' &&
    [ "$pane_ready" -eq 1 ]; then
    emit_finding "$role" "readiness-drift" "watch" "repair-readiness" "$active_route" \
      "Role emitted ROLE_READY but structured telemetry still marks startup blocked." \
      "$SESSION" "$window" "$pane_pid" "ROLE_READY $role"
    continue
  fi

  if [ "$active_route" != "none" ] && [ -z "$pane_info" ]; then
    emit_finding "$role" "missing-pane" "stuck" "relaunch-agent" "$active_route" \
      "Active route has no matching tmux pane." "$SESSION" "$window" "" ""
    continue
  fi

  if [ "$active_route" != "none" ] && [ "$dead" = "1" ]; then
    emit_finding "$role" "dead-pane" "stuck" "relaunch-agent" "$active_route" \
      "Active route pane is dead." "$SESSION" "$window" "$pane_pid" ""
    continue
  fi

  if [ "$active_route" != "none" ] && [ -n "$pane_tail" ] && pane_indicates_failed_session "$pane_tail"; then
    emit_finding "$role" "failed-session" "stuck" "relaunch-agent" "$active_route" \
      "Pane output indicates a failed Codex session." "$SESSION" "$window" "$pane_pid" \
      "$(first_matching_line "$pane_tail" 'stream disconnected|Transport error|error decoding response body|Timeout waiting for child|Falling back from WebSockets|Reconnecting[.][.][.] 5/5|network error')"
    continue
  fi

  if [ -n "$pane_tail" ] && pane_indicates_context_pressure "$pane_tail"; then
    emit_finding "$role" "context-pressure" "watch" "compact-context" "$active_route" \
      "Pane output indicates context pressure; checkpoint before recovery is needed." \
      "$SESSION" "$window" "$pane_pid" \
      "$(first_matching_line "$pane_tail" 'context window warning|context window.*(full|limit|pressure)|[0-9]+%[[:space:]]+context left|context left|context remaining|remaining context|context.*exhaust|auto-compact|compaction')"
  fi
done
