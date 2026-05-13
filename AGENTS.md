# Repository Agent Instructions

These instructions apply to all agents working in this repository.

## Repository Purpose

This repository is configured for a tmux-based multi-agent coding workflow. The actual product requirements live in `agent-control/brief.md`.

## Shared Source Of Truth

- `agent-control/brief.md` - product goal, users, scope, and definition of done
- `agent-control/project-target.md` - current coding project directory and target mode
- `agent-control/intake-notes.md` - rough ideas, clarifying questions, assumptions, and brief readiness
- `agent-control/context-map.md` - role context loading rules and handoff context contract
- `agent-control/agent-policy.md` - autonomy, guardrails, stop conditions, and output discipline
- `agent-control/company/projects.jsonl` - coding company project registry
- `agent-control/company/agent-profiles.jsonl` - machine-readable agent skill cards and current status
- `agent-control/state/agents.jsonl` - live role telemetry for session/window/status/active-route routing decisions
- `agent-control/meetings/` - cross-agent meeting records, decisions, action items, and media references
- `agent-control/media/manifest.jsonl` - attachment metadata for images, videos, screenshots, audio, documents, and references
- `visual-media/` - no-build Agent Office dashboard and visible media attachment option builder
- `agent-control/approvals.jsonl` - brief, architecture, risk, budget, and ship/no-ship approval ledger
- `agent-control/evaluation-suite.md` - scaffold and project evals for repeatable workflow assessment
- `agent-control/failure-recovery.md` - blocked-route recovery owners, retry rules, and evidence requirements
- `agent-control/adaptation-guide.md` - project-type routing guide for adaptable teams
- `agent-control/product-requirements.md` - product-owned users, journeys, scope, non-goals, and acceptance risks
- `agent-control/research-notes.md` - research-owned external/source findings and recommendations
- `agent-control/design-notes.md` - design-owned user flows, UI states, accessibility, and frontend handoff notes
- `agent-control/qa-plan.md` - QA-owned test strategy, fixtures, smoke coverage, and regression plan
- `agent-control/performance-report.md` - performance-owned metrics, baselines, budgets, and profiling notes
- `agent-control/release-notes.md` - docs-owned release notes, migration notes, and user-facing change summary
- `agent-control/sop.md` - standard operating procedure for the agent team
- `agent-control/roles.md` - role responsibilities and file ownership rules
- `agent-control/architecture.md` - CTO-owned architecture plan
- `agent-control/decisions.md` - durable product and technical decisions
- `agent-control/task-board.md` - PM-owned execution board
- `agent-control/handoffs.md` - structured cross-agent handoffs
- `agent-control/quality-gates.md` - required validation gates
- `agent-control/definition-of-ready.md` - checklist before implementation starts
- `agent-control/definition-of-done.md` - checklist before work is marked done
- `agent-control/conflict-resolution.md` - protocol for ownership, architecture, validation, security, and merge conflicts
- `agent-control/change-control.md` - how to change specs, modify features, and fix bugs mid-workflow
- `agent-control/change-request.md` - intake file for mid-workflow changes
- `agent-control/workflow-state.md` - current workflow phase, routes, blockers, and human attention items
- `agent-control/routing-matrix.md` - orchestrator routing policy
- `agent-control/route-schema.md` - required route fields and lifecycle
- `agent-control/routes/R000.md` - durable per-route handoff packet and completion report
- `agent-control/route-budget.md` - max open routes, retries, and escalation rules
- `agent-control/milestone-budget.md` - active task, retry, and branch budget limits
- `agent-control/events.jsonl` - append-only workflow event trace
- `agent-control/state/*.jsonl` - structured state mirrors for projects, routes, tasks, findings, meetings, media, and approvals
- `agent-control/state/workflow.sqlite3` - generated SQLite runtime mirror for atomic route claims, run metadata, gate refs, and cost fields
- `agent-control/state/agent-recovery/` - generated recovery checkpoints used to preserve role context before compaction or relaunch
- `agent-control/inbox/<role>.md` - per-role routed work queue
- `agent-control/ownership/<role>.paths` - path ownership allowlist for each role
- `agent-control/agent-config/<role>.yaml` - per-role required reads, allowed paths, and checks
- `agent-control/schemas/agent-state.md` - live agent telemetry schema
- `agent-control/skills/<role>.md` - role-specific capability, rules, and done criteria
- `agent-control/memory/<role>.md` - durable project-specific lessons and preferences
- `agent-control/memory-policy.md` - governance rules for durable memory
- `agent-control/secrets-policy.md` - rules for credentials, tokens, and secret handling
- `agent-control/schemas/*.md` - structured output formats for each role
- `agent-control/validation-report.md` - validation results and findings
- `agent-control/review-report.md` - reviewer findings
- `agent-control/security-report.md` - security findings
- `scripts/codex-role.sh` - launches each role-specific Codex agent sandboxed with command approval prompts disabled
- `scripts/trust-codex-projects.sh` - pre-trusts generated agent-team and target paths in Codex config to avoid first-run trust prompts during auto-start
- `scripts/wait-for-agent-sessions.sh` - waits for `ROLE_READY <role>` markers before route dispatch treats role panes as ready
- `scripts/watch-routes.sh` - recovers stale active routes, watches queued routes, and dispatches them to tmux agent windows
- `scripts/heartbeat-routes.sh` - performs a heartbeat-style pass over the SQLite route queue, runs recovery by default, and delegates dispatch
- `scripts/detect-agent-health.sh` - detects role-session readiness drift, failed/dead panes, missing active panes, and context-pressure signals
- `scripts/checkpoint-agent-context.sh` - writes durable recovery packets before context compaction or role relaunch
- `scripts/recover-agent-session.sh` - asks live agents to checkpoint context or relaunches failed panes from a recovery packet
- `scripts/monitor-agent-sessions.sh` - runs the role-session prevention loop before stale-route recovery and dispatch
- `scripts/route-db.sh` - owns the generated SQLite runtime store schema and route/run state mutations
- `scripts/record-route-run.sh` - records route run metadata, token counts, cost cents, exit status, and summary
- `scripts/route-status.sh` - summarizes a route from its canonical report, owner, evidence, output refs, and next action
- `scripts/recover-stale-routes.sh` - requeues stale routes inside retry budget and blocks stale routes after retry budget is exhausted
- `scripts/block-route.sh` - records blocked route state with reason and report evidence
- `scripts/validate-route-state.sh` - validates route markdown/report consistency
- `scripts/start-agent-office-dashboard.sh` - serves the Agent Office dashboard, snapshot API, Orchestrator prompt API, and media builder; startup scripts launch it in the tmux `office` window by default
- `scripts/start-visual-media-dashboard.sh` - compatibility launcher for the same dashboard URL

## Core Rules

1. Read `agent-control/project-target.md`, `agent-control/brief.md`, `agent-control/sop.md`, `agent-control/roles.md`, and `agent-control/task-board.md` before making changes.
2. Do not edit files owned by another agent unless the task board explicitly assigns that work.
3. Record cross-agent requests in `agent-control/handoffs.md`.
4. Check your role inbox in `agent-control/inbox/<role>.md` before starting work.
5. Read your role skill pack in `agent-control/skills/<role>.md`.
6. Read your role memory in `agent-control/memory/<role>.md`.
7. Use the relevant schema in `agent-control/schemas/` for role outputs.
8. Follow `agent-control/memory-policy.md` before adding durable memory.
9. Record major technical or product choices in `agent-control/decisions.md`; record human approvals or accepted risks in `agent-control/approvals.jsonl`.
10. Do not start implementation until `agent-control/definition-of-ready.md` is satisfied.
11. Do not mark a task done until `agent-control/definition-of-done.md` is satisfied.
12. Run the relevant checks from `agent-control/quality-gates.md` before handing off.
13. Run `scripts/check-ownership.sh <role>` before review/merge when code changed.
14. Run `scripts/check-route-budget.sh` before creating many routes.
15. Run `scripts/validate-structured-state.sh` before review/merge.
16. Run `scripts/validate-route-state.sh` before review/merge.
17. Run `scripts/check-stale-routes.sh` and escalate stale routes.
18. Run `scripts/monitor-agent-sessions.sh <session> --apply` before relaunching or recovering stuck role sessions; it must checkpoint context before compaction or relaunch.
19. Run `scripts/recover-stale-routes.sh --apply` to requeue or block stale routes when automatic recovery is appropriate; the control-window watcher and heartbeat dispatcher run the same recovery pass before dispatch by default.
20. Run `scripts/check-secrets.sh` before review/merge.
21. Prefer small, reviewable branches or worktrees over broad edits in one checkout.
22. For new projects, send rough ideas to the orchestrator using `agent-control/prompts/intake-orchestrator.md`; the orchestrator drafts `agent-control/brief.md`.
23. For minimal prompting, route mid-workflow scope changes, feature changes, bugs, or status questions through the orchestrator prompt in `agent-control/prompts/orchestrator.md`.
24. Do not ask the human to prompt another role during normal work; write a route or handoff and let the route watcher dispatch it.
25. Auto-launched role agents run sandboxed without shell-command approval prompts; they must still respect ownership, approval gates, and required checks.
26. Use `agent-control/company/agent-profiles.jsonl` to choose the right role before routing; use meetings when several roles need a shared decision before tasking.
27. Attach media through `scripts/attach-media.sh` so future visual tools can render the same references without changing workflow files; use the Media Builder tab in `visual-media/` only as a visible option builder for those same parameters.
28. Completion routes marked `Human approval required: yes` must pass `scripts/complete-route.sh ... --approval-ref <approved-id>`.
29. Completion routes marked `Review required: <role>` must pass `scripts/complete-route.sh ... --review-ref <done-review-route-id>`.

## Recommended Flow

1. Human gives rough idea to Orchestrator.
2. Orchestrator confirms `agent-control/project-target.md`, interviews, drafts `agent-control/brief.md`, and asks for approval.
3. Product clarifies scope when the brief needs stronger user, journey, or acceptance-risk detail.
4. Research resolves unfamiliar or drift-prone stack/API/platform questions.
5. CTO writes or updates `agent-control/architecture.md` and `agent-control/decisions.md`.
6. Design writes UI/UX handoff notes when the work is user-facing.
7. PM writes or updates `agent-control/task-board.md` and routes implementation work.
8. Human approves the architecture and task board before broad implementation.
9. Implementation and specialist agents work only on ready assigned tasks.
10. QA, Performance, Reviewer, Security, and Validation agents check branches/worktrees.
11. Docs updates user/developer/release documentation when behavior or setup changes.
12. Integration owner merges one branch at a time.
13. CTO performs final architecture review.
14. PM performs final acceptance review.

## Validation

Use `agent-control/quality-gates.md` as the validation contract. If this repository later gains framework-specific commands, add them there and keep this file current.
