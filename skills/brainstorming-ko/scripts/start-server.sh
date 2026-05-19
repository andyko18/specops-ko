#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="/tmp/.vc-server.pid"
PORT=4242

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Visual Companion server already running (PID $(cat "$PID_FILE"))"
  exit 0
fi

if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
  echo "Installing dependencies..."
  (cd "$SCRIPT_DIR" && npm install --silent)
fi

node "$SCRIPT_DIR/server.cjs" &
NODE_PID=$!
sleep 0.5

if ! kill -0 "$NODE_PID" 2>/dev/null; then
  echo "서버 시작 실패 — 포트 충돌 또는 node 오류 확인"
  exit 1
fi
echo "$NODE_PID" > "$PID_FILE"

echo "Visual Companion server started (PID $NODE_PID)"
echo "URL: file://$SCRIPT_DIR/frame-template.html"

OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
  open "file://$SCRIPT_DIR/frame-template.html"
elif [ "$OS" = "Linux" ]; then
  xdg-open "file://$SCRIPT_DIR/frame-template.html" 2>/dev/null \
    || echo "브라우저를 수동으로 열어주세요: file://$SCRIPT_DIR/frame-template.html"
else
  echo "브라우저를 수동으로 열어주세요: file://$SCRIPT_DIR/frame-template.html"
fi
