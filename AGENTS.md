# Repository Agent Instructions

These instructions apply to all agents working in this repository.

## Repository Purpose

This repository is configured for a tmux-based multi-agent coding workflow. The actual product requirements live in `.agents/brief.md`.

## Shared Source Of Truth

- `.agents/brief.md` - product goal, users, scope, and definition of done
- `.agents/project-target.md` - current coding project directory and target mode
- `.agents/intake-notes.md` - rough ideas, clarifying questions, assumptions, and brief readiness
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
- `.agents/route-budget.md` - max open routes, retries, and escalation rules
- `.agents/milestone-budget.md` - active task, retry, and branch budget limits
- `.agents/events.jsonl` - append-only workflow event trace
- `.agents/state/*.jsonl` - structured state mirrors for routes, tasks, and findings
- `.agents/inbox/<role>.md` - per-role routed work queue
- `.agents/ownership/<role>.paths` - path ownership allowlist for each role
- `.agents/agent-config/<role>.yaml` - per-role required reads, allowed paths, and checks
- `.agents/skills/<role>.md` - role-specific capability, rules, and done criteria
- `.agents/memory/<role>.md` - durable project-specific lessons and preferences
- `.agents/memory-policy.md` - governance rules for durable memory
- `.agents/secrets-policy.md` - rules for credentials, tokens, and secret handling
- `.agents/schemas/*.md` - structured output formats for each role
- `.agents/validation-report.md` - validation results and findings
- `.agents/review-report.md` - reviewer findings
- `.agents/security-report.md` - security findings

## Core Rules

1. Read `.agents/project-target.md`, `.agents/brief.md`, `.agents/sop.md`, `.agents/roles.md`, and `.agents/task-board.md` before making changes.
2. Do not edit files owned by another agent unless the task board explicitly assigns that work.
3. Record cross-agent requests in `.agents/handoffs.md`.
4. Check your role inbox in `.agents/inbox/<role>.md` before starting work.
5. Read your role skill pack in `.agents/skills/<role>.md`.
6. Read your role memory in `.agents/memory/<role>.md`.
7. Use the relevant schema in `.agents/schemas/` for role outputs.
8. Follow `.agents/memory-policy.md` before adding durable memory.
9. Record major technical or product choices in `.agents/decisions.md`.
10. Do not start implementation until `.agents/definition-of-ready.md` is satisfied.
11. Do not mark a task done until `.agents/definition-of-done.md` is satisfied.
12. Run the relevant checks from `.agents/quality-gates.md` before handing off.
13. Run `scripts/check-ownership.sh <role>` before review/merge when code changed.
14. Run `scripts/check-route-budget.sh` before creating many routes.
15. Run `scripts/validate-structured-state.sh` before review/merge.
16. Run `scripts/check-stale-routes.sh` and escalate stale routes.
17. Run `scripts/check-secrets.sh` before review/merge.
18. Prefer small, reviewable branches or worktrees over broad edits in one checkout.
19. For new projects, send rough ideas to the orchestrator using `.agents/prompts/intake-orchestrator.md`; the orchestrator drafts `.agents/brief.md`.
20. For minimal prompting, route mid-workflow scope changes, feature changes, bugs, or status questions through the orchestrator prompt in `.agents/prompts/orchestrator.md`.

## Recommended Flow

1. Human gives rough idea to Orchestrator.
2. Orchestrator confirms `.agents/project-target.md`, interviews, drafts `.agents/brief.md`, and asks for approval.
3. CTO writes or updates `.agents/architecture.md` and `.agents/decisions.md`.
4. PM writes or updates `.agents/task-board.md`.
5. Human approves the architecture and task board.
6. Implementation agents work only on ready assigned tasks.
7. Reviewer, Security, and Validation agents check branches/worktrees.
8. Integration owner merges one branch at a time.
9. CTO performs final architecture review.
10. PM performs final acceptance review.

## Validation

Use `.agents/quality-gates.md` as the validation contract. If this repository later gains framework-specific commands, add them there and keep this file current.
