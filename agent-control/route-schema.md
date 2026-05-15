# Route Schema

Every route should include these fields in `agent-control/inbox/<role>.md`, `agent-control/handoffs.md`, `agent-control/state/routes.jsonl`, and the per-route report under `agent-control/routes/R000.md`.

```md
## R000 - Short Title
Status: draft | queued | dispatching | dispatched | acknowledged | in-progress | blocked | done | cancelled
From:
To:
Priority:
Related task:
Meeting ID:
Decision ID:
Created:
Last updated:
Attempt:
Route depth:
Target project:
Worktree or branch:
Files / modules:
Context refs:
Output schema:
Risk flags:
Human approval required:
Review required:
Approval ref:
Review ref:
Completion report:

Instruction:

Expected output:

Validation / done criteria:

Response:
```

Non-draft routes must not contain `TBD` in `Instruction`, `Expected output`, or `Validation / done criteria`.

## Lifecycle

1. `scripts/route-agent.sh` creates a route envelope and queued route. It requires `--instruction`, `--expected-output`, and `--validation` unless `--draft` is used. Use `--from <actor>` when the route originates outside Orchestrator, for example `--from human-ui` from Agent Office. It also mirrors the route into `agent-control/state/workflow.sqlite3` through `scripts/route-db.sh`.
2. `scripts/watch-routes.sh` normally runs in the control window, applies agent-session recovery, applies stale-route recovery, promotes the first ready PM task with `scripts/promote-ready-task-route.sh`, and then calls `scripts/dispatch-routes.sh`.
3. `scripts/heartbeat-routes.sh` can run a heartbeat-style pass over the structured queue, runs agent-session and stale-route recovery by default, promotes the first ready PM task, and delegates dispatch. Use `--no-recover-stale`, `AGENT_TEAM_AUTO_RECOVER_AGENTS=0`, or `AGENT_TEAM_AUTO_RECOVER_STALE=0` only for diagnostic scans that must not mutate recovery state.
4. `scripts/monitor-agent-sessions.sh` detects role-level recovery needs before route dispatch. It repairs readiness telemetry drift, asks context-pressured live agents to checkpoint into shared files, and relaunches failed/dead/missing role panes only after `scripts/checkpoint-agent-context.sh` writes a recovery packet.
5. `scripts/dispatch-routes.sh` first confirms the target role pane has emitted `ROLE_READY <role>` or has a matching persistent readiness marker in `agent-control/state/role-ready/`. If the role is still launching, the route stays `queued` for the next watcher pass. Once ready, dispatch marks `queued -> dispatching -> dispatched`, clears stale prompt text, sends a bounded tmux notification, then briefly watches for the target role to claim the route. If tmux delivery itself fails, the route is blocked with pane evidence. If delivery succeeds but the role does not claim before the acknowledgement timeout, the route remains `dispatched` and stale-route recovery owns retry/block decisions.
6. `scripts/claim-route.sh` validates the actor matches the route target, atomically claims the route in SQLite, and marks it `in-progress`.
7. `scripts/complete-route.sh` validates the actor, requires `--report agent-control/routes/R000.md`, enforces any approval/review refs, and marks it `done`.
8. `scripts/block-route.sh` marks the route `blocked` with a reason and route report note.
9. `scripts/cancel-route.sh` marks it `cancelled`.
10. `scripts/record-route-run.sh` records model, token, cost, exit-code, and summary metadata in the SQLite `route_runs` table and route report.
11. `scripts/route-status.sh R000` reads the route report first and prints owner, status, evidence, output refs, and next action.
12. `scripts/recover-stale-routes.sh --apply` requeues stale active routes and recoverable communication blockers inside retry budget, then blocks routes after retry budget is exhausted. In-progress routes whose pane output shows Codex transport/session failure use `AGENT_TEAM_FAILED_SESSION_MINUTES` before recovery, so a failed role session does not stop the whole team until the broad in-progress timeout expires. Blocked routes caused by dispatch infrastructure such as missing tmux sessions or delivery timeouts use `AGENT_TEAM_BLOCKED_COMMUNICATION_MINUTES`.

All lifecycle scripts append to `agent-control/events.jsonl` and mirror route status into `agent-control/state/workflow.sqlite3`. Route creation updates the owning PM task to `in-progress`, and route completion updates the owning task to `done`, so later dependencies can be promoted automatically.

## Gate Refs

- `Human approval required: yes` means completion must include `--approval-ref <approval-id>`, and that approval must exist in `agent-control/approvals.jsonl` or `agent-control/state/approvals.jsonl` with status `approved` or `accepted-risk`.
- `Review required: <role>` means completion must include `--review-ref <route-id>`, and that review route must already be `done`.
- `Approval ref` and `Review ref` are written back to the route report when completion succeeds.

`Meeting ID` and `Decision ID` may be empty for normal work. When a route comes from a cross-agent meeting, fill them so the future visual layer can connect discussion, decision, task, and execution evidence.

## Route Reports

Each route gets a durable report at `agent-control/routes/R000.md`. The tmux prompt is only a notification; the report is the canonical handoff packet and completion evidence.

Required route report fields:

- route metadata
- source context refs
- instruction
- expected output
- validation / done criteria
- dispatch evidence
- completion summary or blocked reason
- output refs produced by completion
- recovery events with pane evidence when a stale route is requeued or blocked
- next owner when work cannot finish in the current role
