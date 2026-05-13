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

assert_file_exists() {
  local path="$1"
  if [ ! -f "$path" ]; then
    fail "missing file: $path"
  fi
}

"$ROOT/scripts/reset-agent-team-state.sh" >/tmp/agent-session-reset.out
"$ROOT/scripts/route-agent.sh" R930 frontend "Context pressure checkpoint route" \
  --instruction "Keep progress in files when the session approaches its context limit." \
  --expected-output "agent-control/routes/R930.md has a progress checkpoint." \
  --validation "agent recovery checkpoint captures enough state to resume." \
  --context "agent-control/failure-recovery.md" >/tmp/route-r930.out
"$ROOT/scripts/claim-route.sh" R930 frontend >/tmp/claim-r930.out
"$ROOT/scripts/update-agent-state.sh" frontend \
  --session fake-session \
  --window frontend \
  --status busy \
  --active-route R930 \
  --workdir "$ROOT" \
  --target-project "$ROOT" \
  --process-status alive >/tmp/state-r930.out

detect_output="$(
  PATH="$ROOT/tests/fixtures:$PATH" \
  TMUX_FIXTURE_CAPTURE=$'ROLE_READY frontend\nContext window warning: 3% context left before compaction.' \
  "$ROOT/scripts/detect-agent-health.sh" fake-session
)"
assert_contains "$detect_output" '"role":"frontend"' "context pressure detection"
assert_contains "$detect_output" '"kind":"context-pressure"' "context pressure detection"
assert_contains "$detect_output" '"action":"compact-context"' "context pressure detection"

checkpoint_path="$(
  PATH="$ROOT/tests/fixtures:$PATH" \
  TMUX_FIXTURE_CAPTURE=$'ROLE_READY frontend\nContext window warning: 3% context left before compaction.' \
  "$ROOT/scripts/checkpoint-agent-context.sh" frontend fake-session --reason "context pressure"
)"
assert_file_exists "$ROOT/$checkpoint_path"
checkpoint_text="$(cat "$ROOT/$checkpoint_path")"
assert_contains "$checkpoint_text" "Role: frontend" "agent checkpoint"
assert_contains "$checkpoint_text" "Active route: R930" "agent checkpoint"
assert_contains "$checkpoint_text" "Context pressure checkpoint route" "agent checkpoint"
assert_contains "$checkpoint_text" "Pane Evidence" "agent checkpoint"
assert_contains "$checkpoint_text" "Resume Prompt" "agent checkpoint"
assert_contains "$(cat "$ROOT/agent-control/state/agent-recovery/index.jsonl")" '"role":"frontend"' "agent recovery index"

PATH="$ROOT/tests/fixtures:$PATH" \
  TMUX_FIXTURE_CAPTURE=$'ROLE_READY frontend\nContext window warning: 3% context left before compaction.' \
  AGENT_TEAM_AUTO_RECOVER_AGENTS=1 \
  ROUTE_DISPATCH_ACK_TIMEOUT=1 \
  "$ROOT/scripts/watch-routes.sh" fake-session --send --once >/tmp/watch-agent-recovery.out 2>/tmp/watch-agent-recovery.err || true

watch_output="$(cat /tmp/watch-agent-recovery.out /tmp/watch-agent-recovery.err)"
assert_contains "$watch_output" "monitor-agent-sessions: compact-context frontend" "watch agent recovery"
latest_marker="$ROOT/agent-control/state/agent-recovery/frontend.context-request"
assert_file_exists "$latest_marker"
assert_contains "$(cat "$latest_marker")" "active_route=R930" "context compact marker"

printf "Agent session recovery tests passed.\n"
