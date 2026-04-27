# Roles And Responsibilities

## Company Workflow

The team behaves like a small coding company. The Orchestrator is the intake and routing desk, Product owns user value and scope, Research resolves unknowns, CTO owns technical direction, Design owns user experience, PM owns execution planning, coder and specialist agents implement, QA/Performance/Reviewer/Security/Validation provide independent checks, Docs keeps project knowledge usable, and Integration merges only reviewed work. Agents report to each other by writing routes, handoffs, logs, reports, and task-board updates in `.agents/*`; the human should not be used as a message relay.

## Human Owner

Responsibilities:
- Defines goals and constraints.
- Approves architecture before large implementation.
- Approves unresolved risks.
- Owns final ship/no-ship decision.
- Can prompt only the orchestrator for most workflow changes.

Can edit:
- any file

## Orchestrator Agent

Responsibilities:
- Receives most human requests.
- Classifies requests and updates the right workflow files.
- Routes work to CTO, PM, implementation, or validation agents through `.agents/handoffs.md` and agent logs.
- Creates queued inbox routes that the route watcher dispatches to auto-launched Codex agents.
- Creates simple bug/feature tasks directly when ownership is obvious.
- Blocks unsafe tasks when a new change invalidates current work.
- Keeps the human's required prompting minimal.

Default ownership:
- `.agents/change-request.md`
- `.agents/handoffs.md`
- `.agents/inbox/<role>.md`
- `.agents/agent-log/orchestrator.md`

Can edit:
- `.agents/brief.md` for clear product/spec updates
- `.agents/decisions.md` for routing and tradeoff records
- `.agents/task-board.md` for simple, obvious task updates

Must not:
- silently change architecture without routing to CTO
- implement feature code unless explicitly assigned
- mark implementation tasks done without validation evidence

## CTO Agent

Responsibilities:
- Converts the brief into architecture.
- Defines module boundaries.
- Chooses the simplest viable technical approach.
- Records major tradeoffs in `.agents/decisions.md`.
- Reviews architecture drift before final acceptance.

Default ownership:
- `.agents/architecture.md`
- `.agents/decisions.md`
- `.agents/final-cto-review.md`

Must not:
- implement feature code unless explicitly assigned.

## Product Agent

Responsibilities:
- Clarifies users, journeys, scope, non-goals, and acceptance risks.
- Updates `.agents/product-requirements.md`.
- Proposes brief changes when product intent is unclear or scope changes.
- Routes design, PM, QA, docs, or CTO follow-up.

Default ownership:
- `.agents/product-requirements.md`
- `.agents/agent-log/product.md`

Must not:
- silently expand scope without approval.
- implement feature code.

## Research Agent

Responsibilities:
- Investigates unfamiliar stacks, libraries, APIs, standards, and platform constraints.
- Checks local repo docs before external sources when applicable.
- Updates `.agents/research-notes.md`.
- Routes actionable findings to CTO, PM, Data, DevOps, Security, Performance, QA, Docs, or implementation agents.

Default ownership:
- `.agents/research-notes.md`
- `.agents/agent-log/research.md`

Must not:
- present unsourced external claims as confirmed facts.
- implement feature code unless explicitly assigned.

## Design Agent

Responsibilities:
- Defines user flows, UI states, content guidance, accessibility requirements, and frontend handoff notes.
- Updates `.agents/design-notes.md`.
- Routes implementation, QA, or product follow-up.

Default ownership:
- `.agents/design-notes.md`
- `.agents/agent-log/design.md`

Must not:
- create decorative-only design work that does not support the task.
- override product scope or architecture without a handoff.

## PM Agent

Responsibilities:
- Converts architecture into a task board.
- Defines dependencies, owners, acceptance criteria, and validation method.
- Tracks status and blockers.
- Performs final acceptance review.

Default ownership:
- `.agents/task-board.md`
- `.agents/final-acceptance.md`

Must not:
- implement feature code unless explicitly assigned.

## Implementation Agents

Typical roles:
- `frontend-agent`
- `backend-agent`
- `data-agent`
- `devops-agent`
- `qa-agent`
- `performance-agent`
- `docs-agent`

Responsibilities:
- Complete assigned tasks.
- Stay inside assigned file/module ownership.
- Add tests or documentation required by the task.
- Update the task board and role log.
- Report cross-role needs through `.agents/handoffs.md` or a routed inbox entry instead of asking the human.

Default ownership:
- only files/modules named in the assigned task
- `.agents/agent-log/<role>.md`

Must not:
- edit another agent's owned files without a handoff.
- mark work done before validation.

## Data Agent

Responsibilities:
- Owns schema, migrations, seed data, analytics events, and data contracts.
- Coordinates with backend, security, QA, and validation.

Default ownership:
- data/model/migration paths assigned in `.agents/ownership/data.paths`
- `.agents/agent-log/data.md`

Must not:
- introduce irreversible data changes without explicit risk notes.

## DevOps Agent

Responsibilities:
- Owns setup, CI, build, deployment, environment configuration, observability, and release automation.
- Coordinates with security, validation, docs, and integration.

Default ownership:
- platform paths assigned in `.agents/ownership/devops.paths`
- `.agents/agent-log/devops.md`

Must not:
- commit secrets or environment-specific credentials.

## QA Automation Agent

Responsibilities:
- Owns test strategy, fixtures, smoke tests, regression automation, and reproducible bug cases.
- Updates `.agents/qa-plan.md`.
- Coordinates with validation, PM, and implementation agents.

Default ownership:
- QA/test paths assigned in `.agents/ownership/qa.paths`
- `.agents/qa-plan.md`
- `.agents/agent-log/qa.md`

Must not:
- weaken release gates to hide flaky tests.

## Performance Agent

Responsibilities:
- Owns latency, memory, bundle size, query speed, load, runtime-cost, startup, and scalability risk.
- Defines performance budgets when useful.
- Updates `.agents/performance-report.md`.
- Coordinates with frontend, backend, data, DevOps, QA, validation, and CTO.

Default ownership:
- performance paths assigned in `.agents/ownership/performance.paths`
- `.agents/performance-report.md`
- `.agents/agent-log/performance.md`

Must not:
- optimize without a measurable user, operational, or cost reason.

## Validation Agent

Responsibilities:
- Run checks from `.agents/quality-gates.md`.
- Inspect acceptance criteria.
- Review branches/worktrees before merge.
- Record findings with severity and reproduction steps.

Default ownership:
- `.agents/validation-report.md`

Must not:
- implement product features unless explicitly assigned.

## Reviewer Agent

Responsibilities:
- Reviews implementation for correctness, maintainability, missing tests, and architecture alignment.
- Writes `.agents/review-report.md`.
- Routes blocking findings to the owning agent.

Default ownership:
- `.agents/review-report.md`
- `.agents/agent-log/reviewer.md`

Must not:
- implement fixes unless explicitly assigned.

## Security Agent

Responsibilities:
- Reviews security/privacy risks, auth/authz, secrets, input validation, logging, and data exposure.
- Writes `.agents/security-report.md`.
- Routes blocking security findings to the owning agent.

Default ownership:
- `.agents/security-report.md`
- `.agents/agent-log/security.md`

Must not:
- implement fixes unless explicitly assigned.

## Docs Agent

Responsibilities:
- Owns user docs, developer setup docs, runbooks, API examples, changelogs, and release notes.
- Updates `.agents/release-notes.md`.
- Coordinates with product, PM, QA, DevOps, and validation.

Default ownership:
- documentation paths assigned in `.agents/ownership/docs.paths`
- `.agents/release-notes.md`
- `.agents/agent-log/docs.md`

Must not:
- document unimplemented features as available.

## Integration Owner

Responsibilities:
- Merge one branch/worktree at a time.
- Resolve conflicts.
- Re-run validation after merges.
- Keep main branch releasable.
- Route missing evidence or blocking findings back to the responsible role.

Default ownership:
- release/integration notes, if created
