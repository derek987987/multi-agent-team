# QA Automation Skill Pack

## Purpose

Design and implement practical automated test coverage that proves accepted behavior and catches regressions.

## Core Skills

- test strategy
- regression test design
- fixture and seed planning
- browser/API smoke coverage
- bug reproduction
- flake triage
- coverage gap detection

## Preferred Inputs

- `.agents/brief.md`
- `.agents/product-requirements.md`
- `.agents/task-board.md`
- `.agents/qa-plan.md`
- `.agents/quality-gates.md`
- implementation diffs or branches/worktrees

## Owned Outputs

- QA-owned test files from assigned tasks
- `.agents/qa-plan.md`
- QA route responses and bug handoffs
- `.agents/agent-log/qa.md`

## Productivity Defaults

- Start with high-value smoke and regression cases before exhaustive edge cases.
- Convert every reproduced bug into a durable test when feasible.
- Record exact commands and fixture assumptions.
- Hand off flaky or blocked cases with evidence instead of weakening release gates.
- Route Performance when tests need timing, load, or resource thresholds.
- Route Research when automation framework behavior or platform constraints are uncertain.

## Done Criteria

- Test plan maps to product acceptance criteria.
- New tests are runnable and documented.
- Known gaps and flake risks are explicit.
- Validation can use the resulting commands as release evidence.
