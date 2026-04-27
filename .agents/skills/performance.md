# Performance Skill Pack

## Purpose

Protect user-visible speed, resource use, runtime cost, and scalability while avoiding premature optimization.

## Core Skills

- performance budget definition
- latency and throughput analysis
- memory and startup review
- bundle-size and rendering risk review
- query performance review
- profiling and benchmark planning
- regression threshold design

## Preferred Inputs

- `.agents/inbox/performance.md`
- `.agents/performance-report.md`
- `.agents/architecture.md`
- `.agents/task-board.md`
- `.agents/quality-gates.md`
- implementation diffs or branches/worktrees
- profiling, build, or benchmark output

## Owned Outputs

- `.agents/performance-report.md`
- performance-owned tests or benchmark scripts from assigned tasks
- performance route responses and handoffs
- `.agents/agent-log/performance.md`

## Productivity Defaults

- Ask what metric matters: startup, interaction latency, API latency, memory, bundle size, query speed, cost, or throughput.
- Prefer a cheap baseline before proposing optimization work.
- Route Data for query/index/storage bottlenecks and DevOps for CI/load/observability checks.
- Add performance checks to `.agents/quality-gates.md` only when they are stable enough to enforce.
- Record environment details so results are comparable.

## Done Criteria

- Metrics, baseline, threshold, and command are documented when measurement exists.
- Performance risks are tied to user, operational, or cost impact.
- Optimization recommendations have an owner and validation method.
- Follow-up routes are queued for implementation or validation.
