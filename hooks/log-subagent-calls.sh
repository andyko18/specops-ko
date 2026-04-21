#!/usr/bin/env bash
# specops-ko v0.2 묶음 1 · 서브에이전트 호출 감사 로그
# 파일 경로 기반 파라미터 전달 규약(skills/file-based-communication-ko/SKILL.md) 준수 점검
# 각 서브에이전트 호출 시 .specops/logs/subagent.jsonl에 한 줄 JSON 추가
# 사용 예: hooks/log-subagent-calls.sh <agent-name> <summary>
# Exit  : 0 정상 / 2 사용법 오류 (로깅 실패는 stderr 경고 + exit 0)
# 참조  : docs/case-studies/2026-04-23-session-6-design.md §4.5
set -u

# v0.2 묶음 3: config guard — disabled 시 조용히 exit 0
script_dir_guard=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root_guard=$(dirname "$script_dir_guard")
bash "$plugin_root_guard/scripts/is-hook-enabled.sh" log-subagent-calls || exit 0

if [ "$#" -lt 2 ]; then
  echo "usage: log-subagent-calls.sh <agent-name> <summary>" >&2
  exit 2
fi

agent=$1
summary=$2
out=${SPECOPS_SUBAGENT_LOG:-.specops/logs/subagent.jsonl}
ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 디렉토리 자동 생성
mkdir -p "$(dirname "$out")" || {
  echo "⚠️  log-subagent-calls: $(dirname "$out") 생성 실패" >&2
  exit 0
}

# 본문 전달 의심 휴리스틱 — 200자 초과는 요약이 아니라 본문 가능성
if [ "${#summary}" -gt 200 ]; then
  echo "⚠️  log-subagent-calls: summary가 ${#summary}자 (>200) — 프롬프트 본문 직접 저장 의심. 파일 경로 + 한 줄 요약 권장." >&2
fi

# json.dumps로 안전한 escape (따옴표·백슬래시·제어문자)
line=$(python3 -c "
import json, sys
print(json.dumps({'ts': sys.argv[1], 'agent': sys.argv[2], 'summary': sys.argv[3]}))
" "$ts" "$agent" "$summary" 2>/dev/null) || {
  echo "⚠️  log-subagent-calls: python3 json.dumps 실패 (python3 누락 가능)" >&2
  exit 0
}

printf '%s\n' "$line" >> "$out" || {
  echo "⚠️  log-subagent-calls: $out append 실패" >&2
  exit 0
}
