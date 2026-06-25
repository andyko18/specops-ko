#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
META="$PLUGIN/skills/using-specops-auto-ko-ko/SKILL.md"

# T5.a 처리 규약 섹션 + 핵심 단계 키워드 존재
if grep -q '자유작업 pending 처리' "$META" && \
   grep -q 'freelog.md' "$META" && \
   grep -q 'gbrain-append' "$META" && \
   grep -q '1줄 보고' "$META" && \
   grep -q '재분류' "$META"; then
  PASS=$((PASS+1)); echo "PASS T5.a 처리 규약 섹션"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.a"
fi
echo "---"; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
