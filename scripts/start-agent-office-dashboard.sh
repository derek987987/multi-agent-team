#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="8765"
PRINT_URL=0

usage() {
  printf "Usage: %s [--port <port>] [--print-url [port]]\n" "$(basename "$0")" >&2
  printf "Example: %s --port 8765\n" "$(basename "$0")" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --port)
      [ "$#" -ge 2 ] || { printf "--port requires a value.\n" >&2; exit 1; }
      PORT="$2"
      shift 2
      ;;
    --print-url)
      PRINT_URL=1
      shift
      if [ "$#" -gt 0 ]; then
        case "$1" in
          --*) ;;
          *) PORT="$1"; shift ;;
        esac
      fi
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf "Unknown option: %s\n" "$1" >&2
      usage
      exit 1
      ;;
  esac
done

case "$PORT" in
  *[!0-9]*|"")
    printf "Port must be numeric: %s\n" "$PORT" >&2
    exit 1
    ;;
esac

URL="http://127.0.0.1:$PORT/visual-media/"

if [ "$PRINT_URL" -eq 1 ]; then
  printf "%s\n" "$URL"
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf "python3 is required to serve the Agent Office dashboard.\n" >&2
  exit 1
fi

exec python3 "$ROOT/visual-media/agent_office_server.py" --root "$ROOT" --port "$PORT"
