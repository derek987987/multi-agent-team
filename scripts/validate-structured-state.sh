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

check_jsonl "$ROOT/.agents/events.jsonl"
check_jsonl "$ROOT/.agents/company/projects.jsonl"
check_jsonl "$ROOT/.agents/company/agent-profiles.jsonl"
check_jsonl "$ROOT/.agents/media/manifest.jsonl"
check_jsonl "$ROOT/.agents/approvals.jsonl"
check_jsonl "$ROOT/.agents/state/projects.jsonl"
check_jsonl "$ROOT/.agents/state/routes.jsonl"
check_jsonl "$ROOT/.agents/state/tasks.jsonl"
check_jsonl "$ROOT/.agents/state/findings.jsonl"
check_jsonl "$ROOT/.agents/state/meetings.jsonl"
check_jsonl "$ROOT/.agents/state/media.jsonl"
check_jsonl "$ROOT/.agents/state/approvals.jsonl"

exit "$status"
