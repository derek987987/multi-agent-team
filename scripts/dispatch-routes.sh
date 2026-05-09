#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/agent-roles.sh"
SESSION="${1:-agent-team}"
MODE="${2:---dry-run}"
ROUTES_JSONL="$ROOT/agent-control/state/routes.jsonl"
ACK_TIMEOUT="${ROUTE_DISPATCH_ACK_TIMEOUT:-20}"
SEND_TIMEOUT="${ROUTE_DISPATCH_SEND_TIMEOUT:-10}"
SUBMIT_DELAY="${ROUTE_DISPATCH_SUBMIT_DELAY:-1}"
TARGET_PATH="$(awk -F': ' '/^Path:/ { print $2; exit }' "$ROOT/agent-control/project-target.md" 2>/dev/null || true)"
TARGET_PATH="${TARGET_PATH:-$ROOT}"

normalize_existing_path() {
  local path="$1"
  if [ -d "$path" ]; then
    (cd "$path" && pwd -P)
  else
    printf "%s" "$path"
  fi
}

ROOT_REAL="$(normalize_existing_path "$ROOT")"
TARGET_REAL="$(normalize_existing_path "$TARGET_PATH")"

case "$ACK_TIMEOUT" in
  ''|*[!0-9]*)
    printf "ROUTE_DISPATCH_ACK_TIMEOUT must be a positive integer: %s\n" "$ACK_TIMEOUT" >&2
    exit 1
    ;;
esac

case "$SEND_TIMEOUT" in
  ''|*[!0-9]*)
    printf "ROUTE_DISPATCH_SEND_TIMEOUT must be a positive integer: %s\n" "$SEND_TIMEOUT" >&2
    exit 1
    ;;
esac

if [ "$ACK_TIMEOUT" -lt 1 ] || [ "$SEND_TIMEOUT" -lt 1 ]; then
  printf "Route dispatch timeouts must be at least 1 second.\n" >&2
  exit 1
fi

case "$SUBMIT_DELAY" in
  ''|*[!0-9.]*)
    printf "ROUTE_DISPATCH_SUBMIT_DELAY must be a non-negative number: %s\n" "$SUBMIT_DELAY" >&2
    exit 1
    ;;
esac

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

agent_workdir_for() {
  local role="$1"
  local state="$ROOT/agent-control/state/agents.jsonl"
  [ -f "$state" ] || return 0
  awk -v role="$role" '
    index($0, "\"role\":\"" role "\"") {
      line = $0
      if (match(line, /"session":"[^"]*"/)) {
        session = substr(line, RSTART + 11, RLENGTH - 12)
      } else {
        session = ""
      }
      if (session != session_filter) {
        next
      }
      if (match(line, /"workdir":"[^"]*"/)) {
        value = substr(line, RSTART + 11, RLENGTH - 12)
      }
    }
    END {
      if (value != "") {
        print value
      }
    }
  ' session_filter="$SESSION" "$state"
}

role_requires_target_workdir() {
  local role="$1"
  role_uses_project_worktree "$role" || [ "$role" = "integration" ]
}

role_workdir_matches_target() {
  local role="$1"
  local workdir
  local workdir_real

  role_requires_target_workdir "$role" || return 0
  [ "$TARGET_REAL" != "$ROOT_REAL" ] || return 0

  workdir="$(agent_workdir_for "$role")"
  [ -n "$workdir" ] || return 0

  workdir_real="$(normalize_existing_path "$workdir")"
  [ "$workdir_real" = "$TARGET_REAL" ]
}

prompt_for_role() {
  local role="$1"
  if is_agent_role "$role" && [ -f "$ROOT/agent-control/prompts/$role.md" ]; then
    printf "agent-control/prompts/%s.md" "$role"
  else
    printf ""
  fi
}

update_route_status() {
  local route="$1"
  local role="$2"
  local status="$3"
  local report="$4"
  local updated
  updated="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  for target in "$ROOT/agent-control/inbox/$role.md" "$ROOT/agent-control/handoffs.md"; do
    [ -f "$target" ] || continue
    tmp="$(mktemp)"
    awk -v id="$route" -v status="$status" '
      /^## / || /^### / { in_route = ($2 == id) }
      in_route && /^Status:/ { print "Status: " status; next }
      { print }
    ' "$target" > "$tmp"
    mv "$tmp" "$target"
  done

  tmp="$(mktemp)"
  awk -v id="$route" -v status="$status" 'BEGIN { FS=OFS="|" } $2 ~ "^[[:space:]]*" id "[[:space:]]*$" { $4 = " " status " " } { print }' \
    "$ROOT/agent-control/workflow-state.md" > "$tmp"
  mv "$tmp" "$ROOT/agent-control/workflow-state.md"

  if [ -n "$report" ] && [ -f "$ROOT/$report" ]; then
    tmp="$(mktemp)"
    awk -v status_line="Status: $status" -v updated_line="Last updated: $updated" '
      /^Status:/ && !status_done { print status_line; status_done=1; next }
      /^Last updated:/ && !updated_done { print updated_line; updated_done=1; next }
      { print }
    ' "$ROOT/$report" > "$tmp"
    mv "$tmp" "$ROOT/$report"
  fi

  printf '{"route_id":"%s","to":"%s","status":"%s","updated":"%s"}\n' \
    "$(json_escape "$route")" "$(json_escape "$role")" "$(json_escape "$status")" "$(json_escape "$updated")" >> "$ROUTES_JSONL"
  "$ROOT/scripts/route-db.sh" update-status "$route" "$status" \
    --actor dispatch-routes \
    --note "dispatch status update for $role" \
    --updated "$updated" >/dev/null
}

route_report_for() {
  local route="$1"
  local role="$2"
  awk -v id="$route" '
    /^## / { in_route = ($2 == id) }
    in_route && /^Completion report:/ { sub(/^Completion report:[[:space:]]*/, ""); print; exit }
  ' "$ROOT/agent-control/inbox/$role.md"
}

route_has_tbd_fields() {
  local route="$1"
  local role="$2"
  awk -v id="$route" '
    /^## / { in_route = ($2 == id); next }
    in_route && /^## / { in_route = 0 }
    in_route && ($0 == "TBD" || $0 == "- TBD" || $0 ~ /Draft route/) { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$ROOT/agent-control/inbox/$role.md"
}

current_route_status() {
  local route="$1"
  local role="$2"
  awk -v id="$route" '
    /^## / { in_route = ($2 == id) }
    in_route && /^Status:/ { print $2; exit }
  ' "$ROOT/agent-control/inbox/$role.md"
}

append_report_note() {
  local report="$1"
  local heading="$2"
  local body="$3"
  [ -n "$report" ] || return 0
  [ -f "$ROOT/$report" ] || return 0
  {
    printf '\n### %s\n\n' "$heading"
    printf '%s\n' "$body"
  } >> "$ROOT/$report"
}

run_with_timeout() {
  local timeout="$1"
  shift
  local pid
  local watcher
  local status
  local timeout_flag

  "$@" &
  pid="$!"
  timeout_flag="$(mktemp)"
  rm -f "$timeout_flag"
  (
    sleep "$timeout"
    if kill -0 "$pid" 2>/dev/null; then
      : > "$timeout_flag"
      kill "$pid" 2>/dev/null || true
    fi
  ) &
  watcher="$!"

  set +e
  wait "$pid"
  status="$?"
  set -e
  if [ -f "$timeout_flag" ]; then
    wait "$watcher" 2>/dev/null || true
    rm -f "$timeout_flag"
    return 124
  fi
  kill "$watcher" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true
  rm -f "$timeout_flag"
  return "$status"
}

send_route_message() {
  local session="$1"
  local role="$2"
  local route="$3"
  local message="$4"
  local buffer="agent-route-$route-$$"
  local message_file

  message_file="$(mktemp)"
  printf '%s' "$message" > "$message_file"
  if ! run_with_timeout "$SEND_TIMEOUT" tmux load-buffer -b "$buffer" "$message_file"; then
    rm -f "$message_file"
    tmux delete-buffer -b "$buffer" 2>/dev/null || true
    return 124
  fi
  rm -f "$message_file"

  if ! run_with_timeout "$SEND_TIMEOUT" tmux send-keys -t "$session:$role" C-u; then
    tmux delete-buffer -b "$buffer" 2>/dev/null || true
    return 124
  fi
  sleep 0.1

  if ! run_with_timeout "$SEND_TIMEOUT" tmux paste-buffer -d -b "$buffer" -t "$session:$role"; then
    tmux delete-buffer -b "$buffer" 2>/dev/null || true
    return 124
  fi

  if [ "$SUBMIT_DELAY" != "0" ] && [ "$SUBMIT_DELAY" != "0.0" ]; then
    sleep "$SUBMIT_DELAY"
  fi

  if ! run_with_timeout "$SEND_TIMEOUT" tmux send-keys -t "$session:$role" C-m; then
    return 124
  fi

  sleep 0.2
  run_with_timeout "$SEND_TIMEOUT" tmux send-keys -t "$session:$role" Tab
}

role_pane_info() {
  local session="$1"
  local role="$2"
  tmux list-panes -a -F '#S:#W #{pane_current_command} #{pane_dead} #{pane_pid}' 2>/dev/null |
    awk -v target="$session:$role" '$1 == target { print $2 "\t" $3 "\t" $4; found = 1 } END { exit found ? 0 : 1 }'
}

ready_marker_matches() {
  local session="$1"
  local role="$2"
  local pane_pid="$3"
  local marker="$ROOT/agent-control/state/role-ready/$role.ready"
  local marker_session
  local marker_window
  local marker_pid

  [ -n "$pane_pid" ] || return 1
  [ -f "$marker" ] || return 1
  marker_session="$(awk -F= '$1 == "session" { print substr($0, index($0, "=") + 1); exit }' "$marker")"
  marker_window="$(awk -F= '$1 == "window" { print substr($0, index($0, "=") + 1); exit }' "$marker")"
  marker_pid="$(awk -F= '$1 == "pane_pid" { print substr($0, index($0, "=") + 1); exit }' "$marker")"

  [ "$marker_session" = "$session" ] && [ "$marker_window" = "$role" ] && [ "$marker_pid" = "$pane_pid" ]
}

role_session_ready() {
  local session="$1"
  local role="$2"
  local info
  local command
  local dead
  local pane_pid

  if ! info="$(role_pane_info "$session" "$role")"; then
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

  if "$ROOT/scripts/wait-for-agent-sessions.sh" "$session" \
    --roles "$role" \
    --timeout 0 \
    --interval 1 \
    --quiet >/dev/null 2>&1; then
    return 0
  fi

  ready_marker_matches "$session" "$role" "$pane_pid"
}

wait_for_ack() {
  local route="$1"
  local role="$2"
  local elapsed=0
  local status
  while [ "$elapsed" -lt "$ACK_TIMEOUT" ]; do
    status="$(current_route_status "$route" "$role")"
    case "$status" in
      in-progress|done)
        return 0
        ;;
      acknowledged)
        return 0
        ;;
      blocked|cancelled)
        return 1
        ;;
    esac
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 2
}

for inbox in "$ROOT"/agent-control/inbox/*.md; do
  role="$(basename "$inbox" .md)"
  prompt="$(prompt_for_role "$role")"
  awk -v role="$role" -v prompt="$prompt" '
    /^## R[0-9]+/ { route = $2; title = substr($0, index($0, "-") + 2) }
    /^Status: queued$/ {
      printf "%s\t%s\t%s\t%s\n", role, route, prompt, title
    }
  ' "$inbox"
done | while IFS=$'\t' read -r role route prompt title; do
  if [ -z "$prompt" ]; then
    printf "No prompt mapping for role %s route %s\n" "$role" "$route" >&2
    continue
  fi
  report="$(route_report_for "$route" "$role")"
  report="${report:-agent-control/routes/$route.md}"
  message="Route $route queued: $title. Use $prompt, agent-control/inbox/$role.md, agent-control/handoffs.md, and $report. First, read the route report enough to confirm the assignment, then immediately claim the route with ./scripts/claim-route.sh $route $role before extended context loading. Complete role-specific work from shared files, write results to owned outputs and $report, create handoffs when another role is needed, then run ./scripts/complete-route.sh $route $role \"<summary>\" --report $report. If blocked, run ./scripts/block-route.sh $route $role \"<reason>\" --report $report and name the needed owner."
  if [ "$MODE" = "--send" ]; then
    if route_has_tbd_fields "$route" "$role"; then
      printf "Route %s for %s contains TBD fields; blocking instead of dispatching.\n" "$route" "$role" >&2
      "$ROOT/scripts/block-route.sh" "$route" dispatch-routes "Route has TBD fields; fill instruction, expected output, and validation before dispatch." --report "$report" >/dev/null
      continue
    fi
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then
      printf "Session not found for route %s: %s\n" "$route" "$SESSION" >&2
      "$ROOT/scripts/block-route.sh" "$route" dispatch-routes "tmux session not found: $SESSION" --report "$report" >/dev/null
      continue
    fi
    if ! role_workdir_matches_target "$role"; then
      role_workdir="$(agent_workdir_for "$role")"
      reason="project-writing role launched from ${role_workdir:-unknown}; expected target workdir $TARGET_PATH. Relaunch $SESSION:$role with $ROOT/scripts/codex-role.sh $role --workdir $TARGET_PATH before dispatching target-writing routes."
      printf "Role workdir mismatch for route %s: %s\n" "$route" "$reason" >&2
      "$ROOT/scripts/update-agent-state.sh" "$role" \
        --session "$SESSION" \
        --window "$role" \
        --status blocked \
        --active-route "$route" \
        --blocked-reason "$reason" \
        --target-project "$TARGET_PATH" \
        --pid-or-command "tmux:$SESSION:$role" \
        --process-status alive
      continue
    fi
    if ! role_session_ready "$SESSION" "$role"; then
      printf "Role session not ready for route %s: %s:%s; leaving queued\n" "$route" "$SESSION" "$role" >&2
      "$ROOT/scripts/update-agent-state.sh" "$role" \
        --session "$SESSION" \
        --window "$role" \
        --status launching \
        --active-route none \
        --target-project "$TARGET_PATH" \
        --pid-or-command "tmux:$SESSION:$role" \
        --process-status starting
      continue
    fi
    update_route_status "$route" "$role" "dispatching" "$report"
    "$ROOT/scripts/update-agent-state.sh" "$role" \
      --session "$SESSION" \
      --window "$role" \
      --status dispatching \
      --active-route "$route" \
      --target-project "$TARGET_PATH" \
      --pid-or-command "tmux:$SESSION:$role" \
      --process-status alive
    if ! send_route_message "$SESSION" "$role" "$route" "$message"; then
      capture="$(tmux capture-pane -p -t "$SESSION:$role" -S -40 2>/dev/null || true)"
      printf "Route %s tmux delivery timeout for %s after %ss\n" "$route" "$role" "$SEND_TIMEOUT" >&2
      append_report_note "$report" "Dispatch failure" "tmux message delivery timed out after ${SEND_TIMEOUT}s. Pane tail:\n\n\`\`\`text\n$capture\n\`\`\`"
      "$ROOT/scripts/update-agent-state.sh" "$role" \
        --session "$SESSION" \
        --window "$role" \
        --status blocked \
        --active-route "$route" \
        --blocked-reason "tmux delivery timeout after ${SEND_TIMEOUT}s" \
        --target-project "$TARGET_PATH" \
        --pid-or-command "tmux:$SESSION:$role" \
        --process-status unknown
      "$ROOT/scripts/block-route.sh" "$route" dispatch-routes "tmux delivery timeout after ${SEND_TIMEOUT}s for $SESSION:$role" --report "$report" >/dev/null
      continue
    fi
    "$ROOT/scripts/log-event.sh" route-dispatched dispatch-routes "Dispatched $route to $role" "$message" "$route"
    update_route_status "$route" "$role" "dispatched" "$report"
    ack_status=0
    wait_for_ack "$route" "$role" || ack_status="$?"
    case "$ack_status" in
      0)
        "$ROOT/scripts/log-event.sh" route-acknowledged dispatch-routes "Route $route acknowledged by $role" "" "$route"
        ;;
      1)
        printf "Route %s left dispatch wait with status %s\n" "$route" "$(current_route_status "$route" "$role")" >&2
        ;;
      2)
        final_status="$(current_route_status "$route" "$role")"
        case "$final_status" in
          in-progress|acknowledged)
            "$ROOT/scripts/update-agent-state.sh" "$role" \
              --session "$SESSION" \
              --window "$role" \
              --status busy \
              --active-route "$route" \
              --blocked-reason none \
              --target-project "$TARGET_PATH" \
              --pid-or-command "tmux:$SESSION:$role" \
              --process-status alive
            "$ROOT/scripts/log-event.sh" route-acknowledged dispatch-routes "Route $route acknowledged by $role after timeout boundary" "" "$route"
            ;;
          done)
            "$ROOT/scripts/log-event.sh" route-acknowledged dispatch-routes "Route $route completed by $role after timeout boundary" "" "$route"
            ;;
          blocked|cancelled)
            printf "Route %s changed to %s after dispatch wait\n" "$route" "$final_status" >&2
            ;;
          *)
            capture="$(tmux capture-pane -p -t "$SESSION:$role" -S -40 2>/dev/null || true)"
            printf "Route %s still awaiting claim by %s after %ss; leaving dispatched for stale recovery\n" "$route" "$role" "$ACK_TIMEOUT" >&2
            append_report_note "$report" "Dispatch acknowledgement pending" "No route claim after ${ACK_TIMEOUT}s. Route remains dispatched so the role can still claim it; stale-route recovery owns retry/block decisions. Pane tail:\n\n\`\`\`text\n$capture\n\`\`\`"
            "$ROOT/scripts/update-agent-state.sh" "$role" \
              --session "$SESSION" \
              --window "$role" \
              --status dispatching \
              --active-route "$route" \
              --blocked-reason none \
              --target-project "$TARGET_PATH" \
              --pid-or-command "tmux:$SESSION:$role" \
              --process-status alive
            "$ROOT/scripts/log-event.sh" route-ack-pending dispatch-routes "Route $route not claimed after ${ACK_TIMEOUT}s; left dispatched" "" "$route"
            ;;
        esac
        ;;
    esac
  else
    printf "[dry-run] %s -> %s: %s\n" "$route" "$role" "$message"
  fi
done
