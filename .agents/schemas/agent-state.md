# Agent State Schema

`.agents/state/agents.jsonl` stores one live telemetry record per role. Scripts update this file when roles launch, receive routes, claim work, complete work, block work, or are cancelled.

Required fields:

- `role` - canonical role key from `scripts/agent-roles.sh`
- `session` - tmux session name, if known
- `window` - tmux window name, normally the role key
- `pid_or_command` - process id or launched command string
- `process_status` - `starting`, `alive`, `dead`, or `unknown`
- `status` - `available`, `launching`, `dispatching`, `busy`, `blocked`, or `offline`
- `last_seen_at` - UTC timestamp
- `active_route` - active route id, or `none`
- `active_task` - active task id, or `none`
- `workdir` - role working directory
- `target_project` - active coding project target
- `branch_or_worktree` - active branch/worktree label, or `none`
- `capacity` - max active routes
- `blocked_reason` - current blocker text, empty if unblocked
- `recovery_owner` - canonical role that owns escalation
- `source` - script or process that last wrote the record
