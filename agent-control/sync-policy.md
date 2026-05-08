# Sync Policy

Worktree sync must keep agents current without deleting local response evidence.

## Root-Owned Control Plane

These files are copied from the root checkout to implementation worktrees:

- `AGENTS.md`
- `README.md`
- `.tmux.agent-team.conf`
- `.github/`
- `scripts/`
- `agent-control/prompts/`
- `agent-control/skills/`
- `agent-control/schemas/`
- `agent-control/ownership/`
- `agent-control/agent-config/`
- `agent-control/brief.md`
- `agent-control/context-map.md`
- `agent-control/agent-policy.md`
- `agent-control/evaluation-suite.md`
- `agent-control/failure-recovery.md`
- `agent-control/adaptation-guide.md`
- `agent-control/product-requirements.md`
- `agent-control/design-notes.md`
- `agent-control/qa-plan.md`
- `agent-control/release-notes.md`
- `agent-control/research-notes.md`
- `agent-control/performance-report.md`
- `agent-control/intake-notes.md`
- `agent-control/sop.md`
- `agent-control/roles.md`
- `agent-control/architecture.md`
- `agent-control/decisions.md`
- `agent-control/task-board.md`
- `agent-control/task-template.md`
- `agent-control/handoffs.md`
- `agent-control/quality-gates.md`
- `agent-control/definition-of-ready.md`
- `agent-control/definition-of-done.md`
- `agent-control/conflict-resolution.md`
- `agent-control/change-control.md`
- `agent-control/change-request.md`
- `agent-control/workflow-state.md`
- `agent-control/routing-matrix.md`
- `agent-control/route-schema.md`
- `agent-control/memory-policy.md`
- `agent-control/sync-policy.md`
- `agent-control/route-budget.md`
- `agent-control/state/`

## Worktree-Mutable Evidence

These files are not deleted or overwritten by sync:

- `agent-control/agent-log/`
- `agent-control/inbox/`
- `agent-control/memory/`
- `agent-control/validation-report.md`
- `agent-control/review-report.md`
- `agent-control/security-report.md`
- `agent-control/events.jsonl`
- `agent-control/final-cto-review.md`
- `agent-control/final-acceptance.md`

## Rule

Root is the authority for planning and control-plane files. Worktrees can keep local logs and evidence until the integration owner pulls them back deliberately.
