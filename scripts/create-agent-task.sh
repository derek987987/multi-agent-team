#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_BOARD="$ROOT/.agents/task-board.md"

if [ "$#" -lt 3 ]; then
  printf "Usage: %s <task-id> <owner> <title>\n" "$(basename "$0")" >&2
  printf "Example: %s T004 frontend-agent \"Build login form\"\n" "$(basename "$0")" >&2
  exit 1
fi

TASK_ID="$1"
OWNER="$2"
TITLE="$3"

cat >> "$TASK_BOARD" <<TASK

### $TASK_ID - $TITLE
Owner: $OWNER
Status: pending
Priority: P2
Depends on:
Branch / worktree:
Files / modules owned:

Objective:

Acceptance criteria:
- TBD

Validation:
- Command:
- Expected:

Handoffs:
- none

Notes:
TASK

printf "Added %s to %s\n" "$TASK_ID" "$TASK_BOARD"

