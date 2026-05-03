#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:---push}"

if [ "$MODE" != "--push" ]; then
  printf "Usage: %s [--push]\n" "$(basename "$0")" >&2
  printf "Currently supported mode: --push root control-plane files to all git worktrees.\n" >&2
  exit 1
fi

TARGET_PATH="$(awk -F': ' '/^Path:/ { print $2; exit }' "$ROOT/.agents/project-target.md" 2>/dev/null || true)"
TARGET_PATH="${TARGET_PATH:-$ROOT}"
TARGET_PATH="$(cd "$TARGET_PATH" && pwd)"

if ! git -C "$TARGET_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf "Target is not inside a git repository: %s\n" "$TARGET_PATH" >&2
  exit 1
fi

target_real="$(cd "$TARGET_PATH" && pwd -P)"
synced=0

while IFS= read -r line; do
  case "$line" in
    worktree\ *)
      wt="${line#worktree }"
      wt_real="$(cd "$wt" && pwd -P)"
      if [ "$wt_real" = "$target_real" ]; then
        continue
      fi

      mkdir -p "$wt/.agents" "$wt/scripts"
      rsync -a "$ROOT/.agents/prompts/" "$wt/.agents/prompts/"
      rsync -a "$ROOT/.agents/skills/" "$wt/.agents/skills/"
      rsync -a "$ROOT/.agents/schemas/" "$wt/.agents/schemas/"
      rsync -a "$ROOT/.agents/ownership/" "$wt/.agents/ownership/"
      rsync -a "$ROOT/.agents/agent-config/" "$wt/.agents/agent-config/"
      rsync -a "$ROOT/.agents/state/" "$wt/.agents/state/"
      rsync -a "$ROOT/.agents/routes/" "$wt/.agents/routes/"
      for file in \
        brief.md context-map.md agent-policy.md evaluation-suite.md \
        failure-recovery.md adaptation-guide.md product-requirements.md \
        design-notes.md qa-plan.md release-notes.md research-notes.md \
        performance-report.md intake-notes.md sop.md roles.md architecture.md decisions.md \
        task-board.md task-template.md handoffs.md quality-gates.md \
        definition-of-ready.md definition-of-done.md conflict-resolution.md \
        change-control.md change-request.md workflow-state.md routing-matrix.md \
        route-schema.md memory-policy.md sync-policy.md route-budget.md \
        project-target.md secrets-policy.md milestone-budget.md; do
        if [ -f "$ROOT/.agents/$file" ]; then
          cp "$ROOT/.agents/$file" "$wt/.agents/$file"
        fi
      done
      cp "$ROOT/AGENTS.md" "$wt/AGENTS.md"
      cp "$ROOT/README.md" "$wt/README.md"
      cp "$ROOT/.tmux.agent-team.conf" "$wt/.tmux.agent-team.conf"
      if [ -d "$ROOT/.github" ]; then
        mkdir -p "$wt/.github"
        rsync -a --delete "$ROOT/.github/" "$wt/.github/"
      fi
      find "$ROOT/scripts" -maxdepth 1 -type f -name "*.sh" -print | while IFS= read -r script; do
        cp "$script" "$wt/scripts/$(basename "$script")"
      done
      chmod +x "$wt"/scripts/*.sh 2>/dev/null || true
      printf "Synced control-plane files to %s\n" "$wt"
      synced=$((synced + 1))
      ;;
  esac
done < <(git -C "$TARGET_PATH" worktree list --porcelain)

"$ROOT/scripts/log-event.sh" state-sync sync-agent-state "Synced control-plane files to worktrees" "count=$synced"
