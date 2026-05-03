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

for required_file in \
  ".agents/company/README.md" \
  ".agents/company/agent-profiles.jsonl" \
  ".agents/company/projects.jsonl" \
  ".agents/meetings/README.md" \
  ".agents/media/README.md" \
  ".agents/media/manifest.jsonl" \
  ".agents/approvals.jsonl" \
  ".agents/schemas/agent-profile.md" \
  ".agents/schemas/meeting-output.md" \
  ".agents/schemas/media-attachment.md" \
  ".agents/schemas/approval-record.md" \
  ".agents/state/meetings.jsonl" \
  ".agents/state/media.jsonl" \
  ".agents/state/approvals.jsonl"; do
  assert_file_exists "$required_file"
done

for required_script in \
  "scripts/company-status.sh" \
  "scripts/create-meeting.sh" \
  "scripts/close-meeting.sh" \
  "scripts/attach-media.sh" \
  "scripts/record-approval.sh"; do
  assert_file_exists "$required_script"
  assert_executable "$required_script"
  bash -n "$ROOT/$required_script"
done

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

project_dir="$tmp_parent/project-one"
mkdir -p "$project_dir"

"$test_root/scripts/set-project-target.sh" "$project_dir" new-project >/dev/null
assert_contains "$(cat "$test_root/.agents/company/projects.jsonl")" "\"path\":\"$project_dir\"" "project registry"
assert_contains "$(cat "$test_root/.agents/state/projects.jsonl")" "\"mode\":\"new-project\"" "project state"

status_output="$("$test_root/scripts/company-status.sh")"
assert_contains "$status_output" "== Company Projects ==" "company status"
assert_contains "$status_output" "== Agent Profiles ==" "company status"
assert_contains "$status_output" "orchestrator" "company status"

"$test_root/scripts/create-meeting.sh" M900 "Functional layer planning" orchestrator product cto >/dev/null
assert_file_exists_tmp="$test_root/.agents/meetings/M900.md"
if [ ! -f "$assert_file_exists_tmp" ]; then
  fail "missing meeting file: .agents/meetings/M900.md"
fi
assert_contains "$(cat "$test_root/.agents/meetings/M900.md")" "Participants: orchestrator, product, cto" "meeting file"
assert_contains "$(cat "$test_root/.agents/state/meetings.jsonl")" "\"meeting_id\":\"M900\"" "meeting state"

"$test_root/scripts/close-meeting.sh" M900 "Functional-first scope approved" "PM converts action items into routes" >/dev/null
assert_contains "$(cat "$test_root/.agents/meetings/M900.md")" "Status: closed" "closed meeting"
assert_contains "$(cat "$test_root/.agents/meetings/M900.md")" "PM converts action items into routes" "closed meeting"

media_file="$tmp_parent/reference.png"
printf "placeholder image bytes\n" > "$media_file"
"$test_root/scripts/attach-media.sh" M900 route R900 "$media_file" screenshot "Reference screenshot for functional requirements" >/dev/null
assert_contains "$(cat "$test_root/.agents/media/manifest.jsonl")" "\"meeting_id\":\"M900\"" "media manifest"
assert_contains "$(cat "$test_root/.agents/state/media.jsonl")" "\"attachment_type\":\"screenshot\"" "media state"

"$test_root/scripts/record-approval.sh" AP900 human "functional-first plan" approved "Proceed before visual UI" M900 >/dev/null
assert_contains "$(cat "$test_root/.agents/approvals.jsonl")" "\"approval_id\":\"AP900\"" "approval ledger"
assert_contains "$(cat "$test_root/.agents/state/approvals.jsonl")" "\"status\":\"approved\"" "approval state"

"$test_root/scripts/route-agent.sh" R900 pm "Plan meeting actions" T900 \
  --meeting M900 --decision D900 \
  --instruction "Convert the closed meeting action items into PM task-board updates." \
  --expected-output ".agents/task-board.md updates and .agents/routes/R900.md route report" \
  --validation "Run ./scripts/check-ready.sh and ./scripts/validate-route-state.sh." >/dev/null
assert_contains "$(cat "$test_root/.agents/inbox/pm.md")" "Meeting ID: M900" "route meeting metadata"
assert_contains "$(cat "$test_root/.agents/inbox/pm.md")" "Decision ID: D900" "route decision metadata"
assert_contains "$(cat "$test_root/.agents/routes/R900.md")" "Route ID: R900" "route report"
assert_contains "$(cat "$test_root/.agents/state/routes.jsonl")" "\"meeting_id\":\"M900\"" "route state metadata"

structured_output="$("$test_root/scripts/validate-structured-state.sh")"
assert_contains "$structured_output" ".agents/state/projects.jsonl valid" "structured state"
assert_contains "$structured_output" ".agents/state/meetings.jsonl valid" "structured state"
assert_contains "$structured_output" ".agents/state/media.jsonl valid" "structured state"
assert_contains "$structured_output" ".agents/state/approvals.jsonl valid" "structured state"

printf "Coding company functional layer tests passed.\n"
