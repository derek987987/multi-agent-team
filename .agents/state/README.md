# Structured State

These files provide machine-readable mirrors of the Markdown workflow.

Markdown remains the human-readable source for now, but scripts should prefer structured state when available.

## Files

- `routes.jsonl` - route lifecycle records
- `tasks.jsonl` - task records
- `findings.jsonl` - validation/review/security findings

## JSONL Rule

One JSON object per line. Append new facts instead of rewriting history where practical.

