#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

usage() {
  printf "Usage: %s <meeting-id> <scope> <related-id> <file-path> <attachment-type> <description>\n" "$(basename "$0")" >&2
  printf "Example: %s M001 route R001 /tmp/screenshot.png screenshot \"Reference UI\"\n" "$(basename "$0")" >&2
}

if [ "$#" -lt 6 ]; then
  usage
  exit 1
fi

MEETING_ID="$1"
SCOPE="$2"
RELATED_ID="$3"
FILE_PATH="$4"
ATTACHMENT_TYPE="$5"
shift 5
DESCRIPTION="$*"
CREATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
ATTACHMENT_ID="A$(date -u +"%Y%m%d%H%M%S")-$$"

if [ ! -f "$FILE_PATH" ]; then
  printf "Attachment file does not exist: %s\n" "$FILE_PATH" >&2
  exit 1
fi

case "$SCOPE" in
  meeting|task|route|validation|design|project) ;;
  *)
    printf "Invalid scope: %s\n" "$SCOPE" >&2
    exit 1
    ;;
esac

case "$ATTACHMENT_TYPE" in
  image|video|screenshot|audio|document|other) ;;
  *)
    printf "Invalid attachment type: %s\n" "$ATTACHMENT_TYPE" >&2
    exit 1
    ;;
esac

mkdir -p "$ROOT/.agents/media" "$ROOT/.agents/state"

record="$(printf '{"attachment_id":"%s","meeting_id":"%s","scope":"%s","related_id":"%s","path":"%s","attachment_type":"%s","description":"%s","created":"%s"}' \
  "$(json_escape "$ATTACHMENT_ID")" "$(json_escape "$MEETING_ID")" "$(json_escape "$SCOPE")" "$(json_escape "$RELATED_ID")" "$(json_escape "$FILE_PATH")" "$(json_escape "$ATTACHMENT_TYPE")" "$(json_escape "$DESCRIPTION")" "$(json_escape "$CREATED")")"

printf '%s\n' "$record" >> "$ROOT/.agents/media/manifest.jsonl"
printf '%s\n' "$record" >> "$ROOT/.agents/state/media.jsonl"

if [ -n "$MEETING_ID" ] && [ -f "$ROOT/.agents/meetings/$MEETING_ID.md" ]; then
  tmp="$(mktemp)"
  awk -v id="$ATTACHMENT_ID" -v path="$FILE_PATH" -v description="$DESCRIPTION" '
    /^## Media Attachments/ { in_media = 1; print; next }
    in_media && /^\| --- \| --- \| --- \|/ && !inserted {
      print
      printf "| %s | %s | %s |\n", id, path, description
      inserted = 1
      next
    }
    /^## / && !/^## Media Attachments/ { in_media = 0 }
    { print }
  ' "$ROOT/.agents/meetings/$MEETING_ID.md" > "$tmp"
  mv "$tmp" "$ROOT/.agents/meetings/$MEETING_ID.md"
fi

"$ROOT/scripts/log-event.sh" media-attached orchestrator "Attached media $ATTACHMENT_ID" "$DESCRIPTION" "$RELATED_ID"
printf "Attached media %s\n" "$ATTACHMENT_ID"
