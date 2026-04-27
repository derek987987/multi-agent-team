#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROLE="${1:-}"
TASK_ID="${2:-}"

if [ -z "$ROLE" ]; then
  printf "Usage: %s <role>\n" "$(basename "$0")" >&2
  printf "Example: %s frontend\n" "$(basename "$0")" >&2
  exit 1
fi

RULES="$ROOT/.agents/ownership/$ROLE.paths"
IGNORED="$ROOT/.agents/ownership/ignored-synced.paths"
if [ ! -f "$RULES" ]; then
  printf "Missing ownership rules: .agents/ownership/%s.paths\n" "$ROLE" >&2
  exit 1
fi

if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf "Ownership check requires a git repository.\n" >&2
  exit 1
fi

status=0
changed="$({
  git -C "$ROOT" diff --name-only HEAD 2>/dev/null || true
  git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null || true
} | sort -u)"

if [ -z "$changed" ]; then
  printf "No changed files to check.\n"
  exit 0
fi

printf "== Ownership Check: %s ==\n\n" "$ROLE"

tmp_rules="$(mktemp)"
cat "$RULES" > "$tmp_rules"

if [ -n "$TASK_ID" ]; then
  awk -v task="$TASK_ID" '
    /^### / { in_task = ($2 == task); section = ""; next }
    in_task && /^Files \/ modules owned:/ { section = "files"; next }
    in_task && /^[A-Za-z].*:/ { if ($0 !~ /^Files \/ modules owned:/) section = "" }
    in_task && section == "files" && /^- / { print substr($0, 3) }
  ' "$ROOT/.agents/task-board.md" >> "$tmp_rules"
fi

while IFS= read -r file; do
  [ -z "$file" ] && continue
  ignored=0
  if [ -f "$IGNORED" ]; then
    while IFS= read -r pattern; do
      case "$pattern" in
        ""|\#*) continue ;;
      esac
      case "$file" in
        $pattern) ignored=1 ;;
      esac
    done < "$IGNORED"
  fi
  if [ "$ignored" -eq 1 ]; then
    continue
  fi
  allowed=0
  while IFS= read -r pattern; do
    case "$pattern" in
      ""|\#*) continue ;;
    esac
    case "$file" in
      $pattern) allowed=1 ;;
    esac
  done < "$tmp_rules"
  if [ "$allowed" -eq 0 ]; then
    printf "Outside ownership: %s\n" "$file"
    status=1
  fi
done <<< "$changed"

if [ "$status" -ne 0 ]; then
  printf "\nOwnership check failed. Create a handoff or update task ownership before merge.\n" >&2
  exit 1
fi

rm -f "$tmp_rules"
printf "Ownership check passed.\n"
