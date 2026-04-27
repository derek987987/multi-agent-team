#!/usr/bin/env bash
set -euo pipefail

SESSION="${1:-agent-team}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_PATH="$(awk -F': ' '/^Path:/ { print $2; exit }' "$ROOT/.agents/project-target.md" 2>/dev/null || true)"
TARGET_PATH="${TARGET_PATH:-$ROOT}"
TARGET_PATH="$(cd "$TARGET_PATH" && pwd)"
PROJECT="$(basename "$TARGET_PATH")"
BASE="$(dirname "$TARGET_PATH")/agent-worktrees"
TMUX_CONF="$ROOT/.tmux.agent-team.conf"

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

create_worktree frontend
create_worktree backend
create_worktree validation

"$ROOT/scripts/sync-agent-state.sh" --push

tmux -f "$TMUX_CONF" new-session -d -s "$SESSION" -c "$ROOT" -n control
tmux send-keys -t "$SESSION:control" "printf 'Control terminal\nAgent home: $ROOT\nProject target: $TARGET_PATH\n\n'; ./scripts/agent-status.sh 2>/dev/null || true" C-m

tmux new-window -t "$SESSION" -c "$ROOT" -n orchestrator
tmux send-keys -t "$SESSION:orchestrator" "printf 'Orchestrator agent terminal\nPrompt: .agents/prompts/orchestrator.md\nProject target: $TARGET_PATH\nUse this window for most human requests.\n\n'" C-m

tmux new-window -t "$SESSION" -c "$ROOT" -n cto
tmux send-keys -t "$SESSION:cto" 'printf "CTO agent terminal\nPrompt: .agents/prompts/cto.md\nSOP: .agents/sop.md\n\n"' C-m

tmux new-window -t "$SESSION" -c "$ROOT" -n pm
tmux send-keys -t "$SESSION:pm" 'printf "PM agent terminal\nPrompt: .agents/prompts/pm.md\nTask template: .agents/task-template.md\n\n"' C-m

tmux new-window -t "$SESSION" -c "$BASE/$PROJECT-frontend" -n frontend
tmux send-keys -t "$SESSION:frontend" 'printf "Frontend worktree\nPrompt: .agents/prompts/frontend.md\nQuality gates: .agents/quality-gates.md\n\n"; git status' C-m

tmux new-window -t "$SESSION" -c "$BASE/$PROJECT-backend" -n backend
tmux send-keys -t "$SESSION:backend" 'printf "Backend worktree\nPrompt: .agents/prompts/backend.md\nQuality gates: .agents/quality-gates.md\n\n"; git status' C-m

tmux new-window -t "$SESSION" -c "$BASE/$PROJECT-validation" -n validation
tmux send-keys -t "$SESSION:validation" 'printf "Validation worktree\nPrompt: .agents/prompts/validation.md\nQuality gates: .agents/quality-gates.md\n\n"; git status' C-m

tmux new-window -t "$SESSION" -c "$ROOT" -n reviewer
tmux send-keys -t "$SESSION:reviewer" 'printf "Reviewer agent terminal\nPrompt: .agents/prompts/reviewer.md\nInbox: .agents/inbox/reviewer.md\n\n"' C-m

tmux new-window -t "$SESSION" -c "$ROOT" -n security
tmux send-keys -t "$SESSION:security" 'printf "Security agent terminal\nPrompt: .agents/prompts/security.md\nInbox: .agents/inbox/security.md\n\n"' C-m

tmux new-window -t "$SESSION" -c "$ROOT" -n server
tmux send-keys -t "$SESSION:server" "cd '$TARGET_PATH'; printf 'Dev server and logs terminal\nProject target: $TARGET_PATH\n\n'" C-m

tmux select-window -t "$SESSION:control"
tmux attach-session -t "$SESSION"
