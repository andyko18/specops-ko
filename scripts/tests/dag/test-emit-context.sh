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

# T4.a: intent 게이트 — 날짜 FID + intent 부재 → rc=1 · dispatch 미생성 (원자성)
#   ★ id 는 T4.a — T1.h 는 이미 스코프 이관 배선 케이스가 쓴다(:146-157, plan-review 1회차 I-5)
#   stderr 를 단언하는 이유(AC-5 Then "stderr 에 intent 안내"): rc=1 만 보면 상류 게이트
#   6종 중 무엇이 막았는지 구분 못 해, intent 게이트가 죽어도 케이스가 통과한다.
tmp=$(mktemp -d)
mkdir -p "$tmp/.specops/20991231-gate"
cp "$FIXTURES/ok-fid"/*.md "$tmp/.specops/20991231-gate/"
err=$(cd "$tmp" && bash "$EMIT" 20991231-gate 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$err" | grep -q 'intent\.md' \
   && [ ! -d "$tmp/.specops/20991231-gate/dispatch" ]; then
  PASS=$((PASS+1)); echo "PASS T4.a intent 부재 → rc=1 · stderr intent 안내 · dispatch 미생성"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.a (rc=$rc err=$(printf '%s' "$err" | head -1) dispatch=$(ls "$tmp/.specops/20991231-gate/dispatch" 2>/dev/null | wc -l))"
fi
rm -rf "$tmp"

# T4.b: intent 를 채우면 정상 산출 (AC-5 Then 둘째 문장 — plan-review 2회차 I-F)
tmp=$(mktemp -d)
mkdir -p "$tmp/.specops/20991231-gate"
cp "$FIXTURES/ok-fid"/*.md "$tmp/.specops/20991231-gate/"
printf '# Intent: 게이트 픽스처\n\n**작성자**: 사용자 · **Status**: accepted\n\n## 문제\n게이트 통과 경로 확인\n\n## 기대 결과\ndispatch 산출\n\n## 영향 사용자·시스템\n- 구현자\n\n## 제약\n- 해당 없음\n\n## 열린 질문\n- 없음\n' > "$tmp/.specops/20991231-gate/intent.md"
out=$(cd "$tmp" && bash "$EMIT" 20991231-gate 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'EMIT:' && [ -d "$tmp/.specops/20991231-gate/dispatch" ]; then
  PASS=$((PASS+1)); echo "PASS T4.b intent 채움 → EMIT · dispatch 생성"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.b (rc=$rc out=$out)"
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

# ── T3: must AC 역방향 커버리지 (20260806 /maintain 정밀분석) ────────────────
# 종전 검증은 task→AC 한 방향(ac 배열의 id 가 AC.md 에 존재)뿐이었다.
# 역방향(모든 must AC 가 ≥1 task 에 매핑)은 decomposing 산문뿐 — AC-R-1 을 채워도
# 어느 태스크에도 안 매핑하면 회귀 테스트가 영영 구현되지 않는 구멍.
out=$(run_emit "$FIXTURES/must-uncovered")
if echo "$out" | grep -q "exit=1" && echo "$out" | grep -q "AC-R-1" \
   && echo "$out" | grep -q "(empty)"; then
  PASS=$((PASS+1)); echo "PASS T3.a must AC 미커버 → exit 1 + 미커버 id 지목 + 부분잔류 0"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.a"; echo "out=$out"
fi
# should AC(AC-2) 미커버는 차단하지 않는다 — 오류 메시지에 AC-2 가 나오면 과잉
if ! echo "$out" | grep -E "커버.*AC-2|AC-2.*커버" >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T3.b should AC 미커버는 비차단"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.b should 과잉 차단"
fi

# ── 20261001-task-id-guard — check-task-ids.sh (판정기 단독) ──
CHK="$PLUGIN/scripts/_internal/check-task-ids.sh"
_pf() { if [ "$2" = ok ]; then PASS=$((PASS+1)); echo "PASS $1"; else FAIL=$((FAIL+1)); echo "FAIL $1${3:+ — $3}"; fi; }
# mk_tid_fixture TMPDIR FID ID값... — tasks.md YAML 만 있는 최소 FID (id 값은 따옴표 포함 원문)
mk_tid_fixture() {
  local d="$1" fid="$2"; shift 2
  mkdir -p "$d/.specops/$fid"
  { echo '# tasks'; echo; echo '## 의존 그래프'; echo; echo '```yaml'; echo 'tasks:'
    for v in "$@"; do echo "  - id: $v"; echo '    depends_on: []'; echo '    ac: [AC-1]'; done
    echo '```'; } > "$d/.specops/$fid/tasks.md"
}

# T1.t1 숫자 id 만 있는 신규 FID → PASS (AC-1)
tmp=$(mktemp -d); mk_tid_fixture "$tmp" 20261001-ok T1 T2 T10
out=$(cd "$tmp" && bash "$CHK" 20261001-ok 2>&1); rc=$?
_pf "T1.t1 숫자 id → TASK-IDS: PASS" "$([ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'TASK-IDS: PASS (3 tasks)' && echo ok || echo no)" "rc=$rc out=$out"
rm -rf "$tmp"

# T1.t2 접미사·비 T숫자·숫자형·따옴표 접미사 → FAIL + 위반 목록 + 사유 (AC-2·AC-10)
#   위반 id 는 '규격 위반:' 목록 줄에서 찾는다 — 안내 문구에도 'T1a' 가 있어 전체 출력 grep 은 공허하다.
#   '1'(숫자형)은 목록 안의 독립 토큰으로 확인한다(AC-10 — 순서 무관). 정상 id T1 은 목록에 없어야 한다.
tmp=$(mktemp -d); mk_tid_fixture "$tmp" 20261001-bad T1 T1a task-3 1 '"T1b"'
out=$(cd "$tmp" && bash "$CHK" 20261001-bad 2>&1); rc=$?
vl=$(printf '%s\n' "$out" | grep '규격 위반:')
_pf "T1.t2 위반 id → rc=1·목록·숫자 전용 사유" "$([ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'TASK-IDS: FAIL' && printf '%s' "$vl" | grep -q 'T1a' && printf '%s' "$vl" | grep -q 'task-3' && printf '%s' "$vl" | grep -qE '(: |, )1(,|$)' &&printf '%s' "$vl" | grep -q 'T1b' && ! printf '%s' "$vl" | grep -qE '(: |, )T1(,|$)' && printf '%s' "$out" | grep -q '숫자 전용' && echo ok || echo no)" "rc=$rc out=$out"
rm -rf "$tmp"

# T1.t3 레거시(cutoff 미만)·비날짜 FID → SKIP, 막지 않는다 (AC-3)
tmp=$(mktemp -d); mk_tid_fixture "$tmp" 20260902-legacy N1 FIRST; mk_tid_fixture "$tmp" fid-test N1
o1=$(cd "$tmp" && bash "$CHK" 20260902-legacy 2>&1); r1=$?; o2=$(cd "$tmp" && bash "$CHK" fid-test 2>&1); r2=$?
_pf "T1.t3 레거시·비날짜 FID → SKIP rc=0" "$([ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && printf '%s' "$o1" | grep -q 'SKIP' && printf '%s' "$o2" | grep -q 'SKIP' && echo ok || echo no)" "o1=$o1 o2=$o2"
rm -rf "$tmp"

# T1.t4 YAML 파싱 불가 → SKIP + 사유(검증하지 못했다는 사실을 숨기지 않는다), rc=0 (AC-8)
tmp=$(mktemp -d); mkdir -p "$tmp/.specops/20261001-broken"
printf '```yaml\ntasks:\n  - id: "T1\n    depends_on: []\n```\n' > "$tmp/.specops/20261001-broken/tasks.md"
out=$(cd "$tmp" && bash "$CHK" 20261001-broken 2>&1); rc=$?
_pf "T1.t4 깨진 YAML → SKIP + 파싱 불가 사유" "$([ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'SKIP' && printf '%s' "$out" | grep -q '파싱 불가' && echo ok || echo no)" "rc=$rc out=$out"
rm -rf "$tmp"

# T1.t5 어떤 env 로도 신규 FID 의 거부가 풀리지 않는다 (AC-3 후단) — 실제 우회 경로 SPECOPS_ROOT 포함
tmp=$(mktemp -d); mk_tid_fixture "$tmp" 20261001-bad T1a
okv=ok
for e in "SPECOPS_TASK_IDS_CUTOFF=20300101" "SPECOPS_ROOT=/nonexistent" "SPECOPS_ROOT=" "SPECOPS_GOVERNANCE_BYPASS=1"; do
  out=$(cd "$tmp" && env "$e" bash "$CHK" 20261001-bad 2>&1); rc=$?
  { [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'TASK-IDS: FAIL'; } || { okv=no; echo "  (풀림: $e rc=$rc out=$out)"; }
done
_pf "T1.t5 env 우회 4종 프로브 → FAIL 유지" "$okv"
rm -rf "$tmp"

# ── emit-context 통합 (20261001-task-id-guard T2) — 라벨 T2.t* (기존 T2.a·T2.b 는 h2 헤더·drift 케이스) ──
_ok_spec_ac() { cp "$FIXTURES/ok-fid/spec.md" "$FIXTURES/ok-fid/acceptance-criteria.md" "$1/.specops/$2/"; }
# _tid_line ERR — 판정기의 'TASK-IDS: FAIL' 줄만. '숫자 전용' 은 emit 의 안내 echo 에도, 'T1a' 는 판정기 안내 줄에도
#   있어 전체 stderr grep 은 공허하다 — 위반 목록이 정확히 T1a 인지를 이 한 줄에서 본다.
_tid_line() { printf '%s\n' "$1" | grep '^TASK-IDS: FAIL'; }
# T2.t_a 접미사 id → emit exit 1 · 위반 목록=T1a · dispatch 미생성(원자성) (AC-2)
#   intent.md 부재 fixture 라 intent 게이트 안내가 stderr 에 없어야 한다 — 게이트가 intent 보다 앞에 있고
#   위반 시 자기가 exit 한다는 증거(`exit 1` 삭제 시 intent 게이트로 낙하해 rc=1 이 유지되는 변이를 잡는다).
tmp=$(mktemp -d); mk_tid_fixture "$tmp" 20261001-tid-bad T1a; _ok_spec_ac "$tmp" 20261001-tid-bad
err=$(cd "$tmp" && bash "$EMIT" 20261001-tid-bad 2>&1 >/dev/null); rc=$?
_pf "T2.t_a 접미사 id → emit exit 1·위반 목록 T1a·intent 낙하 없음·dispatch 0" "$([ "$rc" -eq 1 ] && _tid_line "$err" | grep -qE '숫자 전용.*규격 위반: T1a$' && ! printf '%s' "$err" | grep -q 'intent\.md' && [ ! -d "$tmp/.specops/20261001-tid-bad/dispatch" ] && echo ok || echo no)" "rc=$rc err=$(printf '%s' "$err" | head -3)"
# T2.t_a4 SPECOPS_ROOT 로 면제되지 않는다 (AC-3 후단)
err=$(cd "$tmp" && SPECOPS_ROOT=/nonexistent bash "$EMIT" 20261001-tid-bad 2>&1 >/dev/null); rc=$?
_pf "T2.t_a4 SPECOPS_ROOT=/nonexistent 로도 거부 유지" "$([ "$rc" -eq 1 ] && _tid_line "$err" | grep -qE '규격 위반: T1a$' && echo ok || echo no)" "rc=$rc err=$(printf '%s' "$err" | head -3)"
rm -rf "$tmp"
# T2.t_a2 깨진 YAML(AC-8 후단) → check 는 SKIP(차단 안 함), emit 은 다른 게이트·YAML 오류로 exit 1, TASK-IDS: FAIL 은 없음
tmp=$(mktemp -d); mkdir -p "$tmp/.specops/20261001-tid-broken"; _ok_spec_ac "$tmp" 20261001-tid-broken
printf '```yaml\ntasks:\n  - id: "T1\n    depends_on: []\n```\n' > "$tmp/.specops/20261001-tid-broken/tasks.md"
err=$(cd "$tmp" && bash "$EMIT" 20261001-tid-broken 2>&1 >/dev/null); rc=$?
_pf "T2.t_a2 깨진 YAML → emit exit 1 · TASK-IDS: FAIL 없음" "$([ "$rc" -eq 1 ] && ! printf '%s' "$err" | grep -q 'TASK-IDS: FAIL' && echo ok || echo no)" "rc=$rc err=$(printf '%s' "$err" | head -2)"
rm -rf "$tmp"
# T2.t_c 레거시 FID(cutoff 미만, 비 T숫자 id) → emit 정상 산출 (AC-3 · 회귀)
tmp=$(mktemp -d); mkdir -p "$tmp/.specops/20260902-legacy"; cp "$FIXTURES/ok-fid"/*.md "$tmp/.specops/20260902-legacy/"
sed -i.bak 's/id: T1$/id: N1/; s/id: T2$/id: N2/' "$tmp/.specops/20260902-legacy/tasks.md"; rm -f "$tmp/.specops/20260902-legacy/tasks.md.bak"
out=$(cd "$tmp" && bash "$EMIT" 20260902-legacy 2>&1); rc=$?
_pf "T2.t_c 레거시 FID(N1·N2) → EMIT 정상" "$([ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'EMIT: 2 files' && echo ok || echo no)" "rc=$rc out=$out"
rm -rf "$tmp"
# T1.t6 PYTHONPATH 로 주입한 **조건부** 가짜 yaml 모듈로 판정기를 속이지 못한다 (AC-3 후단 · Phase C Important)
#   가짜는 SPECOPS_TI_YAML(판정기가 python 에 넘기는 env) 이 있을 때만 tasks=[T1] 을 돌려주고 그 외에는 실 pyyaml 로
#   위임한다 — 판정기만 속고 emit 의 자체 파싱은 실 YAML 을 봐서 T1a-context.md 를 디스크에 쓰던 경로(리뷰 실측).
#   무조건 가짜는 emit 도 함께 깨져 이 결함을 못 잡는다. 판정기의 `python3 -E` 가 PYTHON* env 를 무시해 막는다.
_fk=$(mktemp -d); mkdir -p "$_fk/yaml"
cat > "$_fk/yaml/__init__.py" <<'FKEOF'
import os, sys, importlib
_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def _load_real():
    saved_path, saved_mod = sys.path[:], sys.modules.pop("yaml", None)
    try:
        sys.path[:] = [p for p in sys.path if os.path.abspath(p or ".") != _root]
        return importlib.import_module("yaml")
    finally:
        sys.path[:] = saved_path
        if saved_mod is not None:
            sys.modules["yaml"] = saved_mod
_REAL = _load_real()
def safe_load(s):
    if os.environ.get("SPECOPS_TI_YAML") is not None:
        return {"tasks": [{"id": "T1"}]}
    return _REAL.safe_load(s)
def __getattr__(name):
    return getattr(_REAL, name)
FKEOF
# 선검사 — 가짜가 실제로 조건부로 동작하는가(트리거 시 T1 · 미트리거 시 실 pyyaml 위임). 아니면 아래 단언이 다른 것을 잰다.
_fk0=$(PYTHONPATH="$_fk" SPECOPS_TI_YAML=1 python3 -c 'import yaml;print(yaml.safe_load("tasks: [{id: T1a}]"))' 2>&1)
_fk1=$(env -u SPECOPS_TI_YAML PYTHONPATH="$_fk" python3 -c 'import yaml;print(yaml.safe_load("tasks: [{id: T1a}]"))' 2>&1)
_pf "T1.t6-0 픽스처: 조건부 가짜 yaml 성립(트리거 T1 · 그 외 실 pyyaml 위임)" "$([ "$_fk0" = "{'tasks': [{'id': 'T1'}]}" ] && [ "$_fk1" = "{'tasks': [{'id': 'T1a'}]}" ] && echo ok || echo no)" "fk0=$_fk0 fk1=$_fk1"
tmp=$(mktemp -d); mk_tid_fixture "$tmp" 20261001-fake T1a
out=$(cd "$tmp" && PYTHONPATH="$_fk" SPECOPS_TI_YAML=1 bash "$CHK" 20261001-fake 2>&1); rc=$?
_pf "T1.t6 가짜 yaml(PYTHONPATH) 주입에도 FAIL 유지·위반 목록 T1a" "$([ "$rc" -eq 1 ] && _tid_line "$out" | grep -qE '규격 위반: T1a$' && echo ok || echo no)" "rc=$rc out=$(printf '%s' "$out" | head -2)"
rm -rf "$tmp"
# T1.t6b 같은 주입에서 emit 도 exit 1 · dispatch 미생성 — intent 까지 갖춘 fixture 라 판정기가 속으면 실제로 산출된다
tmp=$(mktemp -d); mkdir -p "$tmp/.specops/20261001-fake"; cp "$FIXTURES/ok-fid"/*.md "$tmp/.specops/20261001-fake/"
sed -i.bak 's/id: T1$/id: T1a/' "$tmp/.specops/20261001-fake/tasks.md"; rm -f "$tmp/.specops/20261001-fake/tasks.md.bak"
printf '# Intent: 게이트 픽스처\n\n**작성자**: 사용자 · **Status**: accepted\n\n## 문제\n게이트 통과 경로 확인\n\n## 기대 결과\ndispatch 산출\n\n## 영향 사용자·시스템\n- 구현자\n\n## 제약\n- 해당 없음\n\n## 열린 질문\n- 없음\n' > "$tmp/.specops/20261001-fake/intent.md"
err=$(cd "$tmp" && env -u SPECOPS_TI_YAML PYTHONPATH="$_fk" bash "$EMIT" 20261001-fake 2>&1 >/dev/null); rc=$?
_pf "T1.t6b 가짜 yaml 주입 → emit exit 1·위반 목록 T1a·dispatch 0" "$([ "$rc" -eq 1 ] && _tid_line "$err" | grep -qE '규격 위반: T1a$' && [ ! -d "$tmp/.specops/20261001-fake/dispatch" ] && echo ok || echo no)" "rc=$rc err=$(printf '%s' "$err" | head -2) dispatch=$(ls "$tmp/.specops/20261001-fake/dispatch" 2>/dev/null | tr '\n' ' ')"
rm -rf "$tmp" "$_fk"
# (정상 숫자 id 날짜 FID 의 EMIT 은 기존 T4.b(FID 20991231-gate, ok-fid ids T1·T2)가 이미 잠근다 — 새 게이트가 앞에 있어도 통과해야 한다)


# ── T5 test_command whitelist 사전 경고 (FID 20261005-implement-bookkeeping) ──
# whitelist 밖 test_command 는 구현 뒤에야 VERIFY: PARTIAL·R-1 커밋 거부로 드러난다 — 분해 시점에 경고한다.
# 경고는 fail-open: 종료 코드와 EMIT 산출은 그대로여야 한다(docs-only FID 의 비코드 명령을 막지 않는다).
# wl_run <test_command> → "rc|warn|emit" (ok-fid 사본의 T1 test_command 를 교체해 실행. 날짜형 FID 는 intent 게이트가 걸려 비날짜 FID 를 쓴다)
wl_run() {
  local tmp out rc w e
  tmp=$(mktemp -d); mkdir -p "$tmp/.specops/wl-fid"; cp "$FIXTURES/ok-fid"/*.md "$tmp/.specops/wl-fid/"
  python3 - "$tmp/.specops/wl-fid/tasks.md" "$1" <<'PYE'
import sys
p, c = sys.argv[1], sys.argv[2]
s = open(p, encoding="utf-8").read()
old = 'test_command: "bash scripts/tests/test-parser.sh"'
assert old in s
open(p, "w", encoding="utf-8").write(s.replace(old, 'test_command: "' + c + '"', 1))
PYE
  out=$(cd "$tmp" && bash "$EMIT" wl-fid 2>"$tmp/err"); rc=$?
  w=$(grep -c 'WARN T[0-9]* test_command whitelist 밖' "$tmp/err")
  e=$(printf '%s\n' "$out" | grep -c '^EMIT: 2 files')
  rm -rf "$tmp"
  printf '%s|%s|%s' "$rc" "$w" "$e"
}
wl_ok_n=0; wl_bad_n=0; wl_miss=""
for c in "bash scripts/tests/test-x.sh" "bash tests/test-x.sh" "bash test/test-x.sh" "pytest tests/" "python -m pytest -q" "npm test" "npm run test:unit" "go test ./pkg/foo" "cargo test" "npx vitest run"; do
  r=$(wl_run "$c"); [ "$r" = "0|0|1" ] && wl_ok_n=$((wl_ok_n+1)) || wl_miss="$wl_miss [허용 '$c' → $r]"
done
for c in "bash test-greet.sh" "bash ./scripts/x.sh" "ls commands/x.md" "git ls-files examples | wc -l" "sed -n '1,3p' CHANGELOG.md" "bash scripts/tests/a.sh && bash scripts/tests/b.sh" "bash scripts/../x.sh" "make test" "node test.js" "bash /abs/test.sh"; do
  r=$(wl_run "$c"); [ "$r" = "0|1|1" ] && wl_bad_n=$((wl_bad_n+1)) || wl_miss="$wl_miss [불허 '$c' → $r]"
done
if [ "$wl_ok_n" -eq 10 ] && [ "$wl_bad_n" -eq 10 ]; then
  PASS=$((PASS+1)); echo "PASS T5.a whitelist 허용 10종 경고 0 · 불허 10종 경고 1 · 전부 rc 0 + EMIT 2 files (fail-open)"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.a ok=$wl_ok_n bad=$wl_bad_n miss=$wl_miss"
fi
# T5.b 판정 근거 단일화: run-verification.sh 의 _WHITELIST_PAT 와 같은 판정(복제 금지) — 같은 sed 추출로 대조한다
RVPAT=$(grep -m1 '^_WHITELIST_PAT=' "$PLUGIN/scripts/_internal/run-verification.sh" | sed -E "s/^_WHITELIST_PAT='(.*)'\$/\1/")
par_miss=""
for c in "bash scripts/tests/test-x.sh" "bash test-greet.sh" "pytest tests/" "make test" "npx vitest run" "bash scripts/../x.sh" "cd apps/web && npx vitest run" "bash a.sh && bash b.sh"; do
  if [[ "$c" =~ $RVPAT ]] && [[ "$c" != *..* ]]; then want="0|0|1"; else want="0|1|1"; fi
  got=$(wl_run "$c"); [ "$got" = "$want" ] || par_miss="$par_miss [$c want=$want got=$got]"
done
if [ -n "$RVPAT" ] && [ -z "$par_miss" ]; then
  PASS=$((PASS+1)); echo "PASS T5.b emit-context 경고 판정 = run-verification.sh whitelist 판정 (8종 일치)"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.b parity miss=$par_miss pat-len=${#RVPAT}"
fi
# T5.c 정규식 리터럴을 emit-context 에 복제하지 않는다(이미 run-verification·record-task-receipt 두 곳 — 세 번째 금지)
if ! grep -q "^_WHITELIST_PAT='" "$EMIT" && ! grep -q 'poetry|uv|pdm|rye' "$EMIT"; then
  PASS=$((PASS+1)); echo "PASS T5.c emit-context 에 whitelist 정규식 리터럴 없음(단일 근거 읽기)"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.c whitelist 정규식이 emit-context 에 복제됨"
fi
# T5.c2 변수명·내용을 바꾼 복제도 잡는다 — whitelist 정규식의 특징 토큰([[:blank:]] 클래스)이 emit-context 에 한 번도 없어야 한다
if [ "$(grep -c '\[\[:blank:\]\]' "$EMIT")" -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS T5.c2 emit-context 에 정규식 특징 토큰([[:blank:]]) 없음"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.c2 emit-context 에 정규식 조각이 있음"
fi
# T5.d 실제 러너와 대조 — T5.b 는 같은 패턴으로 기대값을 재계산해 반쯤 동어반복이다. 실제 run-verification.sh 가 그 명령을 건너뛰는지(WARN: SKIP) 와 비교한다
RUNV="$PLUGIN/scripts/_internal/run-verification.sh"
rv_skips() {  # $1=test_command → y(러너가 whitelist 로 건너뜀)|n
  local tmp
  tmp=$(mktemp -d); mkdir -p "$tmp/.specops/rv-fid"
  printf '%s\n' '## 의존 그래프' '' '```yaml' 'tasks:' '  - id: T1' "    test_command: \"$1\"" '    depends_on: []' '    inputs: []' '    outputs: []' '    ac: [AC-1]' '```' > "$tmp/.specops/rv-fid/tasks.md"
  (cd "$tmp" && bash "$RUNV" rv-fid >/dev/null 2>"$tmp/err"; true)
  if grep -q 'WARN: SKIP' "$tmp/err"; then printf y; else printf n; fi
  rm -rf "$tmp"
}
rv_miss=""
for c in "bash test-greet.sh" "make test" "bash scripts/../x.sh" "bash scripts/tests/a.sh && bash scripts/tests/b.sh" "bash scripts/tests/nonexist-wl.sh" "bash tests/nonexist-wl.sh" "cd sub && bash tests/nonexist-wl.sh"; do
  rv=$(rv_skips "$c"); w=$(wl_run "$c" | cut -d'|' -f2); [ "$w" = 1 ] && em=y || em=n
  [ "$rv" = "$em" ] || rv_miss="$rv_miss [$c runner=$rv emit=$em]"
done
if [ -z "$rv_miss" ]; then
  PASS=$((PASS+1)); echo "PASS T5.d emit-context 경고 유무 = 실제 run-verification.sh 의 WARN: SKIP (7종 일치)"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.d runner 대조 불일치:$rv_miss"
fi
# T5.e 정규식 사본 동기 — run-verification 과 record-task-receipt 가 각자 복제본을 갖는다. 한쪽만 바뀌면 분해 경고 없음 → receipt 거부가 재발한다
if [ -n "$RVPAT" ] && [ "$(grep -m1 '^_WHITELIST_PAT=' "$PLUGIN/scripts/_internal/record-task-receipt.sh")" = "$(grep -m1 '^_WHITELIST_PAT=' "$RUNV")" ]; then
  PASS=$((PASS+1)); echo "PASS T5.e record-task-receipt·run-verification 의 _WHITELIST_PAT 사본 동일"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.e whitelist 정규식 사본이 갈라짐(run-verification ≠ record-task-receipt)"
fi
# T5.f 경고 안내 줄 잠금 — 불허 명령 경고 뒤에 허용 형태·docs-only 안내가 한 번 나와야 한다
gtmp=$(mktemp -d); mkdir -p "$gtmp/.specops/wl-fid"; cp "$FIXTURES/ok-fid"/*.md "$gtmp/.specops/wl-fid/"
sed -i.bak 's#test_command: "bash scripts/tests/test-parser.sh"#test_command: "bash test-greet.sh"#' "$gtmp/.specops/wl-fid/tasks.md"; rm -f "$gtmp/.specops/wl-fid/tasks.md.bak"
gerr=$(cd "$gtmp" && bash "$EMIT" wl-fid 2>&1 >/dev/null); rm -rf "$gtmp"
if [ "$(printf '%s\n' "$gerr" | grep -c '허용 형태')" -eq 1 ] && printf '%s' "$gerr" | grep -q 'docs-only FID 면 무시해도 됩니다' \
   && printf '%s\n' "$gerr" | grep -qxF "emit-context: WARN T1 test_command whitelist 밖 — 'bash test-greet.sh'"; then
  PASS=$((PASS+1)); echo "PASS T5.f 경고 줄(task id·명령 에코 정확 일치) + 허용 형태·docs-only 안내가 정확히 한 번"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.f 안내 줄 누락/중복: $gerr"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
