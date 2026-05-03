# Repository Agent Instructions

These instructions apply to all agents working in this repository.

## Repository Purpose

This repository is configured for a tmux-based multi-agent coding workflow. The actual product requirements live in `.agents/brief.md`.

## Shared Source Of Truth

- `.agents/brief.md` - product goal, users, scope, and definition of done
- `.agents/project-target.md` - current coding project directory and target mode
- `.agents/intake-notes.md` - rough ideas, clarifying questions, assumptions, and brief readiness
- `.agents/context-map.md` - role context loading rules and handoff context contract
- `.agents/agent-policy.md` - autonomy, guardrails, stop conditions, and output discipline
- `.agents/company/projects.jsonl` - coding company project registry
- `.agents/company/agent-profiles.jsonl` - machine-readable agent skill cards and current status
- `.agents/state/agents.jsonl` - live role telemetry for session/window/status/active-route routing decisions
- `.agents/meetings/` - cross-agent meeting records, decisions, action items, and media references
- `.agents/media/manifest.jsonl` - attachment metadata for images, videos, screenshots, audio, documents, and references
- `.agents/approvals.jsonl` - brief, architecture, risk, budget, and ship/no-ship approval ledger
- `.agents/evaluation-suite.md` - scaffold and project evals for repeatable workflow assessment
- `.agents/failure-recovery.md` - blocked-route recovery owners, retry rules, and evidence requirements
- `.agents/adaptation-guide.md` - project-type routing guide for adaptable teams
- `.agents/product-requirements.md` - product-owned users, journeys, scope, non-goals, and acceptance risks
- `.agents/research-notes.md` - research-owned external/source findings and recommendations
- `.agents/design-notes.md` - design-owned user flows, UI states, accessibility, and frontend handoff notes
- `.agents/qa-plan.md` - QA-owned test strategy, fixtures, smoke coverage, and regression plan
- `.agents/performance-report.md` - performance-owned metrics, baselines, budgets, and profiling notes
- `.agents/release-notes.md` - docs-owned release notes, migration notes, and user-facing change summary
- `.agents/sop.md` - standard operating procedure for the agent team
- `.agents/roles.md` - role responsibilities and file ownership rules
- `.agents/architecture.md` - CTO-owned architecture plan
- `.agents/decisions.md` - durable product and technical decisions
- `.agents/task-board.md` - PM-owned execution board
- `.agents/handoffs.md` - structured cross-agent handoffs
- `.agents/quality-gates.md` - required validation gates
- `.agents/definition-of-ready.md` - checklist before implementation starts
- `.agents/definition-of-done.md` - checklist before work is marked done
- `.agents/conflict-resolution.md` - protocol for ownership, architecture, validation, security, and merge conflicts
- `.agents/change-control.md` - how to change specs, modify features, and fix bugs mid-workflow
- `.agents/change-request.md` - intake file for mid-workflow changes
- `.agents/workflow-state.md` - current workflow phase, routes, blockers, and human attention items
- `.agents/routing-matrix.md` - orchestrator routing policy
- `.agents/route-schema.md` - required route fields and lifecycle
- `.agents/routes/R000.md` - durable per-route handoff packet and completion report
- `.agents/route-budget.md` - max open routes, retries, and escalation rules
- `.agents/milestone-budget.md` - active task, retry, and branch budget limits
- `.agents/events.jsonl` - append-only workflow event trace
- `.agents/state/*.jsonl` - structured state mirrors for projects, routes, tasks, findings, meetings, media, and approvals
- `.agents/inbox/<role>.md` - per-role routed work queue
- `.agents/ownership/<role>.paths` - path ownership allowlist for each role
- `.agents/agent-config/<role>.yaml` - per-role required reads, allowed paths, and checks
- `.agents/schemas/agent-state.md` - live agent telemetry schema
- `.agents/skills/<role>.md` - role-specific capability, rules, and done criteria
- `.agents/memory/<role>.md` - durable project-specific lessons and preferences
- `.agents/memory-policy.md` - governance rules for durable memory
- `.agents/secrets-policy.md` - rules for credentials, tokens, and secret handling
- `.agents/schemas/*.md` - structured output formats for each role
- `.agents/validation-report.md` - validation results and findings
- `.agents/review-report.md` - reviewer findings
- `.agents/security-report.md` - security findings
- `scripts/codex-role.sh` - launches each role-specific Codex agent sandboxed with command approval prompts disabled
- `scripts/watch-routes.sh` - watches queued routes and dispatches them to tmux agent windows
- `scripts/route-status.sh` - summarizes a route from its canonical report, owner, evidence, output refs, and next action
- `scripts/block-route.sh` - records blocked route state with reason and report evidence
- `scripts/validate-route-state.sh` - validates route markdown/report consistency

## Core Rules

1. Read `.agents/project-target.md`, `.agents/brief.md`, `.agents/sop.md`, `.agents/roles.md`, and `.agents/task-board.md` before making changes.
2. Do not edit files owned by another agent unless the task board explicitly assigns that work.
3. Record cross-agent requests in `.agents/handoffs.md`.
4. Check your role inbox in `.agents/inbox/<role>.md` before starting work.
5. Read your role skill pack in `.agents/skills/<role>.md`.
6. Read your role memory in `.agents/memory/<role>.md`.
7. Use the relevant schema in `.agents/schemas/` for role outputs.
8. Follow `.agents/memory-policy.md` before adding durable memory.
9. Record major technical or product choices in `.agents/decisions.md`; record human approvals or accepted risks in `.agents/approvals.jsonl`.
10. Do not start implementation until `.agents/definition-of-ready.md` is satisfied.
11. Do not mark a task done until `.agents/definition-of-done.md` is satisfied.
12. Run the relevant checks from `.agents/quality-gates.md` before handing off.
13. Run `scripts/check-ownership.sh <role>` before review/merge when code changed.
14. Run `scripts/check-route-budget.sh` before creating many routes.
15. Run `scripts/validate-structured-state.sh` before review/merge.
16. Run `scripts/validate-route-state.sh` before review/merge.
17. Run `scripts/check-stale-routes.sh` and escalate stale routes.
18. Run `scripts/check-secrets.sh` before review/merge.
19. Prefer small, reviewable branches or worktrees over broad edits in one checkout.
20. For new projects, send rough ideas to the orchestrator using `.agents/prompts/intake-orchestrator.md`; the orchestrator drafts `.agents/brief.md`.
21. For minimal prompting, route mid-workflow scope changes, feature changes, bugs, or status questions through the orchestrator prompt in `.agents/prompts/orchestrator.md`.
22. Do not ask the human to prompt another role during normal work; write a route or handoff and let the route watcher dispatch it.
23. Auto-launched role agents run sandboxed without shell-command approval prompts; they must still respect ownership, approval gates, and required checks.
24. Use `.agents/company/agent-profiles.jsonl` to choose the right role before routing; use meetings when several roles need a shared decision before tasking.
25. Attach media through `scripts/attach-media.sh` so future visual tools can render the same references without changing workflow files.

## Recommended Flow

1. Human gives rough idea to Orchestrator.
2. Orchestrator confirms `.agents/project-target.md`, interviews, drafts `.agents/brief.md`, and asks for approval.
3. Product clarifies scope when the brief needs stronger user, journey, or acceptance-risk detail.
4. Research resolves unfamiliar or drift-prone stack/API/platform questions.
5. CTO writes or updates `.agents/architecture.md` and `.agents/decisions.md`.
6. Design writes UI/UX handoff notes when the work is user-facing.
7. PM writes or updates `.agents/task-board.md` and routes implementation work.
8. Human approves the architecture and task board before broad implementation.
9. Implementation and specialist agents work only on ready assigned tasks.
10. QA, Performance, Reviewer, Security, and Validation agents check branches/worktrees.
11. Docs updates user/developer/release documentation when behavior or setup changes.
12. Integration owner merges one branch at a time.
13. CTO performs final architecture review.
14. PM performs final acceptance review.

## Validation

Use `.agents/quality-gates.md` as the validation contract. If this repository later gains framework-specific commands, add them there and keep this file current.
