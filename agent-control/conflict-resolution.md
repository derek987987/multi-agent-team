# Conflict Resolution Protocol

Use this when agents disagree, work overlaps, validation blocks a task, or the current plan becomes unsafe.

## Conflict Types

| Type | Examples | First Responder |
| --- | --- | --- |
| ownership conflict | two agents need the same file | Orchestrator |
| architecture conflict | implementation contradicts architecture | CTO |
| scope conflict | task does not match brief | Orchestrator, then PM |
| validation conflict | agent says done but checks fail | Validation |
| security conflict | unsafe auth, secrets, data exposure | Security |
| merge conflict | branches cannot merge cleanly | Integration |

## Protocol

1. Mark affected task(s) `blocked`.
2. Add or update an entry in `.agents/handoffs.md`.
3. Record the conflict in the relevant role log.
4. Route to the first responder using `.agents/inbox/<role>.md`.
5. Do not continue implementation on affected files until resolved.
6. If scope, architecture, or risk changes materially, record a decision in `.agents/decisions.md`.
7. PM updates task ownership/dependencies after resolution.

## Resolution Record Template

```md
### Conflict C000 - Short Title
Status: open | resolved | accepted-risk
Type:
Detected by:
Date:
Affected tasks:
Affected files/modules:

Problem:

Decision:

Follow-up routes:
- 

Validation:
```

