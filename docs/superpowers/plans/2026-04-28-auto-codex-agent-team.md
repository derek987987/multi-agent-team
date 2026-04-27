# Auto Codex Agent Team Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start a tmux-based coding-company team where every role launches Codex with `--full-auto`, and only the Orchestrator needs human prompting.

**Architecture:** Add a role launcher that creates a focused Codex prompt for each role and a route watcher that dispatches queued inbox routes into running role windows. Keep coordination file-backed through `.agents/*`; tmux remains process supervision and Codex input delivery.

**Tech Stack:** Bash, tmux, Codex CLI, markdown control-plane files, existing validation scripts.

---

### Task 1: Launcher And Watcher Tests

**Files:**
- Create: `tests/test-auto-codex-agent-team.sh`
- Modify: `scripts/validate-agent-workflow.sh`

- [ ] Write a shell test that verifies `scripts/codex-role.sh --print` includes `codex --full-auto`, the role prompt, inbox path, project target, and role-specific duties.
- [ ] Write a shell test that verifies `scripts/watch-routes.sh --once --dry-run` exits successfully without requiring tmux.
- [ ] Run `bash tests/test-auto-codex-agent-team.sh` and verify it fails because the scripts do not exist yet.

### Task 2: Codex Role Launcher

**Files:**
- Create: `scripts/codex-role.sh`

- [ ] Implement role validation for `orchestrator`, `cto`, `pm`, `frontend`, `backend`, `validation`, `reviewer`, `security`, and `integration`.
- [ ] Generate a role-specific Codex command using `codex --full-auto --cd <workdir> <prompt>`.
- [ ] Support `--print` for tests and troubleshooting.
- [ ] Include explicit instructions to read the role prompt, skill, memory, config, inbox, project target, and shared workflow files.

### Task 3: Route Watcher And Dispatcher

**Files:**
- Create: `scripts/watch-routes.sh`
- Modify: `scripts/dispatch-routes.sh`

- [ ] Implement `watch-routes.sh` with `--interval`, `--once`, `--dry-run`, and `--send`.
- [ ] Update dispatcher messages so target agents claim routes, read their inbox, act without human prompting, write reports/handoffs, and complete or block the route.
- [ ] Keep `--dry-run` safe for validation.

### Task 4: Tmux Startup Integration

**Files:**
- Modify: `scripts/start-agent-team.sh`
- Modify: `scripts/start-agent-team-worktrees.sh`
- Modify: `scripts/sync-agent-state.sh`
- Modify: `scripts/validate-agent-workflow.sh`

- [ ] Launch Codex in all agent windows using `scripts/codex-role.sh`.
- [ ] Start `scripts/watch-routes.sh <session> --send` in the control window.
- [ ] Preserve the server window as a non-agent terminal.
- [ ] Sync new scripts into worktrees.
- [ ] Add syntax and smoke checks for new scripts.

### Task 5: Role And Documentation Upgrade

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `.agents/prompts/orchestrator.md`
- Modify: `.agents/prompts/intake-orchestrator.md`
- Modify: `.agents/sop.md`
- Modify: `.agents/roles.md`
- Modify: `.agents/skills/*.md`
- Modify: `.agents/agent-config/*.yaml`
- Modify: `.agents/ownership/*.paths`

- [ ] Document Orchestrator-only human input and automatic Codex startup.
- [ ] Make the Orchestrator responsible for routing and dispatching, not asking the user to prompt other agents.
- [ ] Strengthen role-specific company workflow responsibilities and escalation paths.
- [ ] Add `scripts/codex-role.sh` and `scripts/watch-routes.sh` to role configs and ownership where needed.

### Task 6: Verification

**Files:**
- No new production files.

- [ ] Run `bash tests/test-auto-codex-agent-team.sh`.
- [ ] Run `./scripts/validate-agent-workflow.sh`.
- [ ] Run `./scripts/run-quality-gates.sh`.
- [ ] Review `git diff --check` and `git status --short`.
