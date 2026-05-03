#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf "== Agent Workflow Status ==\n\n"

printf "Repository: %s\n\n" "$ROOT"

printf "== Company Functional Layer ==\n"
if [ -x "$ROOT/scripts/company-status.sh" ]; then
  "$ROOT/scripts/company-status.sh" | sed -n '1,40p'
else
  printf "Missing scripts/company-status.sh\n"
fi
printf "\n"

printf "== Workflow State ==\n"
if [ -f "$ROOT/.agents/workflow-state.md" ]; then
  sed -n '1,80p' "$ROOT/.agents/workflow-state.md"
else
  printf "Missing .agents/workflow-state.md\n"
fi
printf "\n"

if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf "== Git Status ==\n"
  git -C "$ROOT" status --short
  printf "\n== Branch ==\n"
  git -C "$ROOT" branch --show-current
  printf "\n"
else
  printf "== Git Status ==\n"
  printf "Not a git repository yet.\n\n"
fi

printf "== Task Status Counts ==\n"
if [ -f "$ROOT/.agents/task-board.md" ]; then
  for status in pending in-progress blocked ready-for-review done; do
    count="$(grep -cE "^Status: $status$" "$ROOT/.agents/task-board.md" || true)"
    printf "%s: %s\n" "$status" "$count"
  done
else
  printf "Missing .agents/task-board.md\n"
fi

printf "\n== Open Handoffs ==\n"
if [ -f "$ROOT/.agents/handoffs.md" ]; then
  awk '
    /^### H[0-9]+/ { title = $0; title_line = NR }
    /^Status: open$/ { printf "%s:%s\n%d:%s\n", title_line, title, NR, $0; found = 1 }
    END { if (!found) print "None" }
  ' "$ROOT/.agents/handoffs.md"
else
  printf "Missing .agents/handoffs.md\n"
fi

printf "\n== Validation Summary ==\n"
if [ -f "$ROOT/.agents/validation-report.md" ]; then
  sed -n '1,80p' "$ROOT/.agents/validation-report.md"
else
  printf "Missing .agents/validation-report.md\n"
fi

printf "\n== Review Summary ==\n"
if [ -f "$ROOT/.agents/review-report.md" ]; then
  sed -n '1,60p' "$ROOT/.agents/review-report.md"
else
  printf "Missing .agents/review-report.md\n"
fi

printf "\n== Security Summary ==\n"
if [ -f "$ROOT/.agents/security-report.md" ]; then
  sed -n '1,60p' "$ROOT/.agents/security-report.md"
else
  printf "Missing .agents/security-report.md\n"
fi
