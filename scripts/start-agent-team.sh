#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:-agent-team}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJECT_DIR/scripts/agent-roles.sh"
TMUX_CONF="$PROJECT_DIR/.tmux.agent-team.conf"
TARGET_PATH="$(awk -F': ' '/^Path:/ { print $2; exit }' "$PROJECT_DIR/.agents/project-target.md" 2>/dev/null || true)"
TARGET_PATH="${TARGET_PATH:-$PROJECT_DIR}"

shell_join() {
  printf '%q ' "$@"
}

if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach-session -t "$SESSION"
  exit 0
fi

tmux -f "$TMUX_CONF" new-session -d -s "$SESSION" -c "$PROJECT_DIR" -n control
control_cmd="$(shell_join printf 'Control terminal\nAgent home: %s\nProject target: %s\nRoute watcher: active\n\n' "$PROJECT_DIR" "$TARGET_PATH") && ./scripts/agent-status.sh 2>/dev/null || true; while true; do ./scripts/watch-routes.sh $(printf '%q' "$SESSION") --send; status=\$?; printf 'watch-routes exited with status %s; restarting in 5s\n' \"\$status\"; sleep 5; done"
tmux send-keys -t "$SESSION:control" "$control_cmd" C-m

start_role_window() {
  local role="$1"
  local workdir="$2"
  local cmd
  tmux new-window -t "$SESSION" -c "$workdir" -n "$role"
  cmd="$(shell_join "$PROJECT_DIR/scripts/codex-role.sh" "$role" --workdir "$workdir")"
  tmux send-keys -t "$SESSION:$role" "$cmd" C-m
}

for role in "${AGENT_ROLES[@]}"; do
  start_role_window "$role" "$PROJECT_DIR"
done

tmux new-window -t "$SESSION" -c "$PROJECT_DIR" -n server
tmux send-keys -t "$SESSION:server" "cd '$TARGET_PATH'; printf 'Dev server and logs terminal\nProject target: $TARGET_PATH\n\n'" C-m

tmux select-window -t "$SESSION:control" 2>/dev/null || tmux select-window -t "$SESSION:orchestrator"
tmux attach-session -t "$SESSION"
