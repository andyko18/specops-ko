#!/usr/bin/env bash
# test-design-screen.sh — scripts/_internal/design-screen.sh 검증
set -u

PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/_internal/design-screen.sh"
PASS=0; FAIL=0
ok()   { echo "PASS $1"; PASS=$((PASS+1)); }
nope() { echo "FAIL $1 — $2"; FAIL=$((FAIL+1)); }

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

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
