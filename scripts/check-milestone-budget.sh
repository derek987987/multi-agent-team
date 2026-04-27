#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_BOARD="$ROOT/.agents/task-board.md"
MAX_ACTIVE_PER_ROLE="${MAX_ACTIVE_PER_ROLE:-3}"
status=0

printf "== Milestone Budget Check ==\n\n"

while read -r owner count; do
  [ -z "$owner" ] && continue
  printf "%s active tasks: %s / %s\n" "$owner" "$count" "$MAX_ACTIVE_PER_ROLE"
  if [ "$count" -gt "$MAX_ACTIVE_PER_ROLE" ]; then
    status=1
  fi
done < <(awk '
  /^Owner:/ { owner=$0; sub(/^Owner:[[:space:]]*/, "", owner) }
  /^Status: / {
    status=$0; sub(/^Status:[[:space:]]*/, "", status)
    if (status == "pending" || status == "in-progress" || status == "ready-for-review") count[owner]++
  }
  END { for (owner in count) print owner, count[owner] }
' "$TASK_BOARD")

"$ROOT/scripts/check-route-budget.sh"

if [ "$status" -ne 0 ]; then
  printf "Milestone budget exceeded. See .agents/milestone-budget.md.\n" >&2
  exit 1
fi

printf "Milestone budget check passed.\n"
