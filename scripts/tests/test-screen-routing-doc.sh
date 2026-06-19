#!/usr/bin/env bash
# 화면 설계 경로 분업 문서 검증 (FID 20260619-screen-routing-doc)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
nope() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }
DS="$PLUGIN/commands/design-screen.md"
DSS="$PLUGIN/commands/design-screens.md"
SP="$PLUGIN/skills/specifying-ko/SKILL.md"

# AC-1: design-screen.md 에 분업표 섹션(신규 헤더) + 3경로
grep -q '^## 화면 설계 3경로 분업' "$DS" && grep -q 'Step 5.5' "$DS" && grep -q '/design-screens' "$DS" \
  && ok "AC-1 분업표 3경로" || nope "AC-1" "분업표 헤더/3경로 누락"
# AC-2: "언제 쓰나" 기준 — 분업표 블록 *내부*에서만 검사 (기존 텍스트 false-pass 방지)
TBL=$(awk '/^## 화면 설계 3경로 분업/,/^## [^화]/' "$DS")
printf '%s' "$TBL" | grep -qiE 'lifecycle 자동' && printf '%s' "$TBL" | grep -qiE '독립' \
  && ok "AC-2 언제쓰나 기준(표 내부)" || nope "AC-2" "표 내부 기준 없음"
# AC-3: design-screens.md 에 분업표 가리키는 *신규 고유* cross-ref (기존 L118 과 구분)
grep -q '§화면 설계 3경로 분업' "$DSS" && ok "AC-3 design-screens cross-ref(고유)" || nope "AC-3" "고유 cross-ref 없음"
# AC-4: specifying Step5.5 cross-ref
awk '/^5\.5\./,/^6\. /' "$SP" | grep -qE '/design-screen' && ok "AC-4 Step5.5 cross-ref" || nope "AC-4" "cross-ref 없음"

# AC-R-1: Step5.5 기존 로직 보존
awk '/^5\.5\./,/^6\. /' "$SP" | grep -q 'ui-ux-pro-max' && ok "AC-R-1 ui-ux-pro-max 보존" || nope "AC-R-1" "기존 로직 소실"
awk '/^5\.5\./,/^6\. /' "$SP" | grep -q '§auto' && ok "AC-R-1b §auto 분기 보존" || nope "AC-R-1b" "§auto 소실"
# AC-R-2: design-screen Process 보존
grep -q '^## Process' "$DS" && grep -q 'design-screen.sh' "$DS" && ok "AC-R-2 Process 보존" || nope "AC-R-2" "Process 소실"

echo "── test-screen-routing-doc: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
