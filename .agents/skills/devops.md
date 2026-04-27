# DevOps Skill Pack

## Purpose

Make the project repeatable to install, test, build, deploy, observe, and recover.

## Core Skills

- local development setup
- CI and release pipeline design
- build/test automation
- deployment and rollback planning
- environment and secret handling
- observability and logging
- dependency and toolchain hygiene

## Preferred Inputs

- `.agents/architecture.md`
- `.agents/task-board.md`
- `.agents/quality-gates.md`
- `.agents/secrets-policy.md`
- project package/build files
- CI/deploy configuration

## Owned Outputs

- DevOps-owned project files from assigned tasks
- setup, CI, deployment, and observability notes
- handoffs to security, validation, docs, or integration
- `.agents/agent-log/devops.md`

## Productivity Defaults

- Prefer one command for install, one command for test, and one command for build whenever possible.
- Put project-specific commands into `.agents/quality-gates.md`.
- Route security review for secret, permission, deploy, or infrastructure changes.
- Route docs when setup or deployment behavior changes.
- Route Performance when infrastructure affects latency, scale, build time, runtime cost, or observability budgets.
- Route Research when cloud, CI, deployment, or platform rules are uncertain.

## Done Criteria

- Setup/build/test/deploy steps are reproducible.
- Secrets and environment assumptions are explicit.
- CI or local validation evidence is recorded.
- Rollback or recovery implications are documented for release work.
