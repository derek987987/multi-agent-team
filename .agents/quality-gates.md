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

## Command Matrix

Add project-specific commands as the repo takes shape.

| Stack | Install | Lint | Type Check | Test | Build |
| --- | --- | --- | --- | --- | --- |
| Node / TypeScript | `npm install` | `npm run lint` | `npm run typecheck` | `npm test` | `npm run build` |
| Python | `python -m pip install -e .` | `python -m ruff check .` | `python -m mypy .` | `python -m pytest` | `python -m compileall .` |
| Swift / iOS | n/a | n/a | n/a | `xcodebuild test -scheme <Scheme> -destination 'generic/platform=iOS'` | `xcodebuild build -scheme <Scheme> -destination 'generic/platform=iOS'` |

## Role-Specific Gates

### Orchestrator

- `.agents/workflow-state.md` is current.
- Routes are in the right `.agents/inbox/<role>.md` files.
- Route lifecycle changes are reflected in `.agents/events.jsonl`.
- `.agents/state/routes.jsonl` mirrors created routes.
- `scripts/check-route-budget.sh` passes.
- `scripts/check-stale-routes.sh` passes or stale routes are escalated.
- Human approval needs are explicit.
- Scope/architecture changes are recorded in `.agents/decisions.md`.

### CTO

- Architecture supports the approved brief.
- Major tradeoffs are recorded.
- Module/file ownership is explicit.
- PM has enough validation implications to create tasks.

### PM

- Every implementation task satisfies `.agents/definition-of-ready.md`.
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

### Reviewer

- Diff is scoped to the task.
- Maintainability and architecture drift are reviewed.
- Missing tests are called out.
- Blocking findings route back to the owner.

### Security

- Auth/authz, secrets, input validation, logging, data exposure, and dependency risks are checked when relevant.
- Critical risks block merge unless human explicitly accepts risk.
- Accepted risk is recorded in `.agents/decisions.md`.
- `scripts/check-secrets.sh` passes before review/merge.

### Validation

- Commands run are recorded.
- Findings include severity and evidence.
- Critical/major findings block done/merge unless accepted.
- Merge recommendation is explicit.

### Integration

- One branch/worktree is merged at a time.
- Review, security, and validation reports are checked.
- Worktree control-plane files are synced before review/merge when worktrees are active.
- `scripts/validate-structured-state.sh` passes.
- `scripts/check-memory.sh` passes.
- `scripts/check-milestone-budget.sh` passes.
- `scripts/check-secrets.sh` passes.
- Relevant quality gates are rerun after merge.
- Main branch status is known.

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
5. `.agents/validation-report.md` has no unresolved critical findings.
6. `.agents/review-report.md` and `.agents/security-report.md` have no unresolved blocking findings when applicable.
