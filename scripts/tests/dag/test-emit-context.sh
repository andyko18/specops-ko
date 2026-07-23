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

# T1.f2: §6 설계 계약 — api-spec-consumer.md(소비 IF, KIND 1·5) 도 계약에 포함 (C2 — 소비 축 정·역 쌍 복원)
tmp=$(mktemp -d)
mkdir -p "$tmp/.specops/ok-fid" "$tmp/.specops/memory"
cp "$FIXTURES/ok-fid"/*.md "$tmp/.specops/ok-fid/"
echo "# consumer" > "$tmp/.specops/memory/api-spec-consumer.md"
(cd "$tmp" && bash "$EMIT" ok-fid >/dev/null 2>&1)
ctx="$tmp/.specops/ok-fid/dispatch/T1-context.md"
if grep -q "6. 설계 계약" "$ctx" && grep -q "api-spec-consumer.md" "$ctx"; then
  PASS=$((PASS+1)); echo "PASS T1.f2 §6 소비 IF 계약 (api-spec-consumer emit)"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.f2 §6 api-spec-consumer 미포함"
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

# T1.j: AC bullet 포맷 겸용 (20260716 trivial dogfood 발견 #2) — `- **AC-1**: ...` 도 요약 추출
tmp=$(mktemp -d)
mkdir -p "$tmp/.specops/ok-fid"
cp "$FIXTURES/ok-fid"/*.md "$tmp/.specops/ok-fid/"
# AC.md 를 bullet 포맷으로 교체 (기존 fixture 의 AC-id 유지 필요 — 원본에서 id 추출)
acids=$(grep -oE 'AC-[A-Za-z0-9-]+' "$tmp/.specops/ok-fid/acceptance-criteria.md" | sort -u)
{ echo "# AC"; for a in $acids; do echo "- **$a**: bullet 포맷 설명 ($a)"; done; } > "$tmp/.specops/ok-fid/acceptance-criteria.md"
(cd "$tmp" && bash "$EMIT" ok-fid >/dev/null 2>&1)
ctx="$tmp/.specops/ok-fid/dispatch/T1-context.md"
if grep -qE '^- AC-[A-Za-z0-9-]+: bullet 포맷 설명' "$ctx"; then
  PASS=$((PASS+1)); echo "PASS T1.j AC bullet 포맷 요약 추출"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.j bullet 요약 빈 문자열 (조용한 degrade)"
fi
rm -rf "$tmp"

# T1.k: AC 요약 추출 실패 시 stderr WARN (조용한 품질 저하 가시화)
tmp=$(mktemp -d)
mkdir -p "$tmp/.specops/ok-fid"
cp "$FIXTURES/ok-fid"/*.md "$tmp/.specops/ok-fid/"
acids=$(grep -oE 'AC-[A-Za-z0-9-]+' "$tmp/.specops/ok-fid/acceptance-criteria.md" | sort -u)
# id 는 존재하나(검증 통과) 요약 추출 불가한 포맷 — 표/인라인 언급만
{ echo "# AC"; for a in $acids; do echo "| $a | must | 표 안에만 존재 |"; done; } > "$tmp/.specops/ok-fid/acceptance-criteria.md"
err=$(cd "$tmp" && bash "$EMIT" ok-fid 2>&1 >/dev/null)
if echo "$err" | grep -q "WARN.*요약 추출 실패"; then
  PASS=$((PASS+1)); echo "PASS T1.k AC 요약 실패 stderr WARN"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.k WARN 미발화 (err='$(echo "$err" | head -1)')"
fi
rm -rf "$tmp"

# T1.h: 스코프 이관 규약 배선 (verify-exec-gate 잔여 backlog) — implementing-ko 에
#   tasks.md-SoT 이관 규약 + emit-context 재실행 + disjoint 재판정 + SCOPE-MOVED 기록이 명문화돼 있어야
#   트리거 5(whitelist 외 파일) 처리가 dispatch 파일 수기 보강(→ R11 race)으로 새지 않는다.
IMPL_SKILL="$PLUGIN/skills/implementing-ko/SKILL.md"
n=$(grep -c "스코프 이관 규약" "$IMPL_SKILL")
if [ "$n" -eq 1 ] && grep -q "SCOPE-MOVED" "$IMPL_SKILL" \
   && grep -q "outputs-disjoint 재판정" "$IMPL_SKILL" \
   && grep -A8 "스코프 이관 규약" "$IMPL_SKILL" | grep -q "emit-context.sh"; then
  PASS=$((PASS+1)); echo "PASS T1.h 스코프 이관 규약 배선 (SoT+재emit+재판정+기록)"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.h 스코프 이관 규약 배선 (n=$n)"
fi

# T1.i: 재실행 멱등 — 같은 FID 로 2회 실행 시 context 재생성 (이관 규약 스텝 2 의 전제)
tmp=$(mktemp -d)
mkdir -p "$tmp/.specops/ok-fid"
cp "$FIXTURES/ok-fid"/*.md "$tmp/.specops/ok-fid/"
(cd "$tmp" && bash "$EMIT" ok-fid >/dev/null 2>&1)
ctx="$tmp/.specops/ok-fid/dispatch/T1-context.md"
sum1=$(cksum < "$ctx")
echo "manual edit" >> "$ctx"
(cd "$tmp" && bash "$EMIT" ok-fid >/dev/null 2>&1)
sum2=$(cksum < "$ctx")
if [ "$sum1" = "$sum2" ] && ! grep -q "manual edit" "$ctx"; then
  PASS=$((PASS+1)); echo "PASS T1.i 재실행 멱등 — 수기 편집 증발(덮어쓰기) 실증"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.i 재실행 멱등"
fi
rm -rf "$tmp"

# ── FID 20260723-lifecycle-robustness (C) — h2 헤더 구제 + fail-closed ──

# T2.a (AC-4): ## (h2) 헤더 AC.md → 요약 정상 추출 (관찰된 drift 구제, 빈 요약 아님)
tmp=$(mktemp -d)
mkdir -p "$tmp/.specops/h2-header"
cp "$FIXTURES/h2-header"/*.md "$tmp/.specops/h2-header/"
rc=$(cd "$tmp" && bash "$EMIT" h2-header >/dev/null 2>&1; echo $?)
ctx="$tmp/.specops/h2-header/dispatch/T1-context.md"
if [ "$rc" = "0" ] && [ -f "$ctx" ] && grep -qE '^- AC-1: parser 추출' "$ctx"; then
  PASS=$((PASS+1)); echo "PASS T2.a h2 헤더 → 요약 정상 추출 + exit 0"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.a h2 요약 추출 실패 (rc=$rc)"
fi
rm -rf "$tmp"

# T2.b (AC-5): AC-id 토큰 존재하나 헤더/불릿 전무(진짜 drift) → exit 1 + dispatch 비어있음 (fail-closed atomic)
tmp=$(mktemp -d)
mkdir -p "$tmp/.specops/ac-no-header"
cp "$FIXTURES/ac-no-header"/*.md "$tmp/.specops/ac-no-header/"
rc=$(cd "$tmp" && bash "$EMIT" ac-no-header 2>/tmp/emit-drift.err >/dev/null; echo $?)
empty=$([ -z "$(ls "$tmp/.specops/ac-no-header/dispatch/" 2>/dev/null)" ] && echo yes || echo no)
if [ "$rc" = "1" ] && [ "$empty" = "yes" ] && grep -q "요약 추출 실패" /tmp/emit-drift.err; then
  PASS=$((PASS+1)); echo "PASS T2.b 추출 실패 drift → exit 1 + 부분잔류 0 (fail-closed)"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.b fail-closed 미작동 (rc=$rc empty=$empty)"
fi
rm -rf "$tmp"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
