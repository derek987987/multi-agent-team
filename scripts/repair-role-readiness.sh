#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="${1:-agent-team}"
if [ "$#" -gt 0 ]; then
  shift
fi

QUIET=0
STATE_FILE="$ROOT/agent-control/state/agents.jsonl"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [tmux-session] [--quiet]

Repairs stale startup telemetry for roles whose panes already emitted
ROLE_READY <role> but whose structured state still says launching/blocked.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --quiet)
      QUIET=1
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

if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

if ! command -v tmux >/dev/null 2>&1; then
  [ "$QUIET" -eq 1 ] || printf "repair-role-readiness: tmux unavailable; skipped.\n" >&2
  exit 0
fi

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  [ "$QUIET" -eq 1 ] || printf "repair-role-readiness: tmux session not found: %s\n" "$SESSION" >&2
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  [ "$QUIET" -eq 1 ] || printf "repair-role-readiness: jq unavailable; skipped.\n" >&2
  exit 0
fi

candidate_output="$(
  jq -r '
    select((.active_route // "none") == "none")
    | ((.status // "") | ascii_downcase) as $status
    | ((.blocked_reason // "") | ascii_downcase) as $reason
    | select(
        $status == "launching"
        or (
          $status == "blocked"
          and ($reason | test("startup|readiness|role_ready|transport fallback|no role_ready marker"))
        )
      )
    | .role
  ' "$STATE_FILE" 2>/dev/null
)"

if [ -z "$candidate_output" ]; then
  exit 0
fi

repaired=()
pending=()
while IFS= read -r role; do
  [ -n "$role" ] || continue
  if "$ROOT/scripts/wait-for-agent-sessions.sh" "$SESSION" \
    --timeout 0 \
    --interval 1 \
    --roles "$role" \
    --quiet >/dev/null 2>&1; then
    repaired+=("$role")
  else
    pending+=("$role")
  fi
done <<< "$candidate_output"

if [ "$QUIET" -eq 1 ]; then
  exit 0
fi

if [ "${#repaired[@]}" -gt 0 ]; then
  printf "repair-role-readiness: repaired ready markers for: %s\n" "${repaired[*]}"
fi
if [ "${#pending[@]}" -gt 0 ]; then
  printf "repair-role-readiness: still waiting for: %s\n" "${pending[*]}"
fi
