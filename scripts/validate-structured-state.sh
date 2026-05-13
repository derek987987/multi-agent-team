#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status=0

printf "== Structured State Check ==\n\n"

check_jsonl() {
  local file="$1"
  local label="${file#$ROOT/}"
  if [ ! -f "$file" ]; then
    printf "Missing %s\n" "$label" >&2
    status=1
    return
  fi
  if [ ! -s "$file" ]; then
    printf "%s is empty; ok for scaffold.\n" "$label"
    return
  fi
  if command -v jq >/dev/null 2>&1; then
    if ! jq -c . "$file" >/dev/null; then
      printf "%s contains invalid JSONL\n" "$label" >&2
      status=1
    else
      printf "%s valid\n" "$label"
    fi
  else
    while IFS= read -r line; do
      case "$line" in
        \{*\}) : ;;
        *) printf "%s has a non-object line: %s\n" "$label" "$line" >&2; status=1 ;;
      esac
    done < "$file"
  fi
}

check_jsonl "$ROOT/agent-control/events.jsonl"
check_jsonl "$ROOT/agent-control/company/projects.jsonl"
check_jsonl "$ROOT/agent-control/company/agent-profiles.jsonl"
check_jsonl "$ROOT/agent-control/media/manifest.jsonl"
check_jsonl "$ROOT/agent-control/approvals.jsonl"
check_jsonl "$ROOT/agent-control/state/projects.jsonl"
check_jsonl "$ROOT/agent-control/state/agents.jsonl"
check_jsonl "$ROOT/agent-control/state/routes.jsonl"
check_jsonl "$ROOT/agent-control/state/tasks.jsonl"
check_jsonl "$ROOT/agent-control/state/findings.jsonl"
check_jsonl "$ROOT/agent-control/state/meetings.jsonl"
check_jsonl "$ROOT/agent-control/state/media.jsonl"
check_jsonl "$ROOT/agent-control/state/approvals.jsonl"
check_jsonl "$ROOT/agent-control/state/notifications.jsonl"

if [ -f "$ROOT/agent-control/state/workflow.sqlite3" ]; then
  if ! "$ROOT/scripts/route-db.sh" check; then
    status=1
  fi
else
  printf "agent-control/state/workflow.sqlite3 not initialized; ok for scaffold.\n"
fi

exit "$status"
