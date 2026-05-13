# Agent Session Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Detect stuck and full-context role sessions, checkpoint their context into durable control-plane files, and recover agents without losing route state.

**Architecture:** Add a role-session recovery layer before route dispatch. The detector emits JSONL findings from tmux pane evidence and `agents.jsonl`; checkpointing writes recovery packets under `agent-control/state/agent-recovery/`; the monitor chooses readiness repair, compact-context request, or relaunch.

**Tech Stack:** Bash scripts, tmux pane capture, JSONL state, SQLite-backed route state through existing scripts, existing shell test suite.

---

### Task 1: Recovery Tests

**Files:**
- Create: `tests/test-agent-session-recovery.sh`

- [x] **Step 1: Write failing test**

Add a test that creates an active frontend route, simulates a pane with `3% context left`, expects `detect-agent-health.sh` to emit `context-pressure`, expects `checkpoint-agent-context.sh` to write a recovery packet, and expects `watch-routes.sh --send --once` to create a compact-context marker.

- [x] **Step 2: Run test to verify it fails**

Run: `./tests/test-agent-session-recovery.sh`

Expected: fails because `scripts/detect-agent-health.sh` does not exist.

### Task 2: Detection And Checkpoint Scripts

**Files:**
- Create: `scripts/detect-agent-health.sh`
- Create: `scripts/checkpoint-agent-context.sh`

- [x] **Step 1: Implement detector**

Emit JSONL findings for readiness drift, failed session pane output, missing/dead active panes, and context-pressure pane output.

- [x] **Step 2: Implement checkpoint writer**

Write `agent-control/state/agent-recovery/<timestamp>-<role>-<pid>.md` with pane evidence, active inbox packet, route report, workflow state, handoffs, target git status, and a resume prompt.

- [x] **Step 3: Run focused test**

Run: `./tests/test-agent-session-recovery.sh`

Expected: detection and checkpoint assertions pass.

### Task 3: Recovery Monitor

**Files:**
- Create: `scripts/recover-agent-session.sh`
- Create: `scripts/monitor-agent-sessions.sh`
- Modify: `scripts/watch-routes.sh`
- Modify: `scripts/heartbeat-routes.sh`

- [x] **Step 1: Implement recovery actions**

`compact-context` sends a file-backed checkpoint request to a live pane. `relaunch-agent` checkpoints first, restarts the role pane, waits for `ROLE_READY`, and sends a resume prompt.

- [x] **Step 2: Wire watcher and heartbeat**

Run `monitor-agent-sessions.sh` before stale-route recovery and dispatch, with `AGENT_TEAM_AUTO_RECOVER_AGENTS=0` as the opt-out.

- [x] **Step 3: Run focused test**

Run: `./tests/test-agent-session-recovery.sh`

Expected: watcher output includes `monitor-agent-sessions: compact-context frontend`.

### Task 4: Documentation And Validation

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `agent-control/failure-recovery.md`
- Modify: `agent-control/quality-gates.md`
- Modify: `agent-control/route-schema.md`
- Modify: `scripts/validate-agent-workflow.sh`
- Modify: `tests/test-auto-codex-agent-team.sh`

- [x] **Step 1: Document the prevention contract**

Describe agent-session monitoring as context-preserving recovery before stale-route recovery.

- [x] **Step 2: Register scripts in validation**

Add script existence, executability, shell syntax, and full-suite execution checks.

- [x] **Step 3: Run full validation**

Run:

```bash
./scripts/validate-agent-workflow.sh
./scripts/validate-route-state.sh
./scripts/validate-structured-state.sh
./scripts/check-secrets.sh
git diff --check
```

Expected: all commands pass.
