#!/usr/bin/env bash
# specops-auto-ko governance-capture 공용 함수 라이브러리
# source 로 로드하여 사용. 실행 파일 아님.

detect_fid() {
  local progress_file=".specops/session-progress.md"
  [ -f "$progress_file" ] || { echo ""; return 0; }
  grep -E '^## [0-9]{8}-[a-z0-9-]+' "$progress_file" \
    | head -1 \
    | sed -E 's/^## ([0-9]{8}-[a-z0-9-]+).*/\1/'
}

# transcript JSONL 에서 최근 N 개 tool_use 이벤트를 추출
# 출력: JSONL, 각 줄 { "index": <0-based>, "tool_name": "...", "input": {...} }
# usage: read_recent_tool_events <transcript_path> <max_count>
read_recent_tool_events() {
  local transcript="$1"
  local max="${2:-20}"
  [ -f "$transcript" ] || return 0
  jq -c --slurp --argjson max "$max" '
    [ .[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | { tool_name: .name, input: .input } ]
    | to_entries
    | map({ index: .key, tool_name: .value.tool_name, input: .value.input })
    | .[-$max:][]?
  ' "$transcript"
}
