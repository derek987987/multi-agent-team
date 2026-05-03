#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

usage() {
  printf "Usage: %s <meeting-id> <title> [participant ...]\n" "$(basename "$0")" >&2
  printf "Example: %s M001 \"Plan functional layer\" orchestrator product cto\n" "$(basename "$0")" >&2
}

if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

MEETING_ID="$1"
TITLE="$2"
shift 2

case "$MEETING_ID" in
  M[0-9]*|M[0-9]*[A-Za-z0-9_-]*) ;;
  *)
    printf "Meeting ID must start with M: %s\n" "$MEETING_ID" >&2
    exit 1
    ;;
esac

participants=""
for participant in "$@"; do
  if [ -z "$participants" ]; then
    participants="$participant"
  else
    participants="$participants, $participant"
  fi
done
[ -n "$participants" ] || participants="orchestrator"

MEETINGS_DIR="$ROOT/.agents/meetings"
STATE_FILE="$ROOT/.agents/state/meetings.jsonl"
CREATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
MEETING_FILE="$MEETINGS_DIR/$MEETING_ID.md"

mkdir -p "$MEETINGS_DIR" "$(dirname "$STATE_FILE")"

if [ -e "$MEETING_FILE" ]; then
  printf "Meeting already exists: %s\n" "$MEETING_FILE" >&2
  exit 1
fi

cat > "$MEETING_FILE" <<EOF
# $MEETING_ID - $TITLE

Status: open
Created: $CREATED
Closed:
Owner: orchestrator
Participants: $participants
Related project:

## Purpose

$TITLE

## Context

Add route, task, project, or media context here.

## Discussion Notes

## Decisions

## Action Items

| Action | Owner | Suggested Task | Suggested Route |
| --- | --- | --- | --- |

## Media Attachments

| Attachment ID | Path | Purpose |
| --- | --- | --- |

## Close Summary
EOF

printf '{"meeting_id":"%s","title":"%s","status":"open","participants":"%s","created":"%s"}\n' \
  "$(json_escape "$MEETING_ID")" "$(json_escape "$TITLE")" "$(json_escape "$participants")" "$(json_escape "$CREATED")" >> "$STATE_FILE"

"$ROOT/scripts/log-event.sh" meeting-created orchestrator "Created meeting $MEETING_ID" "$TITLE" "$MEETING_ID"
printf "Created meeting %s\n" "$MEETING_ID"
