# Quality Gates

This file defines the checks that decide whether work is ready to merge.

## Universal Gates

Every implementation task should satisfy:

- assigned acceptance criteria are met
- definition of ready was satisfied before implementation started
- definition of done is satisfied before task is marked `done`
- relevant tests are added or updated
- documentation is updated when behavior or setup changes
- no unrelated files are changed
- validation findings are resolved or explicitly accepted
- reviewer/security findings are resolved or explicitly accepted when applicable
- auto-launch workflow changes pass `bash tests/test-auto-codex-agent-team.sh`
- Agent Office dashboard changes pass `bash tests/test-agent-office-dashboard.sh`
- visual media functional-layer changes pass `bash tests/test-visual-media-functional-layer.sh`
- routing reliability changes pass `bash tests/test-routing-reliability.sh`
- structured runtime, heartbeat, approval, review, and run-cost changes pass `bash tests/test-runtime-priorities.sh`
- context, policy, evaluation, failure recovery, and adaptation guidance are current when workflow behavior changes

## Command Matrix

Add project-specific commands as the repo takes shape.

| Stack | Install | Lint | Type Check | Test | Build |
| --- | --- | --- | --- | --- | --- |
| Node / TypeScript | `npm install` | `npm run lint` | `npm run typecheck` | `npm test` | `npm run build` |
| Python | `python -m pip install -e .` | `python -m ruff check .` | `python -m mypy .` | `python -m pytest` | `python -m compileall .` |
| Swift / iOS | n/a | n/a | n/a | `xcodebuild test -scheme <Scheme> -destination 'generic/platform=iOS'` | `xcodebuild build -scheme <Scheme> -destination 'generic/platform=iOS'` |

## Role-Specific Gates

### Orchestrator

- `agent-control/workflow-state.md` is current.
- Routes are in the right `agent-control/inbox/<role>.md` files.
- Route lifecycle changes are reflected in `agent-control/events.jsonl`.
- `agent-control/state/routes.jsonl` mirrors created routes.
- `agent-control/state/workflow.sqlite3` validates when initialized.
- `agent-control/state/agents.jsonl` reflects live role telemetry when routes are dispatched, claimed, completed, blocked, or cancelled.
- `scripts/wait-for-agent-sessions.sh <session>` confirms `ROLE_READY <role>` markers before startup dispatch begins and persists readiness markers for later route dispatch.
- `agent-control/routes/R000.md` exists for each created route and is used as the durable route contract.
- Non-draft routes have concrete instruction, expected output, and validation fields.
- `scripts/validate-route-state.sh` passes.
- Meeting-driven routes include `Meeting ID` and `Decision ID` when applicable.
- Human approvals and accepted risks are mirrored in `agent-control/approvals.jsonl`.
- `scripts/check-route-budget.sh` passes.
- `scripts/check-stale-routes.sh` passes or stale routes are recovered with `scripts/recover-stale-routes.sh --apply` and then escalated if still blocked.
- `scripts/watch-routes.sh <session> --send` is active in the control window or routes are manually dispatched.
- Human approval needs are explicit.
- Approval-required routes use `--approval-ref` at completion, and review-required routes use `--review-ref`.
- Scope/architecture changes are recorded in `agent-control/decisions.md`.

### CTO

- Architecture supports the approved brief.
- Major tradeoffs are recorded.
- Module/file ownership is explicit.
- PM has enough validation implications to create tasks.

### Product

- Users, goals, non-goals, and acceptance risks are explicit.
- Scope changes are reflected in `agent-control/brief.md` or `agent-control/product-requirements.md`.
- Product decisions that affect scope or release risk are recorded.
- Design, PM, QA, or docs follow-up is routed when needed.

### Research

- Local repo docs and dependency files were checked before external sources when applicable.
- External facts use primary/official sources when possible.
- Drift-prone facts include links and access dates.
- Recommendations distinguish sourced facts from inference.
- Follow-up is routed to the owner who can act on the research.

### Design

- User flows and interaction states are clear.
- Accessibility, empty/loading/error states, and responsive risks are covered when UI changes.
- Frontend handoff is implementable without another design pass.
- QA has enough state coverage guidance for tests.

### PM

- Every implementation task satisfies `agent-control/definition-of-ready.md`.
- Dependencies and owners are explicit.
- Cross-agent dependencies have handoffs.
- Validation commands are concrete.

### Frontend

- UI behavior matches assigned acceptance criteria.
- Relevant lint/type/test/build commands pass where available.
- Accessibility/responsive risks are checked when UI changes are visible.
- API contract changes are handed off instead of edited across ownership.
- `scripts/check-ownership.sh frontend` passes before review/merge.

### Backend

- API/data behavior matches assigned acceptance criteria.
- Relevant unit/integration tests pass where available.
- Migrations/schema changes are documented when applicable.
- Frontend contract changes are handed off instead of edited across ownership.
- `scripts/check-ownership.sh backend` passes before review/merge.

### Data

- Schema, migration, seed, analytics, and query-contract changes are documented.
- Reversibility or rollback risk is explicit.
- Data-contract tests or validation commands are recorded when relevant.
- Security/privacy review is routed for personal, sensitive, retained, or externally shared data.
- Functional-layer JSONL schema changes are reflected in `agent-control/schemas/` and validation scripts.

### DevOps

- Setup, CI, build, deploy, and rollback steps are reproducible.
- Project-specific commands are reflected in this file when they become release gates.
- Environment variables and secrets follow `agent-control/secrets-policy.md`.
- `scripts/check-secrets.sh` passes before review/merge.

### QA Automation

- Test plan maps to product acceptance criteria.
- Automated coverage includes high-value smoke/regression paths before broad edge cases.
- Commands, fixtures, and known flake risks are recorded in `agent-control/qa-plan.md`.
- Validation can reuse QA commands as release evidence.

### Performance

- Relevant metric, baseline, budget/threshold, and command are documented when measured.
- Performance risks are tied to user, operational, or cost impact.
- Performance checks are added to release gates only when stable enough to enforce.
- Data, DevOps, frontend, backend, or validation follow-up is routed when needed.

### Reviewer

- Diff is scoped to the task.
- Maintainability and architecture drift are reviewed.
- Missing tests are called out.
- Blocking findings route back to the owner.

### Security

- Auth/authz, secrets, input validation, logging, data exposure, and dependency risks are checked when relevant.
- Media attachment paths and sensitive content risk are checked when attachments are added.
- Critical risks block merge unless human explicitly accepts risk.
- Accepted risk is recorded in `agent-control/decisions.md`.
- `scripts/check-secrets.sh` passes before review/merge.

### Validation

- Commands run are recorded.
- Findings include severity and evidence.
- Critical/major findings block done/merge unless accepted.
- Merge recommendation is explicit.

### Docs

- User-facing docs, developer setup docs, runbooks, and release notes match implemented behavior.
- Exact commands and paths are documented where operational behavior depends on them.
- Migration, compatibility, and known-risk notes are explicit when relevant.
- Documentation gaps are routed instead of guessed.

### Integration

- One branch/worktree is merged at a time.
- Review, security, and validation reports are checked.
- Worktree control-plane files are synced before review/merge when worktrees are active.
- `scripts/validate-structured-state.sh` passes.
- `scripts/validate-route-state.sh` passes.
- `scripts/check-memory.sh` passes.
- `scripts/check-milestone-budget.sh` passes.
- `scripts/check-secrets.sh` passes.
- Relevant quality gates are rerun after merge.
- Main branch status is known.

## Workflow Control Gates

- `agent-control/context-map.md` defines role context and handoff context requirements.
- `agent-control/agent-policy.md` defines autonomy, guardrails, stop conditions, and output discipline.
- `agent-control/agent-config/<role>.yaml` defines output schema, route schema, allowed handoff targets, telemetry fields, capacity, stale timeout, and escalation owner for every canonical role.
- `agent-control/evaluation-suite.md` lists scaffold and project evals.
- `agent-control/failure-recovery.md` defines blocked-route recovery owners and retry policy.
- `agent-control/adaptation-guide.md` maps common project types to early specialist routes.

## Validation Report Format

Validation findings should use:

```md
### Finding V001 - Short Title
Severity: critical | major | minor
Status: open | fixed | accepted
Task:
Files:

Problem:

Reproduction / command:

Expected result:

Actual result:

Recommendation:
```

## Merge Gate

Before merge:

1. `git status --short` is understood.
2. Diff contains only intended files.
3. Universal gates are satisfied.
4. Relevant command matrix checks pass.
5. `agent-control/validation-report.md` has no unresolved critical findings.
6. `agent-control/review-report.md` and `agent-control/security-report.md` have no unresolved blocking findings when applicable.
