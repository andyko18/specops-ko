#!/usr/bin/env bash
# test-design-screen.sh — scripts/_internal/design-screen.sh 검증
set -u

PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SCRIPT="$PLUGIN/scripts/_internal/design-screen.sh"
PASS=0; FAIL=0

# 격리 임시 디렉토리
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp "$PLUGIN/templates/screen.md"  "$TMP/screen.md"
cp "$PLUGIN/templates/screen.html" "$TMP/screen.html"

# T1: 스크립트 존재 + exec-bit
[ -f "$SCRIPT" ] && [ -x "$SCRIPT" ] \
  && ok  "T1.a design-screen.sh 존재 + exec-bit" \
  || nope "T1.a design-screen.sh 존재 + exec-bit" "$SCRIPT 없거나 exec-bit 없음"

# --- 이하 테스트는 임시 디렉토리를 프로젝트 루트로 사용 ---
cd "$TMP"

# T2: 유효 이름 → 파일 생성
bash "$SCRIPT" login >/dev/null 2>&1
[ -f "screens/login.md" ] && [ -f "screens/login.html" ] \
  && ok  "T2.a 유효 이름 → screens/login.md + screens/login.html 생성" \
  || nope "T2.a 유효 이름 → 파일 생성" "screens/login.{md,html} 없음"

# T2.b: screen.md frontmatter screen: 필드 확인
grep -q 'screen: "login"' "screens/login.md" 2>/dev/null \
  && ok  "T2.b screen.md frontmatter screen: 올바름" \
  || nope "T2.b screen.md frontmatter screen:" "screen: \"login\" 없음"

# T3: DESIGN.md Primary 색상이 HTML --color-primary에 반영
# DESIGN.md 없을 때 fallback #7C3AED
grep -q -- '--color-primary:' "screens/login.html" 2>/dev/null \
  && ok  "T3.a HTML --color-primary 변수 존재" \
  || nope "T3.a HTML --color-primary" "--color-primary 없음"

# T3.b: DESIGN.md 있을 때 색상 추출 적용
cat > "$TMP/DESIGN.md" <<'DEOF'
## 1. Color System
| Role | Value | Usage |
|---|---|---|
| Primary | `#123456` | 주요 버튼 |
DEOF
bash "$SCRIPT" profile --force >/dev/null 2>&1
grep -q '#123456' "screens/profile.html" 2>/dev/null \
  && ok  "T3.b DESIGN.md Primary 색상 추출 → HTML 반영" \
  || nope "T3.b DESIGN.md 색상 추출" "#123456 이 HTML 에 없음"

# T3.c: 전체 팔레트(9색) 주입 — Primary 외 Background/Surface/Text 등도 반영 (half-fix 회귀 차단)
# light 테마 DESIGN.md 로 부트스트랩 시 --color-bg 가 다크 기본값(#0F0F10)에서 실제값으로 바뀌어야 함.
cat > "$TMP/DESIGN.md" <<'DEOF'
## 1. Color System
| Role | Value | Usage |
|---|---|---|
| Primary | `#000000` | 주요 버튼 |
| Secondary | `#2383E2` | 보조 |
| Background | `#FFFFFF` | 페이지 배경 |
| Surface | `#F7F7F5` | 카드 |
| Text Primary | `#37352F` | 본문 |
| Text Secondary | `#787774` | 보조 텍스트 |
| Border | `#E9E9E7` | 테두리 |
| Error | `#EB5757` | 에러 |
| Success | `#0F7B6C` | 성공 |
DEOF
bash "$SCRIPT" palette --force >/dev/null 2>&1
if grep -q -- '--color-bg: #FFFFFF' "screens/palette.html" 2>/dev/null \
   && grep -q -- '--color-surface: #F7F7F5' "screens/palette.html" 2>/dev/null \
   && grep -q -- '--color-text: #37352F' "screens/palette.html" 2>/dev/null \
   && ! grep -q -- '--color-bg: #0F0F10' "screens/palette.html" 2>/dev/null; then
  ok  "T3.c 전체 팔레트 주입 (Background/Surface/Text — half-fix 차단)"
else
  nope "T3.c 전체 팔레트 주입" "--color-bg/surface/text 미반영 또는 다크 기본값 잔존"
fi

# T3.d: 미확정 색상(#______ placeholder)은 skip → 템플릿 기본값 유지 (Phase 6 단독 시점 안전)
cat > "$TMP/DESIGN.md" <<'DEOF'
## 1. Color System
| Role | Value | Usage |
|---|---|---|
| Primary | `#000000` | 주요 버튼 |
| Background | `#______` | 미확정 |
DEOF
bash "$SCRIPT" partial --force >/dev/null 2>&1
if grep -q -- '--color-primary: #000000' "screens/partial.html" 2>/dev/null \
   && grep -q -- '--color-bg: #0F0F10' "screens/partial.html" 2>/dev/null; then
  ok  "T3.d 미확정 색상 skip → 템플릿 기본값 유지"
else
  nope "T3.d 미확정 색상 skip" "placeholder 를 잘못 주입했거나 primary 미반영"
fi

# T4: screens-overview.md 갱신
mkdir -p .specops/memory
cp "$PLUGIN/templates/screens-overview.md" .specops/memory/screens-overview.md
sed -i.bak 's/<PROJECT_NAME>/TestProj/' .specops/memory/screens-overview.md
bash "$SCRIPT" contact >/dev/null 2>&1
grep -q 'contact' ".specops/memory/screens-overview.md" 2>/dev/null \
  && ok  "T4.a screens-overview.md 표에 신규 행 추가됨" \
  || nope "T4.a screens-overview.md 갱신" "contact 행 없음"

# T5: 잘못된 이름 → exit 1
bash "$SCRIPT" "../evil" 2>/dev/null; code=$?
[ "$code" -ne 0 ] \
  && ok  "T5.a 잘못된 이름 ../evil → exit 1" \
  || nope "T5.a 잘못된 이름 ../evil" "exit code=$code (0이면 안 됨)"

bash "$SCRIPT" "a b" 2>/dev/null; code=$?
[ "$code" -ne 0 ] \
  && ok  "T5.b 잘못된 이름 'a b' → exit 1" \
  || nope "T5.b 잘못된 이름 'a b'" "exit code=$code (0이면 안 됨)"

# T6: 충돌 보호
bash "$SCRIPT" login 2>/dev/null; code=$?
[ "$code" -ne 0 ] \
  && ok  "T6.a 기존 파일 + --force 없음 → exit 1" \
  || nope "T6.a 충돌 보호" "exit code=$code (0이면 안 됨)"

# T6.b: --force 시 덮어쓰기
bash "$SCRIPT" login --force >/dev/null 2>&1; code=$?
[ "$code" -eq 0 ] && [ -f "screens/login.md" ] \
  && ok  "T6.b --force → 덮어쓰기 성공" \
  || nope "T6.b --force 덮어쓰기" "exit code=$code"

# T7: screens-overview.md 없을 때 exit 0 + 파일 생성 성공
bash "$SCRIPT" about >/dev/null 2>&1; code=$?
[ "$code" -eq 0 ] && [ -f "screens/about.md" ] \
  && ok  "T7.a screens-overview.md 없을 때 exit 0 + 파일 생성 성공" \
  || nope "T7.a overview 부재 graceful" "exit=$code"

# T8: 동일 이름 중복 추가 → overview 표에 1행만
mkdir -p .specops/memory
cp "$PLUGIN/templates/screens-overview.md" .specops/memory/screens-overview.md
sed -i.bak 's/<PROJECT_NAME>/TestProj/' .specops/memory/screens-overview.md
bash "$SCRIPT" dup >/dev/null 2>&1
bash "$SCRIPT" dup --force >/dev/null 2>&1  # 동일 이름 재실행
count=$(grep -c '| dup |' .specops/memory/screens-overview.md 2>/dev/null || echo 0)
[ "$count" -eq 1 ] \
  && ok  "T8.a 동일 이름 중복 → overview 1행만 (중복 없음)" \
  || nope "T8.a 중복 방어" "dup 행 수=$count (기대 1)"


# T9: DESIGN.md 템플릿 §1 에 Border 행 존재 (9색 헬퍼 매핑 정합 — P1-1 audit 20260710)
grep -q '| Border |' "$PLUGIN/templates/DESIGN.md" \
  && ok  "T9.a 템플릿 DESIGN.md Border 행 존재 (9색 매핑 정합)" \
  || nope "T9.a 템플릿 Border 행" "lib.sh 9매핑 vs 템플릿 8행 — Border 주입 영구 no-op"

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
