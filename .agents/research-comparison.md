# Research Comparison

Research date: 2026-04-26

## Public Patterns Reviewed

### MetaGPT

Useful pattern:
- Standard operating procedures encoded into role-specific prompt sequences.
- Assembly-line style handoffs across product, architecture, project management, engineering, and QA roles.
- Intermediate artifacts are verified before downstream agents rely on them.

What this workflow adopts:
- `.agents/sop.md`
- explicit phase exit criteria
- durable decision records
- architecture before task execution

### ChatDev

Useful pattern:
- Software development divided into design, coding, testing, and documentation phases.
- Specialized agents communicate through structured phases rather than unbounded chat.
- Review and testing are separate from implementation.

What this workflow adopts:
- phase-based operation
- separate validation role
- handoff protocol

### AutoGen / CrewAI

Useful pattern:
- Conversable agents are useful, but production workflows need controlled interaction patterns.
- CrewAI's distinction between autonomous crews and precise flows maps well to local development: use agents for reasoning, use scripts/files/git for orchestration.

What this workflow adopts:
- deterministic tmux windows and scripts
- shared state files instead of purely conversational coordination
- explicit role goals and ownership

### GitHub Copilot Cloud Agent

Useful pattern:
- Task work happens on branches with logs and pull requests.
- Agents can research, plan, edit, run tests, and hand work back for review.
- Transparency comes from commits, logs, and reviewable diffs.

What this workflow adopts:
- worktree-first implementation mode
- branch/review/merge gates
- integration owner instead of direct self-merge

### OpenHands / SWE-agent

Useful pattern:
- Repository-level agent instructions reduce repeated context discovery.
- Coding agents need a practical interface for reading files, editing code, running commands, and validating results.
- Tests and command execution are part of the core loop, not a final decoration.

What this workflow adopts:
- root `AGENTS.md`
- `.agents/quality-gates.md`
- validation report format with commands and reproduction steps

## Main Differences From The Previous Local Workflow

Previous workflow:
- Had tmux windows and role prompts.
- Had basic shared files.
- Had optional worktree mode.
- Relied on the human to enforce sequencing and review discipline.

Improved workflow:
- Adds a root `AGENTS.md` so coding agents have repo-level instructions.
- Adds `.agents/sop.md` with phase entry/exit criteria.
- Adds `.agents/roles.md` with explicit ownership and restrictions.
- Adds `.agents/handoffs.md` so agents can request cross-role work without editing each other's files.
- Adds `.agents/quality-gates.md` so validation is command-driven.
- Upgrades prompts to require SOP, handoffs, validation gates, and branch/worktree discipline.
- Adds GitHub issue and PR templates for cloud/remote agent workflows.
- Adds workflow helper scripts for status, validation, and task creation.

## Practical Recommendation

Use the local tmux workflow for active supervision and fast iteration. Use GitHub issue/PR style artifacts when you want reviewable asynchronous work, cloud agents, or a durable team audit trail.

## Orchestrator Update - 2026-04-27

After adding the orchestrator role, the workflow now more closely matches supervisor-style multi-agent systems.

Additional public patterns reflected:

- Supervisor/group-chat manager: a central orchestrator chooses routes and coordinates role turns.
- Hierarchical manager: a manager receives the human goal, plans/delegates work, and checks completion.
- Swarm handoffs: work moves between specialized agents through explicit handoff state.
- Mixture-of-agents: orchestrator dispatches work to specialized agents and synthesizes outputs.

Added locally:

- `.agents/workflow-state.md` for current phase, active request, routes, blockers, and human attention.
- `.agents/routing-matrix.md` for consistent routing decisions.
- `.agents/inbox/<role>.md` for per-agent routed work.
- `scripts/route-agent.sh` to create a route in the inbox, handoff log, and workflow state.
- `scripts/agent-inbox.sh` to show a role's active queue.
- `.agents/orchestrator-review.md` to document the gap analysis.
