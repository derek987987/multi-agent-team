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
assert_file_exists "scripts/watch-routes.sh"
assert_file_exists "scripts/agent-roles.sh"
assert_executable "scripts/codex-role.sh"
assert_executable "scripts/watch-routes.sh"

role_registry="$(cat "$ROOT/scripts/agent-roles.sh")"
for required_artifact in \
  .agents/context-map.md \
  .agents/agent-policy.md \
  .agents/evaluation-suite.md \
  .agents/failure-recovery.md \
  .agents/adaptation-guide.md \
  .agents/research-notes.md \
  .agents/performance-report.md; do
  assert_file_exists "$required_artifact"
done

for role in orchestrator product research cto design pm frontend backend data devops qa performance validation reviewer security docs integration; do
  assert_contains "$role_registry" "$role" "role registry"
  assert_file_exists ".agents/prompts/$role.md"
  assert_file_exists ".agents/skills/$role.md"
  assert_file_exists ".agents/memory/$role.md"
  assert_file_exists ".agents/agent-config/$role.yaml"
  assert_file_exists ".agents/inbox/$role.md"
  assert_file_exists ".agents/ownership/$role.paths"
  role_output="$("$ROOT/scripts/codex-role.sh" "$role" --workdir "$ROOT" --print)"
  assert_contains "$role_output" "codex --ask-for-approval never --sandbox workspace-write" "$role launcher"
  assert_contains "$role_output" ".agents/prompts/$role.md" "$role launcher"
  assert_contains "$role_output" ".agents/inbox/$role.md" "$role launcher"
  assert_contains "$role_output" ".agents/context-map.md" "$role launcher"
  assert_contains "$role_output" ".agents/agent-policy.md" "$role launcher"
  assert_contains "$role_output" ".agents/failure-recovery.md" "$role launcher"
done

assert_contains "$(cat "$ROOT/scripts/start-agent-team.sh")" "codex-role.sh" "standard tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team.sh")" "watch-routes.sh" "standard tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team.sh")" "AGENT_ROLES" "standard tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team-worktrees.sh")" "codex-role.sh" "worktree tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team-worktrees.sh")" "watch-routes.sh" "worktree tmux start"
assert_contains "$(cat "$ROOT/scripts/start-agent-team-worktrees.sh")" "PROJECT_WORKTREE_ROLES" "worktree tmux start"

launcher_output="$("$ROOT/scripts/codex-role.sh" orchestrator --print)"
assert_contains "$launcher_output" "codex --ask-for-approval never --sandbox workspace-write" "orchestrator launcher"
assert_contains "$launcher_output" "--cd" "orchestrator launcher"
assert_contains "$launcher_output" ".agents/prompts/orchestrator.md" "orchestrator launcher"
assert_contains "$launcher_output" ".agents/inbox/orchestrator.md" "orchestrator launcher"
assert_contains "$launcher_output" "You are the orchestrator agent" "orchestrator launcher"

frontend_output="$("$ROOT/scripts/codex-role.sh" frontend --workdir "$ROOT" --print)"
assert_contains "$frontend_output" "codex --ask-for-approval never --sandbox workspace-write" "frontend launcher"
assert_contains "$frontend_output" ".agents/prompts/frontend.md" "frontend launcher"
assert_contains "$frontend_output" ".agents/inbox/frontend.md" "frontend launcher"
assert_contains "$frontend_output" "claim assigned routes" "frontend launcher"

"$ROOT/scripts/watch-routes.sh" agent-team-test --once --dry-run >/tmp/agent-team-watch-routes-test.out
assert_contains "$(cat /tmp/agent-team-watch-routes-test.out)" "watch-routes" "route watcher"

cto_backup="$(mktemp)"
cp "$ROOT/.agents/inbox/cto.md" "$cto_backup"
restore_cto_inbox() {
  cp "$cto_backup" "$ROOT/.agents/inbox/cto.md"
  rm -f "$cto_backup"
}
trap restore_cto_inbox EXIT

cat >> "$ROOT/.agents/inbox/cto.md" <<'ROUTE'

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
assert_contains "$dispatch_output" ".agents/handoffs.md" "route dispatch"

printf "Auto Codex agent-team tests passed.\n"
