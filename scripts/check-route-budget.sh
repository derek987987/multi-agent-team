#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/.agents/workflow-state.md"
MAX_OPEN="${MAX_OPEN_ROUTES:-12}"

open_count="$(awk -F'|' '/^\| R[0-9]+/ { gsub(/^[ \t]+|[ \t]+$/, "", $4); if ($4 != "done" && $4 != "cancelled") count++ } END { print count + 0 }' "$STATE")"

printf "== Route Budget Check ==\n\n"
printf "Open routes: %s / %s\n" "$open_count" "$MAX_OPEN"

if [ "$open_count" -gt "$MAX_OPEN" ]; then
  printf "Route budget exceeded. See .agents/route-budget.md.\n" >&2
  exit 1
fi

printf "Route budget check passed.\n"

