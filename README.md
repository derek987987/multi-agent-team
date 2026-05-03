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

Create and start the copied team in one command:

```bash
./scripts/new-coding-project.sh /Users/hay/Documents/my-app --start
```

Use `--worktrees` instead of `--start` when the target project is already a git repository and you want role-specific implementation worktrees:

```bash
./scripts/new-coding-project.sh /Users/hay/Documents/my-app --worktrees
```

Or provide the exact destination for the copied agent team:

```bash
./scripts/new-coding-project.sh /Users/hay/Documents/my-app /Users/hay/Documents/my-app-agent-team
```

Start the copied team:

```bash
cd /Users/hay/Documents/agent-team-instances/my-app-team
./scripts/start-agent-team.sh
```

Startup launches Codex in every agent window with `--ask-for-approval never --sandbox workspace-write` so role agents stay sandboxed and do not stop for shell-command approval prompts. The `control` window runs the route watcher, and the `orchestrator` window is the normal place where you talk to the team.

Security note: `workspace-write` limits writes to the launched workspace plus any `--add-dir` paths, normally the agent-team copy and the target project. Keep secrets out of those writable paths when possible.

If this is the first time Codex has opened the generated agent-team copy or target project, Codex may ask whether you trust the directory. Choose `Yes, continue` for local projects you created and trust.

In the `orchestrator` tmux window, give a rough idea:

```text
Use .agents/prompts/intake-orchestrator.md.

Idea:
<describe the coding project in rough words>

Please interview me if needed, refine my idea, write .agents/brief.md, and ask me to approve the brief before routing Product/CTO work.
```

The Orchestrator asks at most 3 questions at a time, writes `.agents/brief.md`, and waits for approval. After approval, the Orchestrator creates routes in `.agents/inbox/<role>.md`; the watcher dispatches those routes to the matching Codex windows. You should not need to prompt Product, Research, CTO, Design, PM, coder, Data, DevOps, QA, Performance, Reviewer, Security, Docs, Validation, or Integration agents directly during normal work.

Review the brief:

```bash
sed -n '1,220p' .agents/brief.md
```

Approve:

```text
Approved. Proceed with Product/CTO planning and routing.
```

## Daily Usage

Use this workflow as a small coding company, not as a set of separate chat windows.

1. Improve the reusable team in this repo: `cd /Users/hay/Documents/agent-teams`.
2. Create one agent-team copy per coding project with `new-coding-project.sh`.
3. Talk to the `orchestrator` window only during normal work.
4. Let the Orchestrator route Product, Research, CTO, Design, PM, implementation, QA, Security, Validation, Docs, and Integration through `.agents/inbox/<role>.md`.
5. Check status with `./scripts/agent-status.sh` or the lighter functional view with `./scripts/company-status.sh`.
6. Use meetings when several roles need one shared decision before PM writes tasks.
7. Convert closed meeting action items into PM tasks and route implementation from those tasks.
8. Run `./scripts/run-quality-gates.sh` before review, merge, or push.

The source of truth is the files under `.agents/`. Tmux windows run agents and watchers; they are not the durable state.

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
4. `research`
5. `cto`
6. `design`
7. `pm`
8. `frontend`
9. `backend`
10. `data`
11. `devops`
12. `qa`
13. `performance`
14. `validation`
15. `reviewer`
16. `security`
17. `docs`
18. `integration`
19. `server`

All agent windows run:

```bash
codex --ask-for-approval never --sandbox workspace-write --no-alt-screen
```

via `scripts/codex-role.sh`. The server window remains a plain terminal for dev servers and logs.

## Production Roles

- `orchestrator`: human intake, classification, routing, state, approval gates.
- `product`: users, journeys, scope, non-goals, acceptance risks.
- `research`: unfamiliar stacks, libraries, APIs, platform constraints, sourced recommendations.
- `cto`: architecture, decisions, boundaries, technical risk.
- `design`: user flows, UI states, accessibility, frontend handoff.
- `pm`: task board, sequencing, dependencies, acceptance criteria.
- `frontend` / `backend`: implementation in owned files with tests and handoffs.
- `data`: schemas, migrations, seed data, analytics, query contracts.
- `devops`: setup, CI, build, deploy, environment, observability.
- `qa`: automated test strategy, fixtures, smoke/regression coverage.
- `performance`: latency, memory, bundle size, query speed, load, profiling, cost.
- `reviewer`: code correctness, maintainability, architecture drift, missing tests.
- `security`: auth, permissions, secrets, sensitive data, dependency risk.
- `docs`: user docs, developer docs, runbooks, release notes.
- `validation`: independent command execution and acceptance evidence.
- `integration`: reviewed merges, conflict resolution, final validation routing.

## Functional Company Layer

Build and use the functional layer before visual dashboards. The visual app should read these files later instead of inventing a second source of truth.

Company files:

- `.agents/company/projects.jsonl` - project registry updated by `set-project-target.sh`.
- `.agents/company/agent-profiles.jsonl` - machine-readable agent skill cards.
- `.agents/meetings/M*.md` - cross-agent meeting records, decisions, and action items.
- `.agents/media/manifest.jsonl` - image, video, screenshot, audio, and document attachment metadata.
- `.agents/approvals.jsonl` - approval and accepted-risk ledger.
- `.agents/state/projects.jsonl`, `meetings.jsonl`, `media.jsonl`, and `approvals.jsonl` - structured mirrors for scripts and future UI.

Functional commands:

```bash
./scripts/company-status.sh
./scripts/create-meeting.sh M001 "Plan first milestone" orchestrator product cto pm
./scripts/attach-media.sh M001 meeting M001 /path/to/reference.png screenshot "Reference UI"
./scripts/record-approval.sh AP001 human "brief" approved "Proceed with functional layer" M001
./scripts/close-meeting.sh M001 "Functional scope approved" "PM converts actions into tasks"
./scripts/route-agent.sh R001 pm "Plan meeting actions" T001 \
  --meeting M001 --decision D001 \
  --instruction "Convert the closed meeting action items into PM task-board updates." \
  --expected-output ".agents/task-board.md updates and .agents/routes/R001.md report" \
  --validation "Run ./scripts/check-ready.sh and ./scripts/validate-route-state.sh."
```

Use meetings when multiple roles need to discuss a cross-project or cross-domain decision. Close the meeting before PM creates tasks unless the meeting is deliberately left open for ongoing discovery.

Typical functional-first sequence:

```bash
# 1. Confirm the active target and company registry.
./scripts/company-status.sh

# 2. Create a shared planning meeting.
./scripts/create-meeting.sh M001 "Plan functional requirements" orchestrator product cto pm data security

# 3. Attach any reference screenshot, video, audio, document, or local file.
./scripts/attach-media.sh M001 meeting M001 /path/to/reference.png screenshot "Reference from product discussion"

# 4. Record human approval or risk acceptance when the workflow needs it.
./scripts/record-approval.sh AP001 human "functional requirements" approved "Build functional layer before visual UI" M001

# 5. Close the meeting with a decision and action items.
./scripts/close-meeting.sh M001 "Functional scope approved" "PM creates tasks; CTO checks schemas; Security checks attachments"

# 6. Route the next owner with meeting and decision metadata.
./scripts/route-agent.sh R001 pm "Turn meeting actions into task board" T001 \
  --meeting M001 --decision D001 \
  --instruction "Turn meeting decisions into ordered tasks with owners and validation commands." \
  --expected-output ".agents/task-board.md updates and .agents/routes/R001.md report" \
  --validation "Run ./scripts/check-ready.sh and ./scripts/validate-route-state.sh."
```

Functional records map like this:

| Need | File / command |
| --- | --- |
| Current projects | `.agents/company/projects.jsonl`, `scripts/set-project-target.sh` |
| Agent skill cards | `.agents/company/agent-profiles.jsonl` |
| Cross-agent decisions | `.agents/meetings/M*.md` |
| Media references | `.agents/media/manifest.jsonl`, `scripts/attach-media.sh` |
| Human approvals | `.agents/approvals.jsonl`, `scripts/record-approval.sh` |
| Execution routes | `.agents/inbox/<role>.md`, `scripts/route-agent.sh` |
| Future dashboard input | `.agents/state/*.jsonl` |

Do not start the visual dashboard until the functional records above can carry the whole workflow.

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

Worktree mode creates role worktrees for project-editing roles from `PROJECT_WORKTREE_ROLES` in `scripts/agent-roles.sh`: `frontend`, `backend`, `data`, `devops`, `qa`, `performance`, `docs`, and `validation`.

Worktree mode runs:

```bash
./scripts/sync-agent-state.sh --push
```

Run that again whenever the root checkout changes `.agents/*` and implementation worktrees need the latest control-plane files. Sync follows `.agents/sync-policy.md`: root-owned planning files are pushed, while local evidence files such as logs/reports are preserved.

## Operating Flow

1. User gives rough idea to Orchestrator.
2. Orchestrator interviews, drafts `.agents/brief.md`, and asks for approval.
3. Product clarifies users, journeys, scope, non-goals, and acceptance risks when needed.
4. Research resolves unknown stack, API, framework, or platform questions before planning depends on assumptions.
5. CTO writes `.agents/architecture.md` and `.agents/decisions.md`.
6. Design writes `.agents/design-notes.md` for user-facing flows.
7. PM writes `.agents/task-board.md` and routes implementation/specialist work.
8. Human approves architecture and task board before broad implementation.
9. Implementation and specialist agents work only on ready assigned tasks.
10. QA creates or updates regression/smoke automation and `.agents/qa-plan.md`.
11. Performance defines budgets or checks when latency, memory, bundle size, load, query speed, or runtime cost matters.
12. Reviewer, Security, and Validation review the work.
13. Docs updates docs and `.agents/release-notes.md` when behavior, setup, API, or release messaging changes.
14. Integration merges one branch/worktree at a time.
15. CTO and PM perform final review/acceptance.

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
./scripts/complete-route.sh R001 frontend "Implemented assigned UI task" --report .agents/routes/R001.md
./scripts/block-route.sh R001 frontend "Missing API contract" --report .agents/routes/R001.md
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
- `.agents/routes/R000.md`

Create a route:

```bash
./scripts/route-agent.sh R001 cto "Research architecture" T001 \
  --instruction "Read the approved brief and produce architecture, decisions, ownership, and validation implications." \
  --expected-output ".agents/architecture.md, .agents/decisions.md, and .agents/routes/R001.md report" \
  --validation "Run ./scripts/validate-route-state.sh and relevant workflow checks."
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

The startup scripts keep this watcher inside a restart loop. If `watch-routes.sh` exits, the `control` window stays open, prints the exit status, waits 5 seconds, and restarts the watcher. Startup also falls back to the `orchestrator` window if the `control` window is unavailable, so a watcher crash should not abort startup with `can't find window: control`.

Check route health:

```bash
./scripts/check-route-budget.sh
./scripts/check-stale-routes.sh
./scripts/validate-route-state.sh
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
./scripts/validate-route-state.sh
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
./scripts/check-ownership.sh performance
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
- `.agents/context-map.md`
- `.agents/agent-policy.md`
- `.agents/evaluation-suite.md`
- `.agents/failure-recovery.md`
- `.agents/adaptation-guide.md`

Planning:

- `.agents/intake-notes.md`
- `.agents/brief.md`
- `.agents/product-requirements.md`
- `.agents/research-notes.md`
- `.agents/design-notes.md`
- `.agents/architecture.md`
- `.agents/decisions.md`
- `.agents/task-board.md`
- `.agents/qa-plan.md`
- `.agents/performance-report.md`
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
