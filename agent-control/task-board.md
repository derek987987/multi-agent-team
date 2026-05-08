# Task Board

This file is owned by the PM agent.

## Status Values
- pending
- in-progress
- blocked
- ready-for-review
- done

## Task Template

### T001 - Task Title
Owner:
Status: template
Priority: P2
Depends on:
Branch / worktree:
Files / modules owned:

Objective:

Acceptance criteria:
- TBD

Validation:
- Command:
- Expected:

Handoffs:
- none

Notes:

### T101 - Structured Route Runtime State
Owner: devops
Status: ready-for-review
Priority: P1
Depends on: none
Branch / worktree: main
Files / modules owned:
- agent-control/quality-gates.md
- agent-control/route-schema.md
- agent-control/state/README.md
- agent-control/task-board.md
- agent-control/validation-report.md
- agent-control/decisions.md
- agent-control/agent-log/devops.md
- agent-control/agent-log/validation.md
- .gitignore
- AGENTS.md
- README.md
- scripts/block-route.sh
- scripts/cancel-route.sh
- scripts/claim-route.sh
- scripts/complete-route.sh
- scripts/dispatch-routes.sh
- scripts/heartbeat-routes.sh
- scripts/record-route-run.sh
- scripts/recover-stale-routes.sh
- scripts/reset-agent-team-state.sh
- scripts/route-agent.sh
- scripts/route-db.sh
- scripts/validate-agent-workflow.sh
- scripts/validate-structured-state.sh
- tests/test-runtime-priorities.sh

Objective:
Add a generated SQLite runtime mirror for route lifecycle state, atomic route claims, route run metadata, and completion gate references while preserving markdown and JSONL as durable human-readable workflow records.

Acceptance criteria:
- Route creation mirrors queued routes into `agent-control/state/workflow.sqlite3`.
- Claim, dispatch, completion, block, cancel, and stale-recovery lifecycle updates mirror status into SQLite.
- Approval-required completion rejects missing or unapproved `--approval-ref` values.
- Review-required completion rejects missing or non-done `--review-ref` values.
- Route run metadata records model, token, cost, exit-code, and summary fields.
- Heartbeat routing can list queued SQLite routes and delegate dispatch in dry-run or send mode.
- Runtime state is generated local data and is ignored by git.
- README, AGENTS, route schema, quality gates, and state docs describe the runtime layer.

Validation:
- Command: `bash tests/test-runtime-priorities.sh`
- Expected: `Runtime priority tests passed.`
- Command: `bash scripts/validate-agent-workflow.sh`
- Expected: `Agent workflow scaffold validation passed.`
- Command: `./scripts/validate-structured-state.sh`
- Expected: `agent-control/state/workflow.sqlite3 valid`
- Command: `./scripts/validate-route-state.sh`
- Expected: `Route state validation passed.`
- Command: `./scripts/check-secrets.sh`
- Expected: `Secrets check passed.`

Handoffs:
- none

Notes:
- Generated `agent-control/state/workflow.sqlite3` remains local runtime state; markdown reports and JSONL ledgers remain the durable contract.

### T102 - Auto-Start Agent Office With Team Startup
Owner: devops
Status: ready-for-review
Priority: P1
Depends on: T101
Branch / worktree: main
Files / modules owned:
- agent-control/task-board.md
- agent-control/validation-report.md
- agent-control/decisions.md
- agent-control/agent-log/devops.md
- agent-control/agent-log/validation.md
- AGENTS.md
- README.md
- scripts/new-coding-project.sh
- scripts/start-agent-team.sh
- scripts/start-agent-team-worktrees.sh
- tests/test-auto-codex-agent-team.sh

Objective:
Make `--start` and worktree startup host Agent Office automatically so the visual control surface is available as soon as the tmux team starts.

Acceptance criteria:
- Normal startup creates a dedicated tmux `office` window that serves Agent Office.
- Worktree startup creates the same `office` window.
- The existing `server` window remains available for target-project dev servers and logs.
- `AGENT_OFFICE_PORT` can override the default dashboard port.
- `new-coding-project.sh` prints the Agent Office URL and the correct next startup command.
- README and AGENTS describe the new startup behavior.

Validation:
- Command: `bash tests/test-auto-codex-agent-team.sh`
- Expected: `Auto Codex agent-team tests passed.`
- Command: `bash tests/test-agent-office-dashboard.sh`
- Expected: `Agent office dashboard tests passed.`
- Command: `bash scripts/validate-agent-workflow.sh`
- Expected: `Agent workflow scaffold validation passed.`

Handoffs:
- none

Notes:
- Chosen approach: make Agent Office part of `--start` by default instead of adding another opt-in flag.

### T103 - Preserve Route README During State Reset
Owner: devops
Status: ready-for-review
Priority: P1
Depends on: T102
Branch / worktree: main
Files / modules owned:
- agent-control/task-board.md
- agent-control/validation-report.md
- agent-control/agent-log/devops.md
- agent-control/agent-log/validation.md
- scripts/reset-agent-team-state.sh
- tests/test-auto-codex-agent-team.sh

Objective:
Fix new project bootstrap failure where `reset-agent-team-state.sh` removed `agent-control/routes/README.md`, causing `new-coding-project.sh` validation to fail with `Missing: agent-control/routes/README.md`.

Acceptance criteria:
- Reset deletes generated route reports such as `R001.md`.
- Reset preserves `agent-control/routes/README.md`.
- Fresh `new-coding-project.sh` bootstrap validates successfully.
- The previously failed `test_app-team` generated copy is repaired.

Validation:
- Command: `bash tests/test-auto-codex-agent-team.sh`
- Expected: `Auto Codex agent-team tests passed.`
- Command: `AGENT_TEAM_INSTANCE_ROOT=/tmp/agent-team-instances-repro ./scripts/new-coding-project.sh /tmp/agent-teams-repro-project`
- Expected: `Created project agent team.`
- Command: `bash scripts/validate-agent-workflow.sh`
- Expected: `Agent workflow scaffold validation passed.`
- Command: `./scripts/validate-agent-workflow.sh` from `/Users/hay/Documents/agent-team-instances/test_app-team`
- Expected: `Agent workflow scaffold validation passed.`

Handoffs:
- none

Notes:
- Root cause: shell pattern `R*.md` also matches `README.md`; the reset now deletes only `R[0-9]*.md`.

### T104 - Repair Agent Office Profiles And Control Watcher Startup
Owner: devops
Status: ready-for-review
Priority: P1
Depends on: T103
Branch / worktree: main
Files / modules owned:
- agent-control/task-board.md
- agent-control/validation-report.md
- agent-control/agent-log/devops.md
- agent-control/agent-log/validation.md
- scripts/start-agent-team.sh
- scripts/start-agent-team-worktrees.sh
- tests/test-auto-codex-agent-team.sh

Objective:
Fix Agent Office startup symptoms where a stale/incomplete generated copy showed no live telemetry, rejected Orchestrator prompts because role profiles were missing, and the control watcher failed from the wrong tmux working directory.

Acceptance criteria:
- Startup control-window commands use absolute `agent-status.sh` and `watch-routes.sh` paths.
- The watcher command avoids zsh's read-only `status` variable.
- The existing `/Users/hay/Documents/agent-team-instances/test_app-team` copy has required company profiles and static control-plane files restored.
- Agent Office snapshot for `test_app-team` reports 17 profiles, 17 agents, and 17 live telemetry rows.
- `test_app-team` has no diagnostic routes after repair.

Validation:
- Command: `bash tests/test-auto-codex-agent-team.sh`
- Expected: `Auto Codex agent-team tests passed.`
- Command: `python3` dashboard snapshot probe against `http://127.0.0.1:8765/api/snapshot`
- Expected: `profiles 17`, `agents 17`, `live 17`
- Command: `./scripts/validate-structured-state.sh && ./scripts/validate-route-state.sh` from `/Users/hay/Documents/agent-team-instances/test_app-team`
- Expected: structured state and route state pass.

Handoffs:
- none

Notes:
- The live `agent-test_app` control pane was restarted with absolute paths; no tmux session restart was required.
