# Route Schema

Every route should include these fields in `.agents/inbox/<role>.md` and `.agents/handoffs.md`.

```md
## R000 - Short Title
Status: queued | dispatched | in-progress | blocked | done | cancelled
From:
To:
Related task:
Meeting ID:
Decision ID:
Created:

Instruction:

Expected output:

Validation / done criteria:

Response:
```

## Lifecycle

1. `scripts/route-agent.sh` creates a queued route.
2. `scripts/watch-routes.sh` normally runs in the control window and calls `scripts/dispatch-routes.sh` to mark it dispatched.
3. `scripts/claim-route.sh` marks it in-progress.
4. `scripts/complete-route.sh` marks it done.
5. `scripts/cancel-route.sh` marks it cancelled.

All lifecycle scripts append to `.agents/events.jsonl`.

`Meeting ID` and `Decision ID` may be empty for normal work. When a route comes from a cross-agent meeting, fill them so the future visual layer can connect discussion, decision, task, and execution evidence.
