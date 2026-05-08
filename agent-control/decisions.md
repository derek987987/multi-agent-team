# Decisions

Record architecture and product decisions here.

## Template

### Decision 001 - Title
Date:
Owner:

Decision:

Reason:

Impact:

### Decision 001 - Generated SQLite Route Runtime Mirror
Date: 2026-05-05T17:09:52Z
Owner: CTO

Decision:
Add `agent-control/state/workflow.sqlite3` as a generated local runtime mirror for route lifecycle state, atomic claims, completion gate references, and route run metadata. Markdown route reports and JSONL ledgers remain the durable human-readable source of truth.

Reason:
The file-backed workflow needs stronger runtime semantics for route claiming, stale-route recovery, approval/review gate checks, and cost/run tracking without replacing the existing scriptable markdown and JSONL control plane.

Impact:
Route lifecycle scripts must keep SQLite, JSONL, and route reports aligned. The SQLite file is ignored by git, reset with scaffold state, and validated through `scripts/route-db.sh check`, `scripts/validate-structured-state.sh`, and `tests/test-runtime-priorities.sh`.

### Decision 002 - Start Agent Office By Default
Date: 2026-05-05T17:27:38Z
Owner: DevOps

Decision:
Start Agent Office automatically in a dedicated tmux `office` window whenever `scripts/start-agent-team.sh` or `scripts/start-agent-team-worktrees.sh` creates a new team session.

Reason:
The preferred operator flow is to create a project team, immediately see the visual workflow state, and then prompt the Orchestrator through intake until the brief is approved. Making Agent Office part of `--start` removes a repeated manual command without changing the file-backed routing model.

Impact:
The `server` window remains reserved for target-project dev servers and logs. Agent Office uses port `8765` by default and can be moved with `AGENT_OFFICE_PORT=<port>` before startup.
