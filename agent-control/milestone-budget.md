# Milestone Budget

Budgets prevent multi-agent work from expanding without human approval.

## Defaults

- Max active implementation branches: 4
- Max open routes: 12
- Max validation retries per task: 2
- Max reviewer/security block cycles per task: 2
- Max active tasks per implementation role: 3

## Escalate To Human

Escalate when:

- any budget is exceeded
- the same task is blocked twice by validation, reviewer, or security
- the Orchestrator needs to create more than 8 routes for one request
- implementation requires changing ownership boundaries

