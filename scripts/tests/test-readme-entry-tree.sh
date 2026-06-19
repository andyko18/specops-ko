#!/usr/bin/env bash
# README §2 진입로 결정 트리 검증 (FID 20260619-entry-decision-tree)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
R="$PLUGIN/README.md"
ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
nope() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }

# AC-1: /start-auto 등장
grep -q '/start-auto' "$R" && ok "AC-1 start-auto 등장" || nope "AC-1" "start-auto 누락"
# AC-2: 7종 모두 등장
miss=""
for s in '/start ' '/start-auto' '/start-foundation' '/start-batch' '/init-project' '/maintain' '/brainstorming'; do
  grep -q -- "$s" "$R" || miss="$miss $s"
done
[ -z "$miss" ] && ok "AC-2 7종 진입로 등장" || nope "AC-2" "누락:$miss"
# AC-3: start↔maintain 판단 기준 (신규/기존 키워드)
grep -qiE '신규.*기존|기존.*수정|신규 산출물' "$R" && ok "AC-3 판단 기준" || nope "AC-3" "판단 기준 없음"
# AC-4: project→foundation→batch 순서 표현 (한 줄 요약 라인 매칭 — grep 줄단위)
grep -qE '/init-project →.*/start-foundation →.*/start-batch' "$R" && ok "AC-4 선택 순서" || nope "AC-4" "순서 흐름 없음"
# AC-5: start vs start-auto 차이 (게이트/자동통과)
grep -qiE '게이트.*자동|자동 통과|가역 게이트' "$R" && ok "AC-5 게이트 차이" || nope "AC-5" "게이트 차이 없음"
# AC-R-1: 기존 자동체인 설명 보존
grep -qE 'spec → clarify → plan' "$R" && ok "AC-R-1 자동체인 설명 보존" || nope "AC-R-1" "자동체인 설명 소실"
grep -q 'using-specops-auto-ko-ko' "$R" && ok "AC-R-1b 라우팅 설명 보존" || nope "AC-R-1b" "라우팅 설명 소실"

echo "── test-readme-entry-tree: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
