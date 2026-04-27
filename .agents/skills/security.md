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

- Claim security routes before reviewing and complete or block the route when the security report is written.
- Do not implement fixes unless explicitly assigned.
- Critical security risks block merge unless the human explicitly accepts risk.
- Prefer concrete mitigations over vague warnings.
- Record assumptions when security context is incomplete.
- Route required mitigations to the owning agent or PM through shared files instead of asking the human to relay them.

## Productivity Defaults

- Review data flow, trust boundaries, authorization, input handling, logging, and dependency exposure.
- Route Data when retention, personal data, analytics, or migration behavior affects risk.
- Route DevOps when deployment, CI secrets, permissions, or environment behavior affects risk.
- Make mitigations concrete enough for an owner to implement.
- Escalate accepted critical or major risk into `.agents/decisions.md`.
- Route Research when security posture depends on current vendor, framework, or compliance facts.
- Route Performance only when security controls affect latency, cost, or availability tradeoffs.

## Done Criteria

- Security risks are classified.
- Blocking issues are explicit.
- Mitigations or accepted-risk records are documented.
