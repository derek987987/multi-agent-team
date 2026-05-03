#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$#" -lt 1 ]; then
  printf "Usage: %s <project-directory> [mode]\n" "$(basename "$0")" >&2
  printf "Example: %s /Users/hay/Documents/my-app existing-project\n" "$(basename "$0")" >&2
  exit 1
fi

TARGET="$1"
MODE="${2:-existing-project}"

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"
NAME="$(basename "$TARGET")"
UPDATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

json_escape() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

cat > "$ROOT/.agents/project-target.md" <<EOF
# Project Target

This file tells the agent team which coding project directory it should work on.

## Current Target

Path: $TARGET
Name: $NAME
Mode: $MODE
Last updated: $UPDATED

## Rules

- The agent-team home is $ROOT.
- The coding project target can be any local directory.
- The Orchestrator must confirm this file before starting intake, architecture, planning, implementation, validation, review, security, or integration.
- Agents should treat the target directory as the codebase and this directory as the workflow control plane.
- If the target changes during an active workflow, existing routes should be completed, cancelled, or explicitly migrated.
EOF

"$ROOT/scripts/log-event.sh" project-target set-project-target "Set project target to $TARGET" "mode=$MODE" "$NAME"

mkdir -p "$ROOT/.agents/company" "$ROOT/.agents/state"
project_record="$(printf '{"project_id":"%s","name":"%s","path":"%s","mode":"%s","status":"active","updated":"%s","source":"set-project-target"}' \
  "$(json_escape "$NAME")" "$(json_escape "$NAME")" "$(json_escape "$TARGET")" "$(json_escape "$MODE")" "$(json_escape "$UPDATED")")"
printf '%s\n' "$project_record" >> "$ROOT/.agents/company/projects.jsonl"
printf '%s\n' "$project_record" >> "$ROOT/.agents/state/projects.jsonl"

printf "Project target set to %s\n" "$TARGET"
