#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status=0

printf "== Secrets Check ==\n\n"

files="$({
  if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT" diff --name-only HEAD 2>/dev/null || true
    git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null || true
  else
    find "$ROOT" -type f | sed "s#^$ROOT/##"
  fi
} | sort -u)"

if [ -z "$files" ]; then
  printf "No files to scan.\n"
  exit 0
fi

while IFS= read -r file; do
  [ -z "$file" ] && continue
  case "$file" in
    .git/*|.agents/events.jsonl|*.png|*.jpg|*.jpeg|*.gif|*.pdf|*.zip) continue ;;
  esac
  path="$ROOT/$file"
  [ -f "$path" ] || continue
  if grep -IEn '(sk-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----|password[[:space:]]*=[[:space:]]*["'\''][^"'\'']+["'\'']|api[_-]?key[[:space:]]*=[[:space:]]*["'\''][^"'\'']+["'\''])' "$path" >/tmp/secret-scan.$$ 2>/dev/null; then
    printf "Potential secret in %s\n" "$file"
    sed -n '1,5p' /tmp/secret-scan.$$
    status=1
  fi
done <<< "$files"

rm -f /tmp/secret-scan.$$ 2>/dev/null || true

if [ "$status" -ne 0 ]; then
  printf "\nSecrets check failed. See .agents/secrets-policy.md.\n" >&2
  exit 1
fi

printf "Secrets check passed.\n"

