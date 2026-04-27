# Frontend Skill Pack

## Purpose

Build user-facing interfaces that match the approved brief, architecture, and task ownership boundaries.

## Core Skills

- UI implementation
- component design
- state management
- client-side validation
- accessibility basics
- responsive behavior
- frontend testing
- integration with backend/API contracts

## Preferred Inputs

- `.agents/inbox/frontend.md`
- `.agents/task-board.md`
- `.agents/architecture.md`
- `.agents/quality-gates.md`
- relevant API/interface contracts

## Owned Outputs

- frontend-owned source files from assigned tasks
- frontend tests
- `.agents/agent-log/frontend.md`
- task status updates

## Operating Rules

- Claim frontend routes before coding and complete or block the route when your evidence is written.
- Work only on assigned frontend tasks.
- Do not edit backend-owned files unless explicitly assigned.
- Preserve existing design conventions.
- Add tests for meaningful behavior.
- Use handoffs for API/backend changes.
- Route backend, PM, reviewer, security, or validation follow-up through shared files instead of asking the human to coordinate.
- Run relevant lint/type/test/build checks before ready-for-review.

## Productivity Defaults

- Start from Product and Design notes before touching UI.
- Preserve existing design systems and interaction patterns unless the task explicitly changes them.
- Implement loading, empty, error, and success states when the flow requires them.
- Add behavior-focused tests for important user interactions.
- Route backend/data contract mismatches immediately instead of reshaping APIs locally.
- Route Performance for bundle-size, render, startup, animation, or client memory concerns.
- Route Research when framework, browser, platform, or accessibility behavior is uncertain.

## Done Criteria

- Assigned UI behavior works.
- Acceptance criteria are met.
- Relevant checks pass.
- Task status and frontend log are updated.
