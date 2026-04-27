#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_BOARD="$ROOT/.agents/task-board.md"

printf "== Definition Of Ready Check ==\n\n"

if [ ! -f "$TASK_BOARD" ]; then
  printf "Missing .agents/task-board.md\n" >&2
  exit 1
fi

if ! grep -qE "^Status: pending$|^Status: in-progress$|^Status: ready-for-review$" "$TASK_BOARD"; then
  printf "No active implementation tasks found.\n"
  printf "\nReady check passed at scaffold level.\n"
  exit 0
fi

printf "Active tasks found. Review against .agents/definition-of-ready.md.\n"

if ! awk '
  function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
  function reset() {
    task = ""; active = 0; owner = ""; priority = ""; branch = ""; objective = "";
    files = 0; acceptance = 0; command = ""; expected = ""; handoffs = 0;
  }
  function check() {
    if (!task || !active) return
    if (owner == "") { print task ": missing Owner"; missing = 1 }
    if (priority == "") { print task ": missing Priority"; missing = 1 }
    if (branch == "") { print task ": missing Branch / worktree"; missing = 1 }
    if (!files) { print task ": missing Files / modules owned entries"; missing = 1 }
    if (objective == "") { print task ": missing Objective"; missing = 1 }
    if (!acceptance) { print task ": missing Acceptance criteria entries"; missing = 1 }
    if (command == "") { print task ": missing Validation command"; missing = 1 }
    if (expected == "") { print task ": missing Validation expected result"; missing = 1 }
    if (!handoffs) { print task ": missing Handoffs entry"; missing = 1 }
  }
  BEGIN { reset(); section = "" }
  /^### T[0-9]+/ { check(); reset(); task = $0; next }
  /^Status: / { status = trim(substr($0, 9)); active = (status == "pending" || status == "in-progress" || status == "ready-for-review"); next }
  /^Owner: / { owner = trim(substr($0, 8)); next }
  /^Priority: / { priority = trim(substr($0, 11)); next }
  /^Branch \/ worktree: / { branch = trim(substr($0, 20)); next }
  /^Objective:/ { section = "objective"; next }
  /^Files \/ modules owned:/ { section = "files"; next }
  /^Acceptance criteria:/ { section = "acceptance"; next }
  /^Validation:/ { section = "validation"; next }
  /^Handoffs:/ { section = "handoffs"; next }
  /^Notes:/ { section = ""; next }
  section == "objective" && trim($0) != "" { objective = objective " " trim($0); next }
  section == "files" && /^- / && trim(substr($0, 3)) != "" { files = 1; next }
  section == "acceptance" && /^- / && trim(substr($0, 3)) != "" { acceptance = 1; next }
  section == "validation" && /^- Command: / { command = trim(substr($0, 12)); next }
  section == "validation" && /^- Expected: / { expected = trim(substr($0, 13)); next }
  section == "handoffs" && /^- / && trim(substr($0, 3)) != "" { handoffs = 1; next }
  END { check(); exit missing ? 1 : 0 }
' "$TASK_BOARD"; then
  printf "\nReady check failed. See .agents/definition-of-ready.md.\n" >&2
  exit 1
fi

printf "\nReady check passed at scaffold level.\n"
