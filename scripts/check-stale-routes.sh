#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUED_MINUTES="${QUEUED_MINUTES:-30}"
DISPATCHED_MINUTES="${DISPATCHED_MINUTES:-30}"
IN_PROGRESS_HOURS="${IN_PROGRESS_HOURS:-4}"
now="$(date -u +%s)"
status=0

parse_ts() {
  local ts="$1"
  if [ -z "$ts" ]; then
    printf "0"
    return
  fi
  if date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s >/dev/null 2>&1; then
    date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s
  elif date -d "$ts" +%s >/dev/null 2>&1; then
    date -d "$ts" +%s
  else
    printf "0"
  fi
}

printf "== Stale Route Check ==\n\n"

for inbox in "$ROOT"/.agents/inbox/*.md; do
  role="$(basename "$inbox" .md)"
  while IFS=$'\t' read -r route route_status created; do
    case "$route_status" in
      queued|dispatching|dispatched|in-progress)
        created_epoch="$(parse_ts "$created")"
        if [ "$created_epoch" = "0" ]; then
          printf "%s/%s missing or invalid Created timestamp\n" "$role" "$route"
          status=1
          continue
        fi
        age_seconds=$((now - created_epoch))
        case "$route_status" in
          queued)
            limit=$((QUEUED_MINUTES * 60))
            ;;
          dispatching|dispatched)
            limit=$((DISPATCHED_MINUTES * 60))
            ;;
          in-progress)
            limit=$((IN_PROGRESS_HOURS * 3600))
            ;;
        esac
        if [ "$age_seconds" -gt "$limit" ]; then
          printf "%s/%s stale: status=%s age_seconds=%s\n" "$role" "$route" "$route_status" "$age_seconds"
          status=1
        fi
        ;;
    esac
  done < <(awk '
    /^## R[0-9]+/ { if (route) print route "\t" status "\t" created; route=$2; status=""; created=""; created_next=0 }
    /^Status: / { status=$2 }
    /^Created:/ {
      created=$0
      sub(/^Created:[[:space:]]*/, "", created)
      if (created == "") { created_next=1 }
      next
    }
    created_next && $0 != "" { created=$0; created_next=0 }
    END { if (route) print route "\t" status "\t" created }
  ' "$inbox")
done

if [ "$status" -ne 0 ]; then
  printf "\nStale routes found. Run scripts/recover-stale-routes.sh --dry-run, then --apply when automatic recovery is appropriate.\n" >&2
  exit 1
fi

printf "No stale routes found.\n"
