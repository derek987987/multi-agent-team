#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="${1:-agent-team}"
if [ "$#" -gt 0 ]; then
  shift
fi

MODE="--dry-run"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [tmux-session] [--send|--dry-run]

Promotes the first ready PM task into a concrete route so the watcher can
dispatch it without a manual orchestrator step.
EOF
}

require_value() {
  local flag="$1"
  local value="${2:-}"
  if [ -z "$value" ]; then
    printf "%s requires a value.\n" "$flag" >&2
    exit 1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --send|--dry-run)
      MODE="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf "Unexpected argument: %s\n" "$1" >&2
      usage
      exit 1
      ;;
  esac
done

TASK_BOARD="$ROOT/agent-control/task-board.md"
HANDOFFS="$ROOT/agent-control/handoffs.md"
WORKFLOW_STATE="$ROOT/agent-control/workflow-state.md"
ROUTES_DIR="$ROOT/agent-control/routes"

next_route_id() {
  local max=0
  local file
  shopt -s nullglob
  for file in "$ROUTES_DIR"/R[0-9][0-9][0-9].md; do
    local base number
    base="$(basename "$file" .md)"
    number="${base#R}"
    case "$number" in
      ''|*[!0-9]*)
        continue
        ;;
    esac
    if [ "$((10#$number))" -gt "$max" ]; then
      max="$((10#$number))"
    fi
  done
  shopt -u nullglob
  printf "R%03d" $((max + 1))
}

task_records() {
  awk '
    function trim(s) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      return s
    }
    function clean(s) {
      gsub(/\t/, " ", s)
      gsub(/[[:space:]]+/, " ", s)
      return trim(s)
    }
    function append(target, value, sep) {
      value = clean(value)
      if (value == "") return target
      if (target == "") return value
      return target sep value
    }
    function flush() {
      if (task_id == "") return
      order[++count] = task_id
      title_by_id[task_id] = clean(title)
      owner_by_id[task_id] = clean(owner)
      status_by_id[task_id] = clean(status)
      priority_by_id[task_id] = clean(priority)
      depends_by_id[task_id] = clean(depends)
      branch_by_id[task_id] = clean(branch)
      files_by_id[task_id] = clean(files)
      objective_by_id[task_id] = clean(objective)
      acceptance_by_id[task_id] = clean(acceptance)
      validation_cmd_by_id[task_id] = clean(validation_cmd)
      validation_expected_by_id[task_id] = clean(validation_expected)
      handoffs_by_id[task_id] = clean(handoffs)
      notes_by_id[task_id] = clean(notes)
    }
    function reset() {
      task_id = title = owner = status = priority = depends = branch = files = objective = acceptance = validation_cmd = validation_expected = handoffs = notes = ""
      section = ""
    }
    BEGIN { reset() }
    /^### T[0-9]+/ {
      flush()
      reset()
      line = $0
      sub(/^### /, "", line)
      split(line, parts, " - ")
      task_id = parts[1]
      title = substr(line, length(task_id) + 4)
      next
    }
    /^Owner:/ { owner = substr($0, index($0, ":") + 1); next }
    /^Status:/ { status = substr($0, index($0, ":") + 1); next }
    /^Priority:/ { priority = substr($0, index($0, ":") + 1); next }
    /^Depends on:/ { depends = substr($0, index($0, ":") + 1); next }
    /^Branch \/ worktree:/ { branch = substr($0, index($0, ":") + 1); next }
    /^Files \/ modules owned:/ { section = "files"; next }
    /^Objective:/ { section = "objective"; next }
    /^Acceptance criteria:/ { section = "acceptance"; next }
    /^Validation:/ { section = "validation"; next }
    /^Handoffs:/ { section = "handoffs"; next }
    /^Notes:/ { section = "notes"; next }
    section == "files" && /^- / { files = append(files, substr($0, 3), "; "); next }
    section == "objective" && trim($0) != "" { objective = append(objective, $0, " "); next }
    section == "acceptance" && /^- / { acceptance = append(acceptance, substr($0, 3), "; "); next }
    section == "validation" && /^- Command:/ { validation_cmd = append(validation_cmd, substr($0, 12), " | "); next }
    section == "validation" && /^- Expected:/ { validation_expected = append(validation_expected, substr($0, 13), " | "); next }
    section == "handoffs" && /^- / { handoffs = append(handoffs, substr($0, 3), "; "); next }
    section == "notes" && trim($0) != "" { notes = append(notes, $0, " "); next }
    END {
      flush()
      for (i = 1; i <= count; i++) {
        id = order[i]
        if (status_by_id[id] != "pending") continue
        deps = depends_by_id[id]
        ready = 1
        if (deps != "" && deps != "none") {
          n = split(deps, dep_list, /,[[:space:]]*/)
          for (j = 1; j <= n; j++) {
            dep = dep_list[j]
            gsub(/[`[:space:]]/, "", dep)
            if (dep == "" || dep == "none") continue
            if (dep !~ /^T[0-9]+$/) continue
            if (status_by_id[dep] != "done") {
              ready = 0
              break
            }
          }
        }
        if (!ready) continue
        print id "\t" title_by_id[id] "\t" owner_by_id[id] "\t" priority_by_id[id] "\t" branch_by_id[id] "\t" files_by_id[id] "\t" objective_by_id[id] "\t" acceptance_by_id[id] "\t" validation_cmd_by_id[id] "\t" validation_expected_by_id[id] "\t" handoffs_by_id[id] "\t" notes_by_id[id] "\t" deps
        exit
      }
      exit 1
    }
  ' "$TASK_BOARD"
}

if [ ! -f "$TASK_BOARD" ]; then
  printf "Missing task board: %s\n" "$TASK_BOARD" >&2
  exit 1
fi

candidate=""
if candidate="$(task_records)"; then
  :
else
  printf "promote-ready-task-route: no ready task found\n"
  exit 0
fi

IFS=$'\t' read -r task_id title owner priority branch files objective acceptance validation_cmd validation_expected handoffs notes depends <<< "$candidate"

route_exists=0
if grep -R -qE "^Related task: ${task_id}([[:space:]]|$)" "$ROOT/agent-control/inbox" "$ROOT/agent-control/routes" "$WORKFLOW_STATE" 2>/dev/null; then
  route_exists=1
fi

if [ "$route_exists" -eq 1 ]; then
  printf "promote-ready-task-route: %s already has a route; skipping\n" "$task_id"
  exit 0
fi

route_id="$(next_route_id)"
instruction="Implement $task_id: $objective Acceptance criteria: $acceptance"
if [ -n "$handoffs" ] && [ "$handoffs" != "none" ]; then
  instruction="$instruction Handoffs: $handoffs"
fi
expected_output="Route report completed for $task_id. Update owned files in $files and leave the scaffold ready for $owner handoff."
validation="Command: ${validation_cmd:-See task board validation}
Expected: ${validation_expected:-Validation passes.}"
context="Promoted from PM task board entry $task_id and matching handoff packet."

if [ "$MODE" = "--dry-run" ]; then
  printf "promote-ready-task-route: would create %s for %s (%s)\n" "$route_id" "$task_id" "$owner"
  exit 0
fi

"$ROOT/scripts/route-agent.sh" "$route_id" "$owner" "$title" "$task_id" \
  --from orchestrator \
  --target-project "$(awk -F': ' '/^Path:/ { print $2; exit }' "$ROOT/agent-control/project-target.md" 2>/dev/null || printf '%s' "$ROOT")" \
  --worktree "$branch" \
  --files "$files" \
  --context "$context" \
  --priority "$priority" \
  --instruction "$instruction" \
  --expected-output "$expected_output" \
  --validation "$validation"

printf "promote-ready-task-route: created %s for %s (%s)\n" "$route_id" "$task_id" "$owner"
