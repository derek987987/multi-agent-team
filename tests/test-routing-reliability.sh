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

printf "Routing reliability tests passed.\n"
