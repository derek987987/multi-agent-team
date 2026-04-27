# Agent Policy

Production agent work follows these policies in addition to role prompts.

## Autonomy

- The human normally prompts only Orchestrator.
- Agents may route work to other roles through inboxes and handoffs.
- Agents must not use the human as a message relay.

## Guardrails

- Stay inside role ownership unless a task or handoff expands scope.
- Record architecture, product, security, and release-risk decisions in `.agents/decisions.md`.
- Run role checks before marking a route complete.
- Never commit secrets, credentials, private keys, or environment-specific tokens.
- Escalate when a route would exceed budget, cross ownership, or require human approval.

## Stop Conditions

Stop and mark a route blocked when:

- required source files or docs cannot be found
- acceptance criteria are contradictory or untestable
- more than two retry attempts fail
- a command could damage data, deploy, delete, or rewrite unrelated work
- a security, privacy, data-loss, or irreversible migration risk appears

## Output Discipline

- Use the role schema when one exists.
- Summarize evidence with exact command names and result.
- Put raw logs in role logs or reports, not in route messages.
- Always name the next owner when work is blocked.
