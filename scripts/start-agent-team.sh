#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:-agent-team}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_CONF="$PROJECT_DIR/.tmux.agent-team.conf"
TARGET_PATH="$(awk -F': ' '/^Path:/ { print $2; exit }' "$PROJECT_DIR/.agents/project-target.md" 2>/dev/null || true)"
TARGET_PATH="${TARGET_PATH:-$PROJECT_DIR}"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach-session -t "$SESSION"
  exit 0
fi

tmux -f "$TMUX_CONF" new-session -d -s "$SESSION" -c "$PROJECT_DIR" -n control
tmux send-keys -t "$SESSION:control" "printf 'Control terminal\nAgent home: $PROJECT_DIR\nProject target: $TARGET_PATH\n\n'; ./scripts/agent-status.sh 2>/dev/null || true" C-m

tmux new-window -t "$SESSION" -c "$PROJECT_DIR" -n orchestrator
tmux send-keys -t "$SESSION:orchestrator" "printf 'Orchestrator agent terminal\nPrompt: .agents/prompts/orchestrator.md\nProject target: $TARGET_PATH\nUse this window for most human requests.\n\n'" C-m

tmux new-window -t "$SESSION" -c "$PROJECT_DIR" -n cto
tmux send-keys -t "$SESSION:cto" 'printf "CTO agent terminal\nPrompt: .agents/prompts/cto.md\nSOP: .agents/sop.md\n\n"' C-m

tmux new-window -t "$SESSION" -c "$PROJECT_DIR" -n pm
tmux send-keys -t "$SESSION:pm" 'printf "PM agent terminal\nPrompt: .agents/prompts/pm.md\nTask template: .agents/task-template.md\n\n"' C-m

tmux new-window -t "$SESSION" -c "$PROJECT_DIR" -n frontend
tmux send-keys -t "$SESSION:frontend" 'printf "Frontend agent terminal\nPrompt: .agents/prompts/frontend.md\nQuality gates: .agents/quality-gates.md\n\n"' C-m

tmux new-window -t "$SESSION" -c "$PROJECT_DIR" -n backend
tmux send-keys -t "$SESSION:backend" 'printf "Backend agent terminal\nPrompt: .agents/prompts/backend.md\nQuality gates: .agents/quality-gates.md\n\n"' C-m

tmux new-window -t "$SESSION" -c "$PROJECT_DIR" -n validation
tmux send-keys -t "$SESSION:validation" 'printf "Validation agent terminal\nPrompt: .agents/prompts/validation.md\nQuality gates: .agents/quality-gates.md\n\n"' C-m

tmux new-window -t "$SESSION" -c "$PROJECT_DIR" -n reviewer
tmux send-keys -t "$SESSION:reviewer" 'printf "Reviewer agent terminal\nPrompt: .agents/prompts/reviewer.md\nInbox: .agents/inbox/reviewer.md\n\n"' C-m

tmux new-window -t "$SESSION" -c "$PROJECT_DIR" -n security
tmux send-keys -t "$SESSION:security" 'printf "Security agent terminal\nPrompt: .agents/prompts/security.md\nInbox: .agents/inbox/security.md\n\n"' C-m

tmux new-window -t "$SESSION" -c "$PROJECT_DIR" -n server
tmux send-keys -t "$SESSION:server" "cd '$TARGET_PATH'; printf 'Dev server and logs terminal\nProject target: $TARGET_PATH\n\n'" C-m

tmux select-window -t "$SESSION:control"
tmux attach-session -t "$SESSION"
