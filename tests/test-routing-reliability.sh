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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    fail "$label unexpectedly contains text: $needle"
  fi
}

assert_file_exists() {
  local path="$1"
  if [ ! -f "$ROOT/$path" ]; then
    fail "missing file: $path"
  fi
}

if "$ROOT/scripts/route-agent.sh" R901 cto "TBD route should not dispatch" >/tmp/route-tbd.out 2>/tmp/route-tbd.err; then
  fail "route-agent accepted a non-draft route with TBD fields"
fi
assert_contains "$(cat /tmp/route-tbd.err)" "--instruction" "route-agent TBD rejection"

"$ROOT/scripts/route-agent.sh" R901 cto "Reliable route envelope" \
  --instruction "Read the routing audit and produce an architecture-ready transition note." \
  --expected-output "agent-control/agent-log/cto.md entry and agent-control/routes/R901.md completion report" \
  --validation "Run ./scripts/validate-route-state.sh before completing." \
  --context "agent-control/workflow-routing-transition-audit.md" \
  --priority P1 \
  --target-project "$ROOT" \
  --files "agent-control/route-schema.md,scripts/dispatch-routes.sh" \
  >/tmp/route-create.out

assert_file_exists "agent-control/routes/R901.md"
route_report="$(cat "$ROOT/agent-control/routes/R901.md")"
assert_contains "$route_report" "Route ID: R901" "route report"
assert_contains "$route_report" "Priority: P1" "route report"
assert_contains "$route_report" "Target project: $ROOT" "route report"
assert_not_contains "$route_report" "TBD" "route report"

if "$ROOT/scripts/claim-route.sh" R901 frontend >/tmp/claim-wrong.out 2>/tmp/claim-wrong.err; then
  fail "claim-route allowed frontend to claim a cto route"
fi
assert_contains "$(cat /tmp/claim-wrong.err)" "assigned to cto" "claim-route actor validation"

"$ROOT/scripts/claim-route.sh" R901 cto >/tmp/claim-right.out
assert_contains "$(cat "$ROOT/agent-control/inbox/cto.md")" "Status: in-progress" "claim-route status"

if "$ROOT/scripts/complete-route.sh" R901 cto "missing report should fail" >/tmp/complete-missing.out 2>/tmp/complete-missing.err; then
  fail "complete-route allowed completion without a route report"
fi
assert_contains "$(cat /tmp/complete-missing.err)" "--report" "complete-route report requirement"

"$ROOT/scripts/complete-route.sh" R901 cto "route contract documented" --report "agent-control/routes/R901.md" >/tmp/complete-right.out
assert_contains "$(cat "$ROOT/agent-control/inbox/cto.md")" "Status: done" "complete-route status"
assert_contains "$(cat "$ROOT/agent-control/routes/R901.md")" "Completion summary: route contract documented" "completion report"

"$ROOT/scripts/route-agent.sh" R908 backend "Dispatch waits for role readiness" \
  --instruction "Dummy route that should stay queued until the backend role emits a readiness marker." \
  --expected-output "agent-control/routes/R908.md remains queued before readiness." \
  --validation "Dispatcher leaves the route queued instead of blocking when the role session is still launching." \
  --context "agent-control/route-schema.md" >/tmp/route-r908.out

PATH="$ROOT/tests/fixtures:$PATH" \
  "$ROOT/scripts/dispatch-routes.sh" fake-session --send >/tmp/dispatch-not-ready.out 2>/tmp/dispatch-not-ready.err || true

assert_contains "$(cat /tmp/dispatch-not-ready.out /tmp/dispatch-not-ready.err)" "Role session not ready" "dispatch readiness gate"
assert_contains "$(cat "$ROOT/agent-control/inbox/backend.md")" "Status: queued" "dispatch readiness gate"
"$ROOT/scripts/cancel-route.sh" R908 test "readiness gate verified" >/tmp/cancel-r908.out

target_project="$tmp_parent/target-project"
mkdir -p "$target_project"
tmp="$(mktemp)"
awk -v path="$target_project" '/^Path:/ { print "Path: " path; next } { print }' "$ROOT/agent-control/project-target.md" > "$tmp"
mv "$tmp" "$ROOT/agent-control/project-target.md"

"$ROOT/scripts/update-agent-state.sh" frontend \
  --session fake-session \
  --window frontend \
  --status available \
  --active-route none \
  --workdir "$ROOT" \
  --target-project "$target_project" \
  --process-status alive

"$ROOT/scripts/route-agent.sh" R909 frontend "Dispatch detects stale project role workdir" \
  --instruction "Dummy route that should not dispatch to a project-writing role launched from the control-plane root." \
  --expected-output "agent-control/routes/R909.md remains queued until frontend is relaunched from the target path." \
  --validation "Dispatcher leaves target-writing routes queued when live role telemetry workdir does not match the project target." \
  --context "agent-control/failure-recovery.md" >/tmp/route-r909.out

PATH="$ROOT/tests/fixtures:$PATH" TMUX_FIXTURE_CAPTURE="ROLE_READY frontend" \
  "$ROOT/scripts/dispatch-routes.sh" fake-session --send >/tmp/dispatch-workdir-mismatch.out 2>/tmp/dispatch-workdir-mismatch.err || true

assert_contains "$(cat /tmp/dispatch-workdir-mismatch.out /tmp/dispatch-workdir-mismatch.err)" "Role workdir mismatch" "dispatch project workdir gate"
assert_contains "$(cat "$ROOT/agent-control/inbox/frontend.md")" "Status: queued" "dispatch project workdir gate"
assert_contains "$(cat "$ROOT/agent-control/state/agents.jsonl")" "project-writing role launched from" "dispatch project workdir telemetry"
"$ROOT/scripts/cancel-route.sh" R909 test "project workdir mismatch guard verified" >/tmp/cancel-r909.out

"$ROOT/scripts/update-agent-state.sh" frontend \
  --session fake-session \
  --window frontend \
  --status available \
  --active-route none \
  --workdir "$target_project" \
  --target-project "$target_project" \
  --process-status alive

"$ROOT/scripts/route-agent.sh" R902 frontend "Dispatch acknowledgement timeout" \
  --instruction "Dummy dispatch route for timeout behavior." \
  --expected-output "agent-control/routes/R902.md" \
  --validation "Dispatcher captures pane evidence and leaves a slow acknowledgement recoverable." \
  --context "agent-control/route-schema.md" >/tmp/route-r902.out

PATH="$ROOT/tests/fixtures:$PATH" ROUTE_DISPATCH_ACK_TIMEOUT=1 TMUX_FIXTURE_CAPTURE="ROLE_READY frontend" \
  "$ROOT/scripts/dispatch-routes.sh" fake-session --send >/tmp/dispatch-timeout.out 2>/tmp/dispatch-timeout.err || true

assert_contains "$(cat /tmp/dispatch-timeout.out /tmp/dispatch-timeout.err)" "still awaiting claim" "dispatch ack pending"
assert_contains "$(cat "$ROOT/agent-control/inbox/frontend.md")" "Status: dispatched" "dispatch timeout route status"
assert_contains "$(cat "$ROOT/agent-control/routes/R902.md")" "Dispatch acknowledgement pending" "dispatch timeout route report"

"$ROOT/scripts/route-agent.sh" R907 frontend "Dispatch delivery timeout" \
  --instruction "Dummy dispatch route for tmux delivery timeout behavior." \
  --expected-output "agent-control/routes/R907.md" \
  --validation "Dispatcher blocks the route when tmux delivery itself times out." \
  --context "agent-control/route-schema.md" >/tmp/route-r907.out

PATH="$ROOT/tests/fixtures:$PATH" ROUTE_DISPATCH_SEND_TIMEOUT=1 TMUX_FIXTURE_CAPTURE="ROLE_READY frontend" TMUX_FIXTURE_PASTE_SLEEP=5 \
  "$ROOT/scripts/dispatch-routes.sh" fake-session --send >/tmp/dispatch-send-timeout.out 2>/tmp/dispatch-send-timeout.err || true

assert_contains "$(cat /tmp/dispatch-send-timeout.out /tmp/dispatch-send-timeout.err)" "tmux delivery timeout" "dispatch send timeout"
assert_contains "$(cat "$ROOT/agent-control/inbox/frontend.md")" "Status: blocked" "dispatch send timeout route status"
assert_contains "$(cat "$ROOT/agent-control/routes/R907.md")" "Dispatch failure" "dispatch send timeout route report"

"$ROOT/scripts/validate-route-state.sh" >/tmp/validate-route-state.out
assert_contains "$(cat /tmp/validate-route-state.out)" "Route state validation passed" "route state validator"

"$ROOT/scripts/route-agent.sh" R903 pm "Route status reporting" \
  --instruction "Produce a PM route report for status reporting." \
  --expected-output "agent-control/task-board.md update and agent-control/routes/R903.md report" \
  --validation "Route status shows current owner, evidence, and next action." \
  --context "agent-control/route-schema.md" >/tmp/route-r903.out

"$ROOT/scripts/route-status.sh" R903 >/tmp/route-status-queued.out
assert_contains "$(cat /tmp/route-status-queued.out)" "Route: R903" "route-status queued"
assert_contains "$(cat /tmp/route-status-queued.out)" "Status: queued" "route-status queued"
assert_contains "$(cat /tmp/route-status-queued.out)" "Next action: dispatch route to pm" "route-status queued"

"$ROOT/scripts/claim-route.sh" R903 pm >/tmp/claim-r903.out
"$ROOT/scripts/complete-route.sh" R903 pm "PM report produced" \
  --report "agent-control/routes/R903.md" \
  --output-ref "agent-control/task-board.md" \
  --output-ref "agent-control/routes/R903.md" >/tmp/complete-r903.out

completed_report="$(cat "$ROOT/agent-control/routes/R903.md")"
assert_contains "$completed_report" "Completion summary: PM report produced" "completion output refs"
assert_contains "$completed_report" "- agent-control/task-board.md" "completion output refs"
assert_contains "$completed_report" "- agent-control/routes/R903.md" "completion output refs"
assert_contains "$(cat "$ROOT/agent-control/inbox/pm.md")" "See agent-control/routes/R903.md" "inbox response report pointer"
assert_contains "$(cat "$ROOT/agent-control/handoffs.md")" "See agent-control/routes/R903.md" "handoff response report pointer"

"$ROOT/scripts/route-status.sh" R903 >/tmp/route-status-done.out
assert_contains "$(cat /tmp/route-status-done.out)" "Status: done" "route-status done"
assert_contains "$(cat /tmp/route-status-done.out)" "Report: agent-control/routes/R903.md" "route-status done"
assert_contains "$(cat /tmp/route-status-done.out)" "Output refs:" "route-status done"
assert_contains "$(cat /tmp/route-status-done.out)" "Next action: no action; route is done" "route-status done"

set_route_created() {
  local route="$1"
  local role="$2"
  local created="$3"
  local inbox="$ROOT/agent-control/inbox/$role.md"
  local report="$ROOT/agent-control/routes/$route.md"
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

if "$ROOT/scripts/route-agent.sh" R906 pm "Too deep route" \
  --instruction "This route should exceed route depth." \
  --expected-output "agent-control/routes/R906.md" \
  --validation "Route depth over budget is rejected." \
  --route-depth 4 >/tmp/route-depth.out 2>/tmp/route-depth.err; then
  fail "route-agent allowed a route depth over budget"
fi
assert_contains "$(cat /tmp/route-depth.err)" "route depth" "route depth enforcement"

"$ROOT/scripts/route-agent.sh" R904 pm "Recover stale queued route" \
  --instruction "Recover this stale queued route." \
  --expected-output "agent-control/routes/R904.md recovery note" \
  --validation "recover-stale-routes requeues within retry budget." \
  --attempt 0 \
  --context "agent-control/failure-recovery.md" >/tmp/route-r904.out
set_route_created R904 pm "2020-01-01T00:00:00Z"

if QUEUED_MINUTES=1 "$ROOT/scripts/check-stale-routes.sh" >/tmp/stale-utc.out 2>/tmp/stale-utc.err; then
  fail "check-stale-routes did not flag an old UTC queued route"
fi
assert_contains "$(cat /tmp/stale-utc.out /tmp/stale-utc.err)" "pm/R904 stale" "UTC stale route detection"

"$ROOT/scripts/recover-stale-routes.sh" --apply >/tmp/recover-r904.out
assert_contains "$(cat /tmp/recover-r904.out)" "Recovered stale route R904" "stale recovery retry"
assert_contains "$(cat "$ROOT/agent-control/inbox/pm.md")" "Attempt: 1" "stale recovery attempt increment"
assert_contains "$(cat "$ROOT/agent-control/routes/R904.md")" "### Recovery Event" "stale recovery report"
assert_contains "$(cat "$ROOT/agent-control/routes/R904.md")" "Requeued by recover-stale-routes" "stale recovery report"

"$ROOT/scripts/route-agent.sh" R905 pm "Block stale over retry budget" \
  --instruction "Block this stale route after retry budget is exhausted." \
  --expected-output "agent-control/routes/R905.md blocked recovery note" \
  --validation "recover-stale-routes blocks routes over retry budget." \
  --attempt 2 \
  --context "agent-control/failure-recovery.md" >/tmp/route-r905.out
set_route_created R905 pm "2020-01-01T00:00:00Z"

"$ROOT/scripts/recover-stale-routes.sh" --apply >/tmp/recover-r905.out
assert_contains "$(cat /tmp/recover-r905.out)" "Blocked stale route R905" "stale recovery retry budget"
assert_contains "$(cat "$ROOT/agent-control/inbox/pm.md")" "## R905 - Block stale over retry budget" "stale recovery route"
assert_contains "$(cat "$ROOT/agent-control/inbox/pm.md")" "Status: blocked" "stale recovery retry budget"
assert_contains "$(cat "$ROOT/agent-control/routes/R905.md")" "Retry budget exhausted" "stale recovery retry budget"

"$ROOT/scripts/route-agent.sh" R914 cto "Recover transport failed in-progress route" \
  --instruction "Recover this route when the role pane reports a Codex transport failure after claim." \
  --expected-output "agent-control/routes/R914.md recovery note and queued retry." \
  --validation "recover-stale-routes requeues transport-failed active routes before the broad in-progress timeout." \
  --attempt 0 \
  --context "agent-control/failure-recovery.md" >/tmp/route-r914.out
"$ROOT/scripts/claim-route.sh" R914 cto >/tmp/claim-r914.out
set_route_created R914 cto "2020-01-01T00:00:00Z"

PATH="$ROOT/tests/fixtures:$PATH" \
  TMUX_FIXTURE_CAPTURE="■ stream disconnected before completion: Transport error: network error: error decoding response body" \
  IN_PROGRESS_HOURS=999999 \
  AGENT_TEAM_FAILED_SESSION_MINUTES=1 \
  "$ROOT/scripts/recover-stale-routes.sh" fake-session --apply >/tmp/recover-r914.out

assert_contains "$(cat /tmp/recover-r914.out)" "Recovered stale route R914" "transport failure recovery"
assert_contains "$(cat "$ROOT/agent-control/inbox/cto.md")" "## R914 - Recover transport failed in-progress route" "transport failure route"
assert_contains "$(cat "$ROOT/agent-control/inbox/cto.md")" "Status: queued" "transport failure recovery"
assert_contains "$(cat "$ROOT/agent-control/inbox/cto.md")" "Attempt: 1" "transport failure attempt increment"
assert_contains "$(cat "$ROOT/agent-control/routes/R914.md")" "Detected failed role session" "transport failure report"
r914_db_attempt="$(sqlite3 "$ROOT/agent-control/state/workflow.sqlite3" "select status || '|' || attempt from routes where route_id='R914';")"
assert_equals "$r914_db_attempt" "queued|1" "transport failure sqlite attempt"

"$ROOT/scripts/route-agent.sh" R915 frontend "Watcher recovers failed session route" \
  --instruction "This route should be requeued automatically by watch-routes before dispatching again." \
  --expected-output "agent-control/routes/R915.md shows recovery evidence and the route is redispatched." \
  --validation "watch-routes performs stale-session recovery before dispatch." \
  --attempt 0 \
  --context "agent-control/failure-recovery.md" >/tmp/route-r915.out
"$ROOT/scripts/claim-route.sh" R915 frontend >/tmp/claim-r915.out
set_route_created R915 frontend "2020-01-01T00:00:00Z"

PATH="$ROOT/tests/fixtures:$PATH" \
  TMUX_FIXTURE_CAPTURE=$'ROLE_READY frontend\n■ stream disconnected before completion: Transport error: network error: error decoding response body' \
  IN_PROGRESS_HOURS=999999 \
  AGENT_TEAM_FAILED_SESSION_MINUTES=1 \
  ROUTE_DISPATCH_ACK_TIMEOUT=1 \
  "$ROOT/scripts/watch-routes.sh" fake-session --send --once >/tmp/watch-recover-r915.out 2>/tmp/watch-recover-r915.err || true

assert_contains "$(cat /tmp/watch-recover-r915.out /tmp/watch-recover-r915.err)" "Recovered stale route R915" "watch recovery"
assert_contains "$(cat /tmp/watch-recover-r915.out /tmp/watch-recover-r915.err)" "still awaiting claim" "watch redispatch"
assert_contains "$(cat "$ROOT/agent-control/inbox/frontend.md")" "## R915 - Watcher recovers failed session route" "watch recovery route"
assert_contains "$(cat "$ROOT/agent-control/inbox/frontend.md")" "Status: dispatched" "watch recovery redispatch status"
assert_contains "$(cat "$ROOT/agent-control/routes/R915.md")" "Detected failed role session" "watch recovery report"
r915_db_attempt="$(sqlite3 "$ROOT/agent-control/state/workflow.sqlite3" "select status || '|' || attempt from routes where route_id='R915';")"
assert_equals "$r915_db_attempt" "dispatched|1" "watch recovery sqlite attempt"

"$ROOT/scripts/route-agent.sh" R916 frontend "Recover blocked communication route" \
  --instruction "This route should recover when dispatch infrastructure blocked the communication path." \
  --expected-output "agent-control/routes/R916.md recovery note and queued retry." \
  --validation "recover-stale-routes requeues recoverable communication blockers instead of leaving automation stuck." \
  --attempt 0 \
  --context "agent-control/failure-recovery.md" >/tmp/route-r916.out
"$ROOT/scripts/block-route.sh" R916 dispatch-routes "tmux session not found: fake-session" --report agent-control/routes/R916.md >/tmp/block-r916.out
set_route_created R916 frontend "2020-01-01T00:00:00Z"

BLOCKED_COMMUNICATION_MINUTES=1 "$ROOT/scripts/recover-stale-routes.sh" --apply >/tmp/recover-r916.out
assert_contains "$(cat /tmp/recover-r916.out)" "Recovered stale route R916" "blocked communication recovery"
assert_contains "$(cat "$ROOT/agent-control/inbox/frontend.md")" "## R916 - Recover blocked communication route" "blocked communication route"
assert_contains "$(cat "$ROOT/agent-control/inbox/frontend.md")" "Status: queued" "blocked communication recovery"
assert_contains "$(cat "$ROOT/agent-control/inbox/frontend.md")" "Attempt: 1" "blocked communication attempt increment"
assert_contains "$(cat "$ROOT/agent-control/routes/R916.md")" "Detected recoverable communication blocker" "blocked communication report"
r916_db_attempt="$(sqlite3 "$ROOT/agent-control/state/workflow.sqlite3" "select status || '|' || attempt || '|' || blocked_reason from routes where route_id='R916';")"
assert_equals "$r916_db_attempt" "queued|1|" "blocked communication sqlite attempt"

printf "Routing reliability tests passed.\n"
