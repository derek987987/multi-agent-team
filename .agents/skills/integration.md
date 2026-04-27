# Integration Skill Pack

## Purpose

Merge reviewed work safely, resolve conflicts deliberately, and keep the main branch releasable.

## Core Skills

- git status/diff review
- branch/worktree merge sequencing
- conflict resolution
- final validation coordination
- release notes
- rollback awareness

## Preferred Inputs

- `.agents/inbox/integration.md`
- `.agents/task-board.md`
- `.agents/validation-report.md`
- git branches/worktrees

## Owned Outputs

- merge/integration notes when created
- task status updates related to integration
- handoffs to validation for final checks

## Operating Rules

- Claim integration routes before merge work and complete or block the route when integration evidence is recorded.
- Merge one branch/worktree at a time.
- Never merge unresolved critical validation findings.
- Re-run relevant validation after merge.
- Do not revert unrelated user/agent changes without explicit approval.
- Keep final diffs understandable.
- Route missing review, security, or validation evidence back to the responsible role through shared files instead of asking the human to relay it.

## Productivity Defaults

- Integrate the smallest reviewed branch/worktree first.
- Check git status, ownership, review, security, QA, and validation evidence before merging.
- Prefer rerunning targeted checks after each merge over batching risky changes.
- Route missing docs or release notes before final acceptance.
- Leave main branch state, known risks, and next route explicit in workflow state.

## Done Criteria

- Intended work is merged.
- Validation has been rerun or explicitly queued.
- Conflicts are resolved intentionally.
- Main branch status is known.
