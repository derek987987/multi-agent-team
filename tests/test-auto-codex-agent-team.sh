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

assert_file_exists "scripts/codex-role.sh"
assert_file_exists "scripts/trust-codex-projects.sh"
assert_file_exists "scripts/wait-for-agent-sessions.sh"
assert_file_exists "scripts/watch-routes.sh"
assert_file_exists "scripts/agent-roles.sh"
assert_file_exists "scripts/update-agent-state.sh"
assert_executable "scripts/codex-role.sh"
assert_executable "scripts/trust-codex-projects.sh"
assert_executable "scripts/wait-for-agent-sessions.sh"
assert_executable "scripts/watch-routes.sh"
assert_executable "scripts/update-agent-state.sh"

role_registry="$(cat "$ROOT/scripts/agent-roles.sh")"
for required_artifact in \
  agent-control/context-map.md \
  agent-control/agent-policy.md \
  agent-control/evaluation-suite.md \
  agent-control/failure-recovery.md \
  agent-control/adaptation-guide.md \
  agent-control/research-notes.md \
  agent-control/performance-report.md; do
  assert_file_exists "$required_artifact"
done

for role in orchestrator product research cto design pm frontend backend data devops qa performance validation reviewer security docs integration; do
  assert_contains "$role_registry" "$role" "role registry"
  assert_file_exists "agent-control/prompts/$role.md"
  assert_file_exists "agent-control/skills/$role.md"
  assert_file_exists "agent-control/memory/$role.md"
  assert_file_exists "agent-control/agent-config/$role.yaml"
  assert_file_exists "agent-control/inbox/$role.md"
  assert_file_exists "agent-control/ownership/$role.paths"
  role_output="$("$ROOT/scripts/codex-role.sh" "$role" --workdir "$ROOT" --print)"
  assert_contains "$role_output" "codex --ask-for-approval never --sandbox workspace-write" "$role launcher"
  assert_contains "$role_output" "ROLE_READY $role" "$role launcher"
  assert_contains "$role_output" "agent-control/prompts/$role.md" "$role launcher"
  assert_contains "$role_output" "agent-control/inbox/$role.md" "$role launcher"
  assert_contains "$role_output" "agent-control/context-map.md" "$role launcher"
  assert_contains "$role_output" "agent-control/agent-policy.md" "$role launcher"
  assert_contains "$role_output" "agent-control/failure-recovery.md" "$role launcher"
done

assert_contains "$(cat "$ROOT/scripts/start-agent-team.sh")" "codex-role.sh" "standard tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team.sh")" "trust-codex-projects.sh" "standard tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team.sh")" "wait-for-agent-sessions.sh" "standard tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team.sh")" "AGENT_ROLE_READY_TIMEOUT" "standard tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team.sh")" "\"\$PROJECT_DIR/scripts/watch-routes.sh\"" "standard tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team.sh")" "\"\$PROJECT_DIR/scripts/agent-status.sh\"" "standard tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team.sh")" "AGENT_ROLES" "standard tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team.sh")" "start-agent-office-dashboard.sh" "standard tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team.sh")" "AGENT_OFFICE_PORT" "standard tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team.sh")" "Agent Office dashboard" "standard tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team-worktrees.sh")" "codex-role.sh" "worktree tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team-worktrees.sh")" "trust-codex-projects.sh" "worktree tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team-worktrees.sh")" "wait-for-agent-sessions.sh" "worktree tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team-worktrees.sh")" "AGENT_ROLE_READY_TIMEOUT" "worktree tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team-worktrees.sh")" "\"\$ROOT/scripts/watch-routes.sh\"" "worktree tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team-worktrees.sh")" "\"\$ROOT/scripts/agent-status.sh\"" "worktree tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team-worktrees.sh")" "PROJECT_WORKTREE_ROLES" "worktree tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team-worktrees.sh")" "start-agent-office-dashboard.sh" "worktree tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team-worktrees.sh")" "AGENT_OFFICE_PORT" "worktree tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team-worktrees.sh")" "Agent Office dashboard" "worktree tmux start"

launcher_output="$("$ROOT/scripts/codex-role.sh" orchestrator --print)"
assert_contains "$launcher_output" "codex --ask-for-approval never --sandbox workspace-write" "orchestrator launcher"
assert_contains "$launcher_output" "--cd" "orchestrator launcher"
assert_contains "$launcher_output" "agent-control/prompts/orchestrator.md" "orchestrator launcher"
assert_contains "$launcher_output" "agent-control/inbox/orchestrator.md" "orchestrator launcher"
assert_contains "$launcher_output" "You are the orchestrator agent" "orchestrator launcher"
assert_contains "$launcher_output" "Your first response must be exactly: ROLE_READY orchestrator" "orchestrator launcher"

frontend_output="$("$ROOT/scripts/codex-role.sh" frontend --workdir "$ROOT" --print)"
assert_contains "$frontend_output" "codex --ask-for-approval never --sandbox workspace-write" "frontend launcher"
assert_contains "$frontend_output" "agent-control/prompts/frontend.md" "frontend launcher"
assert_contains "$frontend_output" "agent-control/inbox/frontend.md" "frontend launcher"
assert_contains "$frontend_output" "claim assigned routes" "frontend launcher"

"$ROOT/scripts/watch-routes.sh" agent-team-test --once --dry-run >/tmp/agent-team-watch-routes-test.out
assert_contains "$(cat /tmp/agent-team-watch-routes-test.out)" "watch-routes" "route watcher"

trusted_root="$(cd "$ROOT" && pwd -P)"
CODEX_CONFIG_FILE="$tmp_parent/codex/config.toml" "$ROOT/scripts/trust-codex-projects.sh" "$ROOT" >/tmp/trust-codex-projects-test.out
assert_contains "$(cat "$tmp_parent/codex/config.toml")" "[projects.\"$trusted_root\"]" "codex trust config"
assert_contains "$(cat "$tmp_parent/codex/config.toml")" "trust_level = \"trusted\"" "codex trust config"

PATH="$ROOT/tests/fixtures:$PATH" TMUX_FIXTURE_CAPTURE="ROLE_READY frontend" \
  "$ROOT/scripts/wait-for-agent-sessions.sh" fake-session --roles frontend --timeout 0 --quiet
agent_ready_state="$(cat "$ROOT/agent-control/state/agents.jsonl")"
assert_contains "$agent_ready_state" '"role":"frontend"' "agent readiness telemetry"
assert_contains "$agent_ready_state" '"status":"available"' "agent readiness telemetry"

reset_tmp_parent="$tmp_parent/reset-copy"
reset_copy="$reset_tmp_parent/agent-teams"
mkdir -p "$reset_tmp_parent"
rsync -a \
  --exclude ".git/" \
  --exclude ".DS_Store" \
  "$ROOT/" "$reset_copy/"
chmod +x "$reset_copy"/scripts/*.sh
"$reset_copy/scripts/reset-agent-team-state.sh" >/tmp/reset-agent-team-state-test.out
if [ ! -f "$reset_copy/agent-control/routes/README.md" ]; then
  fail "reset-agent-team-state removed agent-control/routes/README.md"
fi
if command -v chflags >/dev/null 2>&1 && find "$reset_copy/agent-control" -flags +hidden -print -quit | grep -q .; then
  fail "reset-agent-team-state left macOS hidden flags on agent-control"
fi

cat >> "$ROOT/agent-control/inbox/cto.md" <<'ROUTE'

## R999 - Test auto dispatch prompt
Status: queued
From: orchestrator
To: cto
Related task:
Created:
2026-04-28T00:00:00Z

Instruction:
Verify dispatcher message content.

Expected output:
Dry-run prompt contains autonomous route handling steps.

Validation / done criteria:
No tmux send occurs in dry-run mode.

Response:
ROUTE

dispatch_output="$("$ROOT/scripts/dispatch-routes.sh" agent-team-test --dry-run)"
assert_contains "$dispatch_output" "claim the route" "route dispatch"
assert_contains "$dispatch_output" "complete-route.sh" "route dispatch"
assert_contains "$dispatch_output" "agent-control/handoffs.md" "route dispatch"

"$ROOT/scripts/update-agent-state.sh" frontend \
  --session agent-team-test \
  --window frontend \
  --status busy \
  --active-route R999 \
  --workdir "$ROOT" \
  --target-project "$ROOT" \
  --process-status alive
agent_state="$(cat "$ROOT/agent-control/state/agents.jsonl")"
assert_contains "$agent_state" '"role":"frontend"' "agent telemetry"
assert_contains "$agent_state" '"status":"busy"' "agent telemetry"
assert_contains "$agent_state" '"active_route":"R999"' "agent telemetry"

printf "Auto Codex agent-team tests passed.\n"
