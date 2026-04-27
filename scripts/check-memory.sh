#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status=0

printf "== Memory Policy Check ==\n\n"

for file in "$ROOT"/.agents/memory/*.md; do
  role="$(basename "$file")"
  if grep -qE "^### [0-9]{4}-[0-9]{2}-[0-9]{2} - " "$file"; then
    awk -v file="$role" '
      /^### [0-9]{4}-[0-9]{2}-[0-9]{2} - / {
        if (entry && (!source || !confidence || !scope || !content)) {
          printf "%s: previous memory entry missing Source/Confidence/Scope/Content\n", file
          bad = 1
        }
        entry = 1; source = confidence = scope = content = 0
        next
      }
      entry && /^Source:/ { source = 1 }
      entry && /^Confidence: (low|medium|high)$/ { confidence = 1 }
      entry && /^Scope:/ { scope = 1 }
      entry && /^Content:/ { content = 1 }
      END {
        if (entry && (!source || !confidence || !scope || !content)) {
          printf "%s: memory entry missing Source/Confidence/Scope/Content\n", file
          bad = 1
        }
        exit bad ? 1 : 0
      }
    ' "$file" || status=1
  fi
done

if [ "$status" -ne 0 ]; then
  printf "\nMemory check failed. See .agents/memory-policy.md.\n" >&2
  exit 1
fi

printf "Memory check passed.\n"

