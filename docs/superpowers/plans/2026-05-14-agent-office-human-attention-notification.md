# Agent Office Human Attention Notification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a file-backed project-completion notification that Agent Office renders as a `!` marker on the Orchestrator.

**Architecture:** A new completion-check script evaluates routes, task status, done checks, final acceptance artifacts, and agent health, then writes a deduplicated notification record to `agent-control/state/notifications.jsonl` and mirrors the message into `workflow-state.md`. Agent Office reads the notification state through the existing snapshot API and renders active Orchestrator notifications in the canvas and inspector.

**Tech Stack:** Bash scripts, Python standard library for JSONL parsing and markdown updates, no-build vanilla JavaScript/CSS dashboard, existing shell test suite.

---

### Task 1: Completion Notification Script And State Contract

**Files:**
- Create: `scripts/check-project-completion-notification.sh`
- Create: `agent-control/state/notifications.jsonl`
- Modify: `scripts/reset-agent-team-state.sh`
- Modify: `scripts/validate-structured-state.sh`
- Test: `tests/test-project-completion-notification.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test-project-completion-notification.sh` with cases that:
- reset a copied control plane;
- verify no notification is written while final acceptance files are still `Pending.`;
- verify no notification is written when a route is still queued;
- verify no notification is written when `check-done.sh` sees an open major finding;
- write meaningful final CTO and PM acceptance files, run `check-project-completion-notification.sh fake-session --apply`, and assert one active `project-complete-ready-for-human` record exists;
- run the script a second time and assert it does not append a duplicate active record;
- assert `workflow-state.md` contains `Project ready for final human review`.

Run:

```bash
bash tests/test-project-completion-notification.sh
```

Expected before implementation:

```text
No such file or directory
```

- [ ] **Step 2: Implement the script**

Add `scripts/check-project-completion-notification.sh` as a Bash wrapper around a Python standard-library check. The script must support:

```bash
./scripts/check-project-completion-notification.sh [tmux-session] --dry-run
./scripts/check-project-completion-notification.sh [tmux-session] --apply
```

The Python logic should:
- treat statuses `queued`, `dispatching`, `dispatched`, `acknowledged`, `in-progress`, `blocked`, `pending`, and `ready-for-review` as not complete;
- inspect latest route records from `agent-control/state/routes.jsonl` plus `agent-control/routes/R*.md`;
- inspect `agent-control/task-board.md` for task status lines and reject `pending`, `in-progress`, `blocked`, or `ready-for-review`;
- reject final review files whose non-heading content is empty, `Pending.`, or contains `TBD`;
- run `scripts/check-done.sh`;
- run `scripts/detect-agent-health.sh <session>` and reject non-empty findings;
- append one active notification record only when the latest status for `project-complete-ready-for-human` is not already `active`;
- append a `dismissed` record if an active notification exists and completion criteria later fail;
- update `## Human Attention Needed` in `workflow-state.md` only in `--apply` mode.

- [ ] **Step 3: Wire structured state**

Add an empty tracked `agent-control/state/notifications.jsonl`, make reset truncate it, and make `validate-structured-state.sh` validate it with the other JSONL state mirrors.

- [ ] **Step 4: Run the notification test**

Run:

```bash
bash tests/test-project-completion-notification.sh
```

Expected:

```text
Project completion notification tests passed.
```

### Task 2: Watcher And Heartbeat Integration

**Files:**
- Modify: `scripts/watch-routes.sh`
- Modify: `scripts/heartbeat-routes.sh`
- Test: `tests/test-project-completion-notification.sh`

- [ ] **Step 1: Add failing assertions**

Extend `tests/test-project-completion-notification.sh` to assert both watcher scripts mention `check-project-completion-notification.sh`.

Run:

```bash
bash tests/test-project-completion-notification.sh
```

Expected before wiring:

```text
FAIL: watcher integration missing expected text: check-project-completion-notification.sh
```

- [ ] **Step 2: Integrate the script**

In `watch-routes.sh`, call:

```bash
"$ROOT/scripts/check-project-completion-notification.sh" "$SESSION" "$completion_mode" || true
```

after dispatch completes, where `completion_mode` is `--apply` in `--send` mode and `--dry-run` otherwise.

In `heartbeat-routes.sh`, call the same script after dispatch.

- [ ] **Step 3: Run the notification test**

Run:

```bash
bash tests/test-project-completion-notification.sh
```

Expected:

```text
Project completion notification tests passed.
```

### Task 3: Agent Office API And UI Marker

**Files:**
- Modify: `visual-media/agent_office_server.py`
- Modify: `visual-media/app.js`
- Modify: `visual-media/styles.css`
- Test: `tests/test-agent-office-dashboard.sh`

- [ ] **Step 1: Add failing API/UI assertions**

Extend `tests/test-agent-office-dashboard.sh` to:
- write an active notification record to `agent-control/state/notifications.jsonl`;
- assert `build_snapshot(root)` includes `notifications`;
- assert the active notification targets `orchestrator`;
- assert the dashboard JavaScript contains `notificationBadge` and `notificationsForRole`;
- assert CSS contains `.notification-card`.

Run:

```bash
bash tests/test-agent-office-dashboard.sh
```

Expected before implementation:

```text
AssertionError
```

- [ ] **Step 2: Expose notifications in the API**

In `visual-media/agent_office_server.py`, add a parser for `agent-control/state/notifications.jsonl`. Build latest notification state by `notification_id`, return all latest records in `notifications`, and return active records in `human_attention_notifications`.

- [ ] **Step 3: Render the Orchestrator marker**

In `visual-media/app.js`:
- add `notificationsForRole(role)`;
- add `hasActionNotification(role)`;
- draw a `!` marker for any agent with active `action` or `watch` notifications;
- include matching notifications in `refsForAgent`;
- include notification cards in `updateHealthList(agent)`.

In `visual-media/styles.css`, add `.notification-card` styling consistent with existing health cards.

- [ ] **Step 4: Run the Agent Office test**

Run:

```bash
bash tests/test-agent-office-dashboard.sh
```

Expected:

```text
Agent office dashboard tests passed.
```

### Task 4: Documentation And Validation

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `agent-control/state/README.md`
- Modify: `docs/superpowers/specs/2026-05-14-agent-office-human-attention-design.md`

- [ ] **Step 1: Document the behavior**

Update docs to state:
- completion notification state lives at `agent-control/state/notifications.jsonl`;
- watcher/heartbeat checks can mark Orchestrator as needing human attention;
- Agent Office shows `!` on the Orchestrator when active human attention is required;
- the notification means ready for human ship/no-ship review, not approval.

- [ ] **Step 2: Run validators and tests**

Run:

```bash
bash tests/test-project-completion-notification.sh
bash tests/test-agent-office-dashboard.sh
./scripts/validate-agent-workflow.sh
./scripts/validate-route-state.sh
./scripts/validate-structured-state.sh
./scripts/check-secrets.sh
git diff --check
```

Expected:

```text
Project completion notification tests passed.
Agent office dashboard tests passed.
Agent workflow scaffold validation passed.
Route state validation passed.
agent-control/state/notifications.jsonl valid
Secrets check passed.
```

### Task 5: Commit

**Files:**
- All files changed by Tasks 1-4.

- [ ] **Step 1: Review the diff**

Run:

```bash
git diff --stat
git diff -- scripts/check-project-completion-notification.sh visual-media/agent_office_server.py visual-media/app.js visual-media/styles.css
```

- [ ] **Step 2: Commit implementation**

Run:

```bash
git add scripts/check-project-completion-notification.sh scripts/watch-routes.sh scripts/heartbeat-routes.sh scripts/reset-agent-team-state.sh scripts/validate-structured-state.sh agent-control/state/notifications.jsonl visual-media/agent_office_server.py visual-media/app.js visual-media/styles.css tests/test-project-completion-notification.sh tests/test-agent-office-dashboard.sh README.md AGENTS.md agent-control/state/README.md docs/superpowers/specs/2026-05-14-agent-office-human-attention-design.md docs/superpowers/plans/2026-05-14-agent-office-human-attention-notification.md
git commit -m "feat: add Agent Office human attention notification"
```

---

## Self-Review

Spec coverage:
- Durable file-backed notification: Task 1.
- Orchestrator `!` marker in Agent Office: Task 3.
- Watcher/heartbeat integration: Task 2.
- Workflow-state human attention mirror: Task 1.
- Conservative final-completion semantics: Task 1.
- Tests and docs: Tasks 1, 3, and 4.

Placeholder scan:
- No `TBD`, `TODO`, or implementation-later placeholders remain in the plan.

Type consistency:
- The notification fields match the approved spec: `notification_id`, `status`, `severity`, `target_role`, `title`, `message`, `source`, `evidence_refs`, `created`, and `updated`.
