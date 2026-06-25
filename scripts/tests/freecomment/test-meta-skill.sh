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
# T: freework.md 템플릿 5필드 존재 (AC-7)
TPL="$PLUGIN/templates/freework.md"
if [ -f "$TPL" ] && grep -q 'type' "$TPL" && grep -q 'files' "$TPL" \
   && grep -q 'prompt' "$TPL" && grep -q '요약' "$TPL" && grep -q 'ts' "$TPL"; then
  PASS=$((PASS+1)); echo "PASS freework.md 5필드"
else
  FAIL=$((FAIL+1)); echo "FAIL freework.md 템플릿"
fi
# T4: 분기 지시 키워드 존재 (AC-3,4,5,6,8,9,10,11,12)
if grep -q 'freework-resolve-fid' "$META" && \
   grep -q 'freework.md' "$META" && \
   grep -q 'ATTACH' "$META" && \
   grep -q '\-\-fid' "$META"; then
  PASS=$((PASS+1)); echo "PASS T4 분기 지시 키워드"
else
  FAIL=$((FAIL+1)); echo "FAIL T4 분기 지시 키워드"
fi
echo "---"; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
