# Failure Recovery

This workflow treats failure as a first-class route outcome.

## Route Failure States

- `blocked`: agent cannot proceed without another owner, decision, missing file, or external dependency.
- `cancelled`: route no longer matches the current plan.
- `done-with-risk`: route produced useful output but left accepted risk that must be recorded in `agent-control/decisions.md`.

## Retry Policy

- Try a failing command once after correcting an obvious local issue.
- After two failed attempts, route the blocker to the owner most likely to fix root cause.
- Do not loop between the same two agents without PM or Orchestrator intervention.

## Recovery Owners

| Failure | Route to |
| --- | --- |
| unclear user value or scope | product |
| missing external facts or framework docs | research |
| architecture contradiction | cto |
| ambiguous UX state | design |
| task dependency conflict | pm |
| data or migration risk | data |
| setup, CI, environment, deploy failure | devops |
| flaky or missing regression test | qa |
| performance regression | performance |
| security/privacy issue | security |
| docs or release-note gap | docs |
| merge conflict or integration order issue | integration |

## Evidence Required

Every blocker should include:

- route ID
- failing command or missing artifact
- current owner
- suspected next owner
- files inspected
- next action requested

## Stale Route Recovery

Run `scripts/recover-stale-routes.sh --dry-run` before changing state. Run `scripts/recover-stale-routes.sh --apply` when recovery should proceed automatically.

Recovery behavior:

- stale routes inside retry budget are requeued with `Attempt` incremented
- stale routes at retry budget are blocked
- active routes with pane evidence of Codex transport/session failure are recovered using `AGENT_TEAM_FAILED_SESSION_MINUTES`, default `5`, instead of waiting for the broad in-progress timeout
- routes blocked by recoverable dispatch infrastructure, such as missing tmux sessions or tmux delivery timeouts, are requeued using `AGENT_TEAM_BLOCKED_COMMUNICATION_MINUTES`, default `5`, so communication failures do not become permanent manual stops
- `scripts/watch-routes.sh` runs this recovery pass automatically before dispatch unless `AGENT_TEAM_AUTO_RECOVER_STALE=0`
- `scripts/heartbeat-routes.sh` also runs recovery before dispatch by default; use `--no-recover-stale` or `AGENT_TEAM_AUTO_RECOVER_STALE=0` for diagnostic scans
- route reports receive `### Recovery Event` evidence
- pane evidence is captured when a tmux session is supplied
