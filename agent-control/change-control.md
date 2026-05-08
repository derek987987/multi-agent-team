# Change Control During The Workflow

Use this guide when you need to change specifications, modify features, or fix bugs after the multi-agent workflow has already started.

## Core Principle

Do not rely on a private instruction to one coding agent for anything that affects product behavior, architecture, task ownership, or validation. Record the change in the shared workflow files first, then ask the right role to act.

## Fallback Path - One Prompt To The CTO

Use this only when you intentionally want CTO-led routing instead of the orchestrator.

Steps:

1. Add your request to `.agents/change-request.md`.
2. Ask the CTO agent to run `.agents/prompts/change-router-cto.md`.
3. Ask the PM agent to run `.agents/prompts/change-router-pm.md` if the CTO notes that task-board updates are needed.
4. Resume implementation agents only after the task board is updated.

Human prompt:

```text
I added a change request to .agents/change-request.md.

Act as CTO change router.
Use .agents/prompts/change-router-cto.md.

Classify the change, update the necessary source-of-truth docs, and write the PM instruction in .agents/agent-log/cto.md.
Do not implement code.
```

PM follow-up prompt:

```text
The CTO routed a change request.

Act as PM change router.
Use .agents/prompts/change-router-pm.md.

Update .agents/task-board.md with concrete tasks, owners, dependencies, acceptance criteria, and validation commands.
Do not implement code.
```

This is useful for architecture-heavy changes, but the orchestrator path below is preferred when you want minimal prompting.

## Lowest-Prompt Path - One Prompt To The Orchestrator

If you want to prompt only one agent, use the orchestrator window.

Human prompt:

```text
Use .agents/prompts/orchestrator.md.

Request:
<describe the change, bug, feature modification, or status question>

Please classify it, update the suitable workflow files, route the work to the right agents through handoffs/tasks, and tell me the next single action.
```

What the orchestrator should do:

- update `.agents/change-request.md` when the request is a change
- update `.agents/brief.md` when product behavior or scope changes
- update `.agents/decisions.md` when a tradeoff or approval record is needed
- update `.agents/task-board.md` for simple obvious task changes
- create `.agents/handoffs.md` entries when CTO, PM, implementation, or validation agents need to act
- write a routing summary to `.agents/agent-log/orchestrator.md`

Important limitation:

In a plain tmux setup, one agent does not automatically type into another agent's terminal. Cascading happens through shared files: tasks, handoffs, logs, decisions, and validation reports. Other agents then read those files and continue from their own windows.

This is the recommended path when you want minimal prompting.

## Where To Put Each Kind Of Change

| Situation | Primary File | Supporting Files |
| --- | --- | --- |
| Product/spec change | `.agents/brief.md` | `.agents/decisions.md`, `.agents/architecture.md`, `.agents/task-board.md` |
| Feature addition/removal | `.agents/brief.md` | `.agents/decisions.md`, `.agents/task-board.md` |
| Architecture change | `.agents/architecture.md` | `.agents/decisions.md`, `.agents/task-board.md` |
| New bug | `.agents/task-board.md` | `.agents/validation-report.md`, `.agents/agent-log/<role>.md` |
| Cross-agent dependency | `.agents/handoffs.md` | `.agents/task-board.md` |
| Validation rule change | `.agents/quality-gates.md` | `.agents/validation-report.md` |

## Scenario 1 - Change The Specification

Use this when the product goal, requirements, user behavior, non-goals, or definition of done changes.

Steps:

1. Update `.agents/brief.md`.
2. Add a decision record to `.agents/decisions.md`.
3. Ask the CTO agent to review impact and update `.agents/architecture.md`.
4. Ask the PM agent to update `.agents/task-board.md`.
5. Pause affected implementation tasks until ownership and validation are clear.
6. Resume implementation agents only after the updated task board is reviewed.

Decision record template:

```md
### Decision 000 - Short Title
Date:
Owner:

Decision:

Reason:

Impact:
- Affected roles:
- Affected files/modules:
- Affected tasks:
- Validation changes:
```

CTO prompt:

```text
The project specification changed.

Read:
- AGENTS.md
- .agents/brief.md
- .agents/sop.md
- .agents/roles.md
- .agents/decisions.md
- .agents/architecture.md
- .agents/task-board.md

Update .agents/architecture.md if needed.
Record new tradeoffs in .agents/decisions.md.
Identify affected modules, risks, task ownership changes, and validation changes.
Do not implement code.
```

PM prompt:

```text
The project specification changed.

Read:
- AGENTS.md
- .agents/brief.md
- .agents/sop.md
- .agents/roles.md
- .agents/architecture.md
- .agents/decisions.md
- .agents/task-board.md
- .agents/quality-gates.md

Update .agents/task-board.md:
- add new tasks
- update affected tasks
- mark obsolete tasks
- update dependencies
- update owners
- update acceptance criteria
- update validation commands

Do not implement code.
```

## Scenario 2 - Modify A Feature

Use this when an existing feature should behave differently, gain a small capability, or lose a capability.

Steps:

1. If user-facing behavior changes, update `.agents/brief.md`.
2. If the change creates a tradeoff or affects architecture, add `.agents/decisions.md`.
3. Add or update tasks in `.agents/task-board.md`.
4. Check whether the change crosses ownership boundaries.
5. If yes, create a handoff in `.agents/handoffs.md`.
6. Ask the assigned implementation agent to work only on the updated task.

Implementation prompt:

```text
Feature behavior changed for task <TASK_ID>.

Read:
- AGENTS.md
- .agents/brief.md
- .agents/architecture.md
- .agents/task-board.md
- .agents/handoffs.md
- .agents/quality-gates.md

Only work on <TASK_ID>.
Keep edits inside the assigned files/modules.
Update acceptance criteria, validation evidence, task status, and your agent log.
Do not change architecture silently.
```

## Scenario 3 - Fix A Bug

Use this when validation, a user, or an agent finds incorrect behavior.

Steps:

1. Add the bug to `.agents/validation-report.md` if it came from validation.
2. Add a bug-fix task to `.agents/task-board.md`.
3. Assign an owner and file/module boundaries.
4. Add reproduction steps and validation commands.
5. Ask the owner agent to fix only that bug.
6. Ask the validation agent to verify the fix before merge.

Bug task template:

```md
### T000 - Fix short bug title
Owner:
Status: pending
Priority: P0 | P1 | P2 | P3
Depends on:
Branch / worktree:
Files / modules owned:

Objective:
Fix the observed bug without changing unrelated behavior.

Acceptance criteria:
- Bug is fixed.
- Regression test covers the bug where practical.
- Existing behavior outside the bug remains unchanged.

Validation:
- Command:
- Expected:

Handoffs:
- none

Notes:
- Reproduction:
- Observed:
- Expected:
```

Bug-fix prompt:

```text
A bug-fix task was added: <TASK_ID>.

Read:
- AGENTS.md
- .agents/task-board.md
- .agents/validation-report.md
- .agents/quality-gates.md

Only work on <TASK_ID>.
Reproduce the bug if possible.
Fix the smallest responsible area.
Add or update a regression test where practical.
Run the relevant validation command.
Update task status and your agent log.
```

Validation prompt:

```text
Validate bug fix <TASK_ID>.

Read:
- AGENTS.md
- .agents/task-board.md
- .agents/validation-report.md
- .agents/quality-gates.md

Check:
- the bug is fixed
- the regression test exists where practical
- relevant validation commands pass
- unrelated behavior was not changed

Update .agents/validation-report.md with evidence and remaining findings.
```

## Scenario 4 - Cross-Agent Dependency

Use this when one agent needs another agent to change its owned files/modules.

Steps:

1. Add a handoff to `.agents/handoffs.md`.
2. Do not let the requesting agent edit the receiving agent's files.
3. Receiving agent marks the handoff `accepted`, `blocked`, `done`, or `declined`.
4. PM updates `.agents/task-board.md` if the handoff changes dependencies or scope.

Handoff example:

```md
### H002 - Frontend needs task status label
Status: open
From: frontend
To: backend
Date:
Related task: T014
Files / modules:
- API response for tasks

Request:
Expose `statusLabel` in the task list API response.

Context:
The dashboard needs a display-ready status label.

Acceptance criteria:
- API response includes `statusLabel`.
- Backend tests cover the field.

Response:
```

## Scenario 5 - Emergency Stop Or Replan

Use this when the current direction is wrong, too risky, or causing repeated conflicts.

Steps:

1. Mark affected tasks `blocked` in `.agents/task-board.md`.
2. Add a decision record in `.agents/decisions.md`.
3. Ask CTO for a replan.
4. Ask PM to rebuild the task board.
5. Resume only after the human approves the new plan.

Emergency replan prompt:

```text
Pause implementation and replan.

Reason:
<describe why the current direction is blocked or risky>

Read:
- AGENTS.md
- .agents/brief.md
- .agents/sop.md
- .agents/architecture.md
- .agents/decisions.md
- .agents/task-board.md
- .agents/validation-report.md

Identify what should stop, what should continue, and what must change.
Update architecture/decisions if you are the CTO.
Update task-board if you are the PM.
Do not implement code.
```

## Priority Guide

- `P0`: blocks the project or causes data loss/security failure
- `P1`: blocks a core workflow or major acceptance criterion
- `P2`: normal feature or bug fix
- `P3`: polish, cleanup, docs, minor improvement

## Status Rules

- `pending`: task is ready but not started
- `in-progress`: owner is actively working
- `blocked`: task cannot proceed without a decision, dependency, or handoff
- `ready-for-review`: owner believes the task is complete and validation can inspect it
- `done`: validation passed and integration owner accepts it
- `obsolete`: task was replaced by a spec change or replan

## Quick Decision Path

```text
Small bug in one module:
  validation-report if needed -> task-board -> owner agent -> validation

Feature behavior change:
  brief if user-facing -> decisions if tradeoff -> task-board -> owner agent -> validation

Cross-agent dependency:
  handoffs -> receiving agent -> PM updates task-board if needed

Architecture change:
  decisions -> CTO architecture update -> PM task update -> implementation resumes

Current plan is wrong:
  block affected tasks -> decision record -> CTO replan -> PM replan -> human approval
```
