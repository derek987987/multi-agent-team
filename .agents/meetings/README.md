# Meetings

Meeting files capture cross-agent discussions before they become tasks or routes.
They are the functional layer behind the future visual meeting room.

## Lifecycle

1. `scripts/create-meeting.sh M001 "Title" orchestrator product cto`
2. Agents add notes, decisions, and open questions to `.agents/meetings/M001.md`.
3. `scripts/close-meeting.sh M001 "Decision summary" "Action items"`
4. Orchestrator or PM converts action items into task-board entries and routes.

## Rules

- Meeting files are not a chat transcript dump. Keep decisions and action items concise.
- Every route created from a meeting should include `Meeting ID`.
- Every durable decision created from a meeting should include `Decision ID` when available.
