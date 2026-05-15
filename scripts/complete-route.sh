#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

if [ "$#" -lt 1 ]; then
  printf "Usage: %s <route-id> [actor] [summary] --report <route-report> [--output-ref <path> ...]\n" "$(basename "$0")" >&2
  exit 1
fi

ROUTE_ID="$1"
shift
ACTOR="unknown"
SUMMARY="Completed route $ROUTE_ID"
REPORT=""
OUTPUT_REFS=()
APPROVAL_REF=""
REVIEW_REF=""
UPDATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [ "$#" -gt 0 ] && [ "${1:-}" != "--report" ]; then
  ACTOR="$1"
  shift
fi

if [ "$#" -gt 0 ] && [ "${1:-}" != "--report" ]; then
  SUMMARY="$1"
  shift
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --report)
      if [ -z "${2:-}" ]; then
        printf '%s\n' "--report requires a value." >&2
        exit 1
      fi
      REPORT="$2"
      shift 2
      ;;
    --output-ref)
      if [ -z "${2:-}" ]; then
        printf '%s\n' "--output-ref requires a value." >&2
        exit 1
      fi
      OUTPUT_REFS+=("$2")
      shift 2
      ;;
    --approval-ref)
      if [ -z "${2:-}" ]; then
        printf '%s\n' "--approval-ref requires a value." >&2
        exit 1
      fi
      APPROVAL_REF="$2"
      shift 2
      ;;
    --review-ref)
      if [ -z "${2:-}" ]; then
        printf '%s\n' "--review-ref requires a value." >&2
        exit 1
      fi
      REVIEW_REF="$2"
      shift 2
      ;;
    *)
      printf "Unexpected argument: %s\n" "$1" >&2
      printf "Usage: %s <route-id> [actor] [summary] --report <route-report> [--output-ref <path> ...]\n" "$(basename "$0")" >&2
      exit 1
      ;;
  esac
done

if [ -z "$REPORT" ]; then
  printf "Completing a route requires --report <route-report>.\n" >&2
  exit 1
fi

case "$REPORT" in
  /*) report_path="$REPORT" ;;
  *) report_path="$ROOT/$REPORT" ;;
esac

if [ ! -f "$report_path" ]; then
  printf "Route report not found: %s\n" "$REPORT" >&2
  exit 1
fi

update_status() {
  local file="$1"
  local heading_prefix="$2"
  local status="$3"
  local tmp
  tmp="$(mktemp)"
  awk -v id="$ROUTE_ID" -v prefix="$heading_prefix" -v status="$status" '
    $0 ~ "^" prefix " " id "([[:space:]-]|$)" { in_route = 1; print; next }
    in_route && $0 ~ "^" prefix " " { in_route = 0 }
    in_route && /^Status:/ { print "Status: " status; next }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

route_field() {
  local field="$1"
  local value=""
  if [ -f "$report_path" ]; then
    value="$(awk -F':[[:space:]]*' -v field="$field" '$1 == field { print $2; exit }' "$report_path")"
  fi
  if [ -z "$value" ] && [ -n "$route_file" ]; then
    value="$(awk -F':[[:space:]]*' -v id="$ROUTE_ID" -v field="$field" '
      /^## / { in_route = ($2 == id) }
      in_route && $1 == field { print $2; exit }
    ' "$route_file")"
  fi
  printf "%s" "$value"
}

approval_is_recorded() {
  local approval_ref="$1"
  awk -v id="$approval_ref" '
    index($0, "\"approval_id\":\"" id "\"") && ($0 ~ /"status":"approved"/ || $0 ~ /"status":"accepted-risk"/) { found=1 }
    END { exit found ? 0 : 1 }
  ' "$ROOT/agent-control/approvals.jsonl" "$ROOT/agent-control/state/approvals.jsonl" 2>/dev/null
}

route_done_status() {
  local route_ref="$1"
  local status=""
  status="$("$ROOT/scripts/route-db.sh" route-status "$route_ref" 2>/dev/null | tail -n 1 || true)"
  if [ -z "$status" ]; then
    status="$(awk -v id="$route_ref" '
      /^## / { in_route = ($2 == id) }
      in_route && /^Status:/ { print $2; exit }
    ' "$ROOT"/agent-control/inbox/*.md 2>/dev/null || true)"
  fi
  printf "%s" "$status"
}

found=0
route_file=""
route_role=""
route_status=""
for inbox in "$ROOT"/agent-control/inbox/*.md; do
  if grep -qE "^## $ROUTE_ID([[:space:]-]|$)" "$inbox"; then
    route_file="$inbox"
    route_role="$(basename "$inbox" .md)"
    route_status="$(awk -v id="$ROUTE_ID" '
      /^## / { in_route = ($2 == id) }
      in_route && /^Status:/ { print $2; exit }
    ' "$inbox")"
    found=1
  fi
done

if [ "$found" -eq 0 ]; then
  printf "Route not found in any inbox: %s\n" "$ROUTE_ID" >&2
  exit 1
fi

if [ "$ACTOR" != "$route_role" ]; then
  printf "Route %s is assigned to %s, not %s\n" "$ROUTE_ID" "$route_role" "$ACTOR" >&2
  exit 1
fi

case "$route_status" in
  in-progress)
    ;;
  *)
    printf "Route %s cannot be completed from status %s\n" "$ROUTE_ID" "${route_status:-unknown}" >&2
    exit 1
    ;;
esac

approval_required="$(route_field "Human approval required")"
if [ "$approval_required" = "yes" ]; then
  if [ -z "$APPROVAL_REF" ]; then
    printf "Route %s requires human approval; pass --approval-ref <approval-id>.\n" "$ROUTE_ID" >&2
    exit 1
  fi
  if ! approval_is_recorded "$APPROVAL_REF"; then
    printf "Approval ref is not approved or accepted-risk: %s\n" "$APPROVAL_REF" >&2
    exit 1
  fi
fi

review_required="$(route_field "Review required")"
if [ -n "$review_required" ] && [ "$review_required" != "no" ]; then
  if [ -z "$REVIEW_REF" ]; then
    printf "Route %s requires review by %s; pass --review-ref <done-review-route-id>.\n" "$ROUTE_ID" "$review_required" >&2
    exit 1
  fi
  review_status="$(route_done_status "$REVIEW_REF")"
  if [ "$review_status" != "done" ]; then
    printf "Review ref is not done: %s status=%s\n" "$REVIEW_REF" "${review_status:-unknown}" >&2
    exit 1
  fi
fi

update_status "$route_file" "##" "done"

update_response() {
  local file="$1"
  local heading_prefix="$2"
  local tmp
  tmp="$(mktemp)"
  awk -v id="$ROUTE_ID" -v prefix="$heading_prefix" -v report="$REPORT" '
    $0 ~ "^" prefix " " id "([[:space:]-]|$)" { in_route = 1; response_done = 0; print; next }
    in_route && $0 ~ "^" prefix " " { in_route = 0 }
    in_route && /^Response:/ && !response_done { print "Response:"; print "See " report; response_done = 1; next }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

update_task_status() {
  local task_id="$1"
  local status="$2"
  local tmp
  [ -n "$task_id" ] || return 0
  [ -f "$ROOT/agent-control/task-board.md" ] || return 0
  tmp="$(mktemp)"
  awk -v id="$task_id" -v status="$status" '
    /^### T[0-9]+/ { in_task = ($2 == id); print; next }
    in_task && /^Status:/ { print "Status: " status; next }
    { print }
  ' "$ROOT/agent-control/task-board.md" > "$tmp"
  mv "$tmp" "$ROOT/agent-control/task-board.md"
}

update_response "$route_file" "##"

related_task="$(awk -v id="$ROUTE_ID" '
  /^## / { in_route = ($2 == id) }
  in_route && /^Related task:/ { sub(/^Related task:[[:space:]]*/, ""); print; exit }
' "$route_file")"
if [ -n "$related_task" ] && [ "$related_task" != "none" ]; then
  update_task_status "$related_task" "done"
fi

if grep -qE "^### $ROUTE_ID([[:space:]-]|$)" "$ROOT/agent-control/handoffs.md"; then
  update_status "$ROOT/agent-control/handoffs.md" "###" "done"
  update_response "$ROOT/agent-control/handoffs.md" "###"
fi

tmp="$(mktemp)"
awk -v id="$ROUTE_ID" 'BEGIN { FS=OFS="|" } $2 ~ "^[[:space:]]*" id "[[:space:]]*$" { $4 = " done " } { print }' \
  "$ROOT/agent-control/workflow-state.md" > "$tmp"
mv "$tmp" "$ROOT/agent-control/workflow-state.md"

tmp="$(mktemp)"
awk -v status="Status: done" -v updated="Last updated: $UPDATED" '
  /^Status:/ && !status_done { print status; status_done=1; next }
  /^Last updated:/ && !updated_done { print updated; updated_done=1; next }
  { print }
' "$report_path" > "$tmp"
mv "$tmp" "$report_path"

if [ -n "$APPROVAL_REF" ] || [ -n "$REVIEW_REF" ]; then
  tmp="$(mktemp)"
  awk -v approval_ref="$APPROVAL_REF" -v review_ref="$REVIEW_REF" '
    /^Approval ref:/ && approval_ref != "" { print "Approval ref: " approval_ref; next }
    /^Review ref:/ && review_ref != "" { print "Review ref: " review_ref; next }
    { print }
  ' "$report_path" > "$tmp"
  mv "$tmp" "$report_path"
fi

cat >> "$report_path" <<REPORT

### Completion Event

Completed at: $UPDATED
Completed by: $ACTOR
Completion summary: $SUMMARY
REPORT

if [ "${#OUTPUT_REFS[@]}" -gt 0 ]; then
  {
    printf '\nOutput refs:\n'
    for output_ref in "${OUTPUT_REFS[@]}"; do
      printf -- '- %s\n' "$output_ref"
    done
  } >> "$report_path"
fi

"$ROOT/scripts/log-event.sh" route-completed "$ACTOR" "$SUMMARY" "" "$ROUTE_ID"
"$ROOT/scripts/update-agent-state.sh" "$ACTOR" --status available --active-route none --blocked-reason none
output_refs_json="$(printf '%s' "${OUTPUT_REFS[*]:-}" | sed 's/ /,/g')"
"$ROOT/scripts/route-db.sh" update-status "$ROUTE_ID" done \
  --actor "$ACTOR" \
  --note "$SUMMARY" \
  --approval-ref "$APPROVAL_REF" \
  --review-ref "$REVIEW_REF" \
  --output-refs "$output_refs_json" \
  --updated "$UPDATED" >/dev/null
printf '{"route_id":"%s","status":"done","actor":"%s","summary":"%s","report":"%s","output_refs":"%s","updated":"%s"}\n' \
  "$(json_escape "$ROUTE_ID")" "$(json_escape "$ACTOR")" "$(json_escape "$SUMMARY")" "$(json_escape "$REPORT")" "$(json_escape "$output_refs_json")" "$(json_escape "$UPDATED")" >> "$ROOT/agent-control/state/routes.jsonl"
printf "Completed route %s\n" "$ROUTE_ID"
