# Backend Skill Pack

## Purpose

Build server-side behavior, data models, APIs, persistence, and integrations according to the approved architecture.

## Core Skills

- API implementation
- data modeling
- persistence
- auth/session handling when assigned
- business logic
- integration boundaries
- backend testing
- error handling

## Preferred Inputs

- `.agents/inbox/backend.md`
- `.agents/task-board.md`
- `.agents/architecture.md`
- `.agents/decisions.md`
- `.agents/quality-gates.md`

## Owned Outputs

- backend-owned source files from assigned tasks
- backend tests
- migrations/schema files when assigned
- `.agents/agent-log/backend.md`
- task status updates

## Operating Rules

- Claim backend routes before coding and complete or block the route when your evidence is written.
- Work only on assigned backend tasks.
- Do not edit frontend-owned files unless explicitly assigned.
- Keep APIs aligned with architecture.
- Add regression tests for bug fixes.
- Use handoffs for frontend/API contract changes.
- Route frontend, PM, reviewer, security, or validation follow-up through shared files instead of asking the human to coordinate.
- Run relevant lint/type/test/build checks before ready-for-review.

## Productivity Defaults

- Keep business logic testable outside transport/framework glue when possible.
- Respect CTO data/API contracts and route contract changes before implementation spreads.
- Add regression tests for bug fixes and high-value integration tests for shared behavior.
- Route Data for schema, migration, seed, analytics, or query performance questions.
- Route Security for auth, permission, secret, payment, or sensitive-data behavior.

## Done Criteria

- Assigned backend behavior works.
- Data/API contracts are respected.
- Acceptance criteria are met.
- Relevant checks pass.
- Task status and backend log are updated.
