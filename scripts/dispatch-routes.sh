#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/agent-roles.sh"
SESSION="${1:-agent-team}"
MODE="${2:---dry-run}"
ROUTES_JSONL="$ROOT/.agents/state/routes.jsonl"
ACK_TIMEOUT="${ROUTE_DISPATCH_ACK_TIMEOUT:-30}"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

prompt_for_role() {
  local role="$1"
  if is_agent_role "$role" && [ -f "$ROOT/.agents/prompts/$role.md" ]; then
    printf ".agents/prompts/%s.md" "$role"
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

  for target in "$ROOT/.agents/inbox/$role.md" "$ROOT/.agents/handoffs.md"; do
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
    "$ROOT/.agents/workflow-state.md" > "$tmp"
  mv "$tmp" "$ROOT/.agents/workflow-state.md"

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
}

route_report_for() {
  local route="$1"
  local role="$2"
  awk -v id="$route" '
    /^## / { in_route = ($2 == id) }
    in_route && /^Completion report:/ { sub(/^Completion report:[[:space:]]*/, ""); print; exit }
  ' "$ROOT/.agents/inbox/$role.md"
}

route_has_tbd_fields() {
  local route="$1"
  local role="$2"
  awk -v id="$route" '
    /^## / { in_route = ($2 == id); next }
    in_route && /^## / { in_route = 0 }
    in_route && ($0 == "TBD" || $0 == "- TBD" || $0 ~ /Draft route/) { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$ROOT/.agents/inbox/$role.md"
}

current_route_status() {
  local route="$1"
  local role="$2"
  awk -v id="$route" '
    /^## / { in_route = ($2 == id) }
    in_route && /^Status:/ { print $2; exit }
  ' "$ROOT/.agents/inbox/$role.md"
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

pane_is_ready() {
  local session="$1"
  local role="$2"
  tmux list-panes -a -F '#S:#W #{pane_current_command} #{pane_dead}' |
    awk -v target="$session:$role" '$1 == target && $3 == "0" { found = 1 } END { exit found ? 0 : 1 }'
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
      blocked|cancelled)
        return 1
        ;;
    esac
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 2
}

for inbox in "$ROOT"/.agents/inbox/*.md; do
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
  report="${report:-.agents/routes/$route.md}"
  message="Route $route queued: $title. Use $prompt, .agents/inbox/$role.md, .agents/handoffs.md, and $report. Read the route report, claim the route with ./scripts/claim-route.sh $route $role, complete role-specific work from shared files, write results to owned outputs and $report, create handoffs when another role is needed, then run ./scripts/complete-route.sh $route $role \"<summary>\" --report $report. If blocked, run ./scripts/block-route.sh $route $role \"<reason>\" --report $report and name the needed owner."
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
    if ! pane_is_ready "$SESSION" "$role"; then
      printf "Pane not ready for route %s: %s:%s\n" "$route" "$SESSION" "$role" >&2
      "$ROOT/scripts/block-route.sh" "$route" dispatch-routes "tmux pane not ready: $SESSION:$role" --report "$report" >/dev/null
      continue
    fi
    update_route_status "$route" "$role" "dispatching" "$report"
    tmux send-keys -t "$SESSION:$role" -l "$message"
    tmux send-keys -t "$SESSION:$role" C-m
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
        capture="$(tmux capture-pane -p -t "$SESSION:$role" -S -40 2>/dev/null || true)"
        printf "Route %s ack timeout for %s after %ss\n" "$route" "$role" "$ACK_TIMEOUT" >&2
        append_report_note "$report" "Dispatch failure" "Ack timeout after ${ACK_TIMEOUT}s. Pane tail:\n\n\`\`\`text\n$capture\n\`\`\`"
        "$ROOT/scripts/block-route.sh" "$route" dispatch-routes "ack timeout after ${ACK_TIMEOUT}s for $SESSION:$role" --report "$report" >/dev/null
        ;;
    esac
  else
    printf "[dry-run] %s -> %s: %s\n" "$route" "$role" "$message"
  fi
done
