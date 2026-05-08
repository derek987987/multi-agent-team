# Orchestrator Workflow Review

Review date: 2026-04-27

## Summary

The workflow now follows a supervisor-style pattern: the human can prompt the orchestrator, and the orchestrator routes work through shared state, inboxes, tasks, handoffs, decisions, and validation gates.

## Research Notes

Public orchestration patterns reviewed:

- AutoGen group chat: agents can communicate dynamically, and a group chat manager can decide the next speaker.
- Microsoft Agent Framework group chat: uses a star topology with an orchestrator in the middle and supports round-robin, prompt-based, or custom speaker selection.
- AutoGen mixture-of-agents: an orchestrator receives the user task, dispatches work to workers, collects results, and aggregates the final output.
- CrewAI hierarchical process: a manager agent plans, delegates, validates, and assesses completion.
- LangGraph swarm: agents use handoff tools and shared state; the system tracks the active agent and passes state updates between agents.

## Gaps Found

| Gap | Risk | Improvement Added |
| --- | --- | --- |
| Orchestrator had no explicit workflow state | routes and phase status could drift | added `agent-control/workflow-state.md` |
| Routing rules lived only in prose | orchestrator could route inconsistently | added `agent-control/routing-matrix.md` |
| Handoffs were centralized but not per-agent | agents had to scan the whole handoff file | added `agent-control/inbox/<role>.md` files |
| No helper to create route entries | manual route formatting was error-prone | added `scripts/route-agent.sh` |
| No helper to inspect one role's work queue | each agent had to inspect several docs manually | added `scripts/agent-inbox.sh` |
| Status helper did not show workflow state | human could not quickly see the control-plane snapshot | updated `scripts/agent-status.sh` |
| Orchestrator prompt did not require queue/state updates | cascade could be incomplete | updated orchestrator prompt |

## Remaining Limitation

This is still a local tmux/file-based workflow, not a true agent runtime. The orchestrator does not automatically execute other agents unless you add a wrapper around your specific agent CLI. The safer baseline is file-based routing plus optional tmux nudges.

## Recommendation

Use the orchestrator as the single human interface. Require it to update:

1. `agent-control/workflow-state.md`
2. relevant `agent-control/inbox/<role>.md`
3. `agent-control/handoffs.md` when cross-role work is needed
4. `agent-control/task-board.md` for executable work
5. `agent-control/decisions.md` for material product or technical choices

