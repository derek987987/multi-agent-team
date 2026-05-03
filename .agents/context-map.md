# Context Map

This file defines what context each role should load so the team can handle unfamiliar projects without dumping every file into every agent.

## Principles

- Start from `.agents/project-target.md`, `.agents/brief.md`, `.agents/task-board.md`, `.agents/company/agent-profiles.jsonl`, and the assigned inbox route.
- Load role-specific prompts, skills, memory, config, schemas, and ownership rules before acting.
- Ask Research to inspect unfamiliar frameworks, libraries, APIs, standards, or external docs.
- Keep route responses concise; link to files and logs instead of pasting raw terminal output.
- Route heavy investigation to Research or the relevant specialist so Orchestrator context stays clean.

## Per-Role Context

| Role | Extra context to prefer |
| --- | --- |
| product | `product-requirements`, user journeys, acceptance risks |
| research | external docs, repo docs, dependency docs, comparison notes |
| cto | architecture, decisions, research notes, constraints |
| design | product requirements, design notes, current UI conventions |
| pm | architecture, decisions, task template, readiness/done gates |
| frontend | design notes, product requirements, API contracts |
| backend | architecture, data contracts, security constraints |
| data | schema/migration files, analytics contracts, privacy notes |
| devops | setup scripts, CI, deploy config, secrets policy |
| qa | product requirements, task board, fixtures, smoke/regression plan |
| performance | quality gates, benchmarks, profiling evidence, architecture risks |
| reviewer | diff, task board, architecture, tests, ownership |
| security | data flow, trust boundaries, secrets policy, auth paths |
| docs | release notes, task board, validation evidence |
| validation | QA plan, quality gates, implementation diff, reports |
| integration | review/security/validation evidence, release notes |

For meeting-driven work, every role should also load the related `.agents/meetings/M*.md`, linked media records in `.agents/media/manifest.jsonl`, and any approval records in `.agents/approvals.jsonl`.

## Context Handoff Contract

When a route creates downstream work, include:

- source files or docs to read
- decisions already made
- assumptions that are still open
- commands already run
- meeting ID, decision ID, and media attachment IDs when relevant
- expected output file
- completion evidence required
