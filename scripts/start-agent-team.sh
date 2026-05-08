#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:-agent-team}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJECT_DIR/scripts/agent-roles.sh"
TMUX_CONF="$PROJECT_DIR/.tmux.agent-team.conf"
TARGET_PATH="$(awk -F': ' '/^Path:/ { print $2; exit }' "$PROJECT_DIR/agent-control/project-target.md" 2>/dev/null || true)"
TARGET_PATH="${TARGET_PATH:-$PROJECT_DIR}"

shell_join() {
  printf '%q ' "$@"
}

if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach-session -t "$SESSION"
  exit 0
fi

AGENT_OFFICE_PORT="${AGENT_OFFICE_PORT:-8765}"
AGENT_OFFICE_URL="$("$PROJECT_DIR/scripts/start-agent-office-dashboard.sh" --print-url "$AGENT_OFFICE_PORT")"
AGENT_ROLE_READY_TIMEOUT="${AGENT_ROLE_READY_TIMEOUT:-180}"

if [ "${AGENT_TEAM_AUTO_TRUST_CODEX_PROJECTS:-1}" != "0" ]; then
  "$PROJECT_DIR/scripts/trust-codex-projects.sh" "$PROJECT_DIR" "$TARGET_PATH" >/dev/null || \
    printf "Warning: could not pre-trust Codex project paths; role sessions may stop for workspace trust prompts.\n" >&2
fi

tmux -f "$TMUX_CONF" new-session -d -s "$SESSION" -c "$PROJECT_DIR" -n control
control_cmd="$(shell_join printf 'Control terminal\nAgent home: %s\nProject target: %s\nRoute watcher: waiting up to %ss for Codex role readiness\n\n' "$PROJECT_DIR" "$TARGET_PATH" "$AGENT_ROLE_READY_TIMEOUT") && $(shell_join "$PROJECT_DIR/scripts/agent-status.sh") 2>/dev/null || true; $(shell_join "$PROJECT_DIR/scripts/wait-for-agent-sessions.sh" "$SESSION" --timeout "$AGENT_ROLE_READY_TIMEOUT") || true; while true; do $(shell_join "$PROJECT_DIR/scripts/watch-routes.sh" "$SESSION" --send); route_status=\$?; printf 'watch-routes exited with status %s; restarting in 5s\n' \"\$route_status\"; sleep 5; done"

start_role_window() {
  local role="$1"
  local workdir="$2"
  local cmd
  tmux new-window -t "$SESSION" -c "$workdir" -n "$role"
  "$PROJECT_DIR/scripts/update-agent-state.sh" "$role" \
    --session "$SESSION" \
    --window "$role" \
    --status launching \
    --workdir "$workdir" \
    --target-project "$TARGET_PATH" \
    --pid-or-command "codex-role.sh $role" \
    --process-status starting
  cmd="$(shell_join "$PROJECT_DIR/scripts/codex-role.sh" "$role" --workdir "$workdir")"
  tmux send-keys -t "$SESSION:$role" "$cmd" C-m
}

for role in "${AGENT_ROLES[@]}"; do
  start_role_window "$role" "$PROJECT_DIR"
done

tmux send-keys -t "$SESSION:control" "$control_cmd" C-m

tmux new-window -t "$SESSION" -c "$PROJECT_DIR" -n office
office_cmd="$(shell_join printf 'Agent Office dashboard\nAgent home: %s\nProject target: %s\nURL: %s\n\n' "$PROJECT_DIR" "$TARGET_PATH" "$AGENT_OFFICE_URL") && $(shell_join "$PROJECT_DIR/scripts/start-agent-office-dashboard.sh" --port "$AGENT_OFFICE_PORT")"
tmux send-keys -t "$SESSION:office" "$office_cmd" C-m

tmux new-window -t "$SESSION" -c "$PROJECT_DIR" -n server
tmux send-keys -t "$SESSION:server" "cd '$TARGET_PATH'; printf 'Dev server and logs terminal\nProject target: $TARGET_PATH\n\n'" C-m

tmux select-window -t "$SESSION:control" 2>/dev/null || tmux select-window -t "$SESSION:orchestrator"
tmux attach-session -t "$SESSION"
