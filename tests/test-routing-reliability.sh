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

backup_dir="$(mktemp -d)"
files_to_restore=(
  ".agents/inbox/cto.md"
  ".agents/inbox/frontend.md"
  ".agents/inbox/pm.md"
  ".agents/handoffs.md"
  ".agents/workflow-state.md"
  ".agents/state/agents.jsonl"
  ".agents/state/routes.jsonl"
  ".agents/events.jsonl"
)

restore_files() {
  for file in "${files_to_restore[@]}"; do
    if [ -f "$backup_dir/$file" ]; then
      mkdir -p "$ROOT/$(dirname "$file")"
      cp "$backup_dir/$file" "$ROOT/$file"
    fi
  done
  rm -rf "$ROOT/.agents/routes/R901.md" "$ROOT/.agents/routes/R902.md" "$ROOT/.agents/routes/R903.md"
  rm -rf "$backup_dir"
}
trap restore_files EXIT

for file in "${files_to_restore[@]}"; do
  mkdir -p "$backup_dir/$(dirname "$file")"
  cp "$ROOT/$file" "$backup_dir/$file"
done

if "$ROOT/scripts/route-agent.sh" R901 cto "TBD route should not dispatch" >/tmp/route-tbd.out 2>/tmp/route-tbd.err; then
  fail "route-agent accepted a non-draft route with TBD fields"
fi
assert_contains "$(cat /tmp/route-tbd.err)" "--instruction" "route-agent TBD rejection"

"$ROOT/scripts/route-agent.sh" R901 cto "Reliable route envelope" \
  --instruction "Read the routing audit and produce an architecture-ready transition note." \
  --expected-output ".agents/agent-log/cto.md entry and .agents/routes/R901.md completion report" \
  --validation "Run ./scripts/validate-route-state.sh before completing." \
  --context ".agents/workflow-routing-transition-audit.md" \
  --priority P1 \
  --target-project "$ROOT" \
  --files ".agents/route-schema.md,scripts/dispatch-routes.sh" \
  >/tmp/route-create.out

assert_file_exists ".agents/routes/R901.md"
route_report="$(cat "$ROOT/.agents/routes/R901.md")"
assert_contains "$route_report" "Route ID: R901" "route report"
assert_contains "$route_report" "Priority: P1" "route report"
assert_contains "$route_report" "Target project: $ROOT" "route report"
assert_not_contains "$route_report" "TBD" "route report"

if "$ROOT/scripts/claim-route.sh" R901 frontend >/tmp/claim-wrong.out 2>/tmp/claim-wrong.err; then
  fail "claim-route allowed frontend to claim a cto route"
fi
assert_contains "$(cat /tmp/claim-wrong.err)" "assigned to cto" "claim-route actor validation"

"$ROOT/scripts/claim-route.sh" R901 cto >/tmp/claim-right.out
assert_contains "$(cat "$ROOT/.agents/inbox/cto.md")" "Status: in-progress" "claim-route status"

if "$ROOT/scripts/complete-route.sh" R901 cto "missing report should fail" >/tmp/complete-missing.out 2>/tmp/complete-missing.err; then
  fail "complete-route allowed completion without a route report"
fi
assert_contains "$(cat /tmp/complete-missing.err)" "--report" "complete-route report requirement"

"$ROOT/scripts/complete-route.sh" R901 cto "route contract documented" --report ".agents/routes/R901.md" >/tmp/complete-right.out
assert_contains "$(cat "$ROOT/.agents/inbox/cto.md")" "Status: done" "complete-route status"
assert_contains "$(cat "$ROOT/.agents/routes/R901.md")" "Completion summary: route contract documented" "completion report"

"$ROOT/scripts/route-agent.sh" R902 frontend "Dispatch acknowledgement timeout" \
  --instruction "Dummy dispatch route for timeout behavior." \
  --expected-output ".agents/routes/R902.md" \
  --validation "Dispatcher captures pane evidence on ack timeout." \
  --context ".agents/route-schema.md" >/tmp/route-r902.out

PATH="$ROOT/tests/fixtures:$PATH" ROUTE_DISPATCH_ACK_TIMEOUT=1 \
  "$ROOT/scripts/dispatch-routes.sh" fake-session --send >/tmp/dispatch-timeout.out 2>/tmp/dispatch-timeout.err || true

assert_contains "$(cat /tmp/dispatch-timeout.out /tmp/dispatch-timeout.err)" "ack timeout" "dispatch ack timeout"
assert_contains "$(cat "$ROOT/.agents/inbox/frontend.md")" "Status: blocked" "dispatch timeout route status"
assert_contains "$(cat "$ROOT/.agents/routes/R902.md")" "Dispatch failure" "dispatch timeout route report"

"$ROOT/scripts/validate-route-state.sh" >/tmp/validate-route-state.out
assert_contains "$(cat /tmp/validate-route-state.out)" "Route state validation passed" "route state validator"

"$ROOT/scripts/route-agent.sh" R903 pm "Route status reporting" \
  --instruction "Produce a PM route report for status reporting." \
  --expected-output ".agents/task-board.md update and .agents/routes/R903.md report" \
  --validation "Route status shows current owner, evidence, and next action." \
  --context ".agents/route-schema.md" >/tmp/route-r903.out

"$ROOT/scripts/route-status.sh" R903 >/tmp/route-status-queued.out
assert_contains "$(cat /tmp/route-status-queued.out)" "Route: R903" "route-status queued"
assert_contains "$(cat /tmp/route-status-queued.out)" "Status: queued" "route-status queued"
assert_contains "$(cat /tmp/route-status-queued.out)" "Next action: dispatch route to pm" "route-status queued"

"$ROOT/scripts/claim-route.sh" R903 pm >/tmp/claim-r903.out
"$ROOT/scripts/complete-route.sh" R903 pm "PM report produced" \
  --report ".agents/routes/R903.md" \
  --output-ref ".agents/task-board.md" \
  --output-ref ".agents/routes/R903.md" >/tmp/complete-r903.out

completed_report="$(cat "$ROOT/.agents/routes/R903.md")"
assert_contains "$completed_report" "Completion summary: PM report produced" "completion output refs"
assert_contains "$completed_report" "- .agents/task-board.md" "completion output refs"
assert_contains "$completed_report" "- .agents/routes/R903.md" "completion output refs"
assert_contains "$(cat "$ROOT/.agents/inbox/pm.md")" "See .agents/routes/R903.md" "inbox response report pointer"
assert_contains "$(cat "$ROOT/.agents/handoffs.md")" "See .agents/routes/R903.md" "handoff response report pointer"

"$ROOT/scripts/route-status.sh" R903 >/tmp/route-status-done.out
assert_contains "$(cat /tmp/route-status-done.out)" "Status: done" "route-status done"
assert_contains "$(cat /tmp/route-status-done.out)" "Report: .agents/routes/R903.md" "route-status done"
assert_contains "$(cat /tmp/route-status-done.out)" "Output refs:" "route-status done"
assert_contains "$(cat /tmp/route-status-done.out)" "Next action: no action; route is done" "route-status done"

printf "Routing reliability tests passed.\n"
