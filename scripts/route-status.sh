#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$#" -ne 1 ]; then
  printf "Usage: %s <route-id>\n" "$(basename "$0")" >&2
  exit 1
fi

ROUTE_ID="$1"
route_file=""
route_role=""
title=""
status=""
report=""

field_from_file() {
  local file="$1"
  local field="$2"
  awk -F':[[:space:]]*' -v field="$field" '$1 == field { print $2; exit }' "$file"
}

section_from_file() {
  local file="$1"
  local heading="$2"
  awk -v heading="$heading" '
    $0 == heading { in_section=1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$file" | sed '/^[[:space:]]*$/d'
}

for inbox in "$ROOT"/.agents/inbox/*.md; do
  if grep -qE "^## $ROUTE_ID([[:space:]-]|$)" "$inbox"; then
    route_file="$inbox"
    route_role="$(basename "$inbox" .md)"
    title="$(awk -v id="$ROUTE_ID" '$0 ~ "^## " id "([[:space:]-]|$)" { sub("^## " id "[[:space:]]*-?[[:space:]]*", ""); print; exit }' "$inbox")"
    status="$(awk -v id="$ROUTE_ID" '
      /^## / { in_route = ($2 == id) }
      in_route && /^Status:/ { print $2; exit }
    ' "$inbox")"
    report="$(awk -v id="$ROUTE_ID" '
      /^## / { in_route = ($2 == id) }
      in_route && /^Completion report:/ { sub(/^Completion report:[[:space:]]*/, ""); print; exit }
    ' "$inbox")"
    break
  fi
done

report="${report:-.agents/routes/$ROUTE_ID.md}"
report_path="$ROOT/$report"

if [ -z "$route_file" ] && [ ! -f "$report_path" ]; then
  printf "Route not found: %s\n" "$ROUTE_ID" >&2
  exit 1
fi

if [ -f "$report_path" ]; then
  title="${title:-$(sed -n '1s/^# '"$ROUTE_ID"'[[:space:]]*-[[:space:]]*//p' "$report_path")}"
  status="${status:-$(field_from_file "$report_path" "Status")}"
  route_role="${route_role:-$(field_from_file "$report_path" "To")}"
fi

status="${status:-unknown}"
route_role="${route_role:-unknown}"
title="${title:-unknown}"

case "$status" in
  draft)
    next_action="fill route fields before dispatch"
    ;;
  queued)
    next_action="dispatch route to $route_role"
    ;;
  dispatching|dispatched)
    next_action="wait for $route_role to claim route"
    ;;
  acknowledged|in-progress)
    next_action="wait for $route_role to complete or block"
    ;;
  blocked)
    next_action="resolve blocker or re-route to next owner"
    ;;
  done)
    next_action="no action; route is done"
    ;;
  cancelled)
    next_action="no action; route is cancelled"
    ;;
  *)
    next_action="inspect route report and workflow state"
    ;;
esac

printf "Route: %s\n" "$ROUTE_ID"
printf "Title: %s\n" "$title"
printf "Status: %s\n" "$status"
printf "Owner: %s\n" "$route_role"
printf "Report: %s\n" "$report"

if [ -f "$report_path" ]; then
  last_updated="$(field_from_file "$report_path" "Last updated")"
  priority="$(field_from_file "$report_path" "Priority")"
  related_task="$(field_from_file "$report_path" "Related task")"
  target_project="$(field_from_file "$report_path" "Target project")"
  completion_summary="$(awk -F':[[:space:]]*' '/^Completion summary:/ { print $2; exit }' "$report_path")"

  printf "Priority: %s\n" "${priority:-unknown}"
  printf "Related task: %s\n" "${related_task:-none}"
  printf "Target project: %s\n" "${target_project:-unknown}"
  printf "Last updated: %s\n" "${last_updated:-unknown}"

  if [ -n "$completion_summary" ]; then
    printf "Completion summary: %s\n" "$completion_summary"
  fi

  output_refs="$(section_from_file "$report_path" "Output refs:")"
  if [ -n "$output_refs" ]; then
    printf "Output refs:\n%s\n" "$output_refs"
  fi
else
  printf "Report exists: no\n"
fi

printf "Next action: %s\n" "$next_action"
