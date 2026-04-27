#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/agent-roles.sh"
ROLE="${1:-}"
shift || true

WORKDIR=""
PRINT=0

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") <role> [--workdir <dir>] [--print]

Roles:
$(print_agent_roles | sed 's/^/  /')

Options:
  --workdir <dir>   Directory passed to codex --cd. Default: agent-team root.
  --print           Print the Codex command instead of executing it.
EOF
}

require_value() {
  local flag="$1"
  local value="${2:-}"
  if [ -z "$value" ]; then
    printf "%s requires a value.\n" "$flag" >&2
    exit 1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workdir)
      require_value "$1" "${2:-}"
      WORKDIR="${2:-}"
      shift 2
      ;;
    --print)
      PRINT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf "Unexpected argument: %s\n" "$1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$ROLE" ]; then
    usage
    exit 1
fi

if ! is_agent_role "$ROLE"; then
  printf "Unknown role: %s\n" "$ROLE" >&2
  usage
  exit 1
fi

role_focus() {
  case "$1" in
    orchestrator)
      printf "You are the orchestrator agent. You are the only normal human-facing agent. Interview the human, maintain the shared workflow files, create routes, and let the route watcher dispatch work to other agents."
      ;;
    product)
      printf "You are the product agent. Clarify users, jobs-to-be-done, scope, non-goals, user journeys, acceptance risks, and product tradeoffs before planning and implementation."
      ;;
    research)
      printf "You are the research agent. Investigate unfamiliar stacks, libraries, APIs, platform constraints, and repo context, then return concise sourced recommendations."
      ;;
    cto)
      printf "You are the CTO agent. Turn approved intent into architecture, decisions, module boundaries, ownership, risks, and validation implications."
      ;;
    design)
      printf "You are the design agent. Turn product intent into user flows, interaction states, UI guidance, accessibility notes, and design constraints for implementation."
      ;;
    pm)
      printf "You are the PM agent. Turn architecture and product intent into small ordered tasks with owners, dependencies, acceptance criteria, and validation commands."
      ;;
    frontend)
      printf "You are a frontend coder agent. You claim assigned routes, implement UI/client tasks inside ownership boundaries, write tests, and route cross-agent needs through shared files."
      ;;
    backend)
      printf "You are a backend coder agent. You claim assigned routes, implement API/server/data tasks inside ownership boundaries, write tests, and route cross-agent needs through shared files."
      ;;
    data)
      printf "You are the data agent. Own data modeling, migrations, analytics events, seed data, query performance, and data-contract review."
      ;;
    devops)
      printf "You are the DevOps and platform agent. Own local setup, CI, build pipelines, deployment, environment configuration, observability, and release automation."
      ;;
    qa)
      printf "You are the QA automation agent. Own test strategy, reproducible bug cases, fixtures, browser/API smoke coverage, and regression test implementation."
      ;;
    performance)
      printf "You are the performance agent. Own latency, memory, bundle size, query performance, load, profiling, and production performance budgets."
      ;;
    validation)
      printf "You are the validation agent. Independently run checks, verify acceptance criteria, reproduce bugs, and record evidence-backed findings."
      ;;
    reviewer)
      printf "You are the code reviewer agent. Review implementation for bugs, regressions, missing tests, maintainability, and architecture drift."
      ;;
    security)
      printf "You are the security agent. Review auth, authorization, secrets, sensitive data, logging, input validation, dependency risk, and privacy exposure."
      ;;
    docs)
      printf "You are the documentation agent. Own user-facing docs, developer docs, runbooks, release notes, API examples, and setup instructions."
      ;;
    integration)
      printf "You are the integration agent. Merge reviewed work deliberately, coordinate final validation, resolve conflicts, and keep the main branch releasable."
      ;;
  esac
}

TARGET_PATH="$(awk -F': ' '/^Path:/ { print $2; exit }' "$ROOT/.agents/project-target.md" 2>/dev/null || true)"
TARGET_PATH="${TARGET_PATH:-$ROOT}"
if [ -d "$TARGET_PATH" ]; then
  TARGET_PATH="$(cd "$TARGET_PATH" && pwd)"
fi

WORKDIR="${WORKDIR:-$ROOT}"
if [ ! -d "$WORKDIR" ]; then
  printf "Working directory does not exist: %s\n" "$WORKDIR" >&2
  exit 1
fi
WORKDIR="$(cd "$WORKDIR" && pwd)"

PROMPT_PATH=".agents/prompts/$ROLE.md"
INBOX_PATH=".agents/inbox/$ROLE.md"
SKILL_PATH=".agents/skills/$ROLE.md"
MEMORY_PATH=".agents/memory/$ROLE.md"
CONFIG_PATH=".agents/agent-config/$ROLE.yaml"

PROMPT_TEXT="$(cat <<EOF
$(role_focus "$ROLE")

You are running in --full-auto inside the agent-team tmux session.

Agent team control plane:
$ROOT

Project target:
$TARGET_PATH

Working directory:
$WORKDIR

Before acting, read:
- AGENTS.md
- .agents/project-target.md
- $PROMPT_PATH
- $SKILL_PATH
- $MEMORY_PATH
- $CONFIG_PATH
- $INBOX_PATH
- .agents/context-map.md
- .agents/agent-policy.md
- .agents/evaluation-suite.md
- .agents/failure-recovery.md
- .agents/adaptation-guide.md
- .agents/workflow-state.md
- .agents/handoffs.md
- .agents/task-board.md
- .agents/quality-gates.md

Operating loop:
1. Inspect $INBOX_PATH and .agents/workflow-state.md for queued or dispatched work assigned to $ROLE.
2. When you act on a route, claim the route with ./scripts/claim-route.sh <route-id> $ROLE.
3. Work from the shared source-of-truth files, not from terminal chat.
4. Do your role-specific work without asking the human to prompt another agent.
5. If another role is needed, write a concrete handoff or route through .agents/handoffs.md and the target .agents/inbox/<role>.md.
6. If blocked, record the blocker in your inbox response, .agents/handoffs.md, and .agents/workflow-state.md.
7. When finished, update your owned outputs and run ./scripts/complete-route.sh <route-id> $ROLE "<short summary>".

If relative .agents paths are not present in the working directory, use the control-plane directory above.
EOF
)"

cmd=(codex --full-auto --no-alt-screen --cd "$WORKDIR")

root_real="$(cd "$ROOT" && pwd -P)"
workdir_real="$(cd "$WORKDIR" && pwd -P)"
if [ "$root_real" != "$workdir_real" ]; then
  cmd+=(--add-dir "$ROOT")
fi

if [ -d "$TARGET_PATH" ]; then
  target_real="$(cd "$TARGET_PATH" && pwd -P)"
  if [ "$target_real" != "$workdir_real" ] && [ "$target_real" != "$root_real" ]; then
    cmd+=(--add-dir "$TARGET_PATH")
  fi
fi

cmd+=("$PROMPT_TEXT")

if [ "$PRINT" -eq 1 ]; then
  printf '%q ' "${cmd[@]}"
  printf '\n'
  exit 0
fi

exec "${cmd[@]}"
