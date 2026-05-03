#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

if [ "$#" -lt 1 ]; then
  printf "Usage: %s <route-id> [actor] [reason] [--report <route-report>]\n" "$(basename "$0")" >&2
  exit 1
fi

ROUTE_ID="$1"
shift
ACTOR="unknown"
REASON="Route blocked"
REPORT=""
UPDATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [ "$#" -gt 0 ] && [ "${1:-}" != "--report" ]; then
  ACTOR="$1"
  shift
fi

if [ "$#" -gt 0 ] && [ "${1:-}" != "--report" ]; then
  REASON="$1"
  shift
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --report)
      if [ -z "${2:-}" ]; then
        printf '%s\n' "--report requires a value." >&2
        exit 1
      fi
      REPORT="$2"
      shift 2
      ;;
    *)
      printf "Unexpected argument: %s\n" "$1" >&2
      exit 1
      ;;
  esac
done

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
for inbox in "$ROOT"/.agents/inbox/*.md; do
  if grep -qE "^## $ROUTE_ID([[:space:]-]|$)" "$inbox"; then
    route_file="$inbox"
    route_role="$(basename "$inbox" .md)"
    found=1
  fi
done

if [ "$found" -eq 0 ]; then
  printf "Route not found in any inbox: %s\n" "$ROUTE_ID" >&2
  exit 1
fi

if [ "$ACTOR" != "dispatch-routes" ] && [ "$ACTOR" != "orchestrator" ] && [ "$ACTOR" != "$route_role" ]; then
  printf "Route %s is assigned to %s, not %s\n" "$ROUTE_ID" "$route_role" "$ACTOR" >&2
  exit 1
fi

update_status "$route_file" "##" "blocked"

if grep -qE "^### $ROUTE_ID([[:space:]-]|$)" "$ROOT/.agents/handoffs.md"; then
  update_status "$ROOT/.agents/handoffs.md" "###" "blocked"
fi

tmp="$(mktemp)"
awk -v id="$ROUTE_ID" 'BEGIN { FS=OFS="|" } $2 ~ "^[[:space:]]*" id "[[:space:]]*$" { $4 = " blocked " } { print }' \
  "$ROOT/.agents/workflow-state.md" > "$tmp"
mv "$tmp" "$ROOT/.agents/workflow-state.md"

if [ -z "$REPORT" ]; then
  REPORT="$(awk -v id="$ROUTE_ID" '
    /^## / { in_route = ($2 == id) }
    in_route && /^Completion report:/ { sub(/^Completion report:[[:space:]]*/, ""); print; exit }
  ' "$route_file")"
fi
REPORT="${REPORT:-.agents/routes/$ROUTE_ID.md}"

case "$REPORT" in
  /*) report_path="$REPORT" ;;
  *) report_path="$ROOT/$REPORT" ;;
esac

if [ -f "$report_path" ]; then
  tmp="$(mktemp)"
  awk -v status="Status: blocked" -v updated="Last updated: $UPDATED" '
    /^Status:/ && !status_done { print status; status_done=1; next }
    /^Last updated:/ && !updated_done { print updated; updated_done=1; next }
    { print }
  ' "$report_path" > "$tmp"
  mv "$tmp" "$report_path"
  cat >> "$report_path" <<REPORT

### Blocked Event

Blocked at: $UPDATED
Blocked by: $ACTOR
Reason: $REASON
REPORT
fi

"$ROOT/scripts/log-event.sh" route-blocked "$ACTOR" "$REASON" "" "$ROUTE_ID"
"$ROOT/scripts/update-agent-state.sh" "$route_role" --status blocked --active-route "$ROUTE_ID" --blocked-reason "$REASON"
printf '{"route_id":"%s","status":"blocked","actor":"%s","reason":"%s","report":"%s","updated":"%s"}\n' \
  "$(json_escape "$ROUTE_ID")" "$(json_escape "$ACTOR")" "$(json_escape "$REASON")" "$(json_escape "$REPORT")" "$(json_escape "$UPDATED")" >> "$ROOT/.agents/state/routes.jsonl"
printf "Blocked route %s\n" "$ROUTE_ID"
