#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") <route-id> <actor> [options]

Options:
  --run-id <id>
  --status <status>
  --started-at <utc>
  --ended-at <utc>
  --duration-seconds <n>
  --model <model>
  --input-tokens <n>
  --output-tokens <n>
  --cost-cents <n>
  --exit-code <n>
  --summary <text>
EOF
}

if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

ROUTE_ID="$1"
ACTOR="$2"
shift 2

RUN_ID=""
STATUS="succeeded"
STARTED_AT=""
ENDED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
DURATION_SECONDS="0"
MODEL=""
INPUT_TOKENS="0"
OUTPUT_TOKENS="0"
COST_CENTS="0"
EXIT_CODE="0"
SUMMARY=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --run-id) RUN_ID="${2:-}"; shift 2 ;;
    --status) STATUS="${2:-}"; shift 2 ;;
    --started-at) STARTED_AT="${2:-}"; shift 2 ;;
    --ended-at) ENDED_AT="${2:-}"; shift 2 ;;
    --duration-seconds) DURATION_SECONDS="${2:-0}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --input-tokens) INPUT_TOKENS="${2:-0}"; shift 2 ;;
    --output-tokens) OUTPUT_TOKENS="${2:-0}"; shift 2 ;;
    --cost-cents) COST_CENTS="${2:-0}"; shift 2 ;;
    --exit-code) EXIT_CODE="${2:-0}"; shift 2 ;;
    --summary) SUMMARY="${2:-}"; shift 2 ;;
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

STARTED_AT="${STARTED_AT:-$ENDED_AT}"
RUN_ID="${RUN_ID:-RUN-$(date -u +"%Y%m%d%H%M%S")-$$}"

"$ROOT/scripts/route-db.sh" record-run "$ROUTE_ID" "$ACTOR" \
  --run-id "$RUN_ID" \
  --status "$STATUS" \
  --started-at "$STARTED_AT" \
  --ended-at "$ENDED_AT" \
  --duration-seconds "$DURATION_SECONDS" \
  --model "$MODEL" \
  --input-tokens "$INPUT_TOKENS" \
  --output-tokens "$OUTPUT_TOKENS" \
  --cost-cents "$COST_CENTS" \
  --exit-code "$EXIT_CODE" \
  --summary "$SUMMARY" >/dev/null

report="agent-control/routes/$ROUTE_ID.md"
report_path="$ROOT/$report"
if [ -f "$report_path" ]; then
  {
    printf '\n### Run Metadata\n\n'
    printf 'Run ID: %s\n' "$RUN_ID"
    printf 'Recorded at: %s\n' "$ENDED_AT"
    printf 'Actor: %s\n' "$ACTOR"
    printf 'Status: %s\n' "$STATUS"
    printf 'Model: %s\n' "${MODEL:-unknown}"
    printf 'Input tokens: %s\n' "$INPUT_TOKENS"
    printf 'Output tokens: %s\n' "$OUTPUT_TOKENS"
    printf 'Cost cents: %s\n' "$COST_CENTS"
    printf 'Exit code: %s\n' "$EXIT_CODE"
    printf 'Summary: %s\n' "${SUMMARY:-none}"
  } >> "$report_path"
fi

"$ROOT/scripts/log-event.sh" route-run-recorded "$ACTOR" "Recorded run metadata for $ROUTE_ID" "$SUMMARY" "$ROUTE_ID"
printf "Recorded route run %s for %s\n" "$RUN_ID" "$ROUTE_ID"
