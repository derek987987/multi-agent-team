# Routing Matrix

The orchestrator uses this matrix to decide where a human request should go.

## Request Classification

| Request Type | Route First | Files To Update | Human Approval Needed |
| --- | --- | --- | --- |
| project intake / idea refinement | orchestrator, then CTO after brief approval | `intake-notes`, `brief`, `workflow-state`, `inbox/cto`, `handoffs` | yes, approve brief or proceed with assumptions |
| product clarification | product, then PM/Design/CTO as needed | `product-requirements`, `brief`, `decisions`, `workflow-state`, `handoffs` | yes if scope changes materially |
| external research / unknown stack | research, then owning specialist | `research-notes`, `decisions`, `handoffs`, `workflow-state` | no unless recommendation changes scope/risk |
| initial planning | product if scope is unclear, CTO, then PM | `brief`, `product-requirements`, `architecture`, `decisions`, `task-board`, `workflow-state` | yes, before implementation |
| spec change | product and CTO, then PM | `change-request`, `product-requirements`, `brief`, `decisions`, `architecture`, `task-board`, `workflow-state` | yes if scope/risk changes materially |
| feature change | PM, CTO if architecture affected | `change-request`, `brief`, `task-board`, `handoffs`, `workflow-state` | usually no for small changes |
| bug fix | owning implementation agent, then validation | `task-board`, `validation-report`, `handoffs`, `workflow-state` | no unless critical/risky |
| architecture change | CTO, then PM | `architecture`, `decisions`, `task-board`, `workflow-state` | yes |
| design / UX change | design, then frontend and QA | `design-notes`, `task-board`, `handoffs`, `workflow-state` | yes if product scope or brand direction changes |
| data model / migration | data, then backend/security/validation | `architecture`, `decisions`, `task-board`, `handoffs`, `workflow-state` | yes if irreversible or high-risk |
| CI / deployment / environment | devops, then security/validation/docs | `quality-gates`, `task-board`, `handoffs`, `workflow-state` | yes if release process or infrastructure risk changes |
| test automation | QA, then validation | `qa-plan`, `task-board`, `quality-gates`, `handoffs`, `workflow-state` | no unless release gates change |
| performance risk / regression | performance, then owner and validation | `performance-report`, `quality-gates`, `task-board`, `handoffs`, `workflow-state` | yes if budget/risk acceptance changes |
| validation change | validation, PM if task criteria change | `quality-gates`, `validation-report`, `task-board`, `workflow-state` | no unless release gate changes |
| code review | reviewer | `review-report`, `task-board`, `workflow-state`, `handoffs` | no unless blocking risk is accepted |
| security review | security | `security-report`, `decisions`, `task-board`, `workflow-state`, `handoffs` | yes for accepted critical/major risk |
| documentation / release notes | docs, PM if acceptance changes | `release-notes`, docs files, `task-board`, `workflow-state`, `handoffs` | no unless release messaging changes materially |
| emergency replan | CTO and PM | `decisions`, `task-board`, `workflow-state`, `handoffs` | yes |
| status request | orchestrator | `workflow-state` if stale | no |
| implementation request | PM if no task exists, otherwise owner agent | `task-board`, `handoffs`, `workflow-state` | no |
| cross-agent meeting / decision | orchestrator, then invited roles, then PM | `meetings`, `decisions`, `approvals`, `task-board`, `handoffs`, `workflow-state` | yes if scope/risk/architecture changes |
| media attachment / visual reference | orchestrator, then security/design/QA as needed | `media/manifest`, `meetings`, `task-board`, `handoffs` | yes if sensitive data may be exposed |
| coding company functional layer | product, cto, data, backend, PM, QA, security, validation | `company`, `schemas`, `meetings`, `media`, `approvals`, `quality-gates`, `task-board` | yes before visual phase starts |

## Route Status Values

- `queued`: route was created but not picked up
- `dispatched`: route was sent to the target tmux window
- `in-progress`: receiving agent is acting on it
- `blocked`: receiving agent cannot proceed
- `done`: receiving agent completed the requested action
- `cancelled`: route is no longer needed

## Routing Rules

1. If the stack, library, API, platform, or standard is unfamiliar or drift-prone, route Research first.
2. If the request changes architecture, route to CTO before implementation.
3. If the request changes task ownership, dependencies, or acceptance criteria, route to PM.
4. If the request crosses file ownership boundaries, create a handoff.
5. If the request is a bug with clear ownership, create a bug task and route directly to the owner and validation.
6. If a route blocks active implementation, mark affected tasks `blocked`.
7. If a route requires human approval, record that in `.agents/workflow-state.md`.
8. If implementation touches auth, permissions, secrets, payments, personal data, or shared infrastructure, route security review.
9. If implementation touches data models, migrations, analytics, retention, or seed data, route data review.
10. If implementation touches setup, CI, deployment, environment, observability, or release automation, route DevOps review.
11. If implementation changes user-visible UI flows, route design review before frontend work and QA coverage before validation.
12. If implementation could affect latency, memory, bundle size, query speed, throughput, startup, or runtime cost, route Performance.
13. If implementation changes user-facing behavior, setup, API behavior, or release notes, route docs work.
14. If implementation is ready for merge, route reviewer, security when relevant, QA/validation, then integration.
15. If multiple agents need to align before tasking, create or update a meeting instead of broadcasting vague routes.
16. If a route comes from a meeting decision, include `Meeting ID` and `Decision ID`.
17. If media is attached, add it through `scripts/attach-media.sh` and route security review when content may be sensitive.
