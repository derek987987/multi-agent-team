#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

usage() {
  printf "Usage: %s <meeting-id> <scope> <related-id> <file-path> <attachment-type> <description> [options]\n" "$(basename "$0")" >&2
  printf "Example: %s M001 route R001 /tmp/screenshot.png screenshot \"Reference UI\" --copy --sensitive no --review-owner security\n" "$(basename "$0")" >&2
  printf "\nOptions:\n" >&2
  printf "  --copy                         Copy the file into .agents/media/files/ and record stored_path\n" >&2
  printf "  --sensitive <yes|no|unknown>   Mark whether the attachment may contain sensitive content\n" >&2
  printf "  --review-owner <role>          Role responsible for reviewing sensitive or risky media\n" >&2
  printf "  --attribution <text>           Source, license, or origin note for the media\n" >&2
  printf "  --tags <csv>                   Comma-separated tags for future filtering\n" >&2
  printf "  --width <pixels>               Image/video width in pixels\n" >&2
  printf "  --height <pixels>              Image/video height in pixels\n" >&2
  printf "  --mime-type <type/subtype>     Override detected MIME type\n" >&2
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    printf "unavailable"
  fi
}

detect_mime_type() {
  if command -v file >/dev/null 2>&1; then
    file -b --mime-type "$1" 2>/dev/null || printf "application/octet-stream"
  else
    printf "application/octet-stream"
  fi
}

append_string_field() {
  local current="$1"
  local key="$2"
  local value="$3"
  if [ -n "$value" ]; then
    printf '%s,"%s":"%s"' "$current" "$key" "$(json_escape "$value")"
  else
    printf '%s' "$current"
  fi
}

append_number_field() {
  local current="$1"
  local key="$2"
  local value="$3"
  if [ -n "$value" ]; then
    printf '%s,"%s":%s' "$current" "$key" "$value"
  else
    printf '%s' "$current"
  fi
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

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

description_parts=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --*) break ;;
    *) description_parts+=("$1"); shift ;;
  esac
done

if [ "${#description_parts[@]}" -eq 0 ]; then
  printf "Description is required.\n" >&2
  usage
  exit 1
fi

DESCRIPTION="${description_parts[*]}"
COPY_MEDIA=0
SENSITIVE=""
REVIEW_OWNER=""
ATTRIBUTION=""
TAGS=""
WIDTH=""
HEIGHT=""
MIME_TYPE_OVERRIDE=""
CREATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
ATTACHMENT_ID="A$(date -u +"%Y%m%d%H%M%S")-$$"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --copy)
      COPY_MEDIA=1
      shift
      ;;
    --sensitive)
      [ "$#" -ge 2 ] || { printf "--sensitive requires a value.\n" >&2; exit 1; }
      SENSITIVE="$2"
      shift 2
      ;;
    --review-owner)
      [ "$#" -ge 2 ] || { printf "--review-owner requires a value.\n" >&2; exit 1; }
      REVIEW_OWNER="$2"
      shift 2
      ;;
    --attribution)
      [ "$#" -ge 2 ] || { printf "--attribution requires a value.\n" >&2; exit 1; }
      ATTRIBUTION="$2"
      shift 2
      ;;
    --tags)
      [ "$#" -ge 2 ] || { printf "--tags requires a value.\n" >&2; exit 1; }
      TAGS="$2"
      shift 2
      ;;
    --width)
      [ "$#" -ge 2 ] || { printf "--width requires a value.\n" >&2; exit 1; }
      WIDTH="$2"
      shift 2
      ;;
    --height)
      [ "$#" -ge 2 ] || { printf "--height requires a value.\n" >&2; exit 1; }
      HEIGHT="$2"
      shift 2
      ;;
    --mime-type)
      [ "$#" -ge 2 ] || { printf "--mime-type requires a value.\n" >&2; exit 1; }
      MIME_TYPE_OVERRIDE="$2"
      shift 2
      ;;
    *)
      printf "Unknown option: %s\n" "$1" >&2
      usage
      exit 1
      ;;
  esac
done

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

case "$SENSITIVE" in
  ""|yes|no|unknown) ;;
  *)
    printf "Invalid sensitive value: %s\n" "$SENSITIVE" >&2
    exit 1
    ;;
esac

case "$WIDTH" in
  ""|*[!0-9]*)
    if [ -n "$WIDTH" ]; then
      printf "Width must be a positive integer: %s\n" "$WIDTH" >&2
      exit 1
    fi
    ;;
esac

case "$HEIGHT" in
  ""|*[!0-9]*)
    if [ -n "$HEIGHT" ]; then
      printf "Height must be a positive integer: %s\n" "$HEIGHT" >&2
      exit 1
    fi
    ;;
esac

mkdir -p "$ROOT/.agents/media" "$ROOT/.agents/state"

FILE_SIZE="$(wc -c < "$FILE_PATH" | tr -d '[:space:]')"
SHA256="$(sha256_file "$FILE_PATH")"
if [ -n "$MIME_TYPE_OVERRIDE" ]; then
  MIME_TYPE="$MIME_TYPE_OVERRIDE"
else
  MIME_TYPE="$(detect_mime_type "$FILE_PATH")"
fi

STORED_PATH=""
if [ "$COPY_MEDIA" -eq 1 ]; then
  mkdir -p "$ROOT/.agents/media/files"
  STORED_PATH=".agents/media/files/$ATTACHMENT_ID-$(basename "$FILE_PATH")"
  cp "$FILE_PATH" "$ROOT/$STORED_PATH"
fi

record="$(printf '{"attachment_id":"%s","meeting_id":"%s","scope":"%s","related_id":"%s","path":"%s","attachment_type":"%s","description":"%s","created":"%s","file_size":%s,"sha256":"%s","mime_type":"%s"' \
  "$(json_escape "$ATTACHMENT_ID")" "$(json_escape "$MEETING_ID")" "$(json_escape "$SCOPE")" "$(json_escape "$RELATED_ID")" "$(json_escape "$FILE_PATH")" "$(json_escape "$ATTACHMENT_TYPE")" "$(json_escape "$DESCRIPTION")" "$(json_escape "$CREATED")" "$FILE_SIZE" "$(json_escape "$SHA256")" "$(json_escape "$MIME_TYPE")")"
record="$(append_string_field "$record" "stored_path" "$STORED_PATH")"
record="$(append_string_field "$record" "sensitive" "$SENSITIVE")"
record="$(append_string_field "$record" "review_owner" "$REVIEW_OWNER")"
record="$(append_string_field "$record" "attribution" "$ATTRIBUTION")"
record="$(append_string_field "$record" "tags" "$TAGS")"
record="$(append_number_field "$record" "width" "$WIDTH")"
record="$(append_number_field "$record" "height" "$HEIGHT")"
record="$record}"

printf '%s\n' "$record" >> "$ROOT/.agents/media/manifest.jsonl"
printf '%s\n' "$record" >> "$ROOT/.agents/state/media.jsonl"

if [ -n "$MEETING_ID" ] && [ -f "$ROOT/.agents/meetings/$MEETING_ID.md" ]; then
  tmp="$(mktemp)"
  display_path="$FILE_PATH"
  [ -n "$STORED_PATH" ] && display_path="$STORED_PATH"
  awk -v id="$ATTACHMENT_ID" -v path="$display_path" -v description="$DESCRIPTION" '
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
