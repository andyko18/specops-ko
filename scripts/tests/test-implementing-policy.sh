#!/usr/bin/env bash
# Wave 2 U5 (FID 20260514) — implementing-ko 본문 정책 grep 검증
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PLUGIN=$(dirname "$PLUGIN")
F="$PLUGIN/skills/implementing-ko/SKILL.md"

# T1.a: cap=2 정책 명시
grep -q "cap=2" "$F" \
  && { PASS=$((PASS+1)); echo "PASS T1.a cap=2 명시"; } \
  || { FAIL=$((FAIL+1)); echo "FAIL T1.a cap=2 부재"; }

# T1.b: Phase B HARD GATE 메시지
grep -qE "HARD-GATE.*Phase B" "$F" \
  && { PASS=$((PASS+1)); echo "PASS T1.b Phase B HARD GATE"; } \
  || { FAIL=$((FAIL+1)); echo "FAIL T1.b Phase B HARD GATE 부재"; }

# T1.c: Phase C HARD GATE 메시지
grep -qE "HARD-GATE.*Phase C" "$F" \
  && { PASS=$((PASS+1)); echo "PASS T1.c Phase C HARD GATE"; } \
  || { FAIL=$((FAIL+1)); echo "FAIL T1.c Phase C HARD GATE 부재"; }

# T1.d: implementer-ko subagent_type 명시
grep -q "specops-auto-ko:implementer-ko" "$F" \
  && { PASS=$((PASS+1)); echo "PASS T1.d implementer-ko subagent_type"; } \
  || { FAIL=$((FAIL+1)); echo "FAIL T1.d implementer-ko subagent_type 부재"; }

# T1.e: reviews/ 디렉토리 경로 명시
grep -qE "reviews/.*feedback" "$F" \
  && { PASS=$((PASS+1)); echo "PASS T1.e reviews/ 디렉토리"; } \
  || { FAIL=$((FAIL+1)); echo "FAIL T1.e reviews/ 디렉토리 부재"; }

# T1.f: emit-context.sh 컨텍스트 자동 생성 명시
grep -q "emit-context" "$F" \
  && { PASS=$((PASS+1)); echo "PASS T1.f emit-context 자동 생성"; } \
  || { FAIL=$((FAIL+1)); echo "FAIL T1.f emit-context 자동 생성 부재"; }

# T1.g: dispatch-log.md 자동 append 명시
grep -q "dispatch-log" "$F" \
  && { PASS=$((PASS+1)); echo "PASS T1.g dispatch-log.md 명시"; } \
  || { FAIL=$((FAIL+1)); echo "FAIL T1.g dispatch-log.md 부재"; }

# T1.h: 자동 재dispatch 정책 (Phase B/C 1회 자동) 명시
grep -qE "(자동 재dispatch|1회 자동)" "$F" \
  && { PASS=$((PASS+1)); echo "PASS T1.h 자동 재dispatch 정책"; } \
  || { FAIL=$((FAIL+1)); echo "FAIL T1.h 자동 재dispatch 정책 부재"; }

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
