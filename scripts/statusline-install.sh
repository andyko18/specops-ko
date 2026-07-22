#!/usr/bin/env bash
# specops-ko statusLine 설치 — statusline.sh 절대경로를 .claude/settings.json statusLine 키에 주입.
# 플러그인 statusLine 번들 불가(claude-code-guide) → 본 스크립트가 수동 주입. 멱등.
set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "error: jq 필요" >&2; exit 1; }

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SL="$ROOT/scripts/statusline.sh"
[ -f "$SL" ] || { echo "error: statusline.sh 없음 ($SL)" >&2; exit 1; }

DIR=".claude"; SETTINGS="$DIR/settings.json"
mkdir -p "$DIR"

NEW_SL=$(jq -n --arg cmd "$SL" '{type:"command", command:$cmd}')

if [ -f "$SETTINGS" ]; then
  if jq -e '.statusLine' "$SETTINGS" >/dev/null 2>&1; then
    cp "$SETTINGS" "$SETTINGS.bak"
    echo "기존 statusLine 백업: $SETTINGS.bak"
  fi
  TMP=$(mktemp)
  if ! jq --argjson sl "$NEW_SL" '.statusLine = $sl' "$SETTINGS" > "$TMP"; then
    echo "error: settings.json 파싱 실패 — 갱신 중단 ($SETTINGS)" >&2
    rm -f "$TMP"
    exit 1
  fi
  mv "$TMP" "$SETTINGS"
else
  jq -n --argjson sl "$NEW_SL" '{statusLine:$sl}' > "$SETTINGS"
fi

echo "✅ statusLine 등록: $SL → $SETTINGS"
echo "   (Claude Code 재시작 또는 다음 메시지부터 상태줄 표시)"
exit 0
