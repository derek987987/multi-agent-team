#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_jsonl_summary() {
  local file="$1"
  local empty_message="$2"
  if [ ! -s "$file" ]; then
    printf "%s\n" "$empty_message"
    return
  fi
  sed -n '1,20p' "$file"
}

printf "== Coding Company Status ==\n\n"

printf "Repository: %s\n\n" "$ROOT"

printf "== Company Projects ==\n"
print_jsonl_summary "$ROOT/.agents/company/projects.jsonl" "No projects recorded."
printf "\n"

printf "== Agent Profiles ==\n"
print_jsonl_summary "$ROOT/.agents/company/agent-profiles.jsonl" "No agent profiles recorded."
printf "\n"

printf "== Open Meetings ==\n"
if [ -d "$ROOT/.agents/meetings" ]; then
  found=0
  for meeting in "$ROOT"/.agents/meetings/M*.md; do
    [ -e "$meeting" ] || continue
    if grep -q '^Status: open$' "$meeting"; then
      printf "%s\n" "${meeting#$ROOT/}"
      found=1
    fi
  done
  [ "$found" -eq 1 ] || printf "None\n"
else
  printf "Missing .agents/meetings\n"
fi
printf "\n"

printf "== Recent Approvals ==\n"
print_jsonl_summary "$ROOT/.agents/approvals.jsonl" "No approvals recorded."
printf "\n"

printf "== Recent Media Attachments ==\n"
print_jsonl_summary "$ROOT/.agents/media/manifest.jsonl" "No media attachments recorded."
