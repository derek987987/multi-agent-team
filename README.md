# Multi-Agent Coding Workflow

This directory contains the reusable source template for a tmux-based, Orchestrator-led multi-agent coding workflow. The user normally talks only to the Orchestrator. Other agents work from routed inboxes, role prompts, skills, memory, ownership rules, and quality gates.

## Quick Start

Use this template home when you want to improve the agent team itself:

```bash
cd /Users/hay/Documents/agent-teams
```

Create a per-project agent-team copy for a coding project:

```bash
./scripts/new-coding-project.sh /Users/hay/Documents/my-app
```

Run `./scripts/new-coding-project.sh` with no arguments if you prefer to be prompted for the project path and copy destination.

Or provide the exact destination for the copied agent team:

```bash
./scripts/new-coding-project.sh /Users/hay/Documents/my-app /Users/hay/Documents/my-app-agent-team
```

Start the copied team:

```bash
cd /Users/hay/Documents/agent-team-instances/my-app-team
./scripts/start-agent-team.sh
```

Startup launches Codex in every agent window with `--full-auto`. The `control` window runs the route watcher, and the `orchestrator` window is the normal place where you talk to the team.

In the `orchestrator` tmux window, give a rough idea:

```text
Use .agents/prompts/intake-orchestrator.md.

Idea:
<describe the coding project in rough words>

Please interview me if needed, refine my idea, write .agents/brief.md, and ask me to approve the brief before routing Product/CTO work.
```

The Orchestrator asks at most 3 questions at a time, writes `.agents/brief.md`, and waits for approval. After approval, the Orchestrator creates routes in `.agents/inbox/<role>.md`; the watcher dispatches those routes to the matching Codex windows. You should not need to prompt Product, CTO, Design, PM, coder, Data, DevOps, QA, Reviewer, Security, Docs, Validation, or Integration agents directly during normal work.

Review the brief:

```bash
sed -n '1,220p' .agents/brief.md
```

Approve:

```text
Approved. Proceed with Product/CTO planning and routing.
```

## Template And Project Copies

`/Users/hay/Documents/agent-teams` is the reusable template home. Keep the original team here, improve it here, and create fresh per-project copies whenever you start a coding project.

By default, `new-coding-project.sh` creates copies under:

```text
/Users/hay/Documents/agent-team-instances/<project-name>-team
```

Override that parent directory when useful:

```bash
AGENT_TEAM_INSTANCE_ROOT=/Users/hay/Documents/workflows ./scripts/new-coding-project.sh /Users/hay/Documents/my-app
```

Inside a generated copy, the script records the target coding project in:

```text
.agents/project-target.md
```

You can still retarget an existing agent-team copy manually:

```bash
cd /Users/hay/Documents/agent-team-instances/my-app-team
./scripts/set-project-target.sh /path/to/your/coding-project existing-project
```

For a new empty project directory:

```bash
./scripts/set-project-target.sh /Users/hay/Documents/my-new-app new-project
```
Agents treat the target directory as the codebase and the copied agent-team directory as the workflow control plane.

## Windows

`./scripts/start-agent-team.sh` creates one window for every role in `scripts/agent-roles.sh`:

1. `control` - status and route watcher
2. `orchestrator`
3. `product`
4. `cto`
5. `design`
6. `pm`
7. `frontend`
8. `backend`
9. `data`
10. `devops`
11. `qa`
12. `validation`
13. `reviewer`
14. `security`
15. `docs`
16. `integration`
17. `server`

All agent windows run:

```bash
codex --full-auto --no-alt-screen
```

via `scripts/codex-role.sh`. The server window remains a plain terminal for dev servers and logs.

## Production Roles

- `orchestrator`: human intake, classification, routing, state, approval gates.
- `product`: users, journeys, scope, non-goals, acceptance risks.
- `cto`: architecture, decisions, boundaries, technical risk.
- `design`: user flows, UI states, accessibility, frontend handoff.
- `pm`: task board, sequencing, dependencies, acceptance criteria.
- `frontend` / `backend`: implementation in owned files with tests and handoffs.
- `data`: schemas, migrations, seed data, analytics, query contracts.
- `devops`: setup, CI, build, deploy, environment, observability.
- `qa`: automated test strategy, fixtures, smoke/regression coverage.
- `reviewer`: code correctness, maintainability, architecture drift, missing tests.
- `security`: auth, permissions, secrets, sensitive data, dependency risk.
- `docs`: user docs, developer docs, runbooks, release notes.
- `validation`: independent command execution and acceptance evidence.
- `integration`: reviewed merges, conflict resolution, final validation routing.

## Real Coding Mode

Use worktrees for real parallel implementation:

```bash
./scripts/new-coding-project.sh /path/to/your/coding-project /path/to/project-agent-team
cd /path/to/project-agent-team
git -C /path/to/your/coding-project init
git -C /path/to/your/coding-project add .
git -C /path/to/your/coding-project commit -m "Initial project state"
./scripts/start-agent-team-worktrees.sh
```

Worktrees are created under:

```text
/Users/hay/Documents/agent-worktrees/
```

Worktree mode creates role worktrees for project-editing roles from `PROJECT_WORKTREE_ROLES` in `scripts/agent-roles.sh`: `frontend`, `backend`, `data`, `devops`, `qa`, `docs`, and `validation`.

Worktree mode runs:

```bash
./scripts/sync-agent-state.sh --push
```

Run that again whenever the root checkout changes `.agents/*` and implementation worktrees need the latest control-plane files. Sync follows `.agents/sync-policy.md`: root-owned planning files are pushed, while local evidence files such as logs/reports are preserved.

## Operating Flow

1. User gives rough idea to Orchestrator.
2. Orchestrator interviews, drafts `.agents/brief.md`, and asks for approval.
3. Product clarifies users, journeys, scope, non-goals, and acceptance risks when needed.
4. CTO writes `.agents/architecture.md` and `.agents/decisions.md`.
5. Design writes `.agents/design-notes.md` for user-facing flows.
6. PM writes `.agents/task-board.md` and routes implementation/specialist work.
7. Human approves architecture and task board before broad implementation.
8. Implementation and specialist agents work only on ready assigned tasks.
9. QA creates or updates regression/smoke automation and `.agents/qa-plan.md`.
10. Reviewer, Security, and Validation review the work.
11. Docs updates docs and `.agents/release-notes.md` when behavior, setup, API, or release messaging changes.
12. Integration merges one branch/worktree at a time.
13. CTO and PM perform final review/acceptance.

Agents communicate through `.agents/*` files. If a role needs another role, it writes a concrete handoff or route; it should not ask the human to prompt that other role.

## Agent Routine

Every agent should read:

- `AGENTS.md`
- `.agents/project-target.md`
- its prompt in `.agents/prompts/<role>.md`
- its skill pack in `.agents/skills/<role>.md`
- its memory in `.agents/memory/<role>.md`
- its config in `.agents/agent-config/<role>.yaml`
- its inbox in `.agents/inbox/<role>.md`

Check an inbox:

```bash
./scripts/agent-inbox.sh cto
./scripts/agent-inbox.sh frontend
./scripts/agent-inbox.sh qa
```

Claim and complete a route:

```bash
./scripts/claim-route.sh R001 frontend
./scripts/complete-route.sh R001 frontend "Implemented assigned UI task"
```

Cancel a route:

```bash
./scripts/cancel-route.sh R001 orchestrator "Route no longer needed"
```

## Route Lifecycle

Routes live in:

- `.agents/inbox/<role>.md`
- `.agents/handoffs.md`
- `.agents/workflow-state.md`
- `.agents/state/routes.jsonl`
- `.agents/events.jsonl`

Create a route:

```bash
./scripts/route-agent.sh R001 cto "Research architecture" T001
```

Dispatch queued routes to tmux windows:

```bash
./scripts/dispatch-routes.sh agent-team --dry-run
./scripts/dispatch-routes.sh agent-team --send
```

The control window normally runs this automatically through:

```bash
./scripts/watch-routes.sh agent-team --send
```

Check route health:

```bash
./scripts/check-route-budget.sh
./scripts/check-stale-routes.sh
```

## Quality Gates

Run the full wrapper:

```bash
./scripts/run-quality-gates.sh
```

It runs scaffold checks, structured-state validation, memory checks, route budget checks, stale-route checks, secrets checks, milestone budget checks, readiness checks, done checks, and project commands when a project stack exists.

Useful targeted checks:

```bash
./scripts/validate-agent-workflow.sh
./scripts/validate-structured-state.sh
./scripts/check-ready.sh
./scripts/check-done.sh
./scripts/check-memory.sh
./scripts/check-secrets.sh
./scripts/check-milestone-budget.sh
```

Before review/merge, implementation agents should run:

```bash
./scripts/check-ownership.sh frontend
./scripts/check-ownership.sh backend
./scripts/check-ownership.sh data
./scripts/check-ownership.sh devops
./scripts/check-ownership.sh qa
./scripts/check-ownership.sh docs
```

For task-specific ownership:

```bash
./scripts/check-ownership.sh frontend T012
```

## Human Approval Gates

Human approval is required before:

- routing Product/CTO/PM work from an unapproved brief, unless explicitly proceeding with assumptions
- starting implementation after initial architecture/task planning
- accepting unresolved critical/major validation, review, or security findings
- changing architecture materially
- exceeding route or milestone budgets
- shipping/final acceptance

## Mid-Workflow Changes

Prompt only the Orchestrator:

```text
Use .agents/prompts/orchestrator.md.

Request:
<describe the feature change, bug, spec change, or replan request>

Please classify it, update the suitable workflow files, route the work to the right agents, and tell me the next single action.
```

The Orchestrator uses:

- `.agents/change-control.md`
- `.agents/change-request.md`
- `.agents/routing-matrix.md`
- `.agents/route-budget.md`
- `.agents/conflict-resolution.md`

## Key Files

Control plane:

- `AGENTS.md`
- `.agents/project-target.md`
- `.agents/workflow-state.md`
- `.agents/routing-matrix.md`
- `.agents/route-schema.md`
- `.agents/route-budget.md`
- `.agents/milestone-budget.md`
- `.agents/events.jsonl`
- `.agents/state/`

Planning:

- `.agents/intake-notes.md`
- `.agents/brief.md`
- `.agents/product-requirements.md`
- `.agents/design-notes.md`
- `.agents/architecture.md`
- `.agents/decisions.md`
- `.agents/task-board.md`
- `.agents/qa-plan.md`
- `.agents/release-notes.md`

Agent behavior:

- `.agents/prompts/`
- `.agents/skills/`
- `.agents/memory/`
- `.agents/memory-policy.md`
- `.agents/agent-config/`
- `.agents/schemas/`
- `.agents/ownership/`

Review and validation:

- `.agents/quality-gates.md`
- `.agents/definition-of-ready.md`
- `.agents/definition-of-done.md`
- `.agents/validation-report.md`
- `.agents/review-report.md`
- `.agents/security-report.md`
- `.agents/secrets-policy.md`

Coordination:

- `.agents/inbox/`
- `.agents/handoffs.md`
- `.agents/agent-log/`
- `.agents/conflict-resolution.md`
- `.agents/sync-policy.md`

Research and rationale:

- `.agents/workflow-upgrade-research.md`

## Status Dashboard

Use:

```bash
./scripts/agent-status.sh
```

This shows workflow state, git status, task counts, open handoffs, validation summary, review summary, and security summary.

## Final Acceptance

Route final CTO review:

```text
Use .agents/prompts/final-cto-review.md.
```

Route final PM acceptance:

```text
Use .agents/prompts/final-acceptance.md.
```

Final outputs:

- `.agents/final-cto-review.md`
- `.agents/final-acceptance.md`

The human makes the final ship/no-ship decision.
