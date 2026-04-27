#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

if [ "$#" -lt 1 ]; then
  printf "Usage: %s <route-id> [actor]\n" "$(basename "$0")" >&2
  exit 1
fi

ROUTE_ID="$1"
ACTOR="${2:-unknown}"

update_status() {
  local file="$1"
  local heading_prefix="$2"
  local status="$3"
  local tmp
  tmp="$(mktemp)"
  awk -v id="$ROUTE_ID" -v prefix="$heading_prefix" -v status="$status" '
    $0 ~ "^" prefix " " id "([[:space:]-]|$)" { in_route = 1; print; next }
    in_route && $0 ~ "^" prefix " " { in_route = 0 }
    in_route && /^Status:/ { print "Status: " status; next }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

found=0
for inbox in "$ROOT"/.agents/inbox/*.md; do
  if grep -qE "^## $ROUTE_ID([[:space:]-]|$)" "$inbox"; then
    update_status "$inbox" "##" "in-progress"
    found=1
  fi
done

if grep -qE "^### $ROUTE_ID([[:space:]-]|$)" "$ROOT/.agents/handoffs.md"; then
  update_status "$ROOT/.agents/handoffs.md" "###" "accepted"
fi

tmp="$(mktemp)"
awk -v id="$ROUTE_ID" 'BEGIN { FS=OFS="|" } $2 ~ "^[[:space:]]*" id "[[:space:]]*$" { $4 = " in-progress " } { print }' \
  "$ROOT/.agents/workflow-state.md" > "$tmp"
mv "$tmp" "$ROOT/.agents/workflow-state.md"

if [ "$found" -eq 0 ]; then
  printf "Route not found in any inbox: %s\n" "$ROUTE_ID" >&2
  exit 1
fi

"$ROOT/scripts/log-event.sh" route-claimed "$ACTOR" "Claimed route $ROUTE_ID" "" "$ROUTE_ID"
printf '{"route_id":"%s","status":"in-progress","actor":"%s"}\n' \
  "$(json_escape "$ROUTE_ID")" "$(json_escape "$ACTOR")" >> "$ROOT/.agents/state/routes.jsonl"
printf "Claimed route %s\n" "$ROUTE_ID"
