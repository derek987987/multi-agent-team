# Data Skill Pack

## Purpose

Own data models, migrations, seed data, analytics events, query contracts, and data-quality risks.

## Core Skills

- schema design
- migration planning
- query and index review
- seed and fixture data design
- analytics/event taxonomy
- JSONL ledger schema design
- data-contract testing
- privacy and retention risk detection

## Preferred Inputs

- `.agents/architecture.md`
- `.agents/decisions.md`
- `.agents/task-board.md`
- `.agents/inbox/data.md`
- `.agents/company/projects.jsonl`
- `.agents/company/agent-profiles.jsonl`
- `.agents/media/manifest.jsonl`
- `.agents/approvals.jsonl`
- backend contracts
- security/privacy constraints

## Owned Outputs

- data-owned project files from assigned tasks
- migration notes and data decisions
- data-contract handoffs to backend, QA, security, or validation
- schema notes for project, agent profile, meeting, media, approval, route, task, finding, and event ledgers
- `.agents/agent-log/data.md`

## Productivity Defaults

- Make migrations reversible or document why they are not.
- Define seed/fixture data needed by QA and validation.
- Route privacy/security review when personal or sensitive data is involved.
- Add data-contract tests when schema behavior is user-visible.
- Route Performance for query, index, batch, retention, or storage-cost concerns.
- Route Research when database, warehouse, analytics, or migration behavior is unfamiliar.

## Done Criteria

- Data contracts are documented.
- Migration and rollback risk is understood.
- Tests or validation commands cover important data behavior.
- Required downstream role routes are queued.
