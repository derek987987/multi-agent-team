#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_PATH="${AGENT_TEAM_DB_PATH:-$ROOT/agent-control/state/workflow.sqlite3}"

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  init
  upsert-route <route-id> [fields]
  claim-route <route-id> <actor>
  update-status <route-id> <status> [fields]
  record-run <route-id> <actor> [fields]
  route-status <route-id>
  check
EOF
}

require_sqlite() {
  if ! command -v sqlite3 >/dev/null 2>&1; then
    printf "sqlite3 is required for the structured workflow store.\n" >&2
    exit 1
  fi
}

sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

sql_value() {
  printf "'%s'" "$(sql_escape "$1")"
}

sql_int() {
  local value="${1:-0}"
  case "$value" in
    ''|*[!0-9-]*)
      printf "0"
      ;;
    *)
      printf "%s" "$value"
      ;;
  esac
}

ensure_db() {
  require_sqlite
  mkdir -p "$(dirname "$DB_PATH")"
  sqlite3 "$DB_PATH" >/dev/null <<'SQL'
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS routes (
  route_id TEXT PRIMARY KEY,
  title TEXT NOT NULL DEFAULT '',
  from_actor TEXT NOT NULL DEFAULT '',
  to_role TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT '',
  priority TEXT NOT NULL DEFAULT '',
  related_task TEXT NOT NULL DEFAULT '',
  meeting_id TEXT NOT NULL DEFAULT '',
  decision_id TEXT NOT NULL DEFAULT '',
  attempt INTEGER NOT NULL DEFAULT 0,
  route_depth INTEGER NOT NULL DEFAULT 1,
  target_project TEXT NOT NULL DEFAULT '',
  worktree_or_branch TEXT NOT NULL DEFAULT '',
  files_or_modules TEXT NOT NULL DEFAULT '',
  context_refs TEXT NOT NULL DEFAULT '',
  output_schema TEXT NOT NULL DEFAULT '',
  risk_flags TEXT NOT NULL DEFAULT '',
  human_approval_required TEXT NOT NULL DEFAULT 'no',
  approval_ref TEXT NOT NULL DEFAULT '',
  review_required TEXT NOT NULL DEFAULT 'no',
  review_ref TEXT NOT NULL DEFAULT '',
  report TEXT NOT NULL DEFAULT '',
  output_refs TEXT NOT NULL DEFAULT '',
  run_id TEXT NOT NULL DEFAULT '',
  claimed_by TEXT NOT NULL DEFAULT '',
  claimed_at TEXT NOT NULL DEFAULT '',
  completed_by TEXT NOT NULL DEFAULT '',
  completed_at TEXT NOT NULL DEFAULT '',
  blocked_reason TEXT NOT NULL DEFAULT '',
  created TEXT NOT NULL DEFAULT '',
  updated TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS route_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  route_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  actor TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT '',
  note TEXT NOT NULL DEFAULT '',
  created TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS route_runs (
  run_id TEXT PRIMARY KEY,
  route_id TEXT NOT NULL,
  actor TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT '',
  started_at TEXT NOT NULL DEFAULT '',
  ended_at TEXT NOT NULL DEFAULT '',
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  model TEXT NOT NULL DEFAULT '',
  input_tokens INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  cost_cents INTEGER NOT NULL DEFAULT 0,
  exit_code INTEGER NOT NULL DEFAULT 0,
  summary TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS tasks (
  task_id TEXT PRIMARY KEY,
  title TEXT NOT NULL DEFAULT '',
  owner TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT '',
  route_id TEXT NOT NULL DEFAULT '',
  created TEXT NOT NULL DEFAULT '',
  updated TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS route_events_route_idx ON route_events(route_id, created);
CREATE INDEX IF NOT EXISTS route_runs_route_idx ON route_runs(route_id);
CREATE INDEX IF NOT EXISTS routes_status_idx ON routes(status, to_role);
SQL
}

append_event_sql() {
  local route_id="$1"
  local event_type="$2"
  local actor="$3"
  local status="$4"
  local note="$5"
  local created="$6"
  printf "INSERT INTO route_events(route_id,event_type,actor,status,note,created) VALUES(%s,%s,%s,%s,%s,%s);" \
    "$(sql_value "$route_id")" \
    "$(sql_value "$event_type")" \
    "$(sql_value "$actor")" \
    "$(sql_value "$status")" \
    "$(sql_value "$note")" \
    "$(sql_value "$created")"
}

cmd="${1:-}"
if [ -z "$cmd" ]; then
  usage
  exit 1
fi
shift || true

case "$cmd" in
  init)
    ensure_db
    printf "Initialized %s\n" "$DB_PATH"
    ;;

  upsert-route)
    if [ "$#" -lt 1 ]; then
      usage
      exit 1
    fi
    ensure_db
    route_id="$1"
    shift
    title=""
    from_actor=""
    to_role=""
    status="queued"
    priority=""
    related_task=""
    meeting_id=""
    decision_id=""
    attempt="0"
    route_depth="1"
    target_project=""
    worktree_or_branch="none"
    files_or_modules="none"
    context_refs="none"
    output_schema="none"
    risk_flags="none"
    human_approval_required="no"
    review_required="no"
    report="agent-control/routes/$route_id.md"
    created="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    updated="$created"

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --title) title="${2:-}"; shift 2 ;;
        --from) from_actor="${2:-}"; shift 2 ;;
        --to) to_role="${2:-}"; shift 2 ;;
        --status) status="${2:-}"; shift 2 ;;
        --priority) priority="${2:-}"; shift 2 ;;
        --related-task) related_task="${2:-}"; shift 2 ;;
        --meeting) meeting_id="${2:-}"; shift 2 ;;
        --decision) decision_id="${2:-}"; shift 2 ;;
        --attempt) attempt="${2:-0}"; shift 2 ;;
        --route-depth) route_depth="${2:-1}"; shift 2 ;;
        --target-project) target_project="${2:-}"; shift 2 ;;
        --worktree) worktree_or_branch="${2:-none}"; shift 2 ;;
        --files) files_or_modules="${2:-none}"; shift 2 ;;
        --context) context_refs="${2:-none}"; shift 2 ;;
        --output-schema) output_schema="${2:-none}"; shift 2 ;;
        --risk-flags) risk_flags="${2:-none}"; shift 2 ;;
        --approval-required) human_approval_required="${2:-no}"; shift 2 ;;
        --review-required) review_required="${2:-no}"; shift 2 ;;
        --report) report="${2:-}"; shift 2 ;;
        --created) created="${2:-$created}"; shift 2 ;;
        --updated) updated="${2:-$updated}"; shift 2 ;;
        *)
          printf "Unexpected upsert-route argument: %s\n" "$1" >&2
          exit 1
          ;;
      esac
    done

    sqlite3 "$DB_PATH" "$(cat <<SQL
BEGIN IMMEDIATE;
INSERT INTO routes(
  route_id,title,from_actor,to_role,status,priority,related_task,meeting_id,decision_id,
  attempt,route_depth,target_project,worktree_or_branch,files_or_modules,context_refs,
  output_schema,risk_flags,human_approval_required,review_required,report,created,updated
) VALUES(
  $(sql_value "$route_id"),$(sql_value "$title"),$(sql_value "$from_actor"),$(sql_value "$to_role"),
  $(sql_value "$status"),$(sql_value "$priority"),$(sql_value "$related_task"),$(sql_value "$meeting_id"),
  $(sql_value "$decision_id"),$(sql_int "$attempt"),$(sql_int "$route_depth"),$(sql_value "$target_project"),
  $(sql_value "$worktree_or_branch"),$(sql_value "$files_or_modules"),$(sql_value "$context_refs"),
  $(sql_value "$output_schema"),$(sql_value "$risk_flags"),$(sql_value "$human_approval_required"),
  $(sql_value "$review_required"),$(sql_value "$report"),$(sql_value "$created"),$(sql_value "$updated")
)
ON CONFLICT(route_id) DO UPDATE SET
  title=excluded.title,
  from_actor=excluded.from_actor,
  to_role=excluded.to_role,
  status=excluded.status,
  priority=excluded.priority,
  related_task=excluded.related_task,
  meeting_id=excluded.meeting_id,
  decision_id=excluded.decision_id,
  attempt=excluded.attempt,
  route_depth=excluded.route_depth,
  target_project=excluded.target_project,
  worktree_or_branch=excluded.worktree_or_branch,
  files_or_modules=excluded.files_or_modules,
  context_refs=excluded.context_refs,
  output_schema=excluded.output_schema,
  risk_flags=excluded.risk_flags,
  human_approval_required=excluded.human_approval_required,
  review_required=excluded.review_required,
  report=excluded.report,
  updated=excluded.updated;
$(append_event_sql "$route_id" route-created "$from_actor" "$status" "$title" "$created")
COMMIT;
SQL
)"
    if [ -n "$related_task" ]; then
      sqlite3 "$DB_PATH" "$(cat <<SQL
INSERT INTO tasks(task_id,title,owner,status,route_id,created,updated)
VALUES($(sql_value "$related_task"),$(sql_value "$title"),$(sql_value "$to_role"),'routed',$(sql_value "$route_id"),$(sql_value "$created"),$(sql_value "$updated"))
ON CONFLICT(task_id) DO UPDATE SET
  title=excluded.title,
  owner=excluded.owner,
  status=excluded.status,
  route_id=excluded.route_id,
  updated=excluded.updated;
SQL
)"
    fi
    printf "Stored route %s\n" "$route_id"
    ;;

  claim-route)
    if [ "$#" -ne 2 ]; then
      usage
      exit 1
    fi
    ensure_db
    route_id="$1"
    actor="$2"
    updated="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    changes="$(sqlite3 "$DB_PATH" "$(cat <<SQL
BEGIN IMMEDIATE;
UPDATE routes
SET status='in-progress',
    claimed_by=$(sql_value "$actor"),
    claimed_at=$(sql_value "$updated"),
    updated=$(sql_value "$updated")
WHERE route_id=$(sql_value "$route_id")
  AND to_role=$(sql_value "$actor")
  AND status IN ('queued','dispatching','dispatched','acknowledged','in-progress');
SELECT changes();
$(append_event_sql "$route_id" route-claimed "$actor" in-progress "" "$updated")
COMMIT;
SQL
)" | tail -n 1)"
    if [ "$changes" != "1" ]; then
      current="$(sqlite3 -separator '|' "$DB_PATH" "SELECT to_role || '|' || status FROM routes WHERE route_id=$(sql_value "$route_id");")"
      if [ -z "$current" ]; then
        printf "Route not found in structured store: %s\n" "$route_id" >&2
      else
        printf "Route %s cannot be claimed by %s from structured state: %s\n" "$route_id" "$actor" "$current" >&2
      fi
      exit 1
    fi
    printf "Structured claim recorded for %s\n" "$route_id"
    ;;

  update-status)
    if [ "$#" -lt 2 ]; then
      usage
      exit 1
    fi
    ensure_db
    route_id="$1"
    status="$2"
    shift 2
    actor=""
    note=""
    approval_ref=""
    review_ref=""
    output_refs=""
    blocked_reason=""
    run_id=""
    updated="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --actor) actor="${2:-}"; shift 2 ;;
        --note) note="${2:-}"; shift 2 ;;
        --approval-ref) approval_ref="${2:-}"; shift 2 ;;
        --review-ref) review_ref="${2:-}"; shift 2 ;;
        --output-refs) output_refs="${2:-}"; shift 2 ;;
        --blocked-reason) blocked_reason="${2:-}"; shift 2 ;;
        --run-id) run_id="${2:-}"; shift 2 ;;
        --updated) updated="${2:-$updated}"; shift 2 ;;
        *)
          printf "Unexpected update-status argument: %s\n" "$1" >&2
          exit 1
          ;;
      esac
    done
    completed_sql=""
    if [ "$status" = "done" ]; then
      completed_sql=", completed_by=$(sql_value "$actor"), completed_at=$(sql_value "$updated")"
    fi
    sqlite3 "$DB_PATH" "$(cat <<SQL
BEGIN IMMEDIATE;
UPDATE routes SET
  status=$(sql_value "$status"),
  updated=$(sql_value "$updated"),
  approval_ref=CASE WHEN $(sql_value "$approval_ref") <> '' THEN $(sql_value "$approval_ref") ELSE approval_ref END,
  review_ref=CASE WHEN $(sql_value "$review_ref") <> '' THEN $(sql_value "$review_ref") ELSE review_ref END,
  output_refs=CASE WHEN $(sql_value "$output_refs") <> '' THEN $(sql_value "$output_refs") ELSE output_refs END,
  blocked_reason=CASE WHEN $(sql_value "$blocked_reason") <> '' THEN $(sql_value "$blocked_reason") ELSE blocked_reason END,
  run_id=CASE WHEN $(sql_value "$run_id") <> '' THEN $(sql_value "$run_id") ELSE run_id END
  $completed_sql
WHERE route_id=$(sql_value "$route_id");
$(append_event_sql "$route_id" "route-$status" "$actor" "$status" "$note" "$updated")
COMMIT;
SQL
)"
    printf "Updated structured route %s to %s\n" "$route_id" "$status"
    ;;

  record-run)
    if [ "$#" -lt 2 ]; then
      usage
      exit 1
    fi
    ensure_db
    route_id="$1"
    actor="$2"
    shift 2
    run_id=""
    status="succeeded"
    started_at=""
    ended_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    duration_seconds="0"
    model=""
    input_tokens="0"
    output_tokens="0"
    cost_cents="0"
    exit_code="0"
    summary=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --run-id) run_id="${2:-}"; shift 2 ;;
        --status) status="${2:-}"; shift 2 ;;
        --started-at) started_at="${2:-}"; shift 2 ;;
        --ended-at) ended_at="${2:-}"; shift 2 ;;
        --duration-seconds) duration_seconds="${2:-0}"; shift 2 ;;
        --model) model="${2:-}"; shift 2 ;;
        --input-tokens) input_tokens="${2:-0}"; shift 2 ;;
        --output-tokens) output_tokens="${2:-0}"; shift 2 ;;
        --cost-cents) cost_cents="${2:-0}"; shift 2 ;;
        --exit-code) exit_code="${2:-0}"; shift 2 ;;
        --summary) summary="${2:-}"; shift 2 ;;
        *)
          printf "Unexpected record-run argument: %s\n" "$1" >&2
          exit 1
          ;;
      esac
    done
    started_at="${started_at:-$ended_at}"
    run_id="${run_id:-RUN-$(date -u +"%Y%m%d%H%M%S")-$$}"
    sqlite3 "$DB_PATH" "$(cat <<SQL
BEGIN IMMEDIATE;
INSERT INTO route_runs(
  run_id,route_id,actor,status,started_at,ended_at,duration_seconds,model,
  input_tokens,output_tokens,cost_cents,exit_code,summary
) VALUES(
  $(sql_value "$run_id"),$(sql_value "$route_id"),$(sql_value "$actor"),$(sql_value "$status"),
  $(sql_value "$started_at"),$(sql_value "$ended_at"),$(sql_int "$duration_seconds"),$(sql_value "$model"),
  $(sql_int "$input_tokens"),$(sql_int "$output_tokens"),$(sql_int "$cost_cents"),$(sql_int "$exit_code"),
  $(sql_value "$summary")
)
ON CONFLICT(run_id) DO UPDATE SET
  status=excluded.status,
  ended_at=excluded.ended_at,
  duration_seconds=excluded.duration_seconds,
  model=excluded.model,
  input_tokens=excluded.input_tokens,
  output_tokens=excluded.output_tokens,
  cost_cents=excluded.cost_cents,
  exit_code=excluded.exit_code,
  summary=excluded.summary;
UPDATE routes SET run_id=$(sql_value "$run_id"), updated=$(sql_value "$ended_at") WHERE route_id=$(sql_value "$route_id");
$(append_event_sql "$route_id" route-run-recorded "$actor" "$status" "$summary" "$ended_at")
COMMIT;
SQL
)"
    printf "Recorded run %s for route %s\n" "$run_id" "$route_id"
    ;;

  route-status)
    if [ "$#" -ne 1 ]; then
      usage
      exit 1
    fi
    ensure_db
    sqlite3 "$DB_PATH" "SELECT status FROM routes WHERE route_id=$(sql_value "$1");"
    ;;

  check)
    ensure_db
    result="$(sqlite3 "$DB_PATH" "PRAGMA quick_check;")"
    if [ "$result" != "ok" ]; then
      printf "SQLite workflow store failed quick_check: %s\n" "$result" >&2
      exit 1
    fi
    printf "%s valid\n" "${DB_PATH#$ROOT/}"
    ;;

  *)
    printf "Unknown route-db command: %s\n" "$cmd" >&2
    usage
    exit 1
    ;;
esac
