#!/usr/bin/env bash

# Central role registry for the agent-team template.
# Source this file from other scripts; do not execute it directly.

AGENT_ROLES=(
  orchestrator
  product
  cto
  design
  pm
  frontend
  backend
  data
  devops
  qa
  validation
  reviewer
  security
  docs
  integration
)

PROJECT_WORKTREE_ROLES=(
  frontend
  backend
  data
  devops
  qa
  docs
  validation
)

is_agent_role() {
  local candidate="$1"
  local role
  for role in "${AGENT_ROLES[@]}"; do
    if [ "$role" = "$candidate" ]; then
      return 0
    fi
  done
  return 1
}

role_uses_project_worktree() {
  local candidate="$1"
  local role
  for role in "${PROJECT_WORKTREE_ROLES[@]}"; do
    if [ "$role" = "$candidate" ]; then
      return 0
    fi
  done
  return 1
}

print_agent_roles() {
  printf "%s\n" "${AGENT_ROLES[@]}"
}
