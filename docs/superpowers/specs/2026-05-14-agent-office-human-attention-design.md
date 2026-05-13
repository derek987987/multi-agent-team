# Agent Office Human Attention Notification Design

## Purpose

When an agent-team project reaches the point where the team needs the human's final attention, Agent Office should make that state visible without relying on macOS notifications or external services.

The visible signal is a `!` marker on the Orchestrator card/character. The Orchestrator remains the normal human-facing entrypoint, so the notification should point the user back to Orchestrator context instead of creating a second command path.

## Scope

In scope:
- Detect a final human-attention state from existing workflow files and route state.
- Record a durable, deduplicated notification in file-backed state.
- Surface active human-attention notifications in the Agent Office snapshot API.
- Render a visible `!` marker on the Orchestrator card when human attention is needed.
- Show notification details in the Orchestrator inspector so the user can see why attention is needed.

Out of scope:
- macOS notifications.
- Email, Slack, browser push, or other external delivery.
- Treating notification as human approval.
- Bypassing final ship/no-ship approval.

## Completion Semantics

The notification means:

> The agents believe the project is complete or ready for final human ship/no-ship review.

It does not mean the human has approved the project.

The first implementation should keep the check conservative. It can notify when:
- no active route is in `queued`, `dispatching`, `dispatched`, `acknowledged`, `in-progress`, or `blocked`;
- no task-board task is in `pending`, `in-progress`, `blocked`, or `ready-for-review`;
- Agent Office health has no `stuck` or `watch` items;
- `scripts/check-done.sh` passes;
- `agent-control/final-cto-review.md` and `agent-control/final-acceptance.md` exist and are non-placeholder enough to be meaningful.

If final acceptance artifacts are missing, the system should not show the final-complete notification. It may later support a separate "final acceptance routes needed" notice, but that is not part of the first slice.

## Data Model

Add a generated local state file:

`agent-control/state/notifications.jsonl`

Each record should be append-only JSONL with fields:
- `notification_id`: stable ID such as `project-complete-ready-for-human`
- `status`: `active`, `acknowledged`, or `dismissed`
- `severity`: `info`, `watch`, or `action`
- `target_role`: `orchestrator`
- `title`: short display title
- `message`: concise user-facing reason
- `source`: script or actor that wrote the record
- `evidence_refs`: comma-separated or JSON array of relevant files
- `created`: UTC timestamp
- `updated`: UTC timestamp

The active notification should be deduplicated by `notification_id`. Repeated watcher passes should not append endless identical active records.

## Workflow State

When the final-complete notification becomes active, update `agent-control/workflow-state.md` under `## Human Attention Needed` with the same concise message and evidence refs.

This keeps the dashboard and terminal source of truth aligned.

## Agent Office Behavior

The snapshot API should include a `notifications` array and a filtered human-attention summary.

The Orchestrator card should show a visible `!` marker when there is any active notification with:
- `target_role=orchestrator`
- `status=active`
- `severity=action` or `watch`

When the user selects Orchestrator, the inspector should show:
- notification title
- message
- evidence refs
- updated timestamp

The marker should disappear only after the notification is acknowledged/dismissed or the completion condition is no longer true and the implementation records a resolved state.

## Integration Point

Add a script such as:

`scripts/check-project-completion-notification.sh`

The route watcher and heartbeat should call it after stale/session recovery and route dispatch checks, because those steps can change the state that determines whether a project is really complete.

The script should support:
- `--dry-run`: report what would happen
- `--apply`: write notification state and workflow-state updates

## Testing

Add focused tests for:
- no notification when routes remain open;
- no notification when `check-done.sh` fails;
- active notification is written once when completion criteria pass;
- Agent Office snapshot includes active notifications;
- Orchestrator card markup/script supports the `!` marker.

Existing validators should still pass:
- `./scripts/validate-agent-workflow.sh`
- `./scripts/validate-route-state.sh`
- `./scripts/validate-structured-state.sh`
- `./scripts/check-secrets.sh`

## Risks

False positives are worse than a quiet dashboard. The first version should require final acceptance artifacts and clean done checks before presenting the project as ready for human attention.

False negatives are acceptable in the first slice if the user can still inspect status manually through Agent Office and tmux.
