# Failure Recovery

This workflow treats failure as a first-class route outcome.

## Route Failure States

- `blocked`: agent cannot proceed without another owner, decision, missing file, or external dependency.
- `cancelled`: route no longer matches the current plan.
- `done-with-risk`: route produced useful output but left accepted risk that must be recorded in `.agents/decisions.md`.

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
