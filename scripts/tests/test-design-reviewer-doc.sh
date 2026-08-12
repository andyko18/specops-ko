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

# ── 문서·일관성 P0 드리프트 락 (gen-eval agents 수 · CLAUDE foundation 5.5) ──
GE="$PLUGIN/skills/generator-evaluator-ko/SKILL.md"
CL="$PLUGIN/CLAUDE.md"
[ -f "$GE" ] || { nope "T8 gen-eval 파일" "부재"; finish; }
[ -f "$CL" ] || { nope "T11 CLAUDE.md" "부재"; finish; }

# T8: harness 매트릭스에 design-reviewer-ko 필수 (제거 시 FAIL — ghost-agent 재발 방지)
grep -q 'design-reviewer-ko' "$GE" \
  && ok "T8 gen-eval design-reviewer-ko" \
  || nope "T8" "generator-evaluator에 design-reviewer-ko 부재"

# T9: agents 8종 표기 + Evaluator 목록에 design-reviewer (구 '7종뿐' 회귀 금지)
grep -q '8종' "$GE" \
  && grep -q 'design-reviewer-ko' "$GE" \
  && ! grep -q '7종뿐' "$GE" \
  && ok "T9 gen-eval agents 8종 (7종뿐 부재)" \
  || nope "T9" "8종/design-reviewer 누락 또는 7종뿐 잔존"

# T10: agents/*.md 실측 == 8, gen-eval이 그와 모순되는 7종뿐 미포함
ag_count=$(ls "$PLUGIN"/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
[ "$ag_count" -eq 8 ] && ! grep -q '7종뿐' "$GE" \
  && ok "T10 agents 실측 8 + gen-eval 비모순" \
  || nope "T10" "agents=$ag_count (기대 8) 또는 gen-eval 7종뿐"

# T11: CLAUDE foundation Step 5.5 전면-skip 단정 금지 · 셸/allowlist 존재
#   구 문구: "Step 5.5 는 skip" / "Step 5.5(화면 루프) skip"
#   허용: "전면 skip 하지 않는다" + 셸 allowlist
if grep -qE 'Step 5\.5[[:space:]]*는[[:space:]]*skip|Step 5\.5\(화면 루프\)[[:space:]]*skip' "$CL"; then
  nope "T11" "CLAUDE foundation Step 5.5 전면-skip 잔존"
elif grep -qE '셸|allowlist|foundation-shell' "$CL"; then
  ok "T11 CLAUDE foundation 5.5 셸 전용"
else
  nope "T11" "CLAUDE에 셸/allowlist/foundation-shell 부재"
fi

# 변이(비-vacuous): design-reviewer 토큰 제거 시 T8과 동형 판정이 FAIL이어야 함
mut=$(mktemp)
sed '/design-reviewer-ko/d' "$GE" >"$mut"
grep -q 'design-reviewer-ko' "$mut" \
  && nope "T8.m" "변이 sed 실패(토큰 잔존)" \
  || ok "T8.m design-reviewer 제거 변이 → T8 동형 FAIL 경로"
rm -f "$mut"

finish
