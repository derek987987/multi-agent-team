# Workflow Upgrade Research

Research date: 2026-04-27

## Researched Patterns

- Agent memory and reflection patterns emphasize durable lessons, preferences, and failures that influence later agent behavior.
- Supervisor/orchestrator frameworks emphasize explicit state, routing, and handoff ownership.
- Production agent guidance emphasizes guardrails, human approval gates, tracing/observability, and structured outputs.
- Software delivery practice emphasizes definitions of ready/done, review separation, quality gates, and conflict escalation.

## Gaps Integrated

| Upgrade | Gap Found | Local Integration |
| --- | --- | --- |
| per-agent memory | skills alone do not preserve project lessons | `.agents/memory/<role>.md` |
| ready/done gates | tasks can start or finish with vague evidence | `.agents/definition-of-ready.md`, `.agents/definition-of-done.md` |
| reviewer/security roles | validation alone checks behavior but misses maintainability/security review | reviewer/security prompts, inboxes, reports, skill packs |
| quality gates | generic gates are too weak for role-specific work | role-specific sections in `.agents/quality-gates.md` |
| conflict protocol | handoffs do not define dispute resolution | `.agents/conflict-resolution.md` |
| command scripts | manual status checks are inconsistent | ready/done/quality scripts |
| structured outputs | free-form agent notes are hard to consume | `.agents/schemas/*.md` |

## Execution-Control Upgrade - 2026-04-27

Additional research patterns integrated:

- Handoff systems benefit from typed metadata and lifecycle status, so local routes now have a schema and lifecycle scripts.
- Guardrail systems distinguish input/output/tool boundaries, so local ownership checks and ready/done gates now act as file-based guardrails.
- Tracing systems record spans/events, so `.agents/events.jsonl` now provides an append-only route/state event trace.
- Coding-agent cloud workflows isolate work in separate environments, so worktree mode now pushes the shared control plane into each worktree.
- Subagent systems use tool/permission boundaries, so `.agents/ownership/<role>.paths` now defines path allowlists.

Files added or upgraded:

- `.agents/route-schema.md`
- `.agents/events.jsonl`
- `.agents/memory-policy.md`
- `.agents/ownership/<role>.paths`
- `scripts/log-event.sh`
- `scripts/sync-agent-state.sh`
- `scripts/claim-route.sh`
- `scripts/complete-route.sh`
- `scripts/cancel-route.sh`
- `scripts/dispatch-routes.sh`
- `scripts/check-ownership.sh`

## Reliability Upgrade - 2026-04-27

Additional gaps addressed after reviewing multi-agent handoff, guardrail, tracing, and subagent permission patterns:

- Worktree sync was changed from destructive `.agents` mirroring to policy-based control-plane sync that preserves local evidence files.
- Route dispatch is now idempotent by moving queued routes to `dispatched`.
- Route messages are sent to tmux as literal input instead of shell-interpolated strings.
- Route creation mirrors records into `.agents/state/routes.jsonl`.
- Event trace records now support `correlation_id`.
- Ownership checks now include untracked files and can add task-specific allowed paths from `.agents/task-board.md`.
- Memory validation is available through `scripts/check-memory.sh`.
- Route fan-out and delegation-loop risk is checked through `scripts/check-route-budget.sh`.
- Per-role agent configuration files were added under `.agents/agent-config/`.
- Structured JSONL mirrors were added under `.agents/state/`.

## Enforcement Upgrade - 2026-04-27

Additional enforcement added from multi-agent workflow review:

- `scripts/check-stale-routes.sh` detects routes that were queued, dispatched, or in progress too long.
- `scripts/check-agent-config.sh` validates role configs and checks allowed paths against ownership rules.
- `scripts/check-secrets.sh` scans changed/untracked files for common credential patterns.
- `scripts/check-milestone-budget.sh` enforces active task and route budgets.
- `.agents/secrets-policy.md` defines secret-handling rules.
- `.agents/milestone-budget.md` defines active task, branch, retry, and escalation budgets.
- `.agents/ownership/ignored-synced.paths` prevents synced control-plane files from producing false ownership failures in worktrees.

## Production Coding Company Upgrade - 2026-04-28

Sources checked:

- Anthropic engineering (`https://www.anthropic.com/engineering/multi-agent-research-system`): multi-agent systems benefit from orchestrator-worker specialization, parallel subagents, clear task descriptions, effort budgets, observability, evals, and filesystem artifacts for durable outputs.
- LangChain multi-agent docs (`https://docs.langchain.com/oss/python/langchain/multi-agent/index`): multi-agent patterns are useful when one agent has too many tools, when specialized context is needed, when work can be parallelized, or when sequential constraints need explicit handoffs.
- Microsoft AutoGen teams docs (`https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/tutorial/teams.html`): teams add value for complex work with diverse expertise but need extra scaffolding, termination/stop conditions, and steering.
- OpenAI Agents SDK tracing and guardrails docs (`https://openai.github.io/openai-agents-js/guides/tracing/`, `https://openai.github.io/openai-agents-python/guardrails/`): production agent systems need handoffs, guardrails, and tracing of agent/tool/handoff spans.
- CrewAI hierarchical process docs (`https://docs.crewai.com/en/learn/hierarchical-process`): manager-led delegation and result validation match a company-style operating model.

Gaps found in the local workflow:

- Missing Product role for user value, scope, non-goals, and acceptance-risk clarification.
- Missing Design role for user flows, UI states, accessibility, and frontend handoff quality.
- Missing Data role for schema, migration, seed, analytics, and query-contract ownership.
- Missing DevOps role for setup, CI, deployment, environments, observability, and release automation.
- Missing QA Automation role for durable regression tests, fixtures, smoke checks, and reproducible bug cases.
- Missing Docs role for developer docs, user docs, runbooks, and release notes.
- Role lists were duplicated in scripts, making future role additions brittle.

Local integration:

- Added `scripts/agent-roles.sh` as the central role registry.
- Added Product, Design, Data, DevOps, QA, and Docs prompts, skills, memory, inboxes, logs, configs, schemas, and ownership rules.
- Updated startup scripts to launch every role from the registry with Codex `--full-auto`.
- Updated worktree mode so project-editing specialists get role-specific worktrees.
- Updated routing matrix and quality gates so specialist review is part of production readiness.
- Updated existing skill packs with productivity defaults and cross-role routing rules.
