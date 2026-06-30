#!/usr/bin/env bash
# Wave 2 U2 — emit-context.sh fail-fast atomic 검증
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
FIXTURES="$PLUGIN/scripts/tests/dag/fixtures/emit-context"
EMIT="$PLUGIN/scripts/dag/emit-context.sh"

# 격리: temp 작업 디렉토리에 fixture 복사 후 실행 (.specops/<FID> 구조 시뮬레이션)
run_emit() {
  local fixture_dir="$1"
  local fid; fid=$(basename "$fixture_dir")
  local tmp; tmp=$(mktemp -d)
  mkdir -p "$tmp/.specops/$fid"
  cp "$fixture_dir"/*.md "$tmp/.specops/$fid/"
  (cd "$tmp" && bash "$EMIT" "$fid" 2>/tmp/emit.err; echo "exit=$?")
  echo "[STDERR]"
  cat /tmp/emit.err
  echo "[DISPATCH_DIR]"
  ls "$tmp/.specops/$fid/dispatch/" 2>/dev/null || echo "(empty)"
  rm -rf "$tmp"
}

# T1.a: PASS fixture → exit 0 + 2 files 생성 + dispatch/ 디렉토리 존재
out=$(run_emit "$FIXTURES/ok-fid")
if echo "$out" | grep -q "EMIT: 2 files" && echo "$out" | grep -q "exit=0"; then
  PASS=$((PASS+1)); echo "PASS T1.a ok-fid → EMIT 2 files + exit 0"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a"; echo "out=$out"
fi

# T1.b: missing-tc fixture → fail-fast exit 1 + stderr 에 task-id 출력 + dispatch/ 비어있음
out=$(run_emit "$FIXTURES/missing-tc")
if echo "$out" | grep -q "exit=1" && echo "$out" | grep -q "T1" && echo "$out" | grep -q "(empty)"; then
  PASS=$((PASS+1)); echo "PASS T1.b missing-tc → fail-fast atomic"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.b"; echo "out=$out"
fi

# T1.c: bad-ac fixture → fail-fast exit 1 + stderr 에 AC-99 + dispatch/ 비어있음
out=$(run_emit "$FIXTURES/bad-ac")
if echo "$out" | grep -q "exit=1" && echo "$out" | grep -q "AC-99" && echo "$out" | grep -q "(empty)"; then
  PASS=$((PASS+1)); echo "PASS T1.c bad-ac → fail-fast atomic"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.c"; echo "out=$out"
fi

# T1.d: ok-fid 산출물 5 섹션 모두 비-빈 (간단 정합 확인)
tmp=$(mktemp -d)
mkdir -p "$tmp/.specops/ok-fid"
cp "$FIXTURES/ok-fid"/*.md "$tmp/.specops/ok-fid/"
(cd "$tmp" && bash "$EMIT" ok-fid >/dev/null 2>&1)
ctx="$tmp/.specops/ok-fid/dispatch/T1-context.md"
if [ -f "$ctx" ] \
  && grep -q "1. 담당 AC" "$ctx" \
  && grep -q "2. 관련 spec" "$ctx" \
  && grep -q "3. 테스트 명령" "$ctx" \
  && grep -q "4. 수정 허용 파일" "$ctx" \
  && grep -q "5. 작업 디렉터리" "$ctx"; then
  PASS=$((PASS+1)); echo "PASS T1.d ctx 5 섹션 정합"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.d"
fi
rm -rf "$tmp"

# T1.e: decomposing-ko Step 10b 명시 (C1 leaf 가 본 케이스를 PASS 시킴)
if grep -qE "Step 10b" "$PLUGIN/skills/decomposing-ko/SKILL.md" \
  && grep -q "emit-context" "$PLUGIN/skills/decomposing-ko/SKILL.md"; then
  PASS=$((PASS+1)); echo "PASS T1.e decomposing-ko Step 10b 본문 명시"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.e decomposing-ko Step 10b 부재"
fi

# T1.f: §6 설계 계약 — memory/data-model.md 존재 시 §6 섹션 + 경로 emit (#4 design-first 배선)
tmp=$(mktemp -d)
mkdir -p "$tmp/.specops/ok-fid" "$tmp/.specops/memory"
cp "$FIXTURES/ok-fid"/*.md "$tmp/.specops/ok-fid/"
echo "# data-model" > "$tmp/.specops/memory/data-model.md"
(cd "$tmp" && bash "$EMIT" ok-fid >/dev/null 2>&1)
ctx="$tmp/.specops/ok-fid/dispatch/T1-context.md"
if grep -q "6. 설계 계약" "$ctx" && grep -q "data-model.md" "$ctx"; then
  PASS=$((PASS+1)); echo "PASS T1.f §6 설계 계약 (memory 존재 시 emit)"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.f §6 미생성/경로누락"
fi
rm -rf "$tmp"

# T1.g: memory 부재 시 §6 미생성 (graceful — 순수 로직/CLI 회귀 보호)
tmp=$(mktemp -d)
mkdir -p "$tmp/.specops/ok-fid"
cp "$FIXTURES/ok-fid"/*.md "$tmp/.specops/ok-fid/"
(cd "$tmp" && bash "$EMIT" ok-fid >/dev/null 2>&1)
ctx="$tmp/.specops/ok-fid/dispatch/T1-context.md"
if ! grep -q "6. 설계 계약" "$ctx"; then
  PASS=$((PASS+1)); echo "PASS T1.g §6 미생성 (memory 부재 graceful)"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.g §6 생성됨 (graceful 위반)"
fi
rm -rf "$tmp"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
