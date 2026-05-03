#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

if [ "$#" -lt 1 ]; then
  printf "Usage: %s <route-id> [actor] [reason]\n" "$(basename "$0")" >&2
  exit 1
fi

ROUTE_ID="$1"
ACTOR="${2:-unknown}"
REASON="${3:-Cancelled route $ROUTE_ID}"
route_role=""

for inbox in "$ROOT"/.agents/inbox/*.md; do
  if grep -qE "^## $ROUTE_ID([[:space:]-]|$)" "$inbox"; then
    route_role="$(basename "$inbox" .md)"
    tmp="$(mktemp)"
    awk -v id="$ROUTE_ID" '
      /^## / { in_route = ($0 ~ "^## " id "([[:space:]-]|$)") }
      in_route && /^Status:/ { print "Status: cancelled"; next }
      { print }
    ' "$inbox" > "$tmp"
    mv "$tmp" "$inbox"
  fi
done

if grep -qE "^### $ROUTE_ID([[:space:]-]|$)" "$ROOT/.agents/handoffs.md"; then
  tmp="$(mktemp)"
  awk -v id="$ROUTE_ID" '
    /^### / { in_route = ($0 ~ "^### " id "([[:space:]-]|$)") }
    in_route && /^Status:/ { print "Status: cancelled"; next }
    { print }
  ' "$ROOT/.agents/handoffs.md" > "$tmp"
  mv "$tmp" "$ROOT/.agents/handoffs.md"
fi

tmp="$(mktemp)"
awk -v id="$ROUTE_ID" 'BEGIN { FS=OFS="|" } $2 ~ "^[[:space:]]*" id "[[:space:]]*$" { $4 = " cancelled " } { print }' \
  "$ROOT/.agents/workflow-state.md" > "$tmp"
mv "$tmp" "$ROOT/.agents/workflow-state.md"

"$ROOT/scripts/log-event.sh" route-cancelled "$ACTOR" "$REASON" "" "$ROUTE_ID"
if [ -n "$route_role" ]; then
  "$ROOT/scripts/update-agent-state.sh" "$route_role" --status available --active-route none --blocked-reason none
fi
printf '{"route_id":"%s","status":"cancelled","actor":"%s","reason":"%s"}\n' \
  "$(json_escape "$ROUTE_ID")" "$(json_escape "$ACTOR")" "$(json_escape "$REASON")" >> "$ROOT/.agents/state/routes.jsonl"
printf "Cancelled route %s\n" "$ROUTE_ID"
