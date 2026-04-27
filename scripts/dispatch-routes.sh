#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="${1:-agent-team}"
MODE="${2:---dry-run}"
ROUTES_JSONL="$ROOT/.agents/state/routes.jsonl"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

prompt_for_role() {
  case "$1" in
    orchestrator) printf ".agents/prompts/orchestrator.md" ;;
    cto) printf ".agents/prompts/cto.md" ;;
    pm) printf ".agents/prompts/pm.md" ;;
    frontend) printf ".agents/prompts/frontend.md" ;;
    backend) printf ".agents/prompts/backend.md" ;;
    validation) printf ".agents/prompts/validation.md" ;;
    reviewer) printf ".agents/prompts/reviewer.md" ;;
    security) printf ".agents/prompts/security.md" ;;
    integration) printf ".agents/skills/integration.md" ;;
    *) printf "" ;;
  esac
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
  message="Route $route queued: $title. Use $prompt and .agents/inbox/$role.md."
  if [ "$MODE" = "--send" ]; then
    tmux send-keys -t "$SESSION:$role" -l "$message"
    tmux send-keys -t "$SESSION:$role" C-m
    "$ROOT/scripts/log-event.sh" route-dispatched dispatch-routes "Dispatched $route to $role" "$message" "$route"
    for target in "$ROOT/.agents/inbox/$role.md" "$ROOT/.agents/handoffs.md"; do
      tmp="$(mktemp)"
      awk -v id="$route" '
        /^## / || /^### / { in_route = ($2 == id) }
        in_route && /^Status: queued$/ { print "Status: dispatched"; next }
        in_route && /^Status: open$/ { print "Status: dispatched"; next }
        { print }
      ' "$target" > "$tmp"
      mv "$tmp" "$target"
    done
    tmp="$(mktemp)"
    awk -v id="$route" 'BEGIN { FS=OFS="|" } $2 ~ "^[[:space:]]*" id "[[:space:]]*$" { $4 = " dispatched " } { print }' \
      "$ROOT/.agents/workflow-state.md" > "$tmp"
    mv "$tmp" "$ROOT/.agents/workflow-state.md"
    printf '{"route_id":"%s","to":"%s","status":"dispatched","title":"%s"}\n' \
      "$(json_escape "$route")" "$(json_escape "$role")" "$(json_escape "$title")" >> "$ROUTES_JSONL"
  else
    printf "[dry-run] %s -> %s: %s\n" "$route" "$role" "$message"
  fi
done
