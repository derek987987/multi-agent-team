#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/agent-roles.sh"
ROLE="${1:-}"

if [ -z "$ROLE" ]; then
  printf "Usage: %s <role>\n" "$(basename "$0")" >&2
  exit 1
fi

CONFIG="$ROOT/.agents/agent-config/$ROLE.yaml"
OWNERSHIP="$ROOT/.agents/ownership/$ROLE.paths"

if [ ! -f "$CONFIG" ]; then
  printf "Missing agent config: .agents/agent-config/%s.yaml\n" "$ROLE" >&2
  exit 1
fi

status=0

printf "== Agent Config Check: %s ==\n\n" "$ROLE"

get_scalar() {
  local key="$1"
  awk -F':[[:space:]]*' -v key="$key" '$1 == key { print $2; exit }' "$CONFIG"
}

list_values() {
  local section_name="$1"
  awk -v section_name="$section_name" '
    $0 ~ "^" section_name ":" { section=1; next }
    /^[a-zA-Z_]+:/ { section=0 }
    section && /^[[:space:]]+- / { print substr($0, index($0, "- ") + 2) }
  ' "$CONFIG"
}

check_existing_path() {
  local label="$1"
  local path="$2"
  [ -z "$path" ] && return 0
  case "$path" in
    *"*"*|*"<"*) return 0 ;;
  esac
  if [ ! -e "$ROOT/$path" ]; then
    printf "%s missing: %s\n" "$label" "$path"
    status=1
  fi
}

if ! is_agent_role "$ROLE"; then
  printf "Unknown role: %s\n" "$ROLE"
  status=1
fi

if ! grep -qE "^role:[[:space:]]*$ROLE$" "$CONFIG"; then
  printf "Config role does not match %s\n" "$ROLE"
  status=1
fi

for section in \
  required_reads \
  allowed_paths \
  required_checks \
  owned_outputs \
  handoff_targets \
  reads_before_claim \
  reads_before_complete \
  live_state_fields; do
  if ! grep -qE "^$section:" "$CONFIG"; then
    printf "Missing section: %s\n" "$section"
    status=1
  fi
done

for scalar in \
  output_schema \
  route_input_schema \
  completion_report_required \
  max_parallel_routes \
  dispatch_timeout_seconds \
  stale_after \
  escalation_owner \
  can_create_routes \
  can_update_workflow_state \
  can_modify_task_board; do
  if [ -z "$(get_scalar "$scalar")" ]; then
    printf "Missing field: %s\n" "$scalar"
    status=1
  fi
done

awk '
  /^required_reads:/ { section="reads"; next }
  /^allowed_paths:/ { section="paths"; next }
  /^required_checks:/ { section="checks"; next }
  /^[a-zA-Z_]+:/ { section="" }
  section=="reads" && /^[[:space:]]+- / { print substr($0, index($0, "- ") + 2) }
' "$CONFIG" | while IFS= read -r path; do
  [ -z "$path" ] && continue
  case "$path" in
    *"*"*) continue ;;
  esac
  if [ ! -e "$ROOT/$path" ]; then
    printf "Required read missing: %s\n" "$path"
    exit 2
  fi
done || status=1

output_schema="$(get_scalar output_schema)"
route_input_schema="$(get_scalar route_input_schema)"
check_existing_path "Output schema" "$output_schema"
check_existing_path "Route input schema" "$route_input_schema"

if ! list_values required_reads | grep -qxF "$output_schema"; then
  printf "Required reads must include output schema: %s\n" "$output_schema"
  status=1
fi

for numeric in max_parallel_routes dispatch_timeout_seconds; do
  value="$(get_scalar "$numeric")"
  case "$value" in
    ''|*[!0-9]*)
      printf "%s must be a number: %s\n" "$numeric" "$value"
      status=1
      ;;
  esac
done

for bool in completion_report_required can_create_routes can_update_workflow_state can_modify_task_board; do
  value="$(get_scalar "$bool")"
  case "$value" in
    true|false)
      ;;
    *)
      printf "%s must be true or false: %s\n" "$bool" "$value"
      status=1
      ;;
  esac
done

escalation_owner="$(get_scalar escalation_owner)"
if [ -n "$escalation_owner" ] && ! is_agent_role "$escalation_owner"; then
  printf "Escalation owner is not a canonical role: %s\n" "$escalation_owner"
  status=1
fi

while IFS= read -r target_role; do
  [ -z "$target_role" ] && continue
  if ! is_agent_role "$target_role"; then
    printf "Handoff target is not a canonical role: %s\n" "$target_role"
    status=1
  fi
done < <(list_values handoff_targets)

if [ -f "$OWNERSHIP" ]; then
  config_paths="$(mktemp)"
  awk '
    /^allowed_paths:/ { section="paths"; next }
    /^[a-zA-Z_]+:/ { section="" }
    section=="paths" && /^[[:space:]]+- / { print substr($0, index($0, "- ") + 2) }
  ' "$CONFIG" | sort -u > "$config_paths"
  ownership_paths="$(mktemp)"
  grep -vE '^[[:space:]]*(#|$)' "$OWNERSHIP" | sort -u > "$ownership_paths"
  if ! diff -q "$config_paths" "$ownership_paths" >/dev/null 2>&1; then
    printf "Allowed paths differ from ownership file for %s\n" "$ROLE"
    status=1
  fi
  rm -f "$config_paths" "$ownership_paths"
fi

if [ "$status" -ne 0 ]; then
  printf "\nAgent config check failed.\n" >&2
  exit 1
fi

printf "Agent config check passed.\n"
