#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:-agent-team}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/agent-roles.sh"
TARGET_PATH="$(awk -F': ' '/^Path:/ { print $2; exit }' "$ROOT/agent-control/project-target.md" 2>/dev/null || true)"
TARGET_PATH="${TARGET_PATH:-$ROOT}"
TARGET_PATH="$(cd "$TARGET_PATH" && pwd)"
PROJECT="$(basename "$TARGET_PATH")"
BASE="$(dirname "$TARGET_PATH")/agent-worktrees"
TMUX_CONF="$ROOT/.tmux.agent-team.conf"

shell_join() {
  printf '%q ' "$@"
}

if ! git -C "$TARGET_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf "This script requires target project %s to be inside a git repository.\n" "$TARGET_PATH" >&2
  printf "Run 'git -C %s init' first, or use scripts/start-agent-team.sh without worktrees.\n" "$TARGET_PATH" >&2
  exit 1
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach-session -t "$SESSION"
  exit 0
fi

AGENT_OFFICE_PORT="${AGENT_OFFICE_PORT:-8765}"
AGENT_OFFICE_URL="$("$ROOT/scripts/start-agent-office-dashboard.sh" --print-url "$AGENT_OFFICE_PORT")"
AGENT_ROLE_READY_TIMEOUT="${AGENT_ROLE_READY_TIMEOUT:-180}"
AGENT_TEAM_SEQUENTIAL_ROLE_STARTUP="${AGENT_TEAM_SEQUENTIAL_ROLE_STARTUP:-1}"

mkdir -p "$BASE"

create_worktree() {
  local name="$1"
  local branch="agent/$name"
  local path="$BASE/$PROJECT-$name"

  if [ ! -d "$path/.git" ] && [ ! -f "$path/.git" ]; then
    if git -C "$TARGET_PATH" show-ref --verify --quiet "refs/heads/$branch"; then
      git -C "$TARGET_PATH" worktree add "$path" "$branch"
    else
      git -C "$TARGET_PATH" worktree add -b "$branch" "$path"
    fi
  fi
}

for role in "${PROJECT_WORKTREE_ROLES[@]}"; do
  create_worktree "$role"
done

"$ROOT/scripts/sync-agent-state.sh" --push

if [ "${AGENT_TEAM_AUTO_TRUST_CODEX_PROJECTS:-1}" != "0" ]; then
  trust_paths=("$ROOT" "$TARGET_PATH")
  for role in "${AGENT_ROLES[@]}"; do
    if role_uses_project_worktree "$role"; then
      trust_paths+=("$BASE/$PROJECT-$role")
    fi
  done
  "$ROOT/scripts/trust-codex-projects.sh" "${trust_paths[@]}" >/dev/null || \
    printf "Warning: could not pre-trust Codex project paths; role sessions may stop for workspace trust prompts.\n" >&2
fi

tmux -f "$TMUX_CONF" new-session -d -s "$SESSION" -c "$ROOT" -n control
control_cmd="$(shell_join printf 'Control terminal\nAgent home: %s\nProject target: %s\nRoute watcher: waiting up to %ss for Codex role readiness\n\n' "$ROOT" "$TARGET_PATH" "$AGENT_ROLE_READY_TIMEOUT") && $(shell_join "$ROOT/scripts/agent-status.sh") 2>/dev/null || true; $(shell_join "$ROOT/scripts/wait-for-agent-sessions.sh" "$SESSION" --timeout "$AGENT_ROLE_READY_TIMEOUT") || true; while true; do $(shell_join "$ROOT/scripts/watch-routes.sh" "$SESSION" --send); route_status=\$?; printf 'watch-routes exited with status %s; restarting in 5s\n' \"\$route_status\"; sleep 5; done"

start_role_window() {
  local role="$1"
  local workdir="$2"
  local cmd
  tmux new-window -t "$SESSION" -c "$workdir" -n "$role"
  "$ROOT/scripts/update-agent-state.sh" "$role" \
    --session "$SESSION" \
    --window "$role" \
    --status launching \
    --workdir "$workdir" \
    --target-project "$TARGET_PATH" \
    --branch-or-worktree "$(basename "$workdir")" \
    --pid-or-command "codex-role.sh $role" \
    --process-status starting
  cmd="$(shell_join "$ROOT/scripts/codex-role.sh" "$role" --workdir "$workdir")"
  tmux send-keys -t "$SESSION:$role" "$cmd" C-m
  if [ "$AGENT_TEAM_SEQUENTIAL_ROLE_STARTUP" != "0" ]; then
    if ! "$ROOT/scripts/wait-for-agent-sessions.sh" "$SESSION" \
      --timeout "$AGENT_ROLE_READY_TIMEOUT" \
      --roles "$role"; then
      printf "Warning: %s did not report startup readiness within %ss; continuing startup.\n" "$role" "$AGENT_ROLE_READY_TIMEOUT" >&2
      "$ROOT/scripts/update-agent-state.sh" "$role" \
        --session "$SESSION" \
        --window "$role" \
        --status blocked \
        --active-route none \
        --blocked-reason "startup readiness timeout" \
        --recovery-owner devops \
        --process-status alive >/dev/null || true
    fi
  fi
}

for role in "${AGENT_ROLES[@]}"; do
  if role_uses_project_worktree "$role"; then
    start_role_window "$role" "$BASE/$PROJECT-$role"
  elif [ "$role" = "integration" ]; then
    start_role_window "$role" "$TARGET_PATH"
  else
    start_role_window "$role" "$ROOT"
  fi
done

tmux send-keys -t "$SESSION:control" "$control_cmd" C-m

tmux new-window -t "$SESSION" -c "$ROOT" -n office
office_cmd="$(shell_join printf 'Agent Office dashboard\nAgent home: %s\nProject target: %s\nURL: %s\n\n' "$ROOT" "$TARGET_PATH" "$AGENT_OFFICE_URL") && $(shell_join "$ROOT/scripts/start-agent-office-dashboard.sh" --port "$AGENT_OFFICE_PORT")"
tmux send-keys -t "$SESSION:office" "$office_cmd" C-m

tmux new-window -t "$SESSION" -c "$ROOT" -n server
tmux send-keys -t "$SESSION:server" "cd '$TARGET_PATH'; printf 'Dev server and logs terminal\nProject target: $TARGET_PATH\n\n'" C-m

tmux select-window -t "$SESSION:control" 2>/dev/null || tmux select-window -t "$SESSION:orchestrator"
tmux attach-session -t "$SESSION"
