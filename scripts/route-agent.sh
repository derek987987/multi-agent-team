#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

usage() {
  printf "Usage: %s <route-id> <to-role> <title> [related-task] [options]\n" "$(basename "$0")" >&2
  printf "Required unless --draft: --instruction, --expected-output, --validation\n" >&2
  printf "Example: %s R003 backend \"Implement task API\" T012 --from orchestrator --instruction \"Build API\" --expected-output \"implementation report\" --validation \"npm test\"\n" "$(basename "$0")" >&2
}

if [ "$#" -lt 3 ]; then
  usage
  exit 1
fi

ROUTE_ID="$1"
TO_ROLE="$2"
TITLE="$3"
FROM_ACTOR="orchestrator"
RELATED_TASK=""
MEETING_ID=""
DECISION_ID=""
PRIORITY="P2"
ATTEMPT="0"
ROUTE_DEPTH="1"
TARGET_PROJECT=""
WORKTREE_OR_BRANCH=""
FILES_OR_MODULES="none"
CONTEXT_REFS="none"
DEPENDS_ON_ROUTES="none"
BLOCKS_TASKS="none"
OUTPUT_SCHEMA="none"
RISK_FLAGS="none"
NEXT_OWNER=""
HUMAN_APPROVAL_REQUIRED="no"
INSTRUCTION=""
EXPECTED_OUTPUT=""
VALIDATION=""
DRAFT=0

if [ "$#" -gt 3 ]; then
  shift 3
  case "${1:-}" in
    --*) ;;
    *)
    RELATED_TASK="$1"
    shift
      ;;
  esac
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --meeting)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--meeting requires a value." >&2
          exit 1
        fi
        MEETING_ID="$2"
        shift 2
        ;;
      --from)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--from requires a value." >&2
          exit 1
        fi
        FROM_ACTOR="$2"
        shift 2
        ;;
      --decision)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--decision requires a value." >&2
          exit 1
        fi
        DECISION_ID="$2"
        shift 2
        ;;
      --priority)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--priority requires a value." >&2
          exit 1
        fi
        PRIORITY="$2"
        shift 2
        ;;
      --attempt)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--attempt requires a value." >&2
          exit 1
        fi
        ATTEMPT="$2"
        shift 2
        ;;
      --route-depth)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--route-depth requires a value." >&2
          exit 1
        fi
        ROUTE_DEPTH="$2"
        shift 2
        ;;
      --target-project)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--target-project requires a value." >&2
          exit 1
        fi
        TARGET_PROJECT="$2"
        shift 2
        ;;
      --worktree|--branch)
        if [ -z "${2:-}" ]; then
          printf '%s requires a value.\n' "$1" >&2
          exit 1
        fi
        WORKTREE_OR_BRANCH="$2"
        shift 2
        ;;
      --files|--files-or-modules)
        if [ -z "${2:-}" ]; then
          printf '%s requires a value.\n' "$1" >&2
          exit 1
        fi
        FILES_OR_MODULES="$2"
        shift 2
        ;;
      --context|--context-refs)
        if [ -z "${2:-}" ]; then
          printf '%s requires a value.\n' "$1" >&2
          exit 1
        fi
        CONTEXT_REFS="$2"
        shift 2
        ;;
      --depends-on)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--depends-on requires a value." >&2
          exit 1
        fi
        DEPENDS_ON_ROUTES="$2"
        shift 2
        ;;
      --blocks)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--blocks requires a value." >&2
          exit 1
        fi
        BLOCKS_TASKS="$2"
        shift 2
        ;;
      --output-schema)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--output-schema requires a value." >&2
          exit 1
        fi
        OUTPUT_SCHEMA="$2"
        shift 2
        ;;
      --risk-flags)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--risk-flags requires a value." >&2
          exit 1
        fi
        RISK_FLAGS="$2"
        shift 2
        ;;
      --next-owner)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--next-owner requires a value." >&2
          exit 1
        fi
        NEXT_OWNER="$2"
        shift 2
        ;;
      --approval-required|--human-approval-required)
        HUMAN_APPROVAL_REQUIRED="yes"
        shift
        ;;
      --instruction)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--instruction requires a value." >&2
          exit 1
        fi
        INSTRUCTION="$2"
        shift 2
        ;;
      --instruction-file)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--instruction-file requires a value." >&2
          exit 1
        fi
        if [ ! -f "$2" ]; then
          printf "Instruction file not found: %s\n" "$2" >&2
          exit 1
        fi
        INSTRUCTION="$(sed -n '1,200p' "$2")"
        shift 2
        ;;
      --expected-output)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--expected-output requires a value." >&2
          exit 1
        fi
        EXPECTED_OUTPUT="$2"
        shift 2
        ;;
      --validation)
        if [ -z "${2:-}" ]; then
          printf '%s\n' "--validation requires a value." >&2
          exit 1
        fi
        VALIDATION="$2"
        shift 2
        ;;
      --draft)
        DRAFT=1
        shift
        ;;
      *)
        printf "Unexpected argument: %s\n" "$1" >&2
        usage
        exit 1
        ;;
    esac
done
fi

INBOX="$ROOT/.agents/inbox/$TO_ROLE.md"
HANDOFFS="$ROOT/.agents/handoffs.md"
STATE="$ROOT/.agents/workflow-state.md"
ROUTES_JSONL="$ROOT/.agents/state/routes.jsonl"
ROUTE_DIR="$ROOT/.agents/routes"
ROUTE_REPORT="$ROUTE_DIR/$ROUTE_ID.md"
CREATED="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
UPDATED="$CREATED"
TARGET_PROJECT="${TARGET_PROJECT:-$(awk -F': ' '/^Path:/ { print $2; exit }' "$ROOT/.agents/project-target.md" 2>/dev/null || true)}"
TARGET_PROJECT="${TARGET_PROJECT:-$ROOT}"
NEXT_OWNER="${NEXT_OWNER:-$TO_ROLE}"
MAX_ROUTE_DEPTH="${MAX_ROUTE_DEPTH:-$(awk -F':[[:space:]]*' '/Max route depth:/ { print $2; exit }' "$ROOT/.agents/route-budget.md" 2>/dev/null || true)}"
MAX_ROUTE_DEPTH="${MAX_ROUTE_DEPTH:-3}"

case "$ROUTE_DEPTH" in
  ''|*[!0-9]*)
    printf "Route depth must be a number: %s\n" "$ROUTE_DEPTH" >&2
    exit 1
    ;;
esac

if [ "$ROUTE_DEPTH" -gt "$MAX_ROUTE_DEPTH" ]; then
  printf "Route depth %s exceeds max route depth %s. See .agents/route-budget.md.\n" "$ROUTE_DEPTH" "$MAX_ROUTE_DEPTH" >&2
  exit 1
fi

if [ "$DRAFT" -eq 0 ]; then
  missing=()
  [ -z "$INSTRUCTION" ] && missing+=("--instruction")
  [ -z "$EXPECTED_OUTPUT" ] && missing+=("--expected-output")
  [ -z "$VALIDATION" ] && missing+=("--validation")
  if [ "${#missing[@]}" -gt 0 ]; then
    printf "Non-draft routes require: %s\n" "${missing[*]}" >&2
    usage
    exit 1
  fi
else
  INSTRUCTION="${INSTRUCTION:-Draft route. Fill instruction before dispatch.}"
  EXPECTED_OUTPUT="${EXPECTED_OUTPUT:-Draft route. Fill expected output before dispatch.}"
  VALIDATION="${VALIDATION:-Draft route. Fill validation before dispatch.}"
fi

if [ ! -f "$INBOX" ]; then
  printf "Unknown role inbox: %s\n" "$INBOX" >&2
  printf "Create .agents/inbox/%s.md first or use one of the existing roles.\n" "$TO_ROLE" >&2
  exit 1
fi

if grep -R -qE "^(##|###)[[:space:]]+$ROUTE_ID([[:space:]-]|$)|^[|][[:space:]]*$ROUTE_ID[[:space:]]*[|]" \
  "$ROOT/.agents/inbox" "$HANDOFFS" "$STATE"; then
  printf "Route ID already exists: %s\n" "$ROUTE_ID" >&2
  exit 1
fi

mkdir -p "$ROUTE_DIR"
if [ -e "$ROUTE_REPORT" ]; then
  printf "Route report already exists: .agents/routes/%s.md\n" "$ROUTE_ID" >&2
  exit 1
fi

cat > "$ROUTE_REPORT" <<ROUTE
# $ROUTE_ID - $TITLE

Route ID: $ROUTE_ID
Status: queued
From: $FROM_ACTOR
To: $TO_ROLE
Priority: $PRIORITY
Created: $CREATED
Last updated: $UPDATED
Attempt: $ATTEMPT
Route depth: $ROUTE_DEPTH
Related task: $RELATED_TASK
Depends on routes: $DEPENDS_ON_ROUTES
Blocks tasks: $BLOCKS_TASKS
Meeting ID: $MEETING_ID
Decision ID: $DECISION_ID
Target project: $TARGET_PROJECT
Worktree or branch: ${WORKTREE_OR_BRANCH:-none}
Files or modules: $FILES_OR_MODULES
Context refs: $CONTEXT_REFS
Output schema: $OUTPUT_SCHEMA
Risk flags: $RISK_FLAGS
Human approval required: $HUMAN_APPROVAL_REQUIRED
Next owner: $NEXT_OWNER

## Instruction

$INSTRUCTION

## Expected Output

$EXPECTED_OUTPUT

## Validation / Done Criteria

$VALIDATION

## Dispatch Evidence

No dispatch yet.

## Completion

No completion yet.
ROUTE

cat >> "$INBOX" <<ROUTE

## $ROUTE_ID - $TITLE
Status: queued
From: $FROM_ACTOR
To: $TO_ROLE
Priority: $PRIORITY
Related task: $RELATED_TASK
Meeting ID: $MEETING_ID
Decision ID: $DECISION_ID
Created:
$CREATED
Last updated:
$UPDATED
Attempt: $ATTEMPT
Route depth: $ROUTE_DEPTH
Target project: $TARGET_PROJECT
Worktree or branch: ${WORKTREE_OR_BRANCH:-none}
Files / modules: $FILES_OR_MODULES
Context refs: $CONTEXT_REFS
Output schema: $OUTPUT_SCHEMA
Risk flags: $RISK_FLAGS
Human approval required: $HUMAN_APPROVAL_REQUIRED
Completion report: .agents/routes/$ROUTE_ID.md

Instruction:
$INSTRUCTION

Expected output:
$EXPECTED_OUTPUT

Validation / done criteria:
$VALIDATION

Response:
ROUTE

cat >> "$HANDOFFS" <<ROUTE

### $ROUTE_ID - $TITLE
Status: open
From: $FROM_ACTOR
To: $TO_ROLE
Date:
$CREATED
Related task: $RELATED_TASK
Meeting ID: $MEETING_ID
Decision ID: $DECISION_ID
Files / modules:
$FILES_OR_MODULES

Request:
See .agents/inbox/$TO_ROLE.md.

Context:
$CONTEXT_REFS

Acceptance criteria:
- $VALIDATION

Response:
ROUTE

tmp="$(mktemp)"
awk -v id="$ROUTE_ID" -v to="$TO_ROLE" -v task="$RELATED_TASK" -v title="$TITLE" '
  /^## Open Routes/ { in_open_routes = 1; print; next }
  /^## / && !/^## Open Routes/ { in_open_routes = 0 }
  BEGIN { inserted = 0 }
  in_open_routes && /^\| Route ID \| To \| Status \| Related Task \| Summary \|/ {
    print
    next
  }
  in_open_routes && /^\| --- \| --- \| --- \| --- \| --- \|/ && !inserted {
    print
    printf "| %s | %s | queued | %s | %s |\n", id, to, task, title
    inserted = 1
    next
  }
  { print }
' "$STATE" > "$tmp"
mv "$tmp" "$STATE"

printf '{"route_id":"%s","from":"%s","to":"%s","status":"queued","priority":"%s","attempt":%s,"route_depth":%s,"related_task":"%s","meeting_id":"%s","decision_id":"%s","title":"%s","target_project":"%s","report":"%s","created":"%s","updated":"%s"}\n' \
  "$(json_escape "$ROUTE_ID")" "$(json_escape "$FROM_ACTOR")" "$(json_escape "$TO_ROLE")" "$(json_escape "$PRIORITY")" "$ATTEMPT" "$ROUTE_DEPTH" "$(json_escape "$RELATED_TASK")" "$(json_escape "$MEETING_ID")" "$(json_escape "$DECISION_ID")" "$(json_escape "$TITLE")" "$(json_escape "$TARGET_PROJECT")" ".agents/routes/$ROUTE_ID.md" "$(json_escape "$CREATED")" "$(json_escape "$UPDATED")" >> "$ROUTES_JSONL"

"$ROOT/scripts/log-event.sh" route-created "$FROM_ACTOR" "Created route $ROUTE_ID for $TO_ROLE" "$TITLE" "$ROUTE_ID"
"$ROOT/scripts/check-route-budget.sh" >/dev/null
printf "Created route %s for %s\n" "$ROUTE_ID" "$TO_ROLE"
