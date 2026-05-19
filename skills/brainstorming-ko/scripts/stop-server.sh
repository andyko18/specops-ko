#!/usr/bin/env bash
set -u

PID_FILE="/tmp/.vc-server.pid"

if [ ! -f "$PID_FILE" ]; then
  echo "Visual Companion server not running (PID file not found)"
  exit 0
fi

PID="$(cat "$PID_FILE")"

if kill -0 "$PID" 2>/dev/null; then
  kill "$PID"
  echo "Visual Companion server stopped (PID $PID)"
else
  echo "Process $PID not running (stale PID file)"
fi

rm -f "$PID_FILE"
