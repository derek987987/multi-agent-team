# Structured State

These files provide machine-readable mirrors of the Markdown workflow.

Markdown remains the human-readable source for now, but scripts should prefer structured state when available.

## Files

- `projects.jsonl` - project target and company registry records
- `routes.jsonl` - route lifecycle records
- `tasks.jsonl` - task records
- `findings.jsonl` - validation/review/security findings
- `meetings.jsonl` - meeting lifecycle records
- `media.jsonl` - media attachment records
- `approvals.jsonl` - approval and risk acceptance records

## JSONL Rule

One JSON object per line. Append new facts instead of rewriting history where practical.
