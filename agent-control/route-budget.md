# Route Budget

Route budgets prevent accidental delegation loops and unbounded task fan-out.

## Limits

- Max open routes: 12
- Max routes per human request: 8
- Max retries per route: 2
- Max route depth: 3
- Human approval required after repeated failure: yes

## Active Statuses

These count toward the open route budget:

- queued
- dispatching
- dispatched
- in-progress
- blocked

## Escalation Conditions

Escalate to the human when:

- the same route is blocked twice
- more than 12 routes are open
- a route would create a fourth delegation level
- ownership conflicts cannot be resolved by the Orchestrator
- validation, reviewer, or security blocks the same task twice

## Recovery Command

Use `scripts/recover-stale-routes.sh --dry-run` to preview stale route recovery.
Use `scripts/recover-stale-routes.sh --apply` to requeue stale active routes inside retry budget and block stale routes after retry budget is exhausted.
