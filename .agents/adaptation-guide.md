# Adaptation Guide

Use this guide to adapt the team to different coding projects without creating a new role for every stack.

## Project Type Routing

| Project Type | Extra roles to involve early |
| --- | --- |
| Web app | product, design, frontend, backend, qa, security, docs |
| API/service | product, cto, backend, data, devops, qa, security, performance |
| Mobile app | product, design, frontend, qa, performance, docs |
| CLI/tooling | product, cto, backend, qa, docs, devops |
| Data/analytics | product, data, backend, security, performance, qa |
| AI/agent app | product, research, cto, backend, qa, security, performance |
| Library/SDK | product, cto, qa, docs, performance, integration |
| Infrastructure | cto, devops, security, qa, docs, validation |

## Adaptation Rules

- Do not activate every specialist for every task.
- Route Research when the team lacks stack knowledge.
- Route Performance only when latency, memory, load, bundle size, query speed, or runtime cost matters.
- Route Docs when behavior becomes user-visible, operational, or release-impacting.
- Route QA before Validation when automation must be created or updated.
- Route Validation after implementation evidence exists.
