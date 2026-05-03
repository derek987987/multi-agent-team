#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
source "$ROOT/scripts/agent-roles.sh"

mkdir -p "$ROOT/.agents/company" "$ROOT/.agents/meetings" "$ROOT/.agents/media" "$ROOT/.agents/state"

cat > "$ROOT/.agents/brief.md" <<'EOF'
# Product Brief

## Goal
Describe the coding project the agent team should build.

## Users
Describe who will use it and what they need to accomplish.

## Core Features
1. TBD
2. TBD
3. TBD

## Non-Goals
List what should not be built in the first pass.

## Tech Preferences
- Frontend:
- Backend:
- Database:
- Auth:
- Deployment:

## Definition of Done
- App runs locally.
- Build command passes.
- Lint/type checks pass where applicable.
- Tests pass.
- README explains setup and usage.
- No known critical or major validation findings remain.
EOF

cat > "$ROOT/.agents/intake-notes.md" <<'EOF'
# Intake Notes

The Orchestrator uses this file to capture rough human ideas, clarifying questions, answers, assumptions, and the path toward a finished product brief.

## Current Intake

Status: empty
Last updated:

## Raw Human Idea

TBD

## Clarifying Questions

None yet.

## Human Answers

None yet.

## Assumptions

None yet.

## Draft Brief Notes

None yet.

## Readiness Checklist

- [ ] Goal is clear
- [ ] Target users are clear
- [ ] Core features are clear
- [ ] Non-goals are clear
- [ ] Tech preferences or constraints are clear enough
- [ ] Definition of done is clear
- [ ] Human has approved `.agents/brief.md`
EOF

cat > "$ROOT/.agents/architecture.md" <<'EOF'
# Architecture

This file is owned by the CTO agent.

## Summary
TBD

## System Design
TBD

## Modules And Ownership
| Module | Owner | Files / Paths | Notes |
| --- | --- | --- | --- |
| TBD | TBD | TBD | TBD |

## Data Model
TBD

## API / Interface Contracts
TBD

## Testing Strategy
TBD

## Risks
TBD
EOF

cat > "$ROOT/.agents/decisions.md" <<'EOF'
# Decisions

Record architecture and product decisions here.

## Template

### Decision 001 - Title
Date:
Owner:

Decision:

Reason:

Impact:
EOF

cat > "$ROOT/.agents/task-board.md" <<'EOF'
# Task Board

This file is owned by the PM agent.

## Status Values
- pending
- in-progress
- blocked
- ready-for-review
- done

## Task Template

### T001 - Task Title
Owner:
Status: template
Priority: P2
Depends on:
Branch / worktree:
Files / modules owned:

Objective:

Acceptance criteria:
- TBD

Validation:
- Command:
- Expected:

Ready checklist:
- See `.agents/definition-of-ready.md`

Done checklist:
- See `.agents/definition-of-done.md`

Handoffs:
- none

Notes:
EOF

cat > "$ROOT/.agents/handoffs.md" <<'EOF'
# Handoffs

Use this file when one agent needs another agent to act.

## Status Values

- open
- accepted
- blocked
- done
- declined

## Handoff Template

### H001 - Short Title
Status: template
From:
To:
Date:
Related task:
Files / modules:

Request:

Context:

Acceptance criteria:
- TBD

Response:
EOF

cat > "$ROOT/.agents/workflow-state.md" <<'EOF'
# Workflow State

This file is the current control-plane snapshot for the multi-agent workflow.

## Current Mode

Mode: setup
Phase: intake
Last updated:
Updated by:

## Active Request

Request ID:
Title:
Status: none
Owner: orchestrator

## Phase Checklist

| Phase | Status | Owner | Exit Criteria |
| --- | --- | --- | --- |
| intake | active | human/orchestrator | `.agents/brief.md` is specific enough to plan |
| architecture | pending | CTO | architecture, decisions, ownership, and risks are documented |
| planning | pending | PM | tasks have owners, dependencies, acceptance criteria, and validation |
| implementation | pending | implementation agents | assigned tasks are ready for review |
| validation | pending | validation-agent | quality gates pass or findings are documented |
| integration | pending | integration owner | reviewed work is merged one branch/worktree at a time |
| acceptance | pending | CTO/PM/human | final review and acceptance are complete |

## Open Routes

| Route ID | To | Status | Related Task | Summary |
| --- | --- | --- | --- | --- |

## Blocked Tasks

| Task | Blocker | Owner | Next Step |
| --- | --- | --- | --- |

## Human Attention Needed

None.
EOF

cat > "$ROOT/.agents/change-request.md" <<'EOF'
# Change Request Intake

Use this file when you want to change something mid-workflow but do not want to manually decide which workflow documents need updates.

Fill in the latest request at the top, then ask the Orchestrator agent to process it using `.agents/prompts/change-router-cto.md`.

## Latest Change Request

### CR000 - Short Title
Date:
Requested by:
Type: spec-change | feature-change | bug-fix | architecture-change | validation-change | emergency-replan
Priority: P0 | P1 | P2 | P3
Status: draft

Request:

Why this matters:

Expected behavior:

Current behavior, if this is a bug:

Known affected areas:
- unknown

Suggested owner, if known:
- unknown

Validation expectation:
- unknown

Human notes:

## Processed Change Requests

Move completed or superseded requests here after CTO/PM processing.
EOF

cat > "$ROOT/.agents/validation-report.md" <<'EOF'
# Validation Report

This file is owned by the validation agent.

## Latest Validation Summary
Date:
Commit / Branch:

## Commands Run
- TBD

## Critical Findings
None recorded.

## Major Findings
None recorded.

## Minor Findings
None recorded.

## Passed Checks
None recorded.

## Finding Template

### Finding V001 - Short Title
Severity: critical | major | minor
Status: open | fixed | accepted
Task:
Files:

Problem:

Reproduction / command:

Expected result:

Actual result:

Recommendation:
EOF

cat > "$ROOT/.agents/review-report.md" <<'EOF'
# Review Report

## Latest Summary

Date:
Branch / Task:
Recommendation: pending

## Blocking Findings

None recorded.

## Non-Blocking Findings

None recorded.
EOF

cat > "$ROOT/.agents/security-report.md" <<'EOF'
# Security Report

## Latest Summary

Date:
Branch / Task:
Recommendation: pending

## Critical Findings

None recorded.

## Major Findings

None recorded.

## Minor Findings

None recorded.
EOF

cat > "$ROOT/.agents/final-cto-review.md" <<'EOF'
# Final CTO Review

Pending.
EOF

cat > "$ROOT/.agents/final-acceptance.md" <<'EOF'
# Final Acceptance

Pending.
EOF

for role in "${AGENT_ROLES[@]}"; do
  title="$(printf '%s' "$role" | awk '{ print toupper(substr($0,1,1)) substr($0,2) }')"
  cat > "$ROOT/.agents/agent-log/$role.md" <<EOF
# $title Agent Log

EOF
done

find "$ROOT/.agents/meetings" -maxdepth 1 -type f -name 'M*.md' -delete
cat > "$ROOT/.agents/company/projects.jsonl" <<EOF
{"project_id":"template","name":"agent-teams","path":"$ROOT","mode":"template","status":"template","updated":"$UPDATED","source":"reset-agent-team-state"}
EOF
cat > "$ROOT/.agents/media/manifest.jsonl" </dev/null
cat > "$ROOT/.agents/approvals.jsonl" </dev/null
cat > "$ROOT/.agents/state/projects.jsonl" </dev/null
cat > "$ROOT/.agents/state/routes.jsonl" </dev/null
cat > "$ROOT/.agents/state/tasks.jsonl" </dev/null
cat > "$ROOT/.agents/state/findings.jsonl" </dev/null
cat > "$ROOT/.agents/state/meetings.jsonl" </dev/null
cat > "$ROOT/.agents/state/media.jsonl" </dev/null
cat > "$ROOT/.agents/state/approvals.jsonl" </dev/null
cat > "$ROOT/.agents/events.jsonl" </dev/null

for inbox in "${AGENT_ROLES[@]}"; do
  title="$(printf '%s' "$inbox" | awk '{ print toupper(substr($0,1,1)) substr($0,2) }')"
  cat > "$ROOT/.agents/inbox/$inbox.md" <<EOF
# $title Inbox

Queued, dispatched, in-progress, and blocked routes arrive here.

EOF
done

"$ROOT/scripts/log-event.sh" reset reset-agent-team-state "Reset agent-team runtime state" "$UPDATED"
printf "Agent-team runtime state reset in %s\n" "$ROOT"
