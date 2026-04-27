# Standard Operating Procedure

This workflow borrows the best practical ideas from role-based multi-agent systems without requiring a heavyweight orchestration framework.

## Phase 0 - Intake

Owner: Human or Orchestrator

Inputs:
- Project idea
- Constraints
- Preferred stack
- Definition of done

Outputs:
- `.agents/brief.md`
- `.agents/workflow-state.md`

Exit criteria:
- Goal, users, core features, non-goals, and definition of done are explicit.
- The orchestrator has set the active phase and next route in `.agents/workflow-state.md`.

## Phase 1 - Product And Architecture

Owners:
- Orchestrator agent
- CTO agent
- PM agent

Inputs:
- `.agents/brief.md`
- existing repo files

Outputs:
- `.agents/architecture.md`
- `.agents/decisions.md`
- `.agents/task-board.md`
- `.agents/inbox/cto.md`
- `.agents/inbox/pm.md`

Exit criteria:
- Major modules are identified.
- File/module ownership is explicit.
- Validation method exists for every task.
- Human has approved the plan.

## Phase 2 - Implementation

Owners:
- frontend-agent
- backend-agent
- docs-agent, data-agent, or other role-specific agents as needed

Inputs:
- assigned task from `.agents/task-board.md`
- current architecture
- current decisions

Rules:
- Orchestrator routes planning work through `.agents/inbox/cto.md` and `.agents/inbox/pm.md`.
- Work in a branch or worktree when possible.
- Keep edits inside assigned ownership.
- Update `.agents/agent-log/<role>.md`.
- Use `.agents/handoffs.md` for dependencies or blockers.
- Do not silently change architecture to make a task easier.

Exit criteria:
- Acceptance criteria are met.
- Relevant checks from `.agents/quality-gates.md` pass.
- Task status is `ready-for-review`.

## Phase 3 - Review And Validation

Owners:
- validation-agent
- integration owner

Inputs:
- implementation branch/worktree
- `.agents/task-board.md`
- `.agents/quality-gates.md`

Outputs:
- `.agents/validation-report.md`
- task status updates
- `.agents/workflow-state.md`

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
- `.agents/final-cto-review.md`
- `.agents/final-acceptance.md`

Exit criteria:
- Architecture drift is reviewed.
- Scope completion is reviewed.
- Known risks are documented.
- Human decides to ship or start the next milestone.
