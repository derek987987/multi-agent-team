#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CONFIG_FILE="${CODEX_CONFIG_FILE:-$CODEX_HOME_DIR/config.toml}"
LOCK_DIR=""

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") <project-dir> [project-dir ...]

Marks local project directories as trusted in the Codex config so auto-started
tmux role sessions do not stop on first-run workspace trust prompts.

Environment:
  CODEX_HOME         Override the Codex home directory. Default: \$HOME/.codex
  CODEX_CONFIG_FILE  Override the exact config.toml path, useful for tests.
EOF
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

json_escape_for_toml_header() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

resolve_path() {
  local path="$1"
  if [ -d "$path" ]; then
    (cd "$path" && pwd -P)
  else
    case "$path" in
      /*) printf '%s\n' "$path" ;;
      *) printf '%s/%s\n' "$(pwd -P)" "$path" ;;
    esac
  fi
}

acquire_lock() {
  local attempts=0
  LOCK_DIR="$CONFIG_FILE.lock"
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 50 ]; then
      printf "Timed out waiting for Codex config lock: %s\n" "$LOCK_DIR" >&2
      exit 1
    fi
    sleep 0.1
  done
  trap 'rm -rf "$LOCK_DIR"' EXIT
}

ensure_config() {
  mkdir -p "$(dirname "$CONFIG_FILE")"
  if [ ! -f "$CONFIG_FILE" ]; then
    umask 077
    : > "$CONFIG_FILE"
  fi
}

ensure_trusted() {
  local path="$1"
  local escaped
  local header
  local tmp

  escaped="$(json_escape_for_toml_header "$path")"
  header="[projects.\"$escaped\"]"

  if grep -Fxq "$header" "$CONFIG_FILE"; then
    tmp="$(mktemp)"
    awk -v header="$header" '
      $0 == header {
        in_section = 1
        saw_trust = 0
        print
        next
      }
      in_section && /^\[/ {
        if (!saw_trust) {
          print "trust_level = \"trusted\""
        }
        in_section = 0
      }
      in_section && /^[[:space:]]*trust_level[[:space:]]*=/ {
        print "trust_level = \"trusted\""
        saw_trust = 1
        next
      }
      { print }
      END {
        if (in_section && !saw_trust) {
          print "trust_level = \"trusted\""
        }
      }
    ' "$CONFIG_FILE" > "$tmp"
    mv "$tmp" "$CONFIG_FILE"
  else
    {
      if [ -s "$CONFIG_FILE" ]; then
        printf '\n'
      fi
      printf '%s\n' "$header"
      printf 'trust_level = "trusted"\n'
    } >> "$CONFIG_FILE"
  fi

  printf "Trusted Codex project: %s\n" "$path"
}

ensure_config
acquire_lock

for input_path in "$@"; do
  [ -n "$input_path" ] || continue
  ensure_trusted "$(resolve_path "$input_path")"
done
