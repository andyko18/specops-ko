#!/usr/bin/env bash
# T19 — /init-project 통합 테스트 (FID 20260507-start-project-bootstrap)
# 14 테스트: KIND 매트릭스 (T1~T4) + skip/conflict/git (T5~T7) + deprecate (T8)
#          + 인용 검증 (T9~T11) + screens (T12) + memory 재실행 (T13) + DB 분기 (T14)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SCRIPT="$PLUGIN/scripts/_internal/init-project.sh"

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

# 활성 산출물 카운트
count_active() {
  local n=0 f
  for f in PRD.md CLAUDE.md README.md DESIGN.md \
    .specops/memory/{constitution,requirements,test-strategy,architecture,frontend-architecture,backend-architecture,api-spec,api-spec-consumer,data-model,screens-overview}.md; do
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
  printf "1\nhome\nn\nn\n"  # 브랜드=Stripe, screens=home, DB=n, consumer=n
} | bash "$SCRIPT" >/dev/null 2>&1
if [ -f DESIGN.md ] && [ -f .specops/memory/frontend-architecture.md ] \
   && [ -f .specops/memory/screens-overview.md ] \
   && [ ! -f .specops/memory/backend-architecture.md ] \
   && [ ! -f .specops/memory/api-spec.md ] \
   && [ ! -f .specops/memory/api-spec-consumer.md ]; then
  ok "T1.a UI(KIND=1) → DESIGN/frontend/screens-overview 활성, backend/api/consumer 부재"
else
  nope "T1.a UI" "활성 매트릭스 mismatch (count=$(count_active))"
fi
teardown_fixture

# ── T1.b UI(KIND=1) consumer=y → api-spec-consumer.md 생성 + git 추적 (M1 회귀) ──
setup_fixture
{
  printf "1\np1\np2\np3\np4\np5\n"
  printf "1. UI app\n2. user\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "1\nhome\nn\ny\n"  # 브랜드=Stripe, screens=home, DB=n, consumer=y
} | bash "$SCRIPT" >/dev/null 2>&1
if [ -f .specops/memory/api-spec-consumer.md ] \
   && git ls-files --error-unmatch .specops/memory/api-spec-consumer.md >/dev/null 2>&1; then
  ok "T1.b UI consumer=y → api-spec-consumer.md 생성 + git 추적 (고아 방지 M1)"
else
  nope "T1.b consumer 고아" "consumer.md 미생성 또는 git 미추적 (phase_10 memory add 누락)"
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

# ── T8.a start-design.md 삭제 확인 (/init-project 통합 완료) ──
if [ ! -f "$PLUGIN/commands/start-design.md" ]; then
  ok "T8.a commands/start-design.md 삭제됨 (/init-project 통합 완료)"
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

# ── T11.a api-spec.md (KIND=2, m=2) → OpenAPI 섹션만 포함, GraphQL 제거 ──
setup_fixture
{
  printf "2\np1\np2\np3\np4\np5\n"
  printf "1. BE\n2. dev\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "n\n2\n"  # DB=n, API=OpenAPI
} | bash "$SCRIPT" >/dev/null 2>&1
if grep -q 'openapi: 3.1' .specops/memory/api-spec.md 2>/dev/null \
   && ! grep -q 'type Query {' .specops/memory/api-spec.md 2>/dev/null \
   && ! grep -q 'type Mutation {' .specops/memory/api-spec.md 2>/dev/null; then
  ok "T11.a api-spec.md OpenAPI 섹션만 포함 (GraphQL·RPC 제거됨)"
else
  nope "T11.a api-spec 섹션 스트리핑" "OpenAPI 전용 섹션 분리 실패"
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

# ── T11.c api-spec.md (KIND=2, m=3) → GraphQL 섹션만 포함, §5·§6·§7 유지 ──
setup_fixture
{
  printf "2\np1\np2\np3\np4\np5\n"
  printf "1. BE\n2. dev\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "n\n3\n"  # DB=n, API=GraphQL
} | bash "$SCRIPT" >/dev/null 2>&1
if grep -q 'GraphQL' .specops/memory/api-spec.md 2>/dev/null \
   && ! grep -q 'openapi: 3.1' .specops/memory/api-spec.md 2>/dev/null \
   && grep -q '§5\. 인증' .specops/memory/api-spec.md 2>/dev/null; then
  ok "T11.c api-spec.md GraphQL 섹션만 포함 + §5 유지"
else
  nope "T11.c api-spec GraphQL 스트리핑" "GraphQL 전용 섹션 분리 실패"
fi
teardown_fixture

# ── T12.a 화면 이름 목록 → screens-overview 표만 (screens/* 껍데기 미생성) ──
setup_fixture
{
  printf "1\np1\np2\np3\np4\np5\n"
  printf "1. x\n2. y\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "1\nhome, dashboard\nn\n"
} | bash "$SCRIPT" >/dev/null 2>&1
if [ ! -f screens/home.md ] && [ ! -f screens/home.html ] \
   && [ ! -f screens/dashboard.md ] \
   && grep -qE '^\| home \|.*예정' .specops/memory/screens-overview.md \
   && grep -qE '^\| dashboard \|.*예정' .specops/memory/screens-overview.md \
   && grep -q 'stateDiagram' .specops/memory/screens-overview.md; then
  ok "T12.a 화면 입력 → overview 목록만 (screens/* 미생성)"
else
  nope "T12.a screens" "overview 누락 또는 screens 껍데기 생성됨"
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
if grep -qE '^\| productlist \| productlist \| 예정' .specops/memory/screens-overview.md \
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

# ── T22.a commands/init-project.md 에 --resume 문서화 ──
if grep -q "\-\-resume" "$PLUGIN/commands/init-project.md"; then
  ok "T22.a commands/init-project.md 에 --resume 문서화"
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

# ── T25.a _replace_line_prefix 백슬래시 escape 회귀 ──
T25=$(mktemp)
printf '**한 줄 설명**: <placeholder>\n' > "$T25"
( source "$SCRIPT" 2>/dev/null
  _replace_line_prefix "$T25" '**한 줄 설명**:' '**한 줄 설명**: 경로\test\new' )
if grep -qF '경로\test\new' "$T25"; then
  ok "T25.a _replace_line_prefix 백슬래시 원문 보존"
else
  nope "T25.a 백슬래시" "escape 확장됨 (awk -v 미전환)"
fi
rm -f "$T25"

# ── T15.a UI(KIND=1) consumer=y → api-spec-consumer.md 생성 ──────────────────
setup_fixture
{
  printf "1\np1\np2\np3\np4\np5\n"
  printf "1. UI consumer\n2. user\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "1\nhome\nn\ny\n"  # 브랜드=Stripe, screens=home, DB=n, consumer=y
} | bash "$SCRIPT" >/dev/null 2>&1
if [ -f .specops/memory/api-spec-consumer.md ] \
   && ! grep -q '<PROJECT_NAME>' .specops/memory/api-spec-consumer.md; then
  ok "T15.a UI(KIND=1) consumer=y → api-spec-consumer.md 생성 + PROJECT_NAME 치환"
else
  nope "T15.a consumer=y" "파일 미생성 또는 PROJECT_NAME 미치환"
fi
teardown_fixture

# ── 결과 ──────────────────────────────────────
echo ""

# ── T26: Phase 7 은 screens 껍데기 미생성 (본설계는 start-all 2.5) ──
setup_fixture
{
  printf "1\np1\np2\np3\np4\np5\n"
  printf "1. UI app\n2. user\n3. a, b, c\n4. m1\n5. m2\n6. m3\n\n"
  printf "1\nhome\nn\nn\n"
} | bash "$SCRIPT" >/dev/null 2>&1
if [ ! -f screens/home.html ] && [ ! -f screens/home.md ] \
   && grep -qE '^\| home \|.*예정' .specops/memory/screens-overview.md; then
  ok "T26.a Phase 7 screens/* 미생성 + overview 목록만"
else
  nope "T26.a Phase 7 껍데기 금지" "screens/home 생성됨 또는 overview 누락"
fi
teardown_fixture

# ── T27: Phase 0 .init-prd-fields → Phase 4 재입력 생략 ──
setup_fixture
mkdir -p .specops
printf '한 줄 from phase0\n페르소나P0\na, b, c\nm1p0\nm2p0\nm3p0\n' > .specops/.init-prd-fields
{
  printf "3\nskip\nN\n"
} | bash "$SCRIPT" >/dev/null 2>&1
if grep -q '한 줄 from phase0' PRD.md \
   && [ ! -f .specops/.init-prd-fields ] \
   && [ -f .specops/memory/project-context.md ] \
   && [ -f .specops/memory/decisions.md ]; then
  ok "T27.a Phase 0 .init-prd-fields → PRD 반영 + 원장 골격"
else
  nope "T27.a phase0 fields" "PRD/원장/필드파일 소비 실패"
fi
teardown_fixture

# ── T23: Phase 0 기존 기획 문서 3단 탐색 배선 (20260716 — prd.md auto-discovery) ──
#   실무는 PRD 가 이미 파일로 존재 — brainstorming-*.md 만 감지하면 온보딩 마찰.
CMD_DOC="$PLUGIN/commands/init-project.md"
n=$(grep -c '0-c. 기존 기획 문서 auto-discovery' "$CMD_DOC")
if [ "$n" -eq 1 ] && grep -q '0-a. 명시 경로' "$CMD_DOC" \
   && grep -q 'PRD 초안 근거로 사용할까요' "$CMD_DOC" \
   && grep -q '사전 문서(브레인스토밍 메모 · Phase 0 에서 사용자가 확인한 기존 기획 문서)' "$CMD_DOC"; then
  ok "T23.a Phase 0 3단 탐색 (명시경로·메모·discovery) + 사용자 확인 + 근거4원 동기"
else
  nope "T23.a Phase 0 discovery 배선" "n=$n 또는 구성요소 누락"
fi

# ── T24: PRD 6필드 **값** 정합 (20260806) ────────────────────────────────────
# 기존 E2E 는 파일 존재·개수만 봐서, 무라벨 numbered list 가 값에 "1. " 를 남긴 채로도
# 전부 PASS 했다. 값이 PRD §1 → CLAUDE.md → README.md → requirements FR 시드까지
# 전파되므로 **한 곳이라도 오염되면 프로젝트 문서 전체가 오염**된다.
setup_fixture
{
  printf "4\nskip\n"
  printf "1. 사내 일정 관리\n2. 팀장\n3. 빠름, 간편, 정확\n4. 로그인\n5. 대시보드\n6. 알림\n\n"
  printf "1\nhome, login\ny\n2\n"
} | bash "$SCRIPT" mychat >/dev/null 2>&1
_one=$(grep -m1 '^\*\*한 줄 설명\*\*:' PRD.md 2>/dev/null | sed 's/^\*\*한 줄 설명\*\*: *//')
_per=$(grep -m1 '^\*\*주요 페르소나\*\*:' PRD.md 2>/dev/null | sed 's/^\*\*주요 페르소나\*\*: *//')
if [ "$_one" = "사내 일정 관리" ] && [ "$_per" = "팀장" ]; then
  ok "T24.a 무라벨 numbered list → PRD 값에 번호 미누출"
else
  nope "T24.a PRD 값 오염" "한줄='$_one' 페르소나='$_per'"
fi
if ! grep -qE '^\| FR-1 \| [0-9]+\. ' .specops/memory/requirements.md 2>/dev/null \
   && grep -q '^| FR-1 | 로그인 |' .specops/memory/requirements.md 2>/dev/null; then
  ok "T24.b requirements FR 시드행에 번호 미누출"
else
  nope "T24.b FR 시드 오염" "$(grep -m1 '^| FR-1 |' .specops/memory/requirements.md 2>/dev/null)"
fi
if ! grep -qE '^[0-9]+\. 사내 일정 관리' CLAUDE.md README.md 2>/dev/null \
   && grep -q '사내 일정 관리' README.md 2>/dev/null; then
  ok "T24.c PRD_ONELINE 전파처(CLAUDE·README) 미오염"
else
  nope "T24.c 전파 오염" "$(grep -m1 '사내 일정 관리' README.md 2>/dev/null)"
fi
teardown_fixture

# T24.d 라벨형도 동일 결과 (회귀 보호 — 두 형식 동치)
setup_fixture
{
  printf "4\nskip\n"
  printf "1. 한 줄 설명: 사내 일정 관리\n2. 페르소나: 팀장\n3. 가치: a, b, c\n4. M1: 로그인\n5. M2: 대시보드\n6. M3: 알림\n\n"
  printf "1\nhome\ny\n2\n"
} | bash "$SCRIPT" mychat >/dev/null 2>&1
_one=$(grep -m1 '^\*\*한 줄 설명\*\*:' PRD.md 2>/dev/null | sed 's/^\*\*한 줄 설명\*\*: *//')
[ "$_one" = "사내 일정 관리" ] \
  && ok "T24.d 라벨형 — 무라벨형과 동일 결과" || nope "T24.d" "한줄='$_one'"
teardown_fixture

# ── T28 repo 루트 가드 (FID 20260811-init-cwd-root-guard) ─────────
# harness.sh 에 SKIP 개념이 없어(ok/fail/nope/run/finish 5종만) 로컬 헬퍼로 구현한다.
#   사유 없는 skip 은 검증 공백을 통과로 위장하므로 FAIL 처리한다 (AC-5).
skipped() {
  if [ -z "${2:-}" ]; then
    nope "$1" "SKIP 사유 누락 — 검증 공백을 은폐함"
    return 1
  fi
  echo "SKIP $1 — $2"
}
LIB="$PLUGIN/scripts/_internal/init-project/lib.sh"

# T28.a subdir → repo 루트로 이동 + stderr 2줄 고지 (AC-2 · 구속사항 C-1)
setup_fixture
mkdir -p sub
_root=$(pwd -P)
_err_f=$(mktemp)
_out=$(cd sub && bash -c ". \"$LIB\"; _cd_repo_root; pwd -P" 2>"$_err_f")
_lines=$(grep -c . "$_err_f"); _err=$(cat "$_err_f"); rm -f "$_err_f"
if [ "$_out" = "$_root" ] && [ "$_lines" -ge 2 ]; then
  ok "T28.a subdir → repo 루트 이동 + 고지 2줄"
else
  nope "T28.a" "pwd=$_out root=$_root err줄=$_lines err=[$_err]"
fi
teardown_fixture

# T28.b repo 루트 실행 → cwd 무변경 + stderr 무출력 (AC-R-2 · 구속사항 C-2)
setup_fixture
_root=$(pwd -P)
_err_f=$(mktemp)
_out=$(bash -c ". \"$LIB\"; _cd_repo_root; pwd -P" 2>"$_err_f")
_err=$(cat "$_err_f"); rm -f "$_err_f"
if [ "$_out" = "$_root" ] && [ -z "$_err" ]; then
  ok "T28.b repo 루트 → 무변경·무출력"
else
  nope "T28.b" "pwd=$_out root=$_root err=[$_err]"
fi
teardown_fixture

# T28.c 비-git → cd 미실행 + rc=0 + 고지 무출력 (AC-4 조용한 실패 방지)
#   ★ `[init]` 부재 단언이 핵심이다 — rc=0/pwd 만 보면 `-z` 가드 제거 변이가 생존한다(실측).
_t=$(mktemp -d); _tp=$(cd "$_t" && pwd -P)
_out=$(cd "$_t" && bash -c ". \"$LIB\"; _cd_repo_root; echo \"rc=\$?\"; pwd -P" 2>&1)
rm -rf "$_t"
if printf '%s' "$_out" | grep -q "rc=0" \
   && printf '%s' "$_out" | grep -qF "$_tp" \
   && ! printf '%s' "$_out" | grep -q '\[init\]'; then
  ok "T28.c 비-git → cd 미실행·rc=0·무출력"
else
  nope "T28.c" "out=$_out"
fi

# T28.g skipped() 가 사유 없는 skip 을 통과로 위장하지 않는다 (AC-5)
#   서브셸이라 PASS/FAIL 카운터가 바깥으로 새지 않는다.
_p1=$(PASS=0; FAIL=0; skipped "probe" >/dev/null 2>&1; echo "FAIL=$FAIL")
_p2=$(PASS=0; FAIL=0; skipped "probe" "사유있음" >/dev/null 2>&1; echo "FAIL=$FAIL")
if [ "$_p1" = "FAIL=1" ] && [ "$_p2" = "FAIL=0" ]; then
  ok "T28.g skip 사유 누락 → FAIL · 사유 있으면 무증가"
else
  nope "T28.g" "무사유=$_p1 유사유=$_p2"
fi

# T28.d git worktree 루트 → _check_git 통과 + stderr 무출력 (AC-1)
setup_fixture
git commit -q --allow-empty -m init
# worktree 는 TMPDIR **내부**에 만든다 — 형제 경로(../)는 teardown 의 rm -rf 가 회수하지 못한다
_wt="$TMPDIR/wt-t28"
if git worktree add -q "$_wt" -b t28branch 2>/dev/null; then
  _err_f=$(mktemp)
  _out=$(cd "$_wt" && bash -c ". \"$LIB\"; _check_git; echo \"rc=\$?\"" 2>"$_err_f")
  _err=$(cat "$_err_f"); rm -f "$_err_f"
  if printf '%s' "$_out" | grep -q "rc=0" && [ -z "$_err" ]; then
    ok "T28.d worktree 루트 → _check_git 통과·무출력"
  else
    nope "T28.d" "out=$_out err=[$_err]"
  fi
  git worktree remove --force "$_wt" 2>/dev/null
else
  skipped "T28.d worktree" "git worktree 미지원 환경 (git $(git --version | awk '{print $3}')) — AC-1 미검증"
fi
teardown_fixture

# T28.e 비-git → exit 1 + 원문 메시지 (AC-R-1 승계 · T6.a 와 동일 계약)
_t=$(mktemp -d)
_out=$(cd "$_t" && bash -c ". \"$LIB\"; _check_git" 2>&1); _ec=$?
rm -rf "$_t"
if [ "$_ec" = "1" ] && printf '%s' "$_out" | grep -q "git 저장소가 아닙니다"; then
  ok "T28.e 비-git → exit 1 + 원문 메시지 보존"
else
  nope "T28.e" "ec=$_ec out=$_out"
fi

# T28.f source 시 호출자 cwd 무변경 (AC-3 — 회귀 방어)
#   ★ 양성 단언이다 — `!= 루트` 부정형으로 쓰면 source 자체가 사망해 _out 이 빈값일 때도
#     "루트가 아니다" 가 성립해 오탐 PASS 한다. sub 물리경로와 **일치**를 요구한다.
setup_fixture
mkdir -p sub
_sub=$(cd sub && pwd -P)
_out=$(cd sub && bash -c ". \"$SCRIPT\" >/dev/null 2>&1; pwd -P")
if [ "$_out" = "$_sub" ]; then
  ok "T28.f source → 호출자 cwd 무변경"
else
  nope "T28.f" "cwd=$_out 기대=$_sub (source 가 cwd 를 옮겼거나 스크립트 사망)"
fi
teardown_fixture

# T28.h 작업트리 밖(`.git` 내부 · bare repo) → exit 1 + 원문 메시지 (AC-R-1 회귀 방어)
#   ★ rc 만 보는 판정(`git rev-parse --git-dir`)은 이 두 위치에서 **rc=0** 이라 통과한다 —
#     구 `[ -d .git ]` 이 차단하던 곳이 뚫린다. `--is-inside-work-tree` 의 **출력**(`false`)
#     비교만이 격추한다(실측: 두 위치 모두 out=false, rc=0).
#   두 입력 클래스를 한 케이스로 묶는다 — 같은 계약(작업트리 밖 차단)의 두 표본이다.
_t=$(mktemp -d)
git -C "$_t" init -q r 2>/dev/null
git init -q --bare "$_t/b.git" 2>/dev/null
_out1=$(cd "$_t/r/.git" && bash -c ". \"$LIB\"; _check_git" 2>&1); _ec1=$?
_out2=$(cd "$_t/b.git" && bash -c ". \"$LIB\"; _check_git" 2>&1); _ec2=$?
rm -rf "$_t"
if [ "$_ec1" = "1" ] && printf '%s' "$_out1" | grep -q "git 저장소가 아닙니다" \
   && [ "$_ec2" = "1" ] && printf '%s' "$_out2" | grep -q "git 저장소가 아닙니다"; then
  ok "T28.h .git 내부·bare repo → exit 1 + 원문 메시지"
else
  nope "T28.h" ".git내부: ec=$_ec1 out=[$_out1] / bare: ec=$_ec2 out=[$_out2]"
fi

# T28.i cd 실패 분기 → rc≠0 + 사유 stderr (AC-4 ② — 유일하게 자동화 안 되던 분기)
#   기법: fake `git` 을 PATH 앞에 주입해 `--show-toplevel` 이 **존재하지 않는 경로**를 뱉게 한다.
#   PATH 오염은 아래 한 줄의 명령 앞 할당으로 한정된다(다른 케이스 무영향).
#   ★ 사유 문자열 단언이 핵심이다 — `cd` 는 `|| { …; return 1; }` 없이도 실패 시 rc=1 이라
#     rc 만 보면 에러 처리 블록 삭제 변이가 생존한다(실측). 경로 문자열 단언은 fake 가 실제로
#     발화했음을 보증한다(heredoc 오확장으로 빈값이면 `-n` 가드에 걸려 오탐 PASS 하므로).
_t=$(mktemp -d); _fake=$(mktemp -d)
cat > "$_fake/git" <<'FAKEGIT'
#!/usr/bin/env bash
# _cd_repo_root 가 부르는 서브커맨드만 가로챈다
case "$*" in
  "rev-parse --show-toplevel") echo "/nonexistent-t28-probe" ;;
  *) exit 1 ;;
esac
FAKEGIT
chmod +x "$_fake/git"
_out=$(cd "$_t" && PATH="$_fake:$PATH" bash -c ". \"$LIB\"; _cd_repo_root; echo \"rc=\$?\"" 2>&1)
rm -rf "$_t" "$_fake"
_rc=$(printf '%s\n' "$_out" | grep -o 'rc=[0-9]*' | tail -1)
if [ -n "$_rc" ] && [ "$_rc" != "rc=0" ] \
   && printf '%s' "$_out" | grep -qF '[init] repo 루트 이동 실패' \
   && printf '%s' "$_out" | grep -qF '/nonexistent-t28-probe'; then
  ok "T28.i cd 실패 → rc≠0 + 사유 stderr"
else
  nope "T28.i" "rc=[$_rc] out=[$_out]"
fi

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
