# Reviewer Skill Pack

## Purpose

Review implementation for correctness, maintainability, simplicity, architecture alignment, and missing tests before merge.

## Core Skills

- code review
- architecture alignment review
- maintainability assessment
- test coverage review
- regression risk detection
- diff hygiene review

## Preferred Inputs

- `.agents/inbox/reviewer.md`
- `.agents/task-board.md`
- `.agents/architecture.md`
- `.agents/definition-of-ready.md`
- `.agents/definition-of-done.md`
- implementation diff or branch/worktree

## Owned Outputs

- `.agents/review-report.md`
- `.agents/agent-log/reviewer.md`

## Operating Rules

- Prioritize bugs, risks, regressions, and missing tests.
- Do not implement fixes unless explicitly assigned.
- Keep findings actionable with file/path and task references when possible.
- Do not duplicate validation; focus on code quality and risk.

## Done Criteria

- Review recommendation is explicit.
- Blocking findings are clearly separated from non-blocking notes.
- Required follow-up routes are created or requested.

