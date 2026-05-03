#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUED_MINUTES="${QUEUED_MINUTES:-30}"
DISPATCHED_MINUTES="${DISPATCHED_MINUTES:-30}"
IN_PROGRESS_HOURS="${IN_PROGRESS_HOURS:-4}"
MAX_ROUTE_RETRIES="${MAX_ROUTE_RETRIES:-$(awk -F':[[:space:]]*' '/Max retries per route:/ { print $2; exit }' "$ROOT/.agents/route-budget.md" 2>/dev/null || true)}"
MAX_ROUTE_RETRIES="${MAX_ROUTE_RETRIES:-2}"
MODE="--dry-run"
SESSION=""

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [tmux-session] [--dry-run|--apply]

Find stale queued, dispatching, dispatched, and in-progress routes. With
--apply, routes inside retry budget are requeued with Attempt incremented.
Routes at or over retry budget are blocked with recovery evidence.
EOF
}

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

update_route_field() {
  local file="$1"
  local heading_prefix="$2"
  local route="$3"
  local field="$4"
  local value="$5"
  local tmp
  tmp="$(mktemp)"
  awk -v id="$route" -v prefix="$heading_prefix" -v field="$field" -v value="$value" '
    $0 ~ "^" prefix " " id "([[:space:]-]|$)" { in_route = 1; print; next }
    in_route && $0 ~ "^" prefix " " { in_route = 0 }
    in_route && $0 ~ "^" field ":" { print field ": " value; next }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

update_route_multiline_field() {
  local file="$1"
  local heading_prefix="$2"
  local route="$3"
  local field="$4"
  local value="$5"
  local tmp
  tmp="$(mktemp)"
  awk -v id="$route" -v prefix="$heading_prefix" -v field="$field" -v value="$value" '
    $0 ~ "^" prefix " " id "([[:space:]-]|$)" { in_route = 1; print; next }
    in_route && $0 ~ "^" prefix " " { in_route = 0 }
    in_route && $0 == field ":" { print; getline; print value; next }
    in_route && $0 ~ "^" field ":" { print field ": " value; next }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

update_workflow_status() {
  local route="$1"
  local status="$2"
  local tmp
  tmp="$(mktemp)"
  awk -v id="$route" -v status="$status" 'BEGIN { FS=OFS="|" } $2 ~ "^[[:space:]]*" id "[[:space:]]*$" { $4 = " " status " " } { print }' \
    "$ROOT/.agents/workflow-state.md" > "$tmp"
  mv "$tmp" "$ROOT/.agents/workflow-state.md"
}

update_report_field() {
  local report="$1"
  local field="$2"
  local value="$3"
  local tmp
  [ -f "$report" ] || return 0
  tmp="$(mktemp)"
  awk -v field="$field" -v value="$value" '$0 ~ "^" field ":" { print field ": " value; next } { print }' "$report" > "$tmp"
  mv "$tmp" "$report"
}

append_recovery_event() {
  local report="$1"
  local status="$2"
  local route="$3"
  local role="$4"
  local old_status="$5"
  local attempt="$6"
  local next_attempt="$7"
  local age_seconds="$8"
  local pane_tail="$9"
  [ -f "$report" ] || return 0
  {
    printf '\n### Recovery Event\n\n'
    printf 'Recovered at: %s\n' "$UPDATED"
    printf 'Recovered by: recover-stale-routes\n'
    printf 'Previous status: %s\n' "$old_status"
    printf 'Recovery status: %s\n' "$status"
    printf 'Owner: %s\n' "$role"
    printf 'Previous attempt: %s\n' "$attempt"
    printf 'Next attempt: %s\n' "$next_attempt"
    printf 'Age seconds: %s\n' "$age_seconds"
    if [ "$status" = "queued" ]; then
      printf 'Action: Requeued by recover-stale-routes\n'
    else
      printf 'Action: Retry budget exhausted\n'
    fi
    printf '\nPane evidence:\n\n```text\n%s\n```\n' "$pane_tail"
  } >> "$report"
}

capture_pane_tail() {
  local role="$1"
  if [ -n "$SESSION" ] && command -v tmux >/dev/null 2>&1 && tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux capture-pane -p -t "$SESSION:$role" -S -40 2>/dev/null || printf "No pane capture available for %s:%s" "$SESSION" "$role"
  else
    printf "No tmux session supplied."
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run|--apply)
      MODE="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      printf "Unexpected argument: %s\n" "$1" >&2
      usage
      exit 1
      ;;
    *)
      if [ -n "$SESSION" ]; then
        printf "Unexpected argument: %s\n" "$1" >&2
        usage
        exit 1
      fi
      SESSION="$1"
      shift
      ;;
  esac
done

case "$MAX_ROUTE_RETRIES" in
  ''|*[!0-9]*)
    MAX_ROUTE_RETRIES=2
    ;;
esac

now="$(date -u +%s)"
UPDATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
found=0

for inbox in "$ROOT"/.agents/inbox/*.md; do
  role="$(basename "$inbox" .md)"
  while IFS=$'\t' read -r route route_status created attempt report; do
    case "$route_status" in
      queued|dispatching|dispatched|in-progress)
        ;;
      *)
        continue
        ;;
    esac

    created_epoch="$(parse_ts "$created")"
    if [ "$created_epoch" = "0" ]; then
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

    if [ "$age_seconds" -le "$limit" ]; then
      continue
    fi

    found=1
    attempt="${attempt:-0}"
    case "$attempt" in
      ''|*[!0-9]*)
        attempt=0
        ;;
    esac
    report="${report:-.agents/routes/$route.md}"
    report_path="$ROOT/$report"
    pane_tail="$(capture_pane_tail "$role")"

    if [ "$attempt" -lt "$MAX_ROUTE_RETRIES" ]; then
      next_attempt=$((attempt + 1))
      if [ "$MODE" = "--dry-run" ]; then
        printf "Would recover stale route %s for %s: status=%s attempt=%s next_attempt=%s age_seconds=%s\n" \
          "$route" "$role" "$route_status" "$attempt" "$next_attempt" "$age_seconds"
        continue
      fi

      update_route_field "$inbox" "##" "$route" "Status" "queued"
      update_route_field "$inbox" "##" "$route" "Attempt" "$next_attempt"
      update_route_multiline_field "$inbox" "##" "$route" "Created" "$UPDATED"
      update_route_multiline_field "$inbox" "##" "$route" "Last updated" "$UPDATED"
      if grep -qE "^### $route([[:space:]-]|$)" "$ROOT/.agents/handoffs.md"; then
        update_route_field "$ROOT/.agents/handoffs.md" "###" "$route" "Status" "open"
      fi
      update_workflow_status "$route" "queued"
      update_report_field "$report_path" "Status" "queued"
      update_report_field "$report_path" "Attempt" "$next_attempt"
      update_report_field "$report_path" "Last updated" "$UPDATED"
      append_recovery_event "$report_path" "queued" "$route" "$role" "$route_status" "$attempt" "$next_attempt" "$age_seconds" "$pane_tail"
      "$ROOT/scripts/log-event.sh" route-recovered recover-stale-routes "Recovered stale route $route for $role" "attempt=$next_attempt age_seconds=$age_seconds" "$route"
      "$ROOT/scripts/update-agent-state.sh" "$role" --status available --active-route none --blocked-reason none
      printf '{"route_id":"%s","status":"queued","actor":"recover-stale-routes","attempt":%s,"previous_status":"%s","age_seconds":%s,"report":"%s","updated":"%s"}\n' \
        "$(json_escape "$route")" "$next_attempt" "$(json_escape "$route_status")" "$age_seconds" "$(json_escape "$report")" "$(json_escape "$UPDATED")" >> "$ROOT/.agents/state/routes.jsonl"
      printf "Recovered stale route %s for %s: attempt %s -> %s\n" "$route" "$role" "$attempt" "$next_attempt"
    else
      if [ "$MODE" = "--dry-run" ]; then
        printf "Would block stale route %s for %s: status=%s attempt=%s max=%s age_seconds=%s\n" \
          "$route" "$role" "$route_status" "$attempt" "$MAX_ROUTE_RETRIES" "$age_seconds"
        continue
      fi

      append_recovery_event "$report_path" "blocked" "$route" "$role" "$route_status" "$attempt" "$attempt" "$age_seconds" "$pane_tail"
      "$ROOT/scripts/block-route.sh" "$route" recover-stale-routes "Retry budget exhausted for stale route after attempt $attempt" --report "$report" >/dev/null
      printf "Blocked stale route %s for %s: retry budget exhausted at attempt %s\n" "$route" "$role" "$attempt"
    fi
  done < <(awk '
    /^## R[0-9]+/ {
      if (route) print route "\t" status "\t" created "\t" attempt "\t" report
      route=$2; status=""; created=""; attempt="0"; report=""; created_next=0
    }
    /^Status: / { status=$2 }
    /^Created:/ {
      created=$0
      sub(/^Created:[[:space:]]*/, "", created)
      if (created == "") { created_next=1 }
      next
    }
    created_next && $0 != "" { created=$0; created_next=0 }
    /^Attempt:/ { attempt=$2 }
    /^Completion report:/ { sub(/^Completion report:[[:space:]]*/, ""); report=$0 }
    END { if (route) print route "\t" status "\t" created "\t" attempt "\t" report }
  ' "$inbox")
done

if [ "$found" -eq 0 ]; then
  printf "No stale routes found for recovery.\n"
fi
