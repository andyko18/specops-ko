#!/usr/bin/env bash
# design-reviewer-ko 계약 — evaluator·판정 시그널·start-all 배선
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }

AG="$PLUGIN/agents/design-reviewer-ko.md"
SA="$PLUGIN/commands/start-all.md"

[ -f "$AG" ] || { nope "T0 agent 파일" "부재"; finish; }

grep -q '^role: evaluator' "$AG" \
  && ok "T1 role: evaluator" || nope "T1" "evaluator 마커 없음"

# Write/Edit 하드 박탈 — tools 라인에 Write|Edit 없어야 함
tools=$(awk '/^tools:/{print; exit}' "$AG")
printf '%s' "$tools" | grep -Eqi 'Write|Edit' \
  && nope "T2 tools" "Write/Edit 잔존: $tools" \
  || ok "T2 tools Write/Edit 부재"

grep -q 'DESIGN-REVIEW-RESULT' "$AG" \
  && ok "T3 판정 시그널" || nope "T3" "DESIGN-REVIEW-RESULT 없음"

grep -q '실측 의무' "$AG" && grep -q 'Interactions' "$AG" \
  && ok "T4 실측·Interactions 관점" || nope "T4" "실측/Interactions 부재"

grep -q 'specops-ko:design-reviewer-ko' "$SA" \
  && grep -q 'design-review.md' "$SA" \
  && ok "T5 start-all dispatch 배선" || nope "T5" "start-all 미배선"

# A 또는 B 산출 시 항상 — SKIP은 둘 다 없을 때만
grep -qE '하나라도 산출|항상' "$SA" \
  && ok "T6 항상 리뷰 계약" || nope "T6" "항상 조건 부재"

# Wave B: Critical cap §auto 정지 + Important-only 자동통과 + Critical 집계줄 파싱
grep -qE '\^Critical:|Critical:\[\[:space:\]\]' "$SA" \
  && grep -q 'Important-only cap' "$SA" \
  && grep -qE 'Critical cap|§auto 자동통과 금지' "$SA" \
  && ok "T7 Critical 정지·Important auto-pass 산문" \
  || nope "T7" "Wave B Critical/Important 계약 부재"

finish
