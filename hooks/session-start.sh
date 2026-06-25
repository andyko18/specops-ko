#!/usr/bin/env bash
# specops-auto-ko · SessionStart hook (Claude Code 전용)
# 역할 (merged):
#   1) skills/using-specops-auto-ko-ko/SKILL.md 전체를 JSON additionalContext 로 주입
#      → Claude Code 세션 진입 시 `<EXTREMELY_IMPORTANT>` 블록으로 자동 활성
#   2) .specops/session-progress.md 최신 블록(있으면)을 동일 additionalContext 뒤에 이어 주입
#      → 재접속 세션에서 FID/상태 rehydrate
# 참조 upstream: obra/superpowers@v5.0.7 hooks/session-start
# 단일 JSON 출력 — Claude Code 가 `hookSpecificOutput.additionalContext` 키를 소비
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# v0.0: config guard — disabled 시 조용히 exit 0 (빈 JSON)
if [ -x "$PLUGIN_ROOT/scripts/_internal/is-hook-enabled.sh" ]; then
  bash "$PLUGIN_ROOT/scripts/_internal/is-hook-enabled.sh" session-start || { printf '{}\n'; exit 0; }
fi

# 1) 메타 skill 본문 로드
meta_path="${PLUGIN_ROOT}/skills/using-specops-auto-ko-ko/SKILL.md"
if [ -f "$meta_path" ]; then
  meta_content=$(cat "$meta_path")
else
  meta_content="⚠️ using-specops-auto-ko-ko/SKILL.md 누락 — 플러그인 설치 불완전"
fi

# 2) session-progress.md 상위 1 블록 (선택)
progress_block=""
target="$(pwd)/.specops/session-progress.md"
if [ -f "$target" ]; then
  progress_block=$(awk '
    /^## / {
      if (in_block) { exit }
      in_block = 1
      current = $0
      next
    }
    in_block { current = current "\n" $0 }
    END { if (in_block && current != "") print current }
  ' "$target")
fi

# JSON escape (superpowers hooks/session-start 방식 차용)
escape_for_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

meta_escaped=$(escape_for_json "$meta_content")

# 세션 컨텍스트 조립
session_context="<EXTREMELY_IMPORTANT>\nspecops-auto-ko 자율 Lifecycle 플러그인이 활성화돼 있다.\n\n**아래는 'specops-auto-ko:using-specops-auto-ko-ko' 메타 skill 본문 — 모든 대화 시작 시 이 지시를 최우선으로 따른다. 다른 skill 은 Skill 도구로 호출한다:**\n\n${meta_escaped}\n</EXTREMELY_IMPORTANT>"

if [ -n "$progress_block" ]; then
  progress_escaped=$(escape_for_json "$progress_block")
  session_context="${session_context}\n\n<session-progress-rehydrate>\n${progress_escaped}\n</session-progress-rehydrate>"
fi

# pending 자유작업 안내 (freecomment-capture) — 기존 출력 경로 불변, 블록만 이어붙임
pending_file="$(pwd)/.specops/pending-capture.jsonl"
if [ -f "$pending_file" ] && [ -s "$pending_file" ]; then
  pending_n=$(grep -c . "$pending_file" 2>/dev/null) || true
  pending_n=${pending_n:-0}
  session_context="${session_context}\n\n<freecomment-pending>\n미기록 자유작업 ${pending_n}건 있음 — pending-capture.jsonl 을 요약해 .specops/freelog.md 와 learnings 에 기록 후 pending 비우고 1줄 보고하라.\n</freecomment-pending>"
fi

printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$session_context"

exit 0
