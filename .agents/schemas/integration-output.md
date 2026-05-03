# Integration Output Schema

Use this structure in `.agents/routes/R000.md`, `.agents/agent-log/integration.md`, or an integration note when the Integration role completes a route.

## Required Sections

- Route ID
- Source branch or worktree
- Target branch
- Reports checked
- Merge or conflict action
- Commands run
- Post-merge validation result
- Rollback point
- Updated workflow files
- Remaining risks or blockers
- Next owner

## Minimum Completion Record

```md
### Integration Output

Route ID:
Source branch / worktree:
Target branch:
Reports checked:
- validation:
- review:
- security:

Merge action:

Conflicts:

Commands run:
- command:
  result:

Rollback point:

Workflow updates:

Remaining risks:

Next owner:
```
