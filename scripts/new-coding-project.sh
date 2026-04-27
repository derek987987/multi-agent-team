#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_INSTANCE_ROOT="${AGENT_TEAM_INSTANCE_ROOT:-/Users/hay/Documents/agent-team-instances}"

usage() {
  cat >&2 <<EOF
Usage:
  $(basename "$0") <coding-project-dir> [agent-team-copy-dir] [options]
  $(basename "$0")

Arguments:
  coding-project-dir    Product/codebase directory to build in.
  agent-team-copy-dir   Optional destination for the copied agent team.
                        Default: $DEFAULT_INSTANCE_ROOT/<project-name>-team

Options:
  --team-dir <dir>      Same as agent-team-copy-dir.
  --mode <mode>         new-project or existing-project. Default is auto-detected.
  --session <name>      tmux session name. Default: agent-<project-name>
  --start               Start the copied agent team after creation.
  --worktrees           Start copied agent team in worktree mode. Implies --start.

Environment:
  AGENT_TEAM_INSTANCE_ROOT   Override the default parent directory for team copies.

Examples:
  ./scripts/new-coding-project.sh /Users/hay/Documents/my-app
  ./scripts/new-coding-project.sh /Users/hay/Documents/my-app /Users/hay/Documents/my-app-team
  ./scripts/new-coding-project.sh /Users/hay/Documents/my-app --start
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

PROJECT_DIR=""
TEAM_DIR=""
MODE=""
SESSION=""
START=0
WORKTREES=0

if [ "$#" -eq 0 ] && [ -t 0 ]; then
  printf "Coding project path: "
  IFS= read -r PROJECT_DIR
  printf "Agent-team copy path (blank for default): "
  IFS= read -r TEAM_DIR
  printf "Mode (blank for auto, or new-project/existing-project): "
  IFS= read -r MODE
  printf "Start tmux session now? [y/N]: "
  IFS= read -r start_answer
  case "$start_answer" in
    y|Y|yes|YES) START=1 ;;
  esac
elif [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --team-dir)
      require_value "$1" "${2:-}"
      if [ -n "$TEAM_DIR" ]; then
        printf "Agent-team destination was provided more than once.\n" >&2
        exit 1
      fi
      TEAM_DIR="${2:-}"
      shift 2
      ;;
    --mode)
      require_value "$1" "${2:-}"
      MODE="${2:-}"
      shift 2
      ;;
    --session)
      require_value "$1" "${2:-}"
      SESSION="${2:-}"
      shift 2
      ;;
    --start)
      START=1
      shift
      ;;
    --worktrees)
      START=1
      WORKTREES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ -z "$PROJECT_DIR" ]; then
        PROJECT_DIR="$1"
      elif [ -z "$TEAM_DIR" ]; then
        TEAM_DIR="$1"
      else
        printf "Unexpected argument: %s\n" "$1" >&2
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$PROJECT_DIR" ]; then
  usage
  exit 1
fi

case "$MODE" in
  ""|new-project|existing-project) ;;
  *)
    printf "Invalid --mode value: %s\n" "$MODE" >&2
    printf "Expected new-project or existing-project.\n" >&2
    exit 1
    ;;
esac

if ! command -v rsync >/dev/null 2>&1; then
  printf "rsync is required to copy the agent-team template.\n" >&2
  exit 1
fi

mkdir -p "$PROJECT_DIR"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

if [ -z "$MODE" ]; then
  if find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 | read -r _; then
    MODE="existing-project"
  else
    MODE="new-project"
  fi
fi

if [ -z "$TEAM_DIR" ]; then
  TEAM_DIR="$DEFAULT_INSTANCE_ROOT/$PROJECT_NAME-team"
fi

mkdir -p "$(dirname "$TEAM_DIR")"
TEAM_DIR="$(cd "$(dirname "$TEAM_DIR")" && pwd)/$(basename "$TEAM_DIR")"
TEMPLATE_ROOT="$(cd "$TEMPLATE_ROOT" && pwd)"

case "$TEAM_DIR/" in
  "$TEMPLATE_ROOT/"*)
    printf "Agent-team copy must be outside the reusable template home:\n" >&2
    printf "  template: %s\n" "$TEMPLATE_ROOT" >&2
    printf "  copy:     %s\n" "$TEAM_DIR" >&2
    exit 1
    ;;
esac

if [ -e "$TEAM_DIR" ]; then
  printf "Agent-team destination already exists: %s\n" "$TEAM_DIR" >&2
  printf "Choose a different destination path or remove it intentionally.\n" >&2
  exit 1
fi

SESSION="${SESSION:-agent-$PROJECT_NAME}"

rsync -a \
  --exclude ".git/" \
  --exclude ".DS_Store" \
  --exclude "node_modules/" \
  --exclude "agent-worktrees/" \
  "$TEMPLATE_ROOT/" "$TEAM_DIR/"

chmod +x "$TEAM_DIR"/scripts/*.sh

"$TEAM_DIR/scripts/reset-agent-team-state.sh" >/dev/null
"$TEAM_DIR/scripts/set-project-target.sh" "$PROJECT_DIR" "$MODE" >/dev/null
"$TEAM_DIR/scripts/validate-agent-workflow.sh" >/dev/null

cat <<EOF
Created project agent team.

Template home:
  $TEMPLATE_ROOT

Coding project:
  $PROJECT_DIR

Agent-team copy:
  $TEAM_DIR

Session:
  $SESSION

Next:
  cd "$TEAM_DIR"
  ./scripts/start-agent-team.sh "$SESSION"
EOF

if [ "$START" -eq 1 ]; then
  cd "$TEAM_DIR"
  if [ "$WORKTREES" -eq 1 ]; then
    ./scripts/start-agent-team-worktrees.sh "$SESSION"
  else
    ./scripts/start-agent-team.sh "$SESSION"
  fi
fi
