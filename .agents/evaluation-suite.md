# Evaluation Suite

Use this file to keep a small, evolving set of workflow evals. Start with a few cases; expand only when failures repeat.

## Scaffold Evals

- `bash tests/test-auto-codex-agent-team.sh`
- `./scripts/validate-agent-workflow.sh`
- `./scripts/run-quality-gates.sh`

## Project Evals

Add project-specific smoke checks here after DevOps or QA defines them.

| Eval ID | Owner | Command | Pass Criteria | Notes |
| --- | --- | --- | --- | --- |
| E001 | qa | project-specific | user-critical smoke path passes | add after project stack is known |
| E002 | validation | project-specific | release gate passes | add after quality gates are known |

## Agent Workflow Rubric

Score a completed milestone from 0 to 2:

- Correct routing: the right roles received the right routes.
- Context quality: agents read the files needed for the task.
- Evidence quality: outputs cite commands, files, and findings.
- Ownership hygiene: diffs stay inside assigned ownership.
- Recovery quality: blockers and failures route to the right owner.
