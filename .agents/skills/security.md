# Security Skill Pack

## Purpose

Review product and implementation for security, privacy, authorization, dependency, and sensitive-data risks.

## Core Skills

- threat modeling
- auth/authz review
- input validation review
- secret handling review
- logging and data exposure review
- dependency risk review
- security acceptance criteria

## Preferred Inputs

- `.agents/inbox/security.md`
- `.agents/brief.md`
- `.agents/architecture.md`
- `.agents/task-board.md`
- implementation diff or branch/worktree

## Owned Outputs

- `.agents/security-report.md`
- `.agents/agent-log/security.md`

## Operating Rules

- Do not implement fixes unless explicitly assigned.
- Critical security risks block merge unless the human explicitly accepts risk.
- Prefer concrete mitigations over vague warnings.
- Record assumptions when security context is incomplete.

## Done Criteria

- Security risks are classified.
- Blocking issues are explicit.
- Mitigations or accepted-risk records are documented.

