#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf "FAIL: %s\n" "$1" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"
  if [ ! -f "$ROOT/$path" ]; then
    fail "missing file: $path"
  fi
}

assert_executable() {
  local path="$1"
  if [ ! -x "$ROOT/$path" ]; then
    fail "not executable: $path"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "$label missing expected text: $needle"
  fi
}

assert_file_exists "visual-media/index.html"
assert_file_exists "visual-media/styles.css"
assert_file_exists "visual-media/app.js"
assert_file_exists "visual-media/README.md"
assert_file_exists "scripts/start-visual-media-dashboard.sh"
assert_executable "scripts/start-visual-media-dashboard.sh"
bash -n "$ROOT/scripts/start-visual-media-dashboard.sh"
bash -n "$ROOT/scripts/attach-media.sh"

dashboard_markup="$(cat "$ROOT/visual-media/index.html" "$ROOT/visual-media/app.js")"
assert_contains "$dashboard_markup" ".agents/media/manifest.jsonl" "visual media dashboard"
assert_contains "$dashboard_markup" ".agents/schemas/media-attachment.md" "visual media dashboard"
assert_contains "$dashboard_markup" "scripts/attach-media.sh" "visual media dashboard"
assert_contains "$dashboard_markup" "attachmentType" "visual media dashboard"
assert_contains "$dashboard_markup" "scope" "visual media dashboard"
assert_contains "$dashboard_markup" "commandPreview" "visual media dashboard"

server_url="$("$ROOT/scripts/start-visual-media-dashboard.sh" --print-url 9876)"
assert_contains "$server_url" "http://127.0.0.1:9876/visual-media/" "visual media server url"

tmp_parent="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_parent"
}
trap cleanup EXIT

test_root="$tmp_parent/agent-teams"
rsync -a \
  --exclude ".git/" \
  --exclude ".DS_Store" \
  "$ROOT/" "$test_root/"
chmod +x "$test_root"/scripts/*.sh

media_file="$tmp_parent/photo.png"
printf "fake png bytes\n" > "$media_file"

"$test_root/scripts/attach-media.sh" M777 route R777 "$media_file" image "Visual media reference" \
  --copy \
  --sensitive no \
  --review-owner security \
  --attribution "Threads post reference" \
  --tags "design,visual,reference" \
  --width 1200 \
  --height 800 >/tmp/visual-media-attach.out

manifest="$(cat "$test_root/.agents/media/manifest.jsonl")"
state_media="$(cat "$test_root/.agents/state/media.jsonl")"
assert_contains "$manifest" "\"attachment_type\":\"image\"" "visual media manifest"
assert_contains "$manifest" "\"file_size\":" "visual media manifest"
assert_contains "$manifest" "\"sha256\":\"" "visual media manifest"
assert_contains "$manifest" "\"mime_type\":\"" "visual media manifest"
assert_contains "$manifest" "\"sensitive\":\"no\"" "visual media manifest"
assert_contains "$manifest" "\"review_owner\":\"security\"" "visual media manifest"
assert_contains "$manifest" "\"attribution\":\"Threads post reference\"" "visual media manifest"
assert_contains "$manifest" "\"tags\":\"design,visual,reference\"" "visual media manifest"
assert_contains "$manifest" "\"width\":1200" "visual media manifest"
assert_contains "$manifest" "\"height\":800" "visual media manifest"
assert_contains "$manifest" "\"stored_path\":\".agents/media/files/" "visual media manifest"
assert_contains "$state_media" "\"stored_path\":\".agents/media/files/" "visual media state"

copied_path="$(printf '%s\n' "$manifest" | sed -n 's/.*"stored_path":"\([^"]*\)".*/\1/p' | tail -1)"
if [ ! -f "$test_root/$copied_path" ]; then
  fail "copied media file missing: $copied_path"
fi

structured_output="$("$test_root/scripts/validate-structured-state.sh")"
assert_contains "$structured_output" ".agents/state/media.jsonl valid" "visual media structured state"

printf "Visual media functional layer tests passed.\n"
