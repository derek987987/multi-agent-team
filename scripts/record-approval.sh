#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

usage() {
  printf "Usage: %s <approval-id> <actor> <subject> <status> <decision> [meeting-id]\n" "$(basename "$0")" >&2
  printf "Example: %s AP001 human \"brief\" approved \"Proceed\" M001\n" "$(basename "$0")" >&2
}

if [ "$#" -lt 5 ]; then
  usage
  exit 1
fi

APPROVAL_ID="$1"
ACTOR="$2"
SUBJECT="$3"
STATUS="$4"
DECISION="$5"
MEETING_ID="${6:-}"
CREATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

case "$STATUS" in
  approved|rejected|accepted-risk|revoked) ;;
  *)
    printf "Invalid approval status: %s\n" "$STATUS" >&2
    exit 1
    ;;
esac

mkdir -p "$ROOT/.agents/state"

record="$(printf '{"approval_id":"%s","actor":"%s","subject":"%s","status":"%s","decision":"%s","meeting_id":"%s","created":"%s"}' \
  "$(json_escape "$APPROVAL_ID")" "$(json_escape "$ACTOR")" "$(json_escape "$SUBJECT")" "$(json_escape "$STATUS")" "$(json_escape "$DECISION")" "$(json_escape "$MEETING_ID")" "$(json_escape "$CREATED")")"

printf '%s\n' "$record" >> "$ROOT/.agents/approvals.jsonl"
printf '%s\n' "$record" >> "$ROOT/.agents/state/approvals.jsonl"

"$ROOT/scripts/log-event.sh" approval-recorded "$ACTOR" "Recorded approval $APPROVAL_ID" "$SUBJECT: $STATUS" "$APPROVAL_ID"
printf "Recorded approval %s\n" "$APPROVAL_ID"
