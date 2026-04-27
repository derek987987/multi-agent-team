#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROLE="${1:-}"

if [ -z "$ROLE" ]; then
  printf "Usage: %s <role>\n" "$(basename "$0")" >&2
  exit 1
fi

CONFIG="$ROOT/.agents/agent-config/$ROLE.yaml"
OWNERSHIP="$ROOT/.agents/ownership/$ROLE.paths"

if [ ! -f "$CONFIG" ]; then
  printf "Missing agent config: .agents/agent-config/%s.yaml\n" "$ROLE" >&2
  exit 1
fi

status=0

printf "== Agent Config Check: %s ==\n\n" "$ROLE"

if ! grep -qE "^role:[[:space:]]*$ROLE$" "$CONFIG"; then
  printf "Config role does not match %s\n" "$ROLE"
  status=1
fi

for section in required_reads allowed_paths required_checks; do
  if ! grep -qE "^$section:" "$CONFIG"; then
    printf "Missing section: %s\n" "$section"
    status=1
  fi
done

awk '
  /^required_reads:/ { section="reads"; next }
  /^allowed_paths:/ { section="paths"; next }
  /^required_checks:/ { section="checks"; next }
  /^[a-zA-Z_]+:/ { section="" }
  section=="reads" && /^[[:space:]]+- / { print substr($0, index($0, "- ") + 2) }
' "$CONFIG" | while IFS= read -r path; do
  [ -z "$path" ] && continue
  case "$path" in
    *"*"*) continue ;;
  esac
  if [ ! -e "$ROOT/$path" ]; then
    printf "Required read missing: %s\n" "$path"
    exit 2
  fi
done || status=1

if [ -f "$OWNERSHIP" ]; then
  config_paths="$(mktemp)"
  awk '
    /^allowed_paths:/ { section="paths"; next }
    /^[a-zA-Z_]+:/ { section="" }
    section=="paths" && /^[[:space:]]+- / { print substr($0, index($0, "- ") + 2) }
  ' "$CONFIG" | sort -u > "$config_paths"
  ownership_paths="$(mktemp)"
  grep -vE '^[[:space:]]*(#|$)' "$OWNERSHIP" | sort -u > "$ownership_paths"
  if ! diff -q "$config_paths" "$ownership_paths" >/dev/null 2>&1; then
    printf "Allowed paths differ from ownership file for %s\n" "$ROLE"
    status=1
  fi
  rm -f "$config_paths" "$ownership_paths"
fi

if [ "$status" -ne 0 ]; then
  printf "\nAgent config check failed.\n" >&2
  exit 1
fi

printf "Agent config check passed.\n"

