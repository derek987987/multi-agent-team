#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

usage() {
  printf "Usage: %s <meeting-id> <decision-summary> <action-items>\n" "$(basename "$0")" >&2
  printf "Example: %s M001 \"Functional layer approved\" \"PM creates tasks\"\n" "$(basename "$0")" >&2
}

if [ "$#" -lt 3 ]; then
  usage
  exit 1
fi

MEETING_ID="$1"
DECISION_SUMMARY="$2"
ACTION_ITEMS="$3"
MEETING_FILE="$ROOT/.agents/meetings/$MEETING_ID.md"
CLOSED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [ ! -f "$MEETING_FILE" ]; then
  printf "Unknown meeting: %s\n" "$MEETING_ID" >&2
  exit 1
fi

tmp="$(mktemp)"
awk -v closed="$CLOSED" '
  /^Status: / { print "Status: closed"; next }
  /^Closed:/ { print "Closed: " closed; next }
  { print }
' "$MEETING_FILE" > "$tmp"
mv "$tmp" "$MEETING_FILE"

cat >> "$MEETING_FILE" <<EOF

### Closed $CLOSED

Decision summary:
$DECISION_SUMMARY

Action items:
$ACTION_ITEMS
EOF

printf '{"meeting_id":"%s","status":"closed","decision_summary":"%s","action_items":"%s","closed":"%s"}\n' \
  "$(json_escape "$MEETING_ID")" "$(json_escape "$DECISION_SUMMARY")" "$(json_escape "$ACTION_ITEMS")" "$(json_escape "$CLOSED")" >> "$ROOT/.agents/state/meetings.jsonl"

"$ROOT/scripts/log-event.sh" meeting-closed orchestrator "Closed meeting $MEETING_ID" "$DECISION_SUMMARY" "$MEETING_ID"
printf "Closed meeting %s\n" "$MEETING_ID"
