#!/usr/bin/env bash
# Wave 2 (FID 20260514-wave2-dispatch-automation) — dispatch-log.md 템플릿 + 동작 검증
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PLUGIN=$(dirname "$PLUGIN")

# T1.a: templates/dispatch-log.md 존재
if [ -f "$PLUGIN/templates/dispatch-log.md" ]; then
  PASS=$((PASS+1)); echo "PASS T1.a templates/dispatch-log.md 존재"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a templates/dispatch-log.md 부재"
fi

# T1.b: frontmatter 5 필드 (FID·OWNER_COMMAND·MUTABLE_BY·reference_upstream·layer)
f="$PLUGIN/templates/dispatch-log.md"
if [ -f "$f" ] \
  && grep -q "FID:" "$f" \
  && grep -q "OWNER_COMMAND:" "$f" \
  && grep -q "MUTABLE_BY:" "$f" \
  && grep -q "reference_upstream:" "$f" \
  && grep -q "layer:" "$f"; then
  PASS=$((PASS+1)); echo "PASS T1.b frontmatter 5 필드"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.b frontmatter 누락"
fi

# T1.c: 재시도 누적 footer 키워드
if [ -f "$f" ] && grep -q "재시도 누적" "$f"; then
  PASS=$((PASS+1)); echo "PASS T1.c 재시도 누적 footer 키워드"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.c 재시도 누적 footer 부재"
fi

# T1.d: task-id 블록 반복 구조 (## task-...)
if [ -f "$f" ] && grep -qE "^## task-" "$f"; then
  PASS=$((PASS+1)); echo "PASS T1.d task-id 블록 반복 구조"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.d task-id 블록 부재"
fi

# T1.e: Phase A/B/C 표 헤더 (시각, agent, 결과)
if [ -f "$f" ] \
  && grep -q "시각" "$f" \
  && grep -q "agent" "$f" \
  && grep -q "결과" "$f"; then
  PASS=$((PASS+1)); echo "PASS T1.e Phase A/B/C 표 헤더"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.e 표 헤더 누락"
fi

# T1.f: cap=2 명시
if [ -f "$f" ] && grep -q "cap=2" "$f"; then
  PASS=$((PASS+1)); echo "PASS T1.f cap=2 명시"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.f cap=2 부재"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
