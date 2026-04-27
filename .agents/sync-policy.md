# Sync Policy

Worktree sync must keep agents current without deleting local response evidence.

## Root-Owned Control Plane

These files are copied from the root checkout to implementation worktrees:

- `AGENTS.md`
- `README.md`
- `.tmux.agent-team.conf`
- `.github/`
- `scripts/`
- `.agents/prompts/`
- `.agents/skills/`
- `.agents/schemas/`
- `.agents/ownership/`
- `.agents/agent-config/`
- `.agents/brief.md`
- `.agents/product-requirements.md`
- `.agents/design-notes.md`
- `.agents/qa-plan.md`
- `.agents/release-notes.md`
- `.agents/intake-notes.md`
- `.agents/sop.md`
- `.agents/roles.md`
- `.agents/architecture.md`
- `.agents/decisions.md`
- `.agents/task-board.md`
- `.agents/task-template.md`
- `.agents/handoffs.md`
- `.agents/quality-gates.md`
- `.agents/definition-of-ready.md`
- `.agents/definition-of-done.md`
- `.agents/conflict-resolution.md`
- `.agents/change-control.md`
- `.agents/change-request.md`
- `.agents/workflow-state.md`
- `.agents/routing-matrix.md`
- `.agents/route-schema.md`
- `.agents/memory-policy.md`
- `.agents/sync-policy.md`
- `.agents/route-budget.md`
- `.agents/state/`

## Worktree-Mutable Evidence

These files are not deleted or overwritten by sync:

- `.agents/agent-log/`
- `.agents/inbox/`
- `.agents/memory/`
- `.agents/validation-report.md`
- `.agents/review-report.md`
- `.agents/security-report.md`
- `.agents/events.jsonl`
- `.agents/final-cto-review.md`
- `.agents/final-acceptance.md`

## Rule

Root is the authority for planning and control-plane files. Worktrees can keep local logs and evidence until the integration owner pulls them back deliberately.
