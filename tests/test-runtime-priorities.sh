#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf "FAIL: %s\n" "$1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "$label missing expected text: $needle"
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

assert_file_exists() {
  local path="$1"
  if [ ! -f "$path" ]; then
    fail "missing file: $path"
  fi
}

tmp_parent="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_parent"
}
trap cleanup EXIT

test_root="$tmp_parent/agent-teams"
rsync -a \
  --exclude ".git/" \
  --exclude ".DS_Store" \
  --exclude "agent-control/state/workflow.sqlite3" \
  --exclude "agent-control/state/workflow.sqlite3-*" \
  "$ROOT/" "$test_root/"
chmod +x "$test_root"/scripts/*.sh

db="$test_root/agent-control/state/workflow.sqlite3"

assert_file_exists "$test_root/scripts/route-db.sh"
assert_file_exists "$test_root/scripts/record-route-run.sh"
assert_file_exists "$test_root/scripts/heartbeat-routes.sh"

set_route_created() {
  local route="$1"
  local role="$2"
  local created="$3"
  local inbox="$test_root/agent-control/inbox/$role.md"
  local report="$test_root/agent-control/routes/$route.md"
  local tmp
  tmp="$(mktemp)"
  awk -v id="$route" -v created="$created" '
    /^## / { in_route = ($2 == id) }
    in_route && /^Created:/ { print; getline; print created; next }
    { print }
  ' "$inbox" > "$tmp"
  mv "$tmp" "$inbox"

  tmp="$(mktemp)"
  awk -v created="$created" '/^Created:/ { print "Created: " created; next } { print }' "$report" > "$tmp"
  mv "$tmp" "$report"
}

"$test_root/scripts/route-agent.sh" R910 cto "DB backed route" \
  --instruction "Use the structured route store for this route." \
  --expected-output "agent-control/routes/R910.md plus SQLite route state" \
  --validation "Route can be atomically claimed and completed only after approval." \
  --approval-required \
  --target-project "$test_root" >/tmp/runtime-route-r910.out

route_row="$(sqlite3 "$db" "select route_id || '|' || status || '|' || to_role || '|' || human_approval_required from routes where route_id='R910';")"
assert_equals "$route_row" "R910|queued|cto|yes" "route db row"

if "$test_root/scripts/claim-route.sh" R910 frontend >/tmp/runtime-claim-wrong.out 2>/tmp/runtime-claim-wrong.err; then
  fail "claim-route allowed the wrong actor to claim R910"
fi
assert_contains "$(cat /tmp/runtime-claim-wrong.err)" "assigned to cto" "wrong actor claim"

"$test_root/scripts/claim-route.sh" R910 cto >/tmp/runtime-claim-right.out
claim_row="$(sqlite3 "$db" "select status || '|' || claimed_by from routes where route_id='R910';")"
assert_equals "$claim_row" "in-progress|cto" "atomic claim row"

if "$test_root/scripts/complete-route.sh" R910 cto "should fail without approval" --report agent-control/routes/R910.md >/tmp/runtime-complete-no-approval.out 2>/tmp/runtime-complete-no-approval.err; then
  fail "complete-route allowed R910 without required approval"
fi
assert_contains "$(cat /tmp/runtime-complete-no-approval.err)" "--approval-ref" "approval gate"

"$test_root/scripts/record-approval.sh" AP910 human "route:R910" approved "Approved completion gate" >/dev/null
"$test_root/scripts/complete-route.sh" R910 cto "approved route complete" \
  --report agent-control/routes/R910.md \
  --approval-ref AP910 >/tmp/runtime-complete-approved.out
done_row="$(sqlite3 "$db" "select status || '|' || completed_by || '|' || approval_ref from routes where route_id='R910';")"
assert_equals "$done_row" "done|cto|AP910" "approved completion row"

"$test_root/scripts/record-route-run.sh" R910 cto \
  --status succeeded \
  --model gpt-runtime-test \
  --input-tokens 100 \
  --output-tokens 50 \
  --cost-cents 12 \
  --exit-code 0 \
  --summary "runtime metadata captured" >/tmp/runtime-record-run.out
run_row="$(sqlite3 "$db" "select route_id || '|' || actor || '|' || status || '|' || model || '|' || input_tokens || '|' || output_tokens || '|' || cost_cents || '|' || exit_code from route_runs where route_id='R910';")"
assert_equals "$run_row" "R910|cto|succeeded|gpt-runtime-test|100|50|12|0" "run metadata row"

"$test_root/scripts/route-agent.sh" R911 pm "Heartbeat visible route" \
  --instruction "Use heartbeat-routes dry run visibility." \
  --expected-output "Heartbeat dry run reports this route." \
  --validation "heartbeat-routes --once --dry-run lists queued work." >/tmp/runtime-route-r911.out
"$test_root/scripts/heartbeat-routes.sh" fake-session --once --dry-run >/tmp/runtime-heartbeat.out
assert_contains "$(cat /tmp/runtime-heartbeat.out)" "queued route R911 -> pm" "heartbeat dry run"
assert_contains "$(cat /tmp/runtime-heartbeat.out)" "dispatch-routes.sh fake-session --dry-run" "heartbeat dispatch preview"

"$test_root/scripts/route-agent.sh" R917 pm "Heartbeat auto recovery" \
  --instruction "Use heartbeat-routes automatic stale recovery." \
  --expected-output "Heartbeat dry run reports the stale route recovery without an extra flag." \
  --validation "heartbeat-routes --once --dry-run runs stale recovery by default." >/tmp/runtime-route-r917.out
set_route_created R917 pm "2020-01-01T00:00:00Z"
QUEUED_MINUTES=1 "$test_root/scripts/heartbeat-routes.sh" fake-session --once --dry-run >/tmp/runtime-heartbeat-recover.out
assert_contains "$(cat /tmp/runtime-heartbeat-recover.out)" "Would recover stale route R917" "heartbeat auto recovery"

"$test_root/scripts/route-agent.sh" R912 frontend "Review gated implementation" \
  --instruction "Implement a change that requires independent review." \
  --expected-output "agent-control/routes/R912.md completion report" \
  --validation "Completion requires a done review route." \
  --review-required reviewer >/tmp/runtime-route-r912.out
"$test_root/scripts/claim-route.sh" R912 frontend >/tmp/runtime-claim-r912.out
if "$test_root/scripts/complete-route.sh" R912 frontend "should fail without review" --report agent-control/routes/R912.md >/tmp/runtime-complete-no-review.out 2>/tmp/runtime-complete-no-review.err; then
  fail "complete-route allowed R912 without required review"
fi
assert_contains "$(cat /tmp/runtime-complete-no-review.err)" "--review-ref" "review gate"

"$test_root/scripts/route-agent.sh" R913 reviewer "Review R912" \
  --instruction "Review the R912 route output." \
  --expected-output "agent-control/review-report.md and agent-control/routes/R913.md completion report" \
  --validation "Review route is marked done." >/tmp/runtime-route-r913.out
"$test_root/scripts/claim-route.sh" R913 reviewer >/tmp/runtime-claim-r913.out
"$test_root/scripts/complete-route.sh" R913 reviewer "review passed" --report agent-control/routes/R913.md >/tmp/runtime-complete-r913.out
"$test_root/scripts/complete-route.sh" R912 frontend "reviewed implementation complete" \
  --report agent-control/routes/R912.md \
  --review-ref R913 >/tmp/runtime-complete-r912.out
review_row="$(sqlite3 "$db" "select status || '|' || review_ref from routes where route_id='R912';")"
assert_equals "$review_row" "done|R913" "review gated completion row"

"$test_root/scripts/validate-structured-state.sh" >/tmp/runtime-structured.out
assert_contains "$(cat /tmp/runtime-structured.out)" "agent-control/state/workflow.sqlite3 valid" "structured sqlite validation"

printf "Runtime priority tests passed.\n"
