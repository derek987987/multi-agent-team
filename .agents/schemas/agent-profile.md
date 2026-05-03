# Agent Profile Schema

`agent-profiles.jsonl` records one JSON object per role.

Required fields:

- `role` - stable role key from `scripts/agent-roles.sh`
- `display_name` - human-readable name
- `skills` - array of role capabilities
- `profile_path` - skill pack path
- `memory_path` - role memory path
- `inbox_path` - role inbox path
- `ownership_path` - role ownership file
- `status` - `available`, `busy`, `blocked`, or `offline`
- `load` - `low`, `normal`, or `high`

Optional fields:

- `current_project`
- `current_route`
- `last_active`
- `notes`

Live process and routing telemetry belongs in `.agents/state/agents.jsonl` and follows `.agents/schemas/agent-state.md`.
