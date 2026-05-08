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

- `agent-control/inbox/performance.md`
- `agent-control/performance-report.md`
- `agent-control/architecture.md`
- `agent-control/task-board.md`
- `agent-control/quality-gates.md`
- implementation diffs or branches/worktrees
- profiling, build, or benchmark output

## Owned Outputs

- `agent-control/performance-report.md`
- performance-owned tests or benchmark scripts from assigned tasks
- performance route responses and handoffs
- `agent-control/agent-log/performance.md`

## Productivity Defaults

- Ask what metric matters: startup, interaction latency, API latency, memory, bundle size, query speed, cost, or throughput.
- Prefer a cheap baseline before proposing optimization work.
- Route Data for query/index/storage bottlenecks and DevOps for CI/load/observability checks.
- Add performance checks to `agent-control/quality-gates.md` only when they are stable enough to enforce.
- Record environment details so results are comparable.

## Done Criteria

- Metrics, baseline, threshold, and command are documented when measurement exists.
- Performance risks are tied to user, operational, or cost impact.
- Optimization recommendations have an owner and validation method.
- Follow-up routes are queued for implementation or validation.
