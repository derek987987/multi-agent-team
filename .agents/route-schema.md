# Route Schema

Every route should include these fields in `.agents/inbox/<role>.md`, `.agents/handoffs.md`, `.agents/state/routes.jsonl`, and the per-route report under `.agents/routes/R000.md`.

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
Completion report:

Instruction:

Expected output:

Validation / done criteria:

Response:
```

Non-draft routes must not contain `TBD` in `Instruction`, `Expected output`, or `Validation / done criteria`.

## Lifecycle

1. `scripts/route-agent.sh` creates a route envelope and queued route. It requires `--instruction`, `--expected-output`, and `--validation` unless `--draft` is used.
2. `scripts/watch-routes.sh` normally runs in the control window and calls `scripts/dispatch-routes.sh`.
3. `scripts/dispatch-routes.sh` marks `queued -> dispatching -> dispatched`, sends a tmux notification, then waits for acknowledgement by watching for the target role to claim the route.
4. `scripts/claim-route.sh` validates the actor matches the route target and marks it `in-progress`.
5. `scripts/complete-route.sh` validates the actor, requires `--report .agents/routes/R000.md`, and marks it `done`.
6. `scripts/block-route.sh` marks the route `blocked` with a reason and route report note.
7. `scripts/cancel-route.sh` marks it `cancelled`.
8. `scripts/route-status.sh R000` reads the route report first and prints owner, status, evidence, output refs, and next action.
9. `scripts/recover-stale-routes.sh --apply` requeues stale active routes inside retry budget and blocks stale routes after retry budget is exhausted.

All lifecycle scripts append to `.agents/events.jsonl`.

`Meeting ID` and `Decision ID` may be empty for normal work. When a route comes from a cross-agent meeting, fill them so the future visual layer can connect discussion, decision, task, and execution evidence.

## Route Reports

Each route gets a durable report at `.agents/routes/R000.md`. The tmux prompt is only a notification; the report is the canonical handoff packet and completion evidence.

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
