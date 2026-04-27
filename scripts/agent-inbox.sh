#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$#" -ne 1 ]; then
  printf "Usage: %s <role>\n" "$(basename "$0")" >&2
  printf "Example: %s orchestrator\n" "$(basename "$0")" >&2
  exit 1
fi

ROLE="$1"
INBOX="$ROOT/.agents/inbox/$ROLE.md"

if [ ! -f "$INBOX" ]; then
  printf "Unknown role inbox: %s\n" "$INBOX" >&2
  exit 1
fi

printf "== %s Inbox ==\n\n" "$ROLE"
awk '
  /^## / { title = $0; block = title "\n"; capture = 1; next }
  capture { block = block $0 "\n" }
  /^Status: queued$/ || /^Status: dispatched$/ || /^Status: in-progress$/ || /^Status: blocked$/ { relevant = 1 }
  /^## / && NR > 1 {
    if (relevant) print block
    relevant = 0
  }
  END {
    if (capture && relevant) print block
  }
' "$INBOX"
