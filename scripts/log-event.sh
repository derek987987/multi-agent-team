#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVENTS="$ROOT/.agents/events.jsonl"

if [ "$#" -lt 3 ]; then
  printf "Usage: %s <type> <actor> <summary> [details] [correlation-id]\n" "$(basename "$0")" >&2
  exit 1
fi

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

type="$(json_escape "$1")"
actor="$(json_escape "$2")"
summary="$(json_escape "$3")"
details="$(json_escape "${4:-}")"
correlation_id="$(json_escape "${5:-}")"
timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p "$(dirname "$EVENTS")"
printf '{"timestamp":"%s","type":"%s","actor":"%s","summary":"%s","details":"%s","correlation_id":"%s"}\n' \
  "$timestamp" "$type" "$actor" "$summary" "$details" "$correlation_id" >> "$EVENTS"
