#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_parent="$(mktemp -d)"
ROOT="$tmp_parent/agent-teams"

cleanup() {
  rm -rf "$tmp_parent"
}
trap cleanup EXIT

rsync -a \
  --exclude ".git/" \
  --exclude ".DS_Store" \
  --exclude "agent-control/state/workflow.sqlite3" \
  --exclude "agent-control/state/workflow.sqlite3-*" \
  "$SOURCE_ROOT/" "$ROOT/"
chmod +x "$ROOT"/scripts/*.sh

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

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "$label missing expected text: $needle"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    fail "$label unexpectedly contains text: $needle"
  fi
}

assert_equals() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  if [ "$actual" != "$expected" ]; then
    fail "$label expected '$expected' but got '$actual'"
  fi
}

reset_state() {
  "$ROOT/scripts/reset-agent-team-state.sh" >/tmp/project-completion-reset.out
}

write_final_artifacts() {
  cat > "$ROOT/agent-control/final-cto-review.md" <<'EOF'
# Final CTO Review

Architecture drift reviewed. The implementation matches the approved architecture and no follow-up architecture blocker remains.
EOF

  cat > "$ROOT/agent-control/final-acceptance.md" <<'EOF'
# Final Acceptance

Completed items:
- The approved milestone is implemented and validated.

Incomplete items:
- None.

Known risks:
- None blocking final human review.

Recommended next milestone:
- Human ship/no-ship decision.
EOF
}

notification_count_for_status() {
  local status="$1"
  python3 - "$ROOT/agent-control/state/notifications.jsonl" "$status" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
status = sys.argv[2]
count = 0
if path.exists():
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        record = json.loads(line)
        if (
            record.get("notification_id") == "project-complete-ready-for-human"
            and record.get("status") == status
        ):
            count += 1
print(count)
PY
}

assert_file_exists "scripts/check-project-completion-notification.sh"
assert_file_exists "agent-control/state/notifications.jsonl"
assert_contains "$(cat "$ROOT/scripts/watch-routes.sh")" "check-project-completion-notification.sh" "watcher integration"
assert_contains "$(cat "$ROOT/scripts/heartbeat-routes.sh")" "check-project-completion-notification.sh" "heartbeat integration"

reset_state

"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-pending.out
assert_equals "$(notification_count_for_status active)" "0" "pending final artifacts"
assert_not_contains "$(cat "$ROOT/agent-control/workflow-state.md")" "Project ready for final human review" "pending final artifacts"

write_final_artifacts
"$ROOT/scripts/route-agent.sh" R990 pm "Open route prevents project-complete notification" \
  --instruction "Keep this route open." \
  --expected-output "No project completion notification." \
  --validation "Completion notification script reports open route." >/tmp/project-completion-open-route.out
"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-open-route-check.out
assert_equals "$(notification_count_for_status active)" "0" "open route blocks notification"
"$ROOT/scripts/cancel-route.sh" R990 test "open route assertion complete" >/tmp/project-completion-cancel-route.out

reset_state
write_final_artifacts
cat >> "$ROOT/agent-control/validation-report.md" <<'EOF'

### Finding V900 - Major blocker
Severity: major
Status: open
Task: final
Files:

Problem:
Open major finding should block final human review.

Reproduction / command:
./scripts/check-done.sh

Expected result:
No open major findings.

Actual result:
Open major finding exists.

Recommendation:
Resolve before final review.
EOF
"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-open-finding.out
assert_equals "$(notification_count_for_status active)" "0" "open major finding blocks notification"

reset_state
write_final_artifacts
"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-ready.out
assert_equals "$(notification_count_for_status active)" "1" "ready notification active"
assert_contains "$(cat "$ROOT/agent-control/workflow-state.md")" "Project ready for final human review" "workflow human attention"

"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-dedupe.out
assert_equals "$(notification_count_for_status active)" "1" "ready notification dedupe"

structured_output="$("$ROOT/scripts/validate-structured-state.sh")"
assert_contains "$structured_output" "agent-control/state/notifications.jsonl valid" "structured notification state"

printf "Project completion notification tests passed.\n"
