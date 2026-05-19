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

write_detect_agent_health_script() {
  local body="$1"
  cat > "$ROOT/scripts/detect-agent-health.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
$body
EOF
  chmod +x "$ROOT/scripts/detect-agent-health.sh"
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

write_final_cto_artifact() {
  cat > "$ROOT/agent-control/final-cto-review.md" <<'EOF'
# Final CTO Review

Architecture drift reviewed. The implementation matches the approved architecture and no follow-up architecture blocker remains.
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

latest_notification_status() {
  python3 - "$ROOT/agent-control/state/notifications.jsonl" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
status = ""
if path.exists():
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        record = json.loads(line)
        if record.get("notification_id") == "project-complete-ready-for-human":
            status = str(record.get("status") or "")
print(status)
PY
}

assert_file_exists "scripts/check-project-completion-notification.sh"
assert_file_exists "scripts/record-final-human-decision.sh"
assert_file_exists "scripts/promote-final-review-routes.sh"
assert_file_exists "agent-control/state/notifications.jsonl"
assert_contains "$(cat "$ROOT/scripts/watch-routes.sh")" "check-project-completion-notification.sh" "watcher integration"
assert_contains "$(cat "$ROOT/scripts/watch-routes.sh")" "promote-final-review-routes.sh" "watcher final review promotion"
assert_contains "$(cat "$ROOT/scripts/heartbeat-routes.sh")" "check-project-completion-notification.sh" "heartbeat integration"
assert_contains "$(cat "$ROOT/scripts/heartbeat-routes.sh")" "promote-final-review-routes.sh" "heartbeat final review promotion"

reset_state

"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-pending.out
assert_equals "$(notification_count_for_status active)" "0" "pending final artifacts"
assert_not_contains "$(cat "$ROOT/agent-control/workflow-state.md")" "Project ready for final human review" "pending final artifacts"

"$ROOT/scripts/promote-final-review-routes.sh" fake-session --send >/tmp/project-completion-promote-cto.out
assert_contains "$(cat /tmp/project-completion-promote-cto.out)" "Created route R001 for cto" "final CTO route promotion"
assert_contains "$(cat "$ROOT/agent-control/routes/R001.md")" "agent-control/final-cto-review.md" "final CTO route files"
"$ROOT/scripts/claim-route.sh" R001 cto >/tmp/project-completion-claim-cto.out
write_final_cto_artifact
"$ROOT/scripts/complete-route.sh" R001 cto "Final CTO review complete" --report agent-control/routes/R001.md >/tmp/project-completion-complete-cto.out

"$ROOT/scripts/promote-final-review-routes.sh" fake-session --send >/tmp/project-completion-promote-pm.out
assert_contains "$(cat /tmp/project-completion-promote-pm.out)" "Created route R002 for pm" "final PM route promotion"
assert_contains "$(cat "$ROOT/agent-control/routes/R002.md")" "agent-control/final-acceptance.md" "final PM route files"
"$ROOT/scripts/claim-route.sh" R002 pm >/tmp/project-completion-claim-pm.out
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
"$ROOT/scripts/complete-route.sh" R002 pm "Final PM acceptance complete" --report agent-control/routes/R002.md >/tmp/project-completion-complete-pm.out
"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-auto-final-ready.out
assert_equals "$(notification_count_for_status active)" "1" "auto final routes enable notification"

reset_state
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
write_detect_agent_health_script 'printf "%s\n" '\''{"role":"pm","kind":"context-pressure","severity":"watch","action":"compact-context","active_route":"none","reason":"idle warning"}'\'''
"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-idle-watch.out
assert_equals "$(notification_count_for_status active)" "1" "idle watch health finding ignored"

reset_state
write_final_artifacts
write_detect_agent_health_script 'printf "%s\n" '\''{"role":"pm","kind":"context-pressure","severity":"watch","action":"compact-context","active_route":"R777","reason":"active route warning"}'\'''
"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-active-watch.out
assert_equals "$(notification_count_for_status active)" "0" "active-route watch finding blocks notification"

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
write_detect_agent_health_script 'exit 0'
"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-ready.out
assert_equals "$(notification_count_for_status active)" "1" "ready notification active"
assert_contains "$(cat "$ROOT/agent-control/workflow-state.md")" "Project ready for final human review" "workflow human attention"

"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-dedupe.out
assert_equals "$(notification_count_for_status active)" "1" "ready notification dedupe"

"$ROOT/scripts/record-final-human-decision.sh" fake-session --status approved --decision "Proceed to ship." >/tmp/project-completion-final-decision.out
assert_contains "$(cat "$ROOT/agent-control/approvals.jsonl")" "\"subject\":\"final ship/no-ship:" "final ship decision ledger"
assert_equals "$(latest_notification_status)" "dismissed" "final ship decision dismisses notification"
assert_not_contains "$(cat "$ROOT/agent-control/workflow-state.md")" "Project ready for final human review" "final ship decision clears human attention"

"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-post-decision.out
assert_equals "$(latest_notification_status)" "dismissed" "approved decision suppresses repeat notification"

sleep 2
touch "$ROOT/agent-control/task-board.md"
"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-reopened-ready.out
assert_equals "$(latest_notification_status)" "active" "project changes after approval require fresh human review"

template_root="$ROOT"
session_root="$tmp_parent/session-team"
rsync -a \
  --exclude "agent-control/state/workflow.sqlite3" \
  --exclude "agent-control/state/workflow.sqlite3-*" \
  "$ROOT/" "$session_root/"
chmod +x "$session_root"/scripts/*.sh
ROOT="$session_root"
reset_state
write_final_artifacts
write_detect_agent_health_script 'exit 0'
"$ROOT/scripts/check-project-completion-notification.sh" fake-session --apply >/tmp/project-completion-session-root-ready.out
fake_bin="$tmp_parent/fake-bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/tmux" <<EOF
#!/usr/bin/env bash
set -euo pipefail
case "\${1:-}" in
  has-session)
    exit 0
    ;;
  display-message)
    printf "%s\n" "$session_root"
    exit 0
    ;;
esac
exit 1
EOF
chmod +x "$fake_bin/tmux"
PATH="$fake_bin:$PATH" "$template_root/scripts/record-final-human-decision.sh" fake-session --status approved --decision "Session root decision." >/tmp/project-completion-session-root-decision.out
assert_contains "$(cat "$session_root/agent-control/approvals.jsonl")" "Session root decision." "session-root approval"
assert_not_contains "$(cat "$template_root/agent-control/approvals.jsonl")" "Session root decision." "template root not mutated for session decision"
assert_equals "$(latest_notification_status)" "dismissed" "session-root final decision dismisses notification"
ROOT="$template_root"

structured_output="$("$ROOT/scripts/validate-structured-state.sh")"
assert_contains "$structured_output" "agent-control/state/notifications.jsonl valid" "structured notification state"

printf "Project completion notification tests passed.\n"
