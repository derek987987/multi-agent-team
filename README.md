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

Startup launches Codex in every agent window with `--ask-for-approval never --sandbox workspace-write --disable apps` so role agents stay sandboxed, avoid app-MCP startup stalls, and do not stop for shell-command approval prompts. Before launch, startup pre-trusts the generated agent-team copy and target project in Codex config so first-run workspace trust prompts do not strand role panes. The `control` window waits for every role to emit `ROLE_READY <role>` before the route watcher starts dispatching. The `office` window serves Agent Office at `http://127.0.0.1:8765/visual-media/`, and the `orchestrator` window is the normal place where you talk to the team.

Set `AGENT_OFFICE_PORT=<port>` before startup when the default dashboard port is already in use. Set `AGENT_ROLE_READY_TIMEOUT=<seconds>` when a slow machine or model needs more startup time. Set `AGENT_TEAM_AUTO_TRUST_CODEX_PROJECTS=0` if you want to handle Codex workspace trust prompts manually.

Security note: `workspace-write` limits writes to the launched workspace plus any `--add-dir` paths, normally the agent-team copy and the target project. Keep secrets out of those writable paths when possible.

If auto-trust is disabled and this is the first time Codex has opened the generated agent-team copy or target project, Codex may ask whether you trust the directory. Choose `Yes, continue` for local projects you created and trust.

In the `orchestrator` tmux window, give a rough idea:

```text
Use agent-control/prompts/intake-orchestrator.md.

Idea:
<describe the coding project in rough words>

Please interview me if needed, refine my idea, write agent-control/brief.md, and ask me to approve the brief before routing Product/CTO work.
```

The Orchestrator asks at most 3 questions at a time, writes `agent-control/brief.md`, and waits for approval. After approval, the Orchestrator creates routes in `agent-control/inbox/<role>.md`; the watcher dispatches those routes to the matching Codex windows. You should not need to prompt Product, Research, CTO, Design, PM, coder, Data, DevOps, QA, Performance, Reviewer, Security, Docs, Validation, or Integration agents directly during normal work.

Review the brief:

```bash
sed -n '1,220p' agent-control/brief.md
```

Approve:

```text
Approved. Proceed with Product/CTO planning and routing.
```

## New Project With Agent Office

Use this flow when you want the visual dashboard while starting a new coding
project.

1. Start from the reusable template home:

   ```bash
   cd /Users/hay/Documents/agent-teams
   ```

2. Create a per-project agent-team copy and start the tmux team:

   ```bash
   ./scripts/new-coding-project.sh /Users/hay/Documents/my-app --start
   ```

   This creates `/Users/hay/Documents/agent-team-instances/my-app-team`, resets
   its `agent-control/*` state, writes `agent-control/project-target.md` to point at
   `/Users/hay/Documents/my-app`, validates the scaffold, and launches tmux.
   The reusable template stays in `/Users/hay/Documents/agent-teams`; normal
   project work should happen from the generated copy.

3. If the target project is already a git repository and you want role-specific
   implementation worktrees, use:

   ```bash
   ./scripts/new-coding-project.sh /Users/hay/Documents/my-app --worktrees
   ```

   `--worktrees` requires the target project to already be inside a git repo.
   For a brand-new empty project, use `--start` first; initialize and commit the
   project before switching to worktree mode later.

4. In the tmux `orchestrator` window, give the first rough idea:

   ```text
   Use agent-control/prompts/intake-orchestrator.md.

   Idea:
   <describe the coding project in rough words>

   Please interview me if needed, refine my idea, write agent-control/brief.md, and ask me to approve the brief before routing Product/CTO work.
   ```

5. Open Agent Office from the URL printed in the tmux `office` window, normally:

   ```text
   http://127.0.0.1:8765/visual-media/
   ```

   If that port is already in use, restart with `AGENT_OFFICE_PORT=<port>` or
   run `./scripts/start-agent-office-dashboard.sh --port <port>` manually from
   the generated copy.

6. Use the dashboard to watch workflow state:

   - Agent Office reads `agent-control/company/agent-profiles.jsonl`,
     `agent-control/state/agents.jsonl`, `agent-control/state/routes.jsonl`,
     `agent-control/events.jsonl`, `agent-control/workflow-state.md`, and route reports.
   - If agents show as offline, the dashboard is telling you that live telemetry
     is empty or the tmux team is not running.
   - Clicking an agent opens the inspector with role, status, active route,
     evidence refs, and recent events.

7. Use the dashboard prompt box for context-aware Orchestrator requests:

   - Select or click an agent.
   - Write the request in the prompt box.
   - Submit it.

   The dashboard creates a queued route with `From: human-ui`, `To:
   orchestrator`, and selected-agent context. The Orchestrator is still the
   routing authority; the dashboard does not directly task implementation
   agents.

8. Continue approvals and interactive decisions in the tmux `orchestrator`
   window. The dashboard is best for visibility, selected-agent context, and
   quick routed prompts; tmux is still where Codex agents actually run and where
   longer back-and-forth is easiest.

9. Let the route watcher dispatch work. The normal path is:

   ```text
   human request -> Orchestrator -> agent-control/inbox/<role>.md route -> watcher dispatches -> role tmux window acts -> route report/state updates -> dashboard refresh shows progress
   ```

10. Before review, merge, or push, run the quality gates from the generated
    copy:

    ```bash
    ./scripts/run-quality-gates.sh
    ```

## Dashboard vs Tmux

Agent Office is a visual control surface over the same file-backed workflow.
tmux is the execution environment.

| Need | Use Agent Office | Use tmux |
| --- | --- | --- |
| See which roles exist and whether they are idle, busy, blocked, or offline | Yes | Possible, but spread across windows and status commands |
| Inspect selected-agent route/status context | Yes | Yes, by reading `agent-control/*` files or running scripts |
| Send a context-aware prompt about a selected role | Yes, it queues an Orchestrator route with `From: human-ui` | Yes, prompt the `orchestrator` window directly |
| Run Codex role agents | No | Yes |
| Dispatch queued routes automatically | No | Yes, the `control` window runs `scripts/watch-routes.sh` |
| Do long interactive planning, approvals, and clarifying Q&A | Limited | Best in the `orchestrator` tmux window |
| Run project dev servers and logs | No | Use the tmux `server` window; Agent Office runs in `office` |
| Attach media through visible options | Yes, Media Builder tab previews `scripts/attach-media.sh` | Yes, run `scripts/attach-media.sh` manually |

The dashboard should never become a second source of truth. If the visual state
looks wrong, check the underlying `agent-control/*` files and the tmux windows; the
dashboard only reads those files and writes Orchestrator prompt routes.

## When To Use Media Builder

Use Media Builder only when you have a local file that should become durable
context for the agent team. Typical examples:

- a screenshot of a design you want agents to follow
- a product reference image
- a short demo video or screen recording
- a PDF or document that explains requirements
- a validation screenshot that proves a bug or UI state

Media Builder does not run agents, does not route work, and does not change the
target app. It only builds the matching `scripts/attach-media.sh` command. That
command records the file path, purpose, sensitivity, and owner metadata in
`agent-control/media/manifest.jsonl` and `agent-control/state/media.jsonl`.

Example:

```bash
./scripts/attach-media.sh M001 design homepage /Users/hay/Desktop/homepage-design.png screenshot "Homepage design reference" \
  --copy \
  --sensitive no \
  --review-owner design \
  --tags "homepage,design,reference"
```

After that, future agents can find the file as workflow context. For normal
control and status, use Agent Office and tmux; use Media Builder only when there
is a file to attach.

## Daily Usage

Use this workflow as a small coding company, not as a set of separate chat windows.

1. Improve the reusable team in this repo: `cd /Users/hay/Documents/agent-teams`.
2. Create one agent-team copy per coding project with `new-coding-project.sh`.
3. Talk to the `orchestrator` window only during normal work.
4. Let the Orchestrator route Product, Research, CTO, Design, PM, implementation, QA, Security, Validation, Docs, and Integration through `agent-control/inbox/<role>.md`.
5. Check status with `./scripts/agent-status.sh` or the lighter functional view with `./scripts/company-status.sh`.
6. Use meetings when several roles need one shared decision before PM writes tasks.
7. Convert closed meeting action items into PM tasks and route implementation from those tasks.
8. Run `./scripts/run-quality-gates.sh` before review, merge, or push.

The source of truth is the files under `agent-control/`. Tmux windows run agents and watchers; they are not the durable state.

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
agent-control/project-target.md
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
19. `office`
20. `server`

All agent windows run:

```bash
codex --ask-for-approval never --sandbox workspace-write --disable apps --no-alt-screen
```

via `scripts/codex-role.sh`. The `office` window serves Agent Office, and the `server` window remains a plain terminal for dev servers and logs.
Startup uses `scripts/trust-codex-projects.sh` to avoid workspace-trust stalls and `scripts/wait-for-agent-sessions.sh` to wait for the `ROLE_READY <role>` startup handshake before route dispatch begins.

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

Build and use the functional layer before visual changes. The Agent Office dashboard reads these files instead of inventing a second source of truth.

Company files:

- `agent-control/company/projects.jsonl` - project registry updated by `set-project-target.sh`.
- `agent-control/company/agent-profiles.jsonl` - machine-readable agent skill cards.
- `agent-control/state/agents.jsonl` - live role telemetry for session, window, status, active route, target path, and recovery owner.
- `agent-control/meetings/M*.md` - cross-agent meeting records, decisions, and action items.
- `agent-control/media/manifest.jsonl` - image, video, screenshot, audio, and document attachment metadata.
- `agent-control/approvals.jsonl` - approval and accepted-risk ledger.
- `agent-control/state/projects.jsonl`, `meetings.jsonl`, `media.jsonl`, and `approvals.jsonl` - structured mirrors for scripts and future UI.
- `agent-control/state/workflow.sqlite3` - generated runtime mirror for atomic route claims, route gate refs, run metadata, token counts, and cost cents.
- `visual-media/` - no-build Agent Office dashboard plus the static option builder for `scripts/attach-media.sh` parameters.

Functional commands:

```bash
./scripts/company-status.sh
./scripts/create-meeting.sh M001 "Plan first milestone" orchestrator product cto pm
./scripts/attach-media.sh M001 meeting M001 /path/to/reference.png screenshot "Reference UI" \
  --copy --sensitive no --review-owner security --tags "design,visual,reference"
./scripts/start-agent-office-dashboard.sh
./scripts/record-approval.sh AP001 human "brief" approved "Proceed with functional layer" M001
./scripts/close-meeting.sh M001 "Functional scope approved" "PM converts actions into tasks"
./scripts/route-db.sh init
./scripts/route-agent.sh R001 pm "Plan meeting actions" T001 \
  --meeting M001 --decision D001 \
  --instruction "Convert the closed meeting action items into PM task-board updates." \
  --expected-output "agent-control/task-board.md updates and agent-control/routes/R001.md report" \
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
./scripts/attach-media.sh M001 meeting M001 /path/to/reference.png screenshot "Reference from product discussion" \
  --copy \
  --sensitive no \
  --review-owner security \
  --attribution "Product discussion reference" \
  --tags "design,visual,reference"

# 4. Record human approval or risk acceptance when the workflow needs it.
./scripts/record-approval.sh AP001 human "functional requirements" approved "Build functional layer before visual UI" M001

# 5. Close the meeting with a decision and action items.
./scripts/close-meeting.sh M001 "Functional scope approved" "PM creates tasks; CTO checks schemas; Security checks attachments"

# 6. Route the next owner with meeting and decision metadata.
./scripts/route-agent.sh R001 pm "Turn meeting actions into task board" T001 \
  --meeting M001 --decision D001 \
  --instruction "Turn meeting decisions into ordered tasks with owners and validation commands." \
  --expected-output "agent-control/task-board.md updates and agent-control/routes/R001.md report" \
  --validation "Run ./scripts/check-ready.sh and ./scripts/validate-route-state.sh."
```

Functional records map like this:

| Need | File / command |
| --- | --- |
| Current projects | `agent-control/company/projects.jsonl`, `scripts/set-project-target.sh` |
| Agent skill cards | `agent-control/company/agent-profiles.jsonl` |
| Live agent telemetry | `agent-control/state/agents.jsonl`, `scripts/update-agent-state.sh` |
| Cross-agent decisions | `agent-control/meetings/M*.md` |
| Media references | `agent-control/media/manifest.jsonl`, `scripts/attach-media.sh` |
| Human approvals | `agent-control/approvals.jsonl`, `scripts/record-approval.sh` |
| Execution routes | `agent-control/inbox/<role>.md`, `scripts/route-agent.sh` |
| Atomic route/runtime state | `agent-control/state/workflow.sqlite3`, `scripts/route-db.sh` |
| Run cost and token metadata | `scripts/record-route-run.sh`, SQLite `route_runs` table |
| Future dashboard input | `agent-control/state/*.jsonl` |
| Agent Office dashboard | `visual-media/`, `scripts/start-agent-office-dashboard.sh` |
| Visual media option builder | `visual-media/`, `scripts/start-visual-media-dashboard.sh` |

Do not build visual dashboards that create their own source of truth. The
`visual-media/` dashboard is allowed because Agent Office reads `agent-control/*`
state through a local snapshot API, and the Media Builder tab only displays the
options for the functional media command and previews the matching
`scripts/attach-media.sh` invocation.

Agent Office APIs:

- `GET /api/snapshot` returns profiles, latest live telemetry, route state,
  workflow summary, route reports, and recent events from the control-plane
  files.
- `POST /api/orchestrator-prompt` validates the selected role and prompt, then
  queues an Orchestrator route with `From: human-ui`.

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

Run that again whenever the root checkout changes `agent-control/*` and implementation worktrees need the latest control-plane files. Sync follows `agent-control/sync-policy.md`: root-owned planning files are pushed, while local evidence files such as logs/reports are preserved.

## Operating Flow

1. User gives rough idea to Orchestrator.
2. Orchestrator interviews, drafts `agent-control/brief.md`, and asks for approval.
3. Product clarifies users, journeys, scope, non-goals, and acceptance risks when needed.
4. Research resolves unknown stack, API, framework, or platform questions before planning depends on assumptions.
5. CTO writes `agent-control/architecture.md` and `agent-control/decisions.md`.
6. Design writes `agent-control/design-notes.md` for user-facing flows.
7. PM writes `agent-control/task-board.md` and routes implementation/specialist work.
8. Human approves architecture and task board before broad implementation.
9. Implementation and specialist agents work only on ready assigned tasks.
10. QA creates or updates regression/smoke automation and `agent-control/qa-plan.md`.
11. Performance defines budgets or checks when latency, memory, bundle size, load, query speed, or runtime cost matters.
12. Reviewer, Security, and Validation review the work.
13. Docs updates docs and `agent-control/release-notes.md` when behavior, setup, API, or release messaging changes.
14. Integration merges one branch/worktree at a time.
15. CTO and PM perform final review/acceptance.

Agents communicate through `agent-control/*` files. If a role needs another role, it writes a concrete handoff or route; it should not ask the human to prompt that other role.

## Agent Routine

Every agent should read:

- `AGENTS.md`
- `agent-control/project-target.md`
- its prompt in `agent-control/prompts/<role>.md`
- its skill pack in `agent-control/skills/<role>.md`
- its memory in `agent-control/memory/<role>.md`
- its config in `agent-control/agent-config/<role>.yaml`
- its inbox in `agent-control/inbox/<role>.md`

Each role config declares its output schema, owned outputs, route input schema, allowed handoff targets, completion-report requirement, live telemetry fields, dispatch timeout, stale timeout, capacity, escalation owner, and workflow-edit permissions.

Check an inbox:

```bash
./scripts/agent-inbox.sh cto
./scripts/agent-inbox.sh frontend
./scripts/agent-inbox.sh qa
```

Claim and complete a route:

```bash
./scripts/claim-route.sh R001 frontend
./scripts/complete-route.sh R001 frontend "Implemented assigned UI task" --report agent-control/routes/R001.md --output-ref src/frontend/LoginForm.tsx
./scripts/block-route.sh R001 frontend "Missing API contract" --report agent-control/routes/R001.md
```

Cancel a route:

```bash
./scripts/cancel-route.sh R001 orchestrator "Route no longer needed"
```

## Route Lifecycle

Routes live in:

- `agent-control/inbox/<role>.md`
- `agent-control/handoffs.md`
- `agent-control/workflow-state.md`
- `agent-control/state/routes.jsonl`
- `agent-control/events.jsonl`
- `agent-control/routes/R000.md`
- `agent-control/state/workflow.sqlite3`

Create a route:

```bash
./scripts/route-agent.sh R001 cto "Research architecture" T001 \
  --instruction "Read the approved brief and produce architecture, decisions, ownership, and validation implications." \
  --expected-output "agent-control/architecture.md, agent-control/decisions.md, and agent-control/routes/R001.md report" \
  --validation "Run ./scripts/validate-route-state.sh and relevant workflow checks."
```

Routes that need explicit gates can be created with `--approval-required` or
`--review-required <role>`. Completion then requires matching refs:

```bash
./scripts/record-approval.sh AP001 human "route:R001" approved "Approved completion"
./scripts/complete-route.sh R001 cto "Architecture approved" --report agent-control/routes/R001.md --approval-ref AP001
./scripts/complete-route.sh R002 frontend "Implementation reviewed" --report agent-control/routes/R002.md --review-ref R003
```

Dispatch queued routes to tmux windows:

```bash
./scripts/dispatch-routes.sh agent-team --dry-run
./scripts/dispatch-routes.sh agent-team --send
./scripts/heartbeat-routes.sh agent-team --once --dry-run
```

The control window normally runs this automatically through:

```bash
./scripts/watch-routes.sh agent-team --send
```

The startup scripts keep this watcher inside a restart loop. They start role windows first, pre-trust the local Codex workspaces, then run `scripts/wait-for-agent-sessions.sh` so dispatch waits for the explicit `ROLE_READY <role>` marker instead of a blind sleep. If a role is still launching, `dispatch-routes.sh` leaves its queued routes queued for the next watcher pass instead of blocking them as infrastructure failures. If `watch-routes.sh` exits, the `control` window stays open, prints the exit status, waits 5 seconds, and restarts the watcher. Startup also falls back to the `orchestrator` window if the `control` window is unavailable, so a watcher crash should not abort startup with `can't find window: control`.

Dispatch has two separate timeouts. `ROUTE_DISPATCH_SEND_TIMEOUT` bounds tmux delivery; a delivery timeout blocks the route because the prompt did not reach the role pane. `ROUTE_DISPATCH_ACK_TIMEOUT` only controls how long the watcher waits for the role to claim the route; if that expires, the route stays `dispatched` so a slow Codex session can still claim it and stale-route recovery can make the retry/block decision later.

Check route health:

```bash
./scripts/check-route-budget.sh
./scripts/check-stale-routes.sh
./scripts/recover-stale-routes.sh --dry-run
./scripts/recover-stale-routes.sh --apply
./scripts/validate-route-state.sh
./scripts/route-status.sh R001
./scripts/update-agent-state.sh frontend --status busy --active-route R001
./scripts/route-db.sh check
./scripts/record-route-run.sh R001 frontend --status succeeded --model gpt-5.4 --input-tokens 12000 --output-tokens 3000 --cost-cents 25 --exit-code 0 --summary "Implemented assigned route"
```

`recover-stale-routes.sh --apply` increments `Attempt` and requeues stale active routes while they are inside `agent-control/route-budget.md`; routes at retry budget are blocked with recovery evidence in `agent-control/routes/R000.md`.

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
./scripts/route-db.sh check
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

`complete-route.sh` enforces these route-local gates when the route envelope
declares them. Use `--approval-ref <approval-id>` for human approvals and
`--review-ref <done-review-route-id>` for review-gated implementation routes.

## Mid-Workflow Changes

Prompt only the Orchestrator:

```text
Use agent-control/prompts/orchestrator.md.

Request:
<describe the feature change, bug, spec change, or replan request>

Please classify it, update the suitable workflow files, route the work to the right agents, and tell me the next single action.
```

The Orchestrator uses:

- `agent-control/change-control.md`
- `agent-control/change-request.md`
- `agent-control/routing-matrix.md`
- `agent-control/route-budget.md`
- `agent-control/conflict-resolution.md`

## Key Files

Control plane:

- `AGENTS.md`
- `agent-control/project-target.md`
- `agent-control/workflow-state.md`
- `agent-control/routing-matrix.md`
- `agent-control/route-schema.md`
- `agent-control/route-budget.md`
- `agent-control/milestone-budget.md`
- `agent-control/events.jsonl`
- `agent-control/state/`
- `agent-control/context-map.md`
- `agent-control/agent-policy.md`
- `agent-control/evaluation-suite.md`
- `agent-control/failure-recovery.md`
- `agent-control/adaptation-guide.md`

Planning:

- `agent-control/intake-notes.md`
- `agent-control/brief.md`
- `agent-control/product-requirements.md`
- `agent-control/research-notes.md`
- `agent-control/design-notes.md`
- `agent-control/architecture.md`
- `agent-control/decisions.md`
- `agent-control/task-board.md`
- `agent-control/qa-plan.md`
- `agent-control/performance-report.md`
- `agent-control/release-notes.md`

Agent behavior:

- `agent-control/prompts/`
- `agent-control/skills/`
- `agent-control/memory/`
- `agent-control/memory-policy.md`
- `agent-control/agent-config/`
- `agent-control/schemas/`
- `agent-control/ownership/`

Review and validation:

- `agent-control/quality-gates.md`
- `agent-control/definition-of-ready.md`
- `agent-control/definition-of-done.md`
- `agent-control/validation-report.md`
- `agent-control/review-report.md`
- `agent-control/security-report.md`
- `agent-control/secrets-policy.md`

Coordination:

- `agent-control/inbox/`
- `agent-control/handoffs.md`
- `agent-control/agent-log/`
- `agent-control/conflict-resolution.md`
- `agent-control/sync-policy.md`

Research and rationale:

- `agent-control/workflow-upgrade-research.md`

## Status Dashboard

Use:

```bash
./scripts/agent-status.sh
```

This shows workflow state, git status, task counts, open handoffs, validation summary, review summary, and security summary.
It also shows live agent telemetry from `agent-control/state/agents.jsonl`.

## Final Acceptance

Route final CTO review:

```text
Use agent-control/prompts/final-cto-review.md.
```

Route final PM acceptance:

```text
Use agent-control/prompts/final-acceptance.md.
```

Final outputs:

- `agent-control/final-cto-review.md`
- `agent-control/final-acceptance.md`

The human makes the final ship/no-ship decision.
