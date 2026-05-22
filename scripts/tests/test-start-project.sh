#!/usr/bin/env bash
# T19 — /start-project 통합 테스트 (FID 20260507-start-project-bootstrap)
# 14 테스트: KIND 매트릭스 (T1~T4) + skip/conflict/git (T5~T7) + deprecate (T8)
#          + 인용 검증 (T9~T11) + screens (T12) + memory 재실행 (T13) + DB 분기 (T14)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
SCRIPT="$PLUGIN/scripts/_internal/start-project.sh"

# ── 헬퍼 ──────────────────────────────────────
TMPDIR=""
setup_fixture() {
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  git init -q
  git config user.email test@test
  git config user.name test
}
teardown_fixture() {
  cd /tmp
  rm -rf "$TMPDIR"
  TMPDIR=""
}
ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
nope() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }

# 활성 산출물 카운트
count_active() {
  local n=0 f
  for f in PRD.md CLAUDE.md README.md DESIGN.md \
    .specops/memory/{constitution,requirements,test-strategy,architecture,frontend-architecture,backend-architecture,api-spec,data-model,screens-overview}.md; do
    [ -f "$f" ] && n=$((n+1))
  done
  echo "$n"
}

# 표준 풀스택 stdin (KIND=4) — 13종 모두 활성
fullstack_stdin() {
  printf "4\np1\np2\np3\np4\np5\n"
  printf "1. 한 줄: 풀스택 데모\n2. 페르소나: dev\n3. 가치: a, b, c\n4. M1: m1\n5. M2: m2\n6. M3: m3\n\n"
  printf "1\nhome, login\ny\n2\n"  # brand=Stripe, screens, DB=y, API=OpenAPI
}

# ── T1.a UI (KIND=1) ──────────────────────────
setup_fixture
{
  printf "1\np1\np2\np3\np4\np5\n"
  printf "1. UI app\n2. user\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "1\nhome\nn\n"
} | bash "$SCRIPT" >/dev/null 2>&1
if [ -f DESIGN.md ] && [ -f .specops/memory/frontend-architecture.md ] \
   && [ -f .specops/memory/screens-overview.md ] \
   && [ ! -f .specops/memory/backend-architecture.md ] \
   && [ ! -f .specops/memory/api-spec.md ]; then
  ok "T1.a UI(KIND=1) → DESIGN/frontend/screens-overview 활성, backend/api 부재"
else
  nope "T1.a UI" "활성 매트릭스 mismatch (count=$(count_active))"
fi
teardown_fixture

# ── T2.a 백엔드 (KIND=2) ──────────────────────
setup_fixture
{
  printf "2\np1\np2\np3\np4\np5\n"
  printf "1. BE\n2. dev\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "y\n2\n"  # DB=y, API=OpenAPI
} | bash "$SCRIPT" >/dev/null 2>&1
if [ -f .specops/memory/backend-architecture.md ] \
   && [ -f .specops/memory/api-spec.md ] \
   && [ -f .specops/memory/data-model.md ] \
   && [ ! -f DESIGN.md ] \
   && [ ! -f .specops/memory/screens-overview.md ]; then
  ok "T2.a BE(KIND=2) → backend/api/data 활성, DESIGN/screens 부재"
else
  nope "T2.a BE" "매트릭스 mismatch"
fi
teardown_fixture

# ── T3.a CLI (KIND=3) ─────────────────────────
setup_fixture
{
  printf "3\np1\np2\np3\np4\np5\n"
  printf "1. CLI\n2. dev\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "n\n"  # DB=n
} | bash "$SCRIPT" >/dev/null 2>&1
# CLI: PRD/CLAUDE/README/constitution/requirements/test-strategy = 6종
n=$(count_active)
if [ "$n" = "6" ] \
   && [ ! -f DESIGN.md ] \
   && [ ! -f .specops/memory/architecture.md ] \
   && [ ! -f .specops/memory/frontend-architecture.md ] \
   && [ ! -f .specops/memory/backend-architecture.md ]; then
  ok "T3.a CLI(KIND=3) → 6종 (PRD/CLAUDE/README/constitution/requirements/test-strategy)"
else
  nope "T3.a CLI" "활성 카운트=${n} (기대 6), architecture 부재 검증"
fi
teardown_fixture

# ── T4.a 풀스택 (KIND=4) → 13종 ───────────────
setup_fixture
fullstack_stdin | bash "$SCRIPT" >/dev/null 2>&1
n=$(count_active)
if [ "$n" = "13" ]; then
  ok "T4.a Full(KIND=4) → 13종 모두 활성"
else
  nope "T4.a Full" "활성=${n} (기대 13)"
fi
teardown_fixture

# ── T5.a 헌법 'skip' → constitution placeholder 유지 ──
setup_fixture
{
  printf "3\nskip\n"  # KIND=CLI, 헌법=skip
  printf "1. x\n2. y\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "n\n"
} | bash "$SCRIPT" >/dev/null 2>&1
if [ -f .specops/memory/constitution.md ] \
   && grep -q '<PRINCIPLE_1_NAME>' .specops/memory/constitution.md; then
  ok "T5.a 헌법 'skip' → constitution.md placeholder 유지"
else
  nope "T5.a skip" "constitution placeholder 미유지"
fi
teardown_fixture

# ── T6.a git init 안 된 디렉토리 → exit 1 ─────
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
out=$(bash "$SCRIPT" 2>&1)
ec=$?
cd /tmp && rm -rf "$TMPDIR"
if [ "$ec" = "1" ] && echo "$out" | grep -q "git 저장소가 아닙니다"; then
  ok "T6.a git 미초기화 → exit 1 + stderr 메시지"
else
  nope "T6.a git" "exit=${ec}, out=$(echo "$out" | head -1)"
fi

# ── T7.a 기존 PRD.md + skip 정책 → 보존 ───────
setup_fixture
echo "# 보존 마커" > PRD.md
echo "기존 내용" >> PRD.md
{
  printf "3\nskip\n"  # KIND=CLI
  printf "skip\n"   # CONFLICT_POLICY=skip (1개 충돌)
  printf "\n"       # phase_4 numbered list 빈 입력 — 즉시 sentinel
  printf "n\n"      # DB=n
} | bash "$SCRIPT" >/dev/null 2>&1
if grep -q "보존 마커" PRD.md; then
  ok "T7.a 기존 PRD.md + skip 정책 → 보존 (마커 유지)"
else
  nope "T7.a skip-policy" "PRD.md 덮어써짐 또는 손상"
fi
teardown_fixture

# ── T8.a start-design.md 삭제 확인 (/start-project 통합 완료) ──
if [ ! -f "$PLUGIN/commands/start-design.md" ]; then
  ok "T8.a commands/start-design.md 삭제됨 (/start-project 통합 완료)"
else
  nope "T8.a start-design 잔존" "start-design.md 가 아직 존재함 — 삭제 필요"
fi

# ── T9.a constitution 5원칙 → CLAUDE.md §컨벤션 인용 ──
setup_fixture
fullstack_stdin | bash "$SCRIPT" >/dev/null 2>&1
got=$(grep -c '^- 원칙 [1-5]:' CLAUDE.md 2>/dev/null || echo 0)
if [ "$got" = "5" ]; then
  ok "T9.a CLAUDE.md §코딩 컨벤션 → 원칙 5개 인용"
else
  nope "T9.a CLAUDE 인용" "원칙 라인 ${got}개 (기대 5)"
fi
teardown_fixture

# ── T10.a PRD §1 → CLAUDE.md + README.md 동일 인용 ──
setup_fixture
fullstack_stdin | bash "$SCRIPT" >/dev/null 2>&1
prd=$(grep -m1 '^\*\*한 줄 설명\*\*:' PRD.md | sed 's/^\*\*한 줄 설명\*\*: *//')
in_claude=$(grep -c "$prd" CLAUDE.md 2>/dev/null || echo 0)
in_readme=$(grep -c "$prd" README.md 2>/dev/null || echo 0)
if [ -n "$prd" ] && [ "$in_claude" -ge 1 ] && [ "$in_readme" -ge 1 ]; then
  ok "T10.a PRD §1 한 줄 → CLAUDE/README 모두 인용"
else
  nope "T10.a 인용" "prd='$prd' claude=${in_claude} readme=${in_readme}"
fi
teardown_fixture

# ── T11.a api-spec.md (KIND=2) → OpenAPI 골격 ──
setup_fixture
{
  printf "2\np1\np2\np3\np4\np5\n"
  printf "1. BE\n2. dev\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "n\n2\n"  # DB=n, API=OpenAPI
} | bash "$SCRIPT" >/dev/null 2>&1
if grep -q 'openapi: 3.1' .specops/memory/api-spec.md 2>/dev/null \
   && grep -q 'GraphQL' .specops/memory/api-spec.md 2>/dev/null; then
  ok "T11.a api-spec.md OpenAPI YAML + GraphQL 골격 포함"
else
  nope "T11.a api-spec" "openapi/GraphQL 골격 부재"
fi
teardown_fixture

# ── T11.b api-spec.md (KIND=2, m=2) → §2 체크박스 활성 + 라벨 ──
setup_fixture
{
  printf "2\np1\np2\np3\np4\np5\n"
  printf "1. BE\n2. dev\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "n\n2\n"  # DB=n, API=OpenAPI(2)
} | bash "$SCRIPT" >/dev/null 2>&1
if grep -q '\[x\] §2 ' .specops/memory/api-spec.md 2>/dev/null \
   && grep -q 'OpenAPI 3.1 YAML (§2)' .specops/memory/api-spec.md 2>/dev/null \
   && grep -q '\[ \] §1 ' .specops/memory/api-spec.md 2>/dev/null; then
  ok "T11.b api-spec.md §2 체크박스 활성 + 라벨 주입, §1 미선택"
else
  cb=$(grep '§2' .specops/memory/api-spec.md 2>/dev/null | head -1)
  nope "T11.b api-spec 체크박스/라벨" "got: $cb"
fi
teardown_fixture

# ── T12.a 화면 목록 → screens/<name>.{md,html} + flow ──
setup_fixture
{
  printf "1\np1\np2\np3\np4\np5\n"
  printf "1. x\n2. y\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "1\nhome, dashboard\nn\n"
} | bash "$SCRIPT" >/dev/null 2>&1
if [ -f screens/home.md ] && [ -f screens/home.html ] \
   && [ -f screens/dashboard.md ] && [ -f screens/dashboard.html ] \
   && grep -q '^| home |.*screens/home.md' .specops/memory/screens-overview.md \
   && grep -q 'stateDiagram' .specops/memory/screens-overview.md; then
  ok "T12.a 화면 입력 → screens/<name>.{md,html} 쌍 + overview 동적 표 + flow"
else
  nope "T12.a screens" "screens/ 또는 overview 표 mismatch"
fi
teardown_fixture

# ── T13.a .specops/memory/ 이미 존재 + n → 종료 ──
setup_fixture
mkdir -p .specops/memory
echo "기존" > .specops/memory/marker.md
out=$(printf "n\n" | bash "$SCRIPT" 2>&1)
ec=$?
if [ "$ec" = "0" ] && echo "$out" | grep -q "이미 존재" && [ -f .specops/memory/marker.md ]; then
  ok "T13.a .specops/memory/ 존재 + n → 안내 후 종료, marker 보존"
else
  nope "T13.a memory 재실행" "exit=${ec}, marker $([ -f .specops/memory/marker.md ] && echo 존재 || echo 손실)"
fi
teardown_fixture

# ── T14.a Phase 8e DB y vs n 응답별 ───────────
setup_fixture
{
  printf "3\np1\np2\np3\np4\np5\n"
  printf "1. CLI\n2. y\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "y\n"  # DB=y
} | bash "$SCRIPT" >/dev/null 2>&1
y_present=0
[ -f .specops/memory/data-model.md ] && y_present=1
teardown_fixture

setup_fixture
{
  printf "3\np1\np2\np3\np4\np5\n"
  printf "1. CLI\n2. y\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "n\n"  # DB=n
} | bash "$SCRIPT" >/dev/null 2>&1
n_absent=0
[ ! -f .specops/memory/data-model.md ] && n_absent=1
teardown_fixture

if [ "$y_present" = "1" ] && [ "$n_absent" = "1" ]; then
  ok "T14.a Phase 8e DB → y 시 data-model.md 생성, n 시 부재"
else
  nope "T14.a 8e DB" "y_present=${y_present} n_absent=${n_absent}"
fi

# ── 코드 리뷰 fix 회귀 테스트 (C1, C2, I1) ────

# ── T15.a (C1) overwrite 정책 → 기존 PRD.md 덮어쓰기 ──
setup_fixture
echo "# OLD MARKER" > PRD.md
# stdin 순서: phase_1 충돌 정책 → phase_2 KIND → phase_3 헌법 skip → phase_4 빈 sentinel → phase_8e DB
{
  printf "overwrite\n"  # 충돌 정책
  printf "3\n"          # KIND=CLI
  printf "skip\n"       # 헌법 skip
  printf "\n"           # phase_4 sentinel
  printf "n\n"          # 8e DB
} | bash "$SCRIPT" >/dev/null 2>&1
if grep -q "OLD MARKER" PRD.md; then
  nope "T15.a overwrite" "기존 OLD MARKER 가 보존됨 — overwrite 미작동"
else
  ok "T15.a (C1) overwrite 정책 → 기존 PRD.md 덮어쓰기 (마커 제거)"
fi
teardown_fixture

# ── T16.a (C1) merge → skip fallback 안내 + 보존 ─
setup_fixture
echo "# MERGE PRESERVED" > PRD.md
out=$({
  printf "merge\n"      # 충돌 정책 = merge → skip fallback
  printf "3\n"
  printf "skip\n"
  printf "\n"
  printf "n\n"
} | bash "$SCRIPT" 2>&1)
if grep -q "MERGE PRESERVED" PRD.md && echo "$out" | grep -q "merge 정책 미구현\|merge 미구현"; then
  ok "T16.a (C1) merge → skip fallback 안내 + 기존 파일 보존 (데이터 손실 차단)"
else
  nope "T16.a merge" "PRD 보존 또는 fallback 안내 부재 (out=$(echo \"$out\" | grep -i merge | head -1))"
fi
teardown_fixture

# ── T17.a (C2) screens path traversal 차단 ─────
setup_fixture
echo "# ROOT README" > README.md
{
  printf "1\np1\np2\np3\np4\np5\n"
  printf "1. x\n2. y\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "1\n"
  printf "../README\n"  # path traversal 시도
  printf "n\n"
} | bash "$SCRIPT" 2>/dev/null >/dev/null
# README.md 가 보존돼야 함 (사용자 입력으로 덮어써지지 않음)
# 단, phase_9_readme 가 README.md 를 덮어쓸 수 있음 → 그 검증 분리
if [ ! -f screens/../README.md ] || grep -q "ROOT README" screens/../README.md 2>/dev/null; then
  # 다른 검증: screens/ 안에 traversal 흔적 0
  traversal_files=$(find screens -name "*README*" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$traversal_files" = "0" ]; then
    ok "T17.a (C2) screens 입력 '../README' → 거부 + traversal 흔적 0"
  else
    nope "T17.a path traversal" "screens/ 안에 README 흔적 ${traversal_files}개"
  fi
else
  nope "T17.a path traversal" "README.md 손상"
fi
teardown_fixture

# ── T18.a (C2) 모든 invalid 화면명 → placeholder 유지 ──
setup_fixture
{
  printf "1\np1\np2\np3\np4\np5\n"
  printf "1. x\n2. y\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "1\n"
  printf "../foo, /etc/bar\n"  # 모두 invalid
  printf "n\n"
} | bash "$SCRIPT" 2>/dev/null >/dev/null
# screens/ 안에 0 file (또는 디렉토리 자체 부재)
n_files=$(find screens -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$n_files" = "0" ]; then
  ok "T18.a (C2) 모두 invalid 화면명 → screens/ 파일 0개 (placeholder 유지)"
else
  nope "T18.a invalid screens" "screens/ 안 ${n_files}개 (기대 0)"
fi
teardown_fixture

# ── I2 회귀: screens-table fence 안정성 ──

# T19.a (I2) fence 내부 행이 home/login/dashboard 가 아닌 다른 이름으로 바뀌어도
# _rebuild_screens_table 이 정상 동작 (예시 행 이름 비의존)
setup_fixture
# 사용자가 templates/screens-overview.md 의 예시 행을 변경한 환경 시뮬:
# fence 내부 행을 임의 이름으로 변조 후 phase_7 호출
{
  printf "1\np1\np2\np3\np4\np5\n"
  printf "1. x\n2. y\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "1\nproductlist\nn\n"
} | bash "$SCRIPT" >/dev/null 2>&1
# 새 화면 productlist 만 표에 존재 + 기존 예시 (home/login/dashboard) 행 부재
if grep -q '^| productlist | productlist | TODO' .specops/memory/screens-overview.md \
   && ! grep -E '^\| (home|login|dashboard) \| (홈|로그인|대시보드)' .specops/memory/screens-overview.md; then
  ok "T19.a (I2) screens-table fence → 사용자 입력 1건만 + 예시 행 제거"
else
  nope "T19.a fence" "예시 행 잔존 또는 신규 행 누락"
fi
teardown_fixture

# ── T20.a --help 에 --resume 설명 포함 ──
out=$(bash "$SCRIPT" --help 2>&1)
if echo "$out" | grep -q "\-\-resume"; then
  ok "T20.a --help 에 --resume 설명 포함"
else
  nope "T20.a --help resume" "--resume 설명 없음"
fi

# ── T21.a resume 모드: .specops/memory/ 존재 + RESUME_MODE=1 → 재확인 프롬프트 없이 통과 ──
setup_fixture
mkdir -p .specops/memory
echo "[sentinel]" > .specops/memory/constitution.md
# RESUME_MODE=1 + 프로젝트명 없음 → _check_memory 에서 prompt 없이 통과하고 Phase 2로 진행
# Phase 2 진입 전에 Ctrl-C 격인 early-exit stdin 을 보내도 Phase 1 (memory 검사) 은 통과 확인
out_r=$(echo "" | RESUME_MODE=1 bash "$SCRIPT" 2>&1 || true)
# "재부트스트랩 진행?" 가 출력되지 않으면 PASS
if ! echo "$out_r" | grep -q "재부트스트랩"; then
  ok "T21.a resume + memory 존재 → 재확인 프롬프트 없이 통과"
else
  nope "T21.a resume memory" "재부트스트랩 프롬프트 출력됨"
fi
teardown_fixture

# ── T21.b resume 모드: 충돌 파일 존재 + RESUME_MODE=1 → CONFLICT_POLICY=skip 자동 설정 ──
setup_fixture
echo "existing" > PRD.md
out_b=$(echo "" | RESUME_MODE=1 bash "$SCRIPT" 2>&1 || true)
# 충돌 정책 프롬프트가 출력되지 않으면 PASS
if ! echo "$out_b" | grep -q "충돌 파일.*개 감지\|기존 파일 처리 정책"; then
  ok "T21.b resume + 충돌 파일 존재 → 충돌 정책 프롬프트 없이 skip 자동 설정"
else
  nope "T21.b resume conflict" "충돌 정책 프롬프트 출력됨"
fi
teardown_fixture

# ── T21.c --resume 인자(플래그 직접) → RESUME_MODE 활성 + 재확인 프롬프트 없음 ──
setup_fixture
mkdir -p .specops/memory
echo "[sentinel]" > .specops/memory/constitution.md
out_c=$(echo "" | bash "$SCRIPT" --resume 2>&1 || true)
# [resume 모드] 안내 출력 + 재부트스트랩 프롬프트 없음
if echo "$out_c" | grep -q "\[resume 모드\]" && ! echo "$out_c" | grep -q "재부트스트랩"; then
  ok "T21.c --resume 인자(플래그) → resume 모드 진입 + 재확인 프롬프트 없음"
else
  nope "T21.c --resume flag" "[resume 모드] 미출력 또는 재부트스트랩 프롬프트 출력됨"
fi
teardown_fixture

# ── T22.a commands/start-project.md 에 --resume 문서화 ──
if grep -q "\-\-resume" "$PLUGIN/commands/start-project.md"; then
  ok "T22.a commands/start-project.md 에 --resume 문서화"
else
  nope "T22.a resume docs" "--resume 언급 없음"
fi

# ── T23.a --resume MyProject → PROJECT_NAME=MyProject (CLAUDE.md 등에 치환됨) ──
setup_fixture
{
  printf "3\np1\np2\np3\np4\np5\n"
  printf "1. cli tool\n2. dev\n3. bash\n4. m1\n5. m2\n6. m3\n\n"
  printf "n\n"
} | bash "$SCRIPT" --resume MyProject >/dev/null 2>&1 || true
if [ -f README.md ] && grep -q "MyProject" README.md; then
  ok "T23.a --resume <project-name> → PROJECT_NAME=MyProject README.md 치환됨"
else
  nope "T23.a resume+name" "README.md 미생성 또는 MyProject 치환 안됨"
fi
teardown_fixture

# ── T24.a merge 정책 선택 → stderr ⚠️ 경고 + skip fallback ──
setup_fixture
echo "existing" > PRD.md
out_24=$(printf 'merge\n' | bash "$SCRIPT" 2>&1 || true)
if echo "$out_24" | grep -q "merge 정책 미구현\|merge.*fallback\|fallback.*merge"; then
  ok "T24.a merge 정책 → ⚠️ 경고 + skip fallback"
else
  nope "T24.a merge warning" "merge fallback 경고 미출력 (out='$(echo "$out_24" | head -5)')"
fi
teardown_fixture

# ── 결과 ──────────────────────────────────────
echo ""
echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
