# Structured State

These files provide machine-readable mirrors of the Markdown workflow.

Markdown remains the human-readable source for now, but scripts should prefer structured state when available.

## Files

- `projects.jsonl` - project target and company registry records
- `agents.jsonl` - live role telemetry records
- `routes.jsonl` - route lifecycle records
- `tasks.jsonl` - task records
- `findings.jsonl` - validation/review/security findings
- `meetings.jsonl` - meeting lifecycle records
- `media.jsonl` - media attachment records
- `approvals.jsonl` - approval and risk acceptance records
- `workflow.sqlite3` - generated SQLite runtime mirror for routes, route events, route runs, and task rows
- `agent-recovery/` - generated role-session checkpoints and compact/relaunch request markers used to preserve context during recovery

## JSONL Rule

One JSON object per line. Append new facts instead of rewriting history where practical.

## SQLite Rule

`workflow.sqlite3` is generated local runtime state and is not committed. Use
`scripts/route-db.sh check` or `scripts/validate-structured-state.sh` to verify
it. Markdown route reports and JSONL ledgers remain the durable human-readable
contract; SQLite provides atomic claim/update semantics and compact runtime
queries.
