#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:-agent-team}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/agent-roles.sh"
TARGET_PATH="$(awk -F': ' '/^Path:/ { print $2; exit }' "$ROOT/.agents/project-target.md" 2>/dev/null || true)"
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

tmux -f "$TMUX_CONF" new-session -d -s "$SESSION" -c "$ROOT" -n control
control_cmd="$(shell_join printf 'Control terminal\nAgent home: %s\nProject target: %s\nRoute watcher: active\n\n' "$ROOT" "$TARGET_PATH") && ./scripts/agent-status.sh 2>/dev/null || true; exec ./scripts/watch-routes.sh $(printf '%q' "$SESSION") --send"
tmux send-keys -t "$SESSION:control" "$control_cmd" C-m

start_role_window() {
  local role="$1"
  local workdir="$2"
  local cmd
  tmux new-window -t "$SESSION" -c "$workdir" -n "$role"
  cmd="$(shell_join "$ROOT/scripts/codex-role.sh" "$role" --workdir "$workdir")"
  tmux send-keys -t "$SESSION:$role" "$cmd" C-m
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

tmux new-window -t "$SESSION" -c "$ROOT" -n server
tmux send-keys -t "$SESSION:server" "cd '$TARGET_PATH'; printf 'Dev server and logs terminal\nProject target: $TARGET_PATH\n\n'" C-m

tmux select-window -t "$SESSION:control"
tmux attach-session -t "$SESSION"
