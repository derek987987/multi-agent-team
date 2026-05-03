# Route Reports

This directory stores one durable report per routed work item.

Route report files use the route ID as the filename, for example `R001.md`.
The tmux dispatcher only notifies a role that a route is ready; the route report is the canonical handoff packet and completion evidence.

Use `scripts/route-status.sh R001` for the current owner, status, report path, output refs, and next action. Completion should run `scripts/complete-route.sh R001 <role> "<summary>" --report .agents/routes/R001.md --output-ref <path>` for every meaningful output produced.

Use `scripts/recover-stale-routes.sh --apply` when queued, dispatching, dispatched, or in-progress routes exceed stale thresholds. Recovery appends `### Recovery Event` evidence to the route report, increments `Attempt` when requeueing, and blocks routes that have exhausted `.agents/route-budget.md`.
