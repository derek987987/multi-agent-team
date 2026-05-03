#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status=0

printf "== Route State Validation ==\n\n"

valid_status() {
  case "$1" in
    draft|queued|dispatching|dispatched|acknowledged|in-progress|blocked|done|cancelled)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

for inbox in "$ROOT"/.agents/inbox/*.md; do
  role="$(basename "$inbox" .md)"
  while IFS=$'\t' read -r route route_status to_role report has_tbd; do
    [ -n "$route" ] || continue

    if ! valid_status "$route_status"; then
      printf "%s/%s invalid status: %s\n" "$role" "$route" "$route_status" >&2
      status=1
    fi

    if [ "$to_role" != "$role" ]; then
      printf "%s/%s To field mismatch: %s\n" "$role" "$route" "$to_role" >&2
      status=1
    fi

    if [ -n "$report" ] && [ ! -f "$ROOT/$report" ]; then
      printf "%s/%s missing route report: %s\n" "$role" "$route" "$report" >&2
      status=1
    fi

    case "$route_status" in
      draft|cancelled)
        ;;
      *)
        if [ "$has_tbd" = "yes" ]; then
          printf "%s/%s has TBD or draft placeholder text outside draft status\n" "$role" "$route" >&2
          status=1
        fi
        ;;
    esac

    if ! grep -qE "^[|][[:space:]]*$route[[:space:]]*[|]" "$ROOT/.agents/workflow-state.md"; then
      printf "%s/%s missing from workflow-state open routes table\n" "$role" "$route" >&2
      status=1
    fi
  done < <(awk '
    function emit() {
      if (route == "") return
      print route "\t" route_status "\t" to_role "\t" report "\t" has_tbd
    }
    /^## R[0-9]+/ {
      emit()
      route = $2
      route_status = ""
      to_role = ""
      report = ""
      has_tbd = "no"
      in_route = 1
      next
    }
    /^## / {
      emit()
      route = ""
      in_route = 0
      next
    }
    in_route && /^Status:/ { route_status = $2; next }
    in_route && /^To:/ { to_role = $2; next }
    in_route && /^Completion report:/ { sub(/^Completion report:[[:space:]]*/, ""); report = $0; next }
    in_route && ($0 == "TBD" || $0 == "- TBD" || $0 ~ /Draft route/) { has_tbd = "yes"; next }
    END { emit() }
  ' "$inbox")
done

if [ "$status" -ne 0 ]; then
  printf "\nRoute state validation failed.\n" >&2
  exit 1
fi

printf "Route state validation passed.\n"
