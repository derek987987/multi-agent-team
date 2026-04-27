#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf "== Quality Gates ==\n\n"

"$ROOT/scripts/validate-agent-workflow.sh"
printf "\n"
"$ROOT/scripts/validate-structured-state.sh"
printf "\n"
"$ROOT/scripts/check-memory.sh"
printf "\n"
"$ROOT/scripts/check-route-budget.sh"
printf "\n"
"$ROOT/scripts/check-stale-routes.sh" || true
printf "\n"
"$ROOT/scripts/check-secrets.sh"
printf "\n"
"$ROOT/scripts/check-milestone-budget.sh"
printf "\n"
"$ROOT/scripts/check-ready.sh" || true
printf "\n"
"$ROOT/scripts/check-done.sh" || true

printf "\n== Project Commands ==\n"

run_if_present() {
  local file="$1"
  local cmd="$2"
  if [ -f "$ROOT/$file" ]; then
    printf "Running: %s\n" "$cmd"
    (cd "$ROOT" && eval "$cmd")
  fi
}

if [ -f "$ROOT/package.json" ]; then
  run_if_present "package.json" "npm run lint"
  run_if_present "package.json" "npm run typecheck"
  run_if_present "package.json" "npm test"
  run_if_present "package.json" "npm run build"
elif [ -f "$ROOT/pyproject.toml" ]; then
  run_if_present "pyproject.toml" "python -m ruff check ."
  run_if_present "pyproject.toml" "python -m mypy ."
  run_if_present "pyproject.toml" "python -m pytest"
else
  printf "No recognized project command file found. Add commands to .agents/quality-gates.md as the project takes shape.\n"
fi
