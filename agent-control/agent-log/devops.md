# DevOps Agent Log

No DevOps activity yet.

## 2026-05-05T17:09:52Z - T101 Structured Route Runtime State

- Added the generated SQLite route runtime layer and wired lifecycle scripts to mirror route creation, dispatch, claim, completion, block, cancel, stale recovery, and run metadata.
- Updated setup/docs contracts so `workflow.sqlite3` is ignored, reset as runtime state, and validated by the scaffold checks.
- Validation evidence is recorded in `agent-control/validation-report.md`.

## 2026-05-05T17:27:38Z - T102 Auto-Start Agent Office With Team Startup

- Updated normal and worktree tmux startup to launch Agent Office in a dedicated `office` window.
- Kept the `server` window available for project dev servers and logs.
- Added `AGENT_OFFICE_PORT` support to startup and documented the default dashboard URL.

## 2026-05-05T17:40:12Z - T103 Preserve Route README During State Reset

- Fixed `reset-agent-team-state.sh` so it deletes generated route reports with `R[0-9]*.md` instead of deleting every markdown file starting with `R`.
- Added a regression check that reset preserves `agent-control/routes/README.md`.
- Repaired `/Users/hay/Documents/agent-team-instances/test_app-team` by restoring the missing route README and narrowing its reset pattern.

## 2026-05-06T05:16:09Z - T104 Repair Agent Office Profiles And Control Watcher Startup

- Restored missing static control-plane files in `/Users/hay/Documents/agent-team-instances/test_app-team`, including company profiles, route README, state files, skills, configs, ownership, schemas, and agent logs.
- Seeded live telemetry for the existing `agent-test_app` tmux role windows.
- Updated startup scripts to run control-window watcher commands through absolute script paths and avoid zsh's read-only `status` variable.

## 2026-05-07T20:11:20Z - Role Startup Readiness Gate

- Added Codex workspace pre-trust for generated team and target paths before tmux role launch.
- Added an explicit `ROLE_READY <role>` startup handshake and a watcher readiness gate before route dispatch starts.
- Changed dispatch so routes stay queued while a role session is still launching instead of being blocked as pane failures.
