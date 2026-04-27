# Routing Matrix

The orchestrator uses this matrix to decide where a human request should go.

## Request Classification

| Request Type | Route First | Files To Update | Human Approval Needed |
| --- | --- | --- | --- |
| project intake / idea refinement | orchestrator, then CTO after brief approval | `intake-notes`, `brief`, `workflow-state`, `inbox/cto`, `handoffs` | yes, approve brief or proceed with assumptions |
| product clarification | product, then PM/Design/CTO as needed | `product-requirements`, `brief`, `decisions`, `workflow-state`, `handoffs` | yes if scope changes materially |
| initial planning | product if scope is unclear, CTO, then PM | `brief`, `product-requirements`, `architecture`, `decisions`, `task-board`, `workflow-state` | yes, before implementation |
| spec change | product and CTO, then PM | `change-request`, `product-requirements`, `brief`, `decisions`, `architecture`, `task-board`, `workflow-state` | yes if scope/risk changes materially |
| feature change | PM, CTO if architecture affected | `change-request`, `brief`, `task-board`, `handoffs`, `workflow-state` | usually no for small changes |
| bug fix | owning implementation agent, then validation | `task-board`, `validation-report`, `handoffs`, `workflow-state` | no unless critical/risky |
| architecture change | CTO, then PM | `architecture`, `decisions`, `task-board`, `workflow-state` | yes |
| design / UX change | design, then frontend and QA | `design-notes`, `task-board`, `handoffs`, `workflow-state` | yes if product scope or brand direction changes |
| data model / migration | data, then backend/security/validation | `architecture`, `decisions`, `task-board`, `handoffs`, `workflow-state` | yes if irreversible or high-risk |
| CI / deployment / environment | devops, then security/validation/docs | `quality-gates`, `task-board`, `handoffs`, `workflow-state` | yes if release process or infrastructure risk changes |
| test automation | QA, then validation | `qa-plan`, `task-board`, `quality-gates`, `handoffs`, `workflow-state` | no unless release gates change |
| validation change | validation-agent, PM if task criteria change | `quality-gates`, `validation-report`, `task-board`, `workflow-state` | no unless release gate changes |
| code review | reviewer | `review-report`, `task-board`, `workflow-state`, `handoffs` | no unless blocking risk is accepted |
| security review | security | `security-report`, `decisions`, `task-board`, `workflow-state`, `handoffs` | yes for accepted critical/major risk |
| documentation / release notes | docs, PM if acceptance changes | `release-notes`, docs files, `task-board`, `workflow-state`, `handoffs` | no unless release messaging changes materially |
| emergency replan | CTO and PM | `decisions`, `task-board`, `workflow-state`, `handoffs` | yes |
| status request | orchestrator | `workflow-state` if stale | no |
| implementation request | PM if no task exists, otherwise owner agent | `task-board`, `handoffs`, `workflow-state` | no |

## Route Status Values

- `queued`: route was created but not picked up
- `dispatched`: route was sent to the target tmux window
- `in-progress`: receiving agent is acting on it
- `blocked`: receiving agent cannot proceed
- `done`: receiving agent completed the requested action
- `cancelled`: route is no longer needed

## Routing Rules

1. If the request changes architecture, route to CTO before implementation.
2. If the request changes task ownership, dependencies, or acceptance criteria, route to PM.
3. If the request crosses file ownership boundaries, create a handoff.
4. If the request is a bug with clear ownership, create a bug task and route directly to the owner and validation.
5. If a route blocks active implementation, mark affected tasks `blocked`.
6. If a route requires human approval, record that in `.agents/workflow-state.md`.
7. If implementation touches auth, permissions, secrets, payments, personal data, or shared infrastructure, route security review.
8. If implementation touches data models, migrations, analytics, retention, or seed data, route data review.
9. If implementation touches setup, CI, deployment, environment, observability, or release automation, route DevOps review.
10. If implementation changes user-visible UI flows, route design review before frontend work and QA coverage before validation.
11. If implementation changes user-facing behavior, setup, API behavior, or release notes, route docs work.
12. If implementation is ready for merge, route reviewer, security when relevant, QA/validation, then integration.
