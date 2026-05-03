#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

usage() {
  printf "Usage: %s <route-id> <to-role> <title> [related-task] [--meeting <meeting-id>] [--decision <decision-id>]\n" "$(basename "$0")" >&2
  printf "Example: %s R003 backend \"Implement task API\" T012 --meeting M001 --decision D001\n" "$(basename "$0")" >&2
}

if [ "$#" -lt 3 ]; then
  usage
  exit 1
fi

ROUTE_ID="$1"
TO_ROLE="$2"
TITLE="$3"
RELATED_TASK=""
MEETING_ID=""
DECISION_ID=""

if [ "$#" -gt 3 ]; then
  shift 3
  if [ "${1:-}" != "--meeting" ] && [ "${1:-}" != "--decision" ]; then
    RELATED_TASK="$1"
    shift
  fi
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --meeting)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--meeting requires a value." >&2
          exit 1
        fi
        MEETING_ID="$2"
        shift 2
        ;;
      --decision)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--decision requires a value." >&2
          exit 1
        fi
        DECISION_ID="$2"
        shift 2
        ;;
      *)
        printf "Unexpected argument: %s\n" "$1" >&2
        usage
        exit 1
        ;;
    esac
  done
fi

INBOX="$ROOT/.agents/inbox/$TO_ROLE.md"
HANDOFFS="$ROOT/.agents/handoffs.md"
STATE="$ROOT/.agents/workflow-state.md"
ROUTES_JSONL="$ROOT/.agents/state/routes.jsonl"
CREATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [ ! -f "$INBOX" ]; then
  printf "Unknown role inbox: %s\n" "$INBOX" >&2
  printf "Create .agents/inbox/%s.md first or use one of the existing roles.\n" "$TO_ROLE" >&2
  exit 1
fi

if grep -R -qE "^(##|###)[[:space:]]+$ROUTE_ID([[:space:]-]|$)|^[|][[:space:]]*$ROUTE_ID[[:space:]]*[|]" \
  "$ROOT/.agents/inbox" "$HANDOFFS" "$STATE"; then
  printf "Route ID already exists: %s\n" "$ROUTE_ID" >&2
  exit 1
fi

cat >> "$INBOX" <<ROUTE

## $ROUTE_ID - $TITLE
Status: queued
From: orchestrator
To: $TO_ROLE
Related task: $RELATED_TASK
Meeting ID: $MEETING_ID
Decision ID: $DECISION_ID
Created:
$CREATED

Instruction:
TBD

Expected output:
TBD

Validation / done criteria:
TBD

Response:
ROUTE

cat >> "$HANDOFFS" <<ROUTE

### $ROUTE_ID - $TITLE
Status: open
From: orchestrator
To: $TO_ROLE
Date:
$CREATED
Related task: $RELATED_TASK
Meeting ID: $MEETING_ID
Decision ID: $DECISION_ID
Files / modules:

Request:
See .agents/inbox/$TO_ROLE.md.

Context:
TBD

Acceptance criteria:
- TBD

Response:
ROUTE

tmp="$(mktemp)"
awk -v id="$ROUTE_ID" -v to="$TO_ROLE" -v task="$RELATED_TASK" -v title="$TITLE" '
  /^## Open Routes/ { in_open_routes = 1; print; next }
  /^## / && !/^## Open Routes/ { in_open_routes = 0 }
  BEGIN { inserted = 0 }
  in_open_routes && /^\| Route ID \| To \| Status \| Related Task \| Summary \|/ {
    print
    next
  }
  in_open_routes && /^\| --- \| --- \| --- \| --- \| --- \|/ && !inserted {
    print
    printf "| %s | %s | queued | %s | %s |\n", id, to, task, title
    inserted = 1
    next
  }
  { print }
' "$STATE" > "$tmp"
mv "$tmp" "$STATE"

printf '{"route_id":"%s","to":"%s","status":"queued","related_task":"%s","meeting_id":"%s","decision_id":"%s","title":"%s","created":"%s"}\n' \
  "$(json_escape "$ROUTE_ID")" "$(json_escape "$TO_ROLE")" "$(json_escape "$RELATED_TASK")" "$(json_escape "$MEETING_ID")" "$(json_escape "$DECISION_ID")" "$(json_escape "$TITLE")" "$(json_escape "$CREATED")" >> "$ROUTES_JSONL"

"$ROOT/scripts/log-event.sh" route-created route-agent "Created route $ROUTE_ID for $TO_ROLE" "$TITLE" "$ROUTE_ID"
"$ROOT/scripts/check-route-budget.sh" >/dev/null
printf "Created route %s for %s\n" "$ROUTE_ID" "$TO_ROLE"
