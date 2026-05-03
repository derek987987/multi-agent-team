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
UPDATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

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
route_file=""
route_role=""
route_status=""
for inbox in "$ROOT"/.agents/inbox/*.md; do
  if grep -qE "^## $ROUTE_ID([[:space:]-]|$)" "$inbox"; then
    route_file="$inbox"
    route_role="$(basename "$inbox" .md)"
    route_status="$(awk -v id="$ROUTE_ID" '
      /^## / { in_route = ($2 == id) }
      in_route && /^Status:/ { print $2; exit }
    ' "$inbox")"
    found=1
  fi
done

if [ "$found" -eq 0 ]; then
  printf "Route not found in any inbox: %s\n" "$ROUTE_ID" >&2
  exit 1
fi

if [ "$ACTOR" != "$route_role" ]; then
  printf "Route %s is assigned to %s, not %s\n" "$ROUTE_ID" "$route_role" "$ACTOR" >&2
  exit 1
fi

case "$route_status" in
  queued|dispatching|dispatched|acknowledged|in-progress)
    ;;
  *)
    printf "Route %s cannot be claimed from status %s\n" "$ROUTE_ID" "${route_status:-unknown}" >&2
    exit 1
    ;;
esac

update_status "$route_file" "##" "in-progress"

if grep -qE "^### $ROUTE_ID([[:space:]-]|$)" "$ROOT/.agents/handoffs.md"; then
  update_status "$ROOT/.agents/handoffs.md" "###" "accepted"
fi

tmp="$(mktemp)"
awk -v id="$ROUTE_ID" 'BEGIN { FS=OFS="|" } $2 ~ "^[[:space:]]*" id "[[:space:]]*$" { $4 = " in-progress " } { print }' \
  "$ROOT/.agents/workflow-state.md" > "$tmp"
mv "$tmp" "$ROOT/.agents/workflow-state.md"

report="$(awk -v id="$ROUTE_ID" '
  /^## / { in_route = ($2 == id) }
  in_route && /^Completion report:/ { sub(/^Completion report:[[:space:]]*/, ""); print; exit }
' "$route_file")"
report="${report:-.agents/routes/$ROUTE_ID.md}"
if [ -f "$ROOT/$report" ]; then
  tmp="$(mktemp)"
  awk -v status="Status: in-progress" -v updated="Last updated: $UPDATED" '
    /^Status:/ && !status_done { print status; status_done=1; next }
    /^Last updated:/ && !updated_done { print updated; updated_done=1; next }
    { print }
  ' "$ROOT/$report" > "$tmp"
  mv "$tmp" "$ROOT/$report"
fi

"$ROOT/scripts/log-event.sh" route-claimed "$ACTOR" "Claimed route $ROUTE_ID" "" "$ROUTE_ID"
printf '{"route_id":"%s","status":"in-progress","actor":"%s","updated":"%s"}\n' \
  "$(json_escape "$ROUTE_ID")" "$(json_escape "$ACTOR")" "$(json_escape "$UPDATED")" >> "$ROOT/.agents/state/routes.jsonl"
printf "Claimed route %s\n" "$ROUTE_ID"
