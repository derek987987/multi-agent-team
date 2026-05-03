# Workflow Routing And Transition Audit

Date: 2026-05-04

## Scope

This audit reviews the current tmux/Codex multi-agent workflow, especially:

- route creation, dispatch, claim, completion, and stale handling
- prompt delivery into role tmux panes
- role-to-role transition quality
- per-agent missing attributes
- reporting and traceability gaps
- gaps between this local workflow and current external multi-agent guidance

No workflow behavior was changed in this pass.

## Current Strengths

- The workflow already has a clear supervisor-style control plane: Orchestrator receives human work and routes via `.agents/inbox/<role>.md`, `.agents/handoffs.md`, `.agents/workflow-state.md`, and `.agents/state/*.jsonl`.
- Roles are centralized in `scripts/agent-roles.sh`, and startup scripts auto-launch role-specific Codex sessions.
- `scripts/dispatch-routes.sh` now sends literal text and `C-m`, which directly addresses the earlier failure where prompt text appeared in the pane but was not submitted.
- Role prompts, skills, memory files, ownership files, and quality gates exist for 17 roles.
- Research, Performance, QA, Security, Validation, Reviewer, Docs, and Integration are first-class roles rather than ad hoc work.
- There are useful guardrail-like scripts: `check-ownership.sh`, `check-route-budget.sh`, `check-stale-routes.sh`, `check-agent-config.sh`, `check-secrets.sh`, `check-memory.sh`, `validate-structured-state.sh`, and `run-quality-gates.sh`.

## External Research Summary

Sources checked:

- OpenAI Agents SDK handoffs: handoffs support typed metadata such as reason, language, priority, or summary; the SDK validates handoff JSON and can filter what history the receiving agent sees. Source: https://openai.github.io/openai-agents-python/handoffs/
- OpenAI Agents SDK tracing: production workflows benefit from end-to-end traces with spans for agents, tool calls, guardrails, handoffs, and custom events. Source: https://github.com/openai/openai-agents-python/blob/main/docs/tracing.md
- OpenAI Agents SDK guardrails: guardrails have workflow boundaries; tool-level guardrails are needed when checks must run around each delegated tool call rather than only the first input or final output. Source: https://openai.github.io/openai-agents-python/guardrails/
- OpenAI practical guide to building agents: agent runs need exit conditions, structured outputs, failure thresholds, and human intervention for high-risk or repeated-failure cases. Source: https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf
- Anthropic multi-agent research system: a lead agent coordinates specialized subagents, subagents work in parallel, and outputs return to the lead for synthesis. Source: https://www.anthropic.com/engineering/multi-agent-research-system
- LangGraph supervisor and command model: supervisor systems coordinate specialized agents, control message history, persist memory, and combine state updates with routing decisions. Sources: https://langchain-ai.github.io/langgraphjs/reference/modules/langgraph-supervisor.html and https://langchain-ai.github.io/langgraphjs/reference/classes/langgraph.Command.html
- Agent Protocol: production agent systems expose runs, threads, agent schemas, background executions, concurrency controls, and persisted thread state/history. Source: https://langchain-ai.github.io/agent-protocol/
- Microsoft AutoGen teams: teams expose participants, custom message/event types, termination conditions, max turns, handoff termination, and optional team event streams. Source: https://microsoft.github.io/autogen/stable/reference/python/autogen_agentchat.teams.html

Research inference:

The local workflow already chose a good file-backed supervisor model. Main gap is not lack of roles. Main gap is that route metadata, acknowledgements, status transitions, and completion reports are still mostly markdown conventions and tmux best effort. Production-style handoffs need typed envelopes, explicit ack/lease/heartbeat, enforced state consistency, and traceable output artifacts.

## Critical Findings

### F001 - Route Dispatch Has No Acknowledgement

Severity: critical

Evidence:

- `scripts/dispatch-routes.sh` sends the prompt to `"$SESSION:$role"` and submits `C-m`, then immediately marks the route dispatched.
- It does not wait for the role to claim the route.
- It does not verify the Codex pane is alive, not blocked, not at a prompt requiring approval, and not in a failed process state.
- It does not store `last_dispatch_at`, `last_ack_at`, `attempt`, `lease_expires_at`, or target pane identity.

Impact:

A route can show `dispatched` even if the receiving role never actually starts. This is the direct class of failure the user saw before.

Recommendation:

Add a dispatch acknowledgement loop:

1. Before send: verify tmux window exists and contains a live Codex process.
2. Send route prompt plus newline.
3. Mark route as `dispatching`, not `dispatched`.
4. Poll `.agents/state/routes.jsonl` or inbox status for `in-progress` from `claim-route.sh`.
5. If not claimed within a short timeout, capture the pane tail, write a blocked dispatch event, and requeue/escalate.

### F002 - Route Schema Is Too Thin For Reliable Handoffs

Severity: critical

Evidence:

- `.agents/route-schema.md` only defines status, from/to, task, meeting/decision, created, instruction, output, validation, and response.
- Missing fields include priority, predecessor route, downstream owner, attempt count, route depth, due/stale deadlines, target project path, branch/worktree, files/modules, source artifacts, output schema, report path, validation commands, risk flags, and next owner.

Impact:

Agents receive a markdown instruction but not a durable work contract. Downstream agents must infer too much from context files.

Recommendation:

Define a strict route envelope and make every route include:

- `route_id`
- `status`
- `from_role`
- `to_role`
- `priority`
- `created_at`
- `last_updated_at`
- `attempt`
- `route_depth`
- `related_task`
- `depends_on_routes`
- `blocks_tasks`
- `target_project`
- `worktree_or_branch`
- `files_or_modules`
- `context_refs`
- `decision_refs`
- `approval_refs`
- `input_summary`
- `expected_outputs`
- `output_schema`
- `validation_commands`
- `risk_flags`
- `handoff_to`
- `completion_report`
- `next_owner`
- `human_approval_required`

### F003 - `route-agent.sh` Creates Unusable TBD Routes By Default

Severity: major

Evidence:

- `scripts/route-agent.sh` writes `Instruction: TBD`, `Expected output: TBD`, `Validation / done criteria: TBD`, `Context: TBD`, and `Acceptance criteria: - TBD`.

Impact:

If Orchestrator uses the script without editing the route body, role agents receive an assignment with no useful work contract. This weakens automation and increases idle/block behavior.

Recommendation:

Make `route-agent.sh` require either:

- `--instruction-file`
- `--instruction`
- `--expected-output`
- `--validation`
- `--context`

For interactive/manual convenience, allow `--draft` to create TBD routes, but prevent dispatch of TBD routes.

### F004 - Claim/Complete Scripts Do Not Enforce Valid State Transitions

Severity: major

Evidence:

- `claim-route.sh` searches all inboxes for a route ID and marks it `in-progress`.
- It does not require the claiming actor to match the route `To:` role.
- It can claim from any prior state.
- `complete-route.sh` marks done without checking done criteria, output files, response content, or role schema usage.
- Handoff status can become `accepted`, but `.agents/route-schema.md` route statuses do not include that value.

Impact:

Routes can be claimed or completed by the wrong role, completed without evidence, or drift between inbox, handoffs, workflow state, and JSONL mirrors.

Recommendation:

Add a route state machine:

- `queued -> dispatching -> dispatched -> acknowledged -> in-progress -> blocked | done | cancelled`
- `claim-route.sh` requires route target equals actor.
- `complete-route.sh` requires non-empty response, owned output path, command evidence, and schema marker.
- Blocked status gets its own script, for example `scripts/block-route.sh`.
- Handoff status values should be separate from route status values and validated.

### F005 - Structured State Validation Only Checks JSON Syntax

Severity: major

Evidence:

- `scripts/validate-structured-state.sh` checks whether JSONL files are syntactically valid JSON objects.
- It does not validate schema, required fields, status consistency, timestamp ordering, route ID uniqueness, or parity between markdown files and `.agents/state/routes.jsonl`.

Impact:

The workflow can look valid while route lifecycle state is contradictory.

Recommendation:

Extend validation to enforce:

- every route in inbox exists in workflow-state and state/routes
- every route ID is unique
- every route has required fields
- every active route has a valid timestamp and owner
- no route has TBD instruction/output/validation unless status is draft
- markdown status and latest JSONL status agree
- claimed role equals route target
- completed routes have output evidence

### F006 - Agent Profile Attributes Are Static And Too Shallow

Severity: major

Evidence:

- `.agents/company/agent-profiles.jsonl` contains role, display name, skills, paths, status, and load.
- Status/load are static text, not live telemetry.
- Missing live fields: tmux session/window, process status, last_seen_at, last_route_id, current_task, active_branch, max_parallel_routes, capabilities by project type, unavailable reason, and recovery owner.

Impact:

Orchestrator cannot reliably route based on real availability or health.

Recommendation:

Add `.agents/state/agents.jsonl` as live telemetry:

- `role`
- `session`
- `window`
- `pid_or_command`
- `status`
- `last_seen_at`
- `active_route`
- `active_task`
- `workdir`
- `target_project`
- `branch_or_worktree`
- `capacity`
- `blocked_reason`

Update this from startup, dispatch, claim, completion, and health-check scripts.

### F007 - Role Configs Do Not Enforce Output Schemas Or Reporting Contracts

Severity: major

Evidence from current config scan:

| Role | Config Includes Output Schema | Prompt Includes Output Schema | Prompt Mentions Workflow State | Prompt Mentions Handoffs |
| --- | --- | --- | --- | --- |
| orchestrator | no | yes | yes | yes |
| product | yes | yes | yes | no |
| research | yes | yes | no | no |
| cto | no | yes | no | yes |
| design | yes | yes | no | no |
| pm | no | yes | no | yes |
| frontend | no | yes | no | yes |
| backend | no | yes | no | yes |
| data | yes | yes | no | no |
| devops | yes | yes | no | no |
| qa | yes | yes | no | no |
| performance | yes | yes | no | no |
| validation | no | yes | no | no |
| reviewer | no | yes | no | yes |
| security | no | yes | no | yes |
| docs | yes | yes | no | no |
| integration | no | no | no | yes |

Impact:

`check-agent-config.sh` can pass while the role config omits important schema/reporting requirements. The launcher prompt asks every role to read shared files, but the per-role config and prompt files are not consistently enforceable.

Recommendation:

Add these keys to every `.agents/agent-config/<role>.yaml`:

- `output_schema`
- `owned_outputs`
- `route_input_schema`
- `completion_report_required`
- `handoff_targets`
- `reads_before_claim`
- `reads_before_complete`
- `live_state_fields`
- `max_parallel_routes`
- `dispatch_timeout_seconds`
- `stale_after`
- `escalation_owner`
- `can_create_routes`
- `can_update_workflow_state`
- `can_modify_task_board`

### F008 - Role Naming Is Inconsistent

Severity: major

Evidence:

- Central registry uses `frontend`, `backend`, `validation`, and similar role names.
- Some prompts/docs still say `frontend-agent`, `backend-agent`, `validation-agent`, etc.
- `scripts/create-agent-task.sh` example uses `frontend-agent`.

Impact:

Tasks may be assigned to names that do not match route windows, inboxes, ownership files, or agent configs. That can cause agents to ignore work or ownership checks to misfire.

Recommendation:

Normalize all owners to canonical role IDs from `scripts/agent-roles.sh`.

Allowed display labels can remain human friendly, but machine fields should use only:

`orchestrator`, `product`, `research`, `cto`, `design`, `pm`, `frontend`, `backend`, `data`, `devops`, `qa`, `performance`, `validation`, `reviewer`, `security`, `docs`, `integration`.

### F009 - Transition Reporting Is Spread Across Too Many Files Without A Single Route Report

Severity: major

Evidence:

Completion evidence may appear in:

- inbox `Response`
- `.agents/handoffs.md`
- role-owned report files
- `.agents/agent-log/<role>.md`
- `.agents/events.jsonl`
- `.agents/state/routes.jsonl`
- `.agents/task-board.md`

Impact:

Downstream agents may not know which file is authoritative for previous results. Orchestrator status summaries must merge too many partial sources.

Recommendation:

Add one required route report per completed route:

`.agents/routes/R000.md`

Schema:

- route metadata
- input context refs
- files changed or docs updated
- commands run
- outputs produced
- findings
- downstream handoffs created
- blocked/accepted risks
- next owner
- final recommendation

Then point inbox Response and handoffs to that report.

### F010 - Stale Route Handling Lacks Recovery Action

Severity: major

Evidence:

- `check-stale-routes.sh` detects stale queued/dispatched/in-progress routes.
- It does not create recovery routes, requeue, cancel, or capture tmux pane evidence.
- The previous UTC stale-route regression test is not present in this checkout.

Impact:

Stale detection can tell humans a route is stale, but the system does not recover smoothly.

Recommendation:

Add `scripts/recover-stale-routes.sh`:

1. find stale active routes
2. capture pane evidence
3. append route event with reason
4. re-dispatch if attempt budget remains
5. route to Orchestrator or PM when repeated
6. mark affected tasks blocked

Restore a regression test for UTC timestamp parsing.

## Missing Attributes By Agent

| Agent | Missing Attributes To Add |
| --- | --- |
| orchestrator | live dispatch ack status, route priority/depth, route id generator state, target pane health, route timeout, retry budget, active session/window map, route completeness validator, downstream ack summary, status dashboard contract |
| product | downstream consumers, approval impact, product-decision ID, scope-change severity, affected journeys, non-goal changes, acceptance-risk owner, human approval requirement |
| research | source type, access date, freshness risk, confidence, primary/secondary source split, inference flag, recommended owner, decision deadline, recheck trigger |
| cto | architecture version, affected modules, ownership map, interface/data contracts, risk class, validation implications by role, required specialist reviews, migration/security/perf flags |
| design | flow ID, screen/state matrix, accessibility checklist, responsive breakpoints, content source, asset/media refs, QA state coverage, frontend component ownership |
| pm | canonical owner IDs, dependency graph, route fanout plan, worktree/branch, task readiness status, acceptance evidence owner, validation command, blocker owner, review sequence |
| frontend | design handoff ref, API/data contract ref, accessibility evidence, visual/browser evidence path, state coverage, route report path, affected components, bundle/perf risk flag |
| backend | API contract ref, data contract/migration ref, auth/security flag, endpoint/test evidence, rollback notes, frontend consumer refs, performance/query risk flag |
| data | schema version, migration ID, rollback method, retention/privacy classification, seed/fixture refs, data-contract tests, query/index impact, analytics event taxonomy |
| devops | environment matrix, secret refs, CI job IDs, build cache/runner details, deploy target, rollback plan, observability/logging plan, release-risk owner |
| qa | acceptance coverage map, fixture/seed refs, smoke/regression split, flake risk, browser/device matrix, test command evidence, validation handoff refs |
| performance | metric name, baseline, threshold, environment, command/method, sample size, affected user flow, owner for optimization, release blocking level |
| validation | target branch/worktree/commit, acceptance criteria checked, command results, environment failure classification, evidence artifact, merge recommendation, unresolved finding IDs |
| reviewer | diff target, task/architecture refs, severity, owner per finding, re-review trigger, missing-test evidence, recommendation, architecture drift flag |
| security | threat assumptions, trust boundary, data classification, auth/authz impact, dependency/secrets check, severity, mitigation owner, accepted-risk approval ref |
| docs | source change refs, implemented behavior refs, validation evidence, user/developer/operator impact, release note status, migration/compatibility notes |
| integration | merge queue position, source branch/worktree, required reports, conflict plan, post-merge validation commands, rollback point, main branch status, final route report |

## Recommended Target Model

Use a file-backed supervisor model with deterministic route envelopes.

### Route Lifecycle

Recommended lifecycle:

1. `draft`
2. `queued`
3. `dispatching`
4. `dispatched`
5. `acknowledged`
6. `in-progress`
7. `blocked`, `done`, or `cancelled`

State transition rules:

- only Orchestrator/PM can create most routes
- only dispatcher can move `queued -> dispatching -> dispatched`
- only target role can move `dispatched -> acknowledged -> in-progress`
- only target role can complete, but completion requires route report and required checks
- only Orchestrator/PM/Integration can cancel active routes
- stale recovery can requeue only within retry budget

### Typed Route Envelope

Store canonical route data as JSONL first, then render markdown inbox views from that state.

Recommended canonical file:

`.agents/state/route-events.jsonl`

Derived views:

- `.agents/inbox/<role>.md`
- `.agents/handoffs.md`
- `.agents/workflow-state.md`
- `.agents/routes/R000.md`

### Dispatch/Ack Protocol

Dispatcher should send:

```text
Route R000 ready.
Run: ./scripts/claim-route.sh R000 <role>
Then read: .agents/routes/R000.md
When complete: ./scripts/complete-route.sh R000 <role> --report .agents/routes/R000.md
```

The route body should live in `.agents/routes/R000.md`, not only in the tmux prompt. Tmux prompt becomes a notification, not the source of truth.

### Reporting Protocol

Every role completion should write a route report and one structured event.

Minimum route report:

- what was requested
- what was changed or decided
- outputs produced
- checks run
- blockers or risks
- downstream routes/handoffs
- next owner

### Health And Recovery

Add:

- `scripts/agent-health.sh`
- `scripts/route-status.sh`
- `scripts/recover-stale-routes.sh`
- `scripts/block-route.sh`
- `scripts/validate-route-state.sh`

Health should inspect:

- tmux session/window exists
- pane process still alive
- Codex prompt not waiting for unsubmitted text
- active route has heartbeat within limit
- route status matches latest JSONL event

## Gap Matrix Against External Guidance

| External Pattern | Local State | Gap |
| --- | --- | --- |
| Typed handoff metadata | Markdown route fields exist | no enforced typed route envelope or local schema validation |
| Handoff input filtering/history control | Context map exists | no per-route context packet that filters what receiver must read |
| Tracing spans for agents/tools/handoffs | `.agents/events.jsonl` exists | no trace/span IDs, no parent-child route graph, no ack/complete spans |
| Runs and threads | tmux sessions and files exist | no run ID/thread ID for a route execution attempt |
| Agent introspection schemas | agent profiles and configs exist | no live schemas/capabilities/status endpoint or state file |
| Termination/stop conditions | policy and stale checker exist | no enforced max turns/actions/retries at route lifecycle level |
| Supervisor with state updates | Orchestrator and workflow-state exist | routing and state update are split across scripts and markdown patches |
| Team events | JSONL events exist | events are not validated and do not always include correlation/parent IDs |
| Human intervention | approvals file exists | repeated failures do not automatically escalate with context bundle |
| Memory/checkpointing | role memory files exist | no route-level checkpoint for interrupted handoffs |

## Prioritized Fix Plan

### P0 - Make Routing Reliable

1. Add `.agents/routes/` route report/envelope files.
2. Extend route schema with typed fields.
3. Update `route-agent.sh` to require real instruction/output/validation fields unless `--draft`.
4. Add dispatch ack loop and pane capture on failure.
5. Add `block-route.sh` and strict state transitions.
6. Add `validate-route-state.sh` for markdown/JSONL consistency.

### P1 - Make Agent Attributes Complete

1. Expand every agent config with output schema, handoff targets, state fields, stale timeout, max active routes, and escalation owner.
2. Normalize role IDs across docs, prompts, scripts, task examples, and workflow state.
3. Add `.agents/state/agents.jsonl` live telemetry.
4. Add Integration output schema.

Implementation status: completed in the P1 follow-up. Every `.agents/agent-config/<role>.yaml` now carries the required attribute set, active workflow docs use canonical role IDs, `.agents/state/agents.jsonl` plus `scripts/update-agent-state.sh` provide live role telemetry, and `.agents/schemas/integration-output.md` defines Integration completion output.

### P2 - Make Reporting Smooth

1. Require `.agents/routes/R000.md` completion reports.
2. Make `complete-route.sh` append summary and output refs to the route report.
3. Add `scripts/route-status.sh R000` to show current owner, status, evidence, and next action.
4. Update Orchestrator status requests to read route reports first.

### P3 - Make Recovery Automatic

1. Restore stale-route timestamp regression coverage.
2. Add stale route recovery command.
3. Add route retry attempt tracking.
4. Add route depth enforcement.
5. Add health checks for Codex pane readiness.

## Bottom Line

The local workflow is strong as a control-plane design, but it still treats route transfer as a tmux prompt delivery problem. It should treat route transfer as a durable state-machine problem where tmux is only a notification channel.

Most important change:

Make `.agents/routes/R000.md` plus `.agents/state/route-events.jsonl` the canonical route contract, add dispatch acknowledgements, and enforce claim/complete state transitions.
