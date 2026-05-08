# Company Registry

This directory is the functional source of truth for the coding company layer.
It is intentionally data-first so visual dashboards can be built later without
changing the agent workflow.

## Files

- `projects.jsonl` - known coding projects and active target changes.
- `agent-profiles.jsonl` - machine-readable role, skill, ownership, and status metadata.

## Rules

- Append new project facts instead of rewriting history when possible.
- Keep profiles aligned with `scripts/agent-roles.sh`, `.agents/skills/`, and `.agents/ownership/`.
- Treat this directory as dashboard input, not as a replacement for `.agents/*` planning files.
