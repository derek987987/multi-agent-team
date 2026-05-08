# Standard Operating Procedure

This workflow borrows the best practical ideas from role-based multi-agent systems without requiring a heavyweight orchestration framework.

## Company Operating Model

The human normally prompts only the Orchestrator. The Orchestrator creates routes and handoffs in `agent-control/*`, and the route watcher dispatches those routes to auto-launched Codex agents running sandboxed without shell-command approval prompts. Agents communicate through markdown control-plane files and per-route reports, not by asking the human to relay messages.

Production controls:
- `agent-control/context-map.md` controls what context each role should load.
- `agent-control/agent-policy.md` defines autonomy, guardrails, stop conditions, and output discipline.
- `agent-control/evaluation-suite.md` tracks scaffold and project evals.
- `agent-control/failure-recovery.md` routes blockers and repeated failures.
- `agent-control/adaptation-guide.md` maps project types to early specialist involvement.

## Phase 0 - Intake

Owner: Human or Orchestrator

Inputs:
- Project idea
- Constraints
- Preferred stack
- Definition of done

Outputs:
- `agent-control/brief.md`
- `agent-control/product-requirements.md` when product scope needs detail
- `agent-control/workflow-state.md`
- `agent-control/inbox/cto.md` after brief approval

Exit criteria:
- Goal, users, core features, non-goals, and definition of done are explicit.
- The orchestrator has set the active phase and next route in `agent-control/workflow-state.md`.
- CTO planning is queued as a route instead of a human prompt.

## Phase 1 - Product And Architecture

Owners:
- Orchestrator agent
- Product agent
- Research agent
- CTO agent
- Design agent
- PM agent

Inputs:
- `agent-control/brief.md`
- existing repo files

Outputs:
- `agent-control/product-requirements.md`
- `agent-control/architecture.md`
- `agent-control/decisions.md`
- `agent-control/design-notes.md`
- `agent-control/task-board.md`
- `agent-control/qa-plan.md`
- `agent-control/inbox/cto.md`
- `agent-control/inbox/pm.md`

Exit criteria:
- Major modules are identified.
- Product/user acceptance risks are identified.
- Unfamiliar stack or platform assumptions are researched.
- Design handoff exists for user-facing work.
- File/module ownership is explicit.
- Validation method exists for every task.
- Human has approved the plan.

## Phase 2 - Implementation

Owners:
- frontend
- backend
- data
- devops
- qa
- performance
- docs
- other role-specific agents as needed

Inputs:
- assigned task from `agent-control/task-board.md`
- current architecture
- current decisions

Rules:
- Orchestrator routes planning work through `agent-control/inbox/cto.md`, `agent-control/inbox/pm.md`, and `agent-control/routes/R000.md` reports.
- Auto-launched agents claim assigned routes before acting and complete or block routes with route-report evidence when finished.
- Work in a branch or worktree when possible.
- Keep edits inside assigned ownership.
- Update `agent-control/agent-log/<role>.md`.
- Use `agent-control/handoffs.md` for dependencies or blockers.
- Do not silently change architecture to make a task easier.

Exit criteria:
- Acceptance criteria are met.
- Relevant checks from `agent-control/quality-gates.md` pass.
- Task status is `ready-for-review`.

## Phase 3 - Review And Validation

Owners:
- qa
- validation
- reviewer
- security
- performance when budgets or regressions matter
- integration owner

Inputs:
- implementation branch/worktree
- `agent-control/task-board.md`
- `agent-control/quality-gates.md`

Outputs:
- `agent-control/validation-report.md`
- task status updates
- `agent-control/workflow-state.md`

Exit criteria:
- Findings are recorded with severity.
- Critical and major findings are resolved or explicitly accepted by the human.
- Build, lint/type checks, and tests pass where applicable.

## Phase 4 - Integration

Owner: integration owner, usually the human or lead engineer agent

Rules:
- Merge one branch at a time.
- Re-run validation after every merge.
- Resolve conflicts deliberately.
- Do not allow implementation agents to merge their own work without review.

Exit criteria:
- Main branch is green.
- Validation report is current.

## Phase 5 - Final Acceptance

Owners:
- CTO agent
- PM agent
- Human

Outputs:
- `agent-control/final-cto-review.md`
- `agent-control/final-acceptance.md`

Exit criteria:
- Architecture drift is reviewed.
- Scope completion is reviewed.
- Known risks are documented.
- Human decides to ship or start the next milestone.
