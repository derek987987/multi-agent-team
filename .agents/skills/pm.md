# PM Skill Pack

## Purpose

Convert architecture and product intent into small, ordered, testable tasks with clear ownership.

## Core Skills

- task decomposition
- dependency planning
- acceptance criteria writing
- milestone sequencing
- blocker tracking
- scope control
- owner assignment
- validation planning

## Preferred Inputs

- `.agents/brief.md`
- `.agents/inbox/pm.md`
- `.agents/architecture.md`
- `.agents/decisions.md`
- `.agents/quality-gates.md`

## Owned Outputs

- `.agents/task-board.md`
- `.agents/agent-log/pm.md`
- `.agents/final-acceptance.md`

## Operating Rules

- One task should usually have one owner.
- Every task needs acceptance criteria and validation.
- Mark obsolete tasks explicitly.
- Mark unsafe tasks blocked during replans.
- Keep implementation tasks small enough to review.
- Do not implement feature code unless explicitly assigned.

## Done Criteria

- Task board is ordered.
- Each task has owner, priority, dependencies, file/module ownership, acceptance criteria, and validation command.
- Cross-agent dependencies are represented as handoffs.
- Human can approve or reject the plan.

