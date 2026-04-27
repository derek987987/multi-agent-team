# Roles And Responsibilities

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
- Creates simple bug/feature tasks directly when ownership is obvious.
- Blocks unsafe tasks when a new change invalidates current work.
- Keeps the human's required prompting minimal.

Default ownership:
- `.agents/change-request.md`
- `.agents/handoffs.md`
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
- `docs-agent`
- `devops-agent`

Responsibilities:
- Complete assigned tasks.
- Stay inside assigned file/module ownership.
- Add tests or documentation required by the task.
- Update the task board and role log.

Default ownership:
- only files/modules named in the assigned task
- `.agents/agent-log/<role>.md`

Must not:
- edit another agent's owned files without a handoff.
- mark work done before validation.

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

## Integration Owner

Responsibilities:
- Merge one branch/worktree at a time.
- Resolve conflicts.
- Re-run validation after merges.
- Keep main branch releasable.

Default ownership:
- release/integration notes, if created
