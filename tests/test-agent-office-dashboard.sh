#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf "FAIL: %s\n" "$1" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"
  if [ ! -f "$ROOT/$path" ]; then
    fail "missing file: $path"
  fi
}

assert_executable() {
  local path="$1"
  if [ ! -x "$ROOT/$path" ]; then
    fail "not executable: $path"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "$label missing expected text: $needle"
  fi
}

free_port() {
  python3 - <<'PY'
import socket
sock = socket.socket()
sock.bind(("127.0.0.1", 0))
print(sock.getsockname()[1])
sock.close()
PY
}

wait_for_server() {
  local port="$1"
  local deadline=$((SECONDS + 10))
  while [ "$SECONDS" -lt "$deadline" ]; do
    if python3 - "$port" <<'PY' >/dev/null 2>&1
import sys
import urllib.request
port = int(sys.argv[1])
with urllib.request.urlopen(f"http://127.0.0.1:{port}/api/snapshot", timeout=1) as response:
    if response.status != 200:
        raise SystemExit(1)
PY
    then
      return 0
    fi
    sleep 0.2
  done
  return 1
}

assert_file_exists "visual-media/index.html"
assert_file_exists "visual-media/styles.css"
assert_file_exists "visual-media/app.js"
assert_file_exists "visual-media/agent_office_server.py"
assert_file_exists "scripts/start-agent-office-dashboard.sh"
assert_file_exists "scripts/start-visual-media-dashboard.sh"
assert_executable "scripts/start-agent-office-dashboard.sh"
assert_executable "scripts/start-visual-media-dashboard.sh"
bash -n "$ROOT/scripts/start-agent-office-dashboard.sh"
bash -n "$ROOT/scripts/start-visual-media-dashboard.sh"
bash -n "$ROOT/scripts/route-agent.sh"
python3 -m py_compile "$ROOT/visual-media/agent_office_server.py"

dashboard_markup="$(cat "$ROOT/visual-media/index.html" "$ROOT/visual-media/app.js")"
assert_contains "$dashboard_markup" "Agent Office" "agent office dashboard"
assert_contains "$dashboard_markup" "Media Builder" "agent office dashboard"
assert_contains "$dashboard_markup" "/api/snapshot" "agent office dashboard"
assert_contains "$dashboard_markup" "/api/orchestrator-prompt" "agent office dashboard"
assert_contains "$dashboard_markup" "scripts/attach-media.sh" "media builder tab"

office_url="$("$ROOT/scripts/start-agent-office-dashboard.sh" --print-url 9877)"
assert_contains "$office_url" "http://127.0.0.1:9877/visual-media/" "agent office server url"
media_url="$("$ROOT/scripts/start-visual-media-dashboard.sh" --print-url 9878)"
assert_contains "$media_url" "http://127.0.0.1:9878/visual-media/" "visual media compatibility url"

tmp_parent="$(mktemp -d)"
server_pid=""
cleanup() {
  if [ -n "$server_pid" ]; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp_parent"
}
trap cleanup EXIT

test_root="$tmp_parent/agent-teams"
rsync -a \
  --exclude ".git/" \
  --exclude ".DS_Store" \
  "$ROOT/" "$test_root/"
chmod +x "$test_root"/scripts/*.sh

"$test_root/scripts/update-agent-state.sh" frontend \
  --status busy \
  --active-route R777 \
  --active-task T777 \
  --session agent-team \
  --window frontend
"$test_root/scripts/update-agent-state.sh" backend \
  --status blocked \
  --active-route R778 \
  --blocked-reason "Needs API contract"

port="$(free_port)"
"$test_root/scripts/start-agent-office-dashboard.sh" --port "$port" >"$tmp_parent/server.log" 2>&1 &
server_pid="$!"
wait_for_server "$port" || {
  cat "$tmp_parent/server.log" >&2 || true
  fail "agent office server did not start"
}

snapshot_file="$tmp_parent/snapshot.json"
python3 - "$port" "$snapshot_file" <<'PY'
import json
import sys
import urllib.request

port = int(sys.argv[1])
out = sys.argv[2]
with urllib.request.urlopen(f"http://127.0.0.1:{port}/api/snapshot", timeout=3) as response:
    payload = json.load(response)
with open(out, "w", encoding="utf-8") as handle:
    json.dump(payload, handle)

roles = {agent["role"]: agent for agent in payload["agents"]}
assert "orchestrator" in roles, "orchestrator profile missing"
assert roles["frontend"]["status"] == "busy", roles["frontend"]
assert roles["frontend"]["active_route"] == "R777", roles["frontend"]
assert roles["backend"]["status"] == "blocked", roles["backend"]
assert "events" in payload and isinstance(payload["events"], list)
assert "workflow" in payload and payload["workflow"]["phase"] == "intake"
assert "routes" in payload and isinstance(payload["routes"], list)
PY

prompt_response="$tmp_parent/prompt-response.json"
python3 - "$port" "$prompt_response" <<'PY'
import json
import sys
import urllib.error
import urllib.request

port = int(sys.argv[1])
out = sys.argv[2]
url = f"http://127.0.0.1:{port}/api/orchestrator-prompt"

def post(payload):
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=3) as response:
        return response.status, json.load(response)

status, payload = post({"role": "frontend", "message": "Check the selected frontend route and decide the next step."})
assert status == 201, status
assert payload["route_id"] == "R001", payload
assert payload["to"] == "orchestrator", payload
assert payload["from"] == "human-ui", payload
assert payload["report"] == ".agents/routes/R001.md", payload
with open(out, "w", encoding="utf-8") as handle:
    json.dump(payload, handle)

status, payload = post({"role": "frontend", "message": "Follow-up prompt should use the next sequential route id."})
assert status == 201, status
assert payload["route_id"] == "R002", payload
assert payload["report"] == ".agents/routes/R002.md", payload

for bad_payload in ({"role": "frontend", "message": "   "}, {"role": "not-a-role", "message": "hello"}):
    request = urllib.request.Request(
        url,
        data=json.dumps(bad_payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        urllib.request.urlopen(request, timeout=3)
    except urllib.error.HTTPError as exc:
        assert exc.code == 400, exc.code
    else:
        raise AssertionError(f"expected HTTP 400 for {bad_payload!r}")
PY

report="$(cat "$test_root/.agents/routes/R001.md")"
inbox="$(cat "$test_root/.agents/inbox/orchestrator.md")"
routes_state="$(cat "$test_root/.agents/state/routes.jsonl")"
events_state="$(cat "$test_root/.agents/events.jsonl")"
assert_contains "$report" "From: human-ui" "ui route report"
assert_contains "$report" "To: orchestrator" "ui route report"
assert_contains "$report" "Selected role: frontend" "ui route report"
assert_contains "$report" "Selected status: busy" "ui route report"
assert_contains "$report" "Selected active route: R777" "ui route report"
assert_contains "$inbox" "From: human-ui" "orchestrator inbox"
assert_contains "$routes_state" "\"from\":\"human-ui\"" "routes structured state"
assert_contains "$routes_state" "\"to\":\"orchestrator\"" "routes structured state"
assert_contains "$events_state" "\"actor\":\"human-ui\"" "events structured state"

structured_output="$("$test_root/scripts/validate-structured-state.sh")"
assert_contains "$structured_output" ".agents/state/routes.jsonl valid" "agent office structured state"
route_output="$("$test_root/scripts/validate-route-state.sh")"
assert_contains "$route_output" "Route state validation passed." "agent office route state"

printf "Agent office dashboard tests passed.\n"
