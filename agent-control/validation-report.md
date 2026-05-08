# Validation Report

This file is owned by the validation agent.

## Latest Validation Summary
Date: 2026-05-06T05:16:09Z
Commit / Branch: main working tree

## Commands Run
- `bash tests/test-runtime-priorities.sh`
- `bash scripts/validate-agent-workflow.sh`
- `./scripts/validate-structured-state.sh`
- `./scripts/validate-route-state.sh`
- `./scripts/check-secrets.sh`
- `./scripts/check-stale-routes.sh`
- `./scripts/check-route-budget.sh`
- `./scripts/check-milestone-budget.sh`
- `./scripts/check-memory.sh`
- `bash tests/test-auto-codex-agent-team.sh`
- `bash tests/test-agent-office-dashboard.sh`
- `AGENT_TEAM_INSTANCE_ROOT=/tmp/agent-team-instances-repro ./scripts/new-coding-project.sh /tmp/agent-teams-repro-project`
- `./scripts/validate-agent-workflow.sh` from `/Users/hay/Documents/agent-team-instances/test_app-team`
- Dashboard snapshot probe against `http://127.0.0.1:8765/api/snapshot`
- `./scripts/validate-structured-state.sh && ./scripts/validate-route-state.sh` from `/Users/hay/Documents/agent-team-instances/test_app-team`

## Critical Findings
None recorded.

## Major Findings
None recorded.

## Minor Findings
None recorded.

## Passed Checks
- Runtime priority tests passed.
- Agent workflow scaffold validation passed.
- Structured state validation passed, including `agent-control/state/workflow.sqlite3 valid`.
- Route state validation passed.
- Secrets check passed.
- Stale route, route budget, milestone budget, and memory policy checks passed.
- Auto Codex agent-team tests passed after Agent Office auto-start changes.
- Agent Office dashboard tests passed after Agent Office auto-start changes.
- Fresh generated project-team bootstrap passed after preserving `agent-control/routes/README.md`.
- Existing `/Users/hay/Documents/agent-team-instances/test_app-team` copy validates after repair.
- Agent Office snapshot reports 17 profiles, 17 agents, and 17 live telemetry rows for `test_app-team`.
- `test_app-team` structured state and route state pass with no open diagnostic routes.

## Finding Template

### Finding V001 - Short Title
Severity: critical | major | minor
Status: open | fixed | accepted
Task:
Files:

Problem:

Reproduction / command:

Expected result:

Actual result:

Recommendation:
