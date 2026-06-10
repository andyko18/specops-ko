#!/usr/bin/env bash
# specops-auto-ko llm-eval — runner 판정 로직 단위 테스트 (stub 기반, 토큰 0)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
EVAL="$PLUGIN/scripts/tests/llm-eval"
FIXTURES="$EVAL/fixtures.jsonl"
RUNNER="$EVAL/run-evals.sh"
STUB="$EVAL/stub-claude.sh"

# T1.a fixtures.jsonl 전 라인 jq 유효
ok=1
while IFS= read -r line; do
  [ -z "$line" ] && continue
  printf '%s' "$line" | jq -e . >/dev/null 2>&1 || ok=0
done < "$FIXTURES"
if [ "$ok" = "1" ] && [ -s "$FIXTURES" ]; then
  PASS=$((PASS+1)); echo "PASS T1.a fixtures jsonl 유효"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a (invalid jsonl)"
fi

# T1.b 건수 ≥10 + 분류별 ≥2 (specifying-ko / analyzing-ko / none) + expect_any ≥2
total=$(grep -c . "$FIXTURES")
n_spec=$(jq -s '[.[] | select(.expect_skill=="specifying-ko")] | length' "$FIXTURES")
n_ana=$(jq -s '[.[] | select(.expect_skill=="analyzing-ko")] | length' "$FIXTURES")
n_none=$(jq -s '[.[] | select(.expect_skill=="none")] | length' "$FIXTURES")
n_any=$(jq -s '[.[] | select(.expect_any)] | length' "$FIXTURES")
if [ "$total" -ge 10 ] && [ "$n_spec" -ge 2 ] && [ "$n_ana" -ge 2 ] && [ "$n_none" -ge 2 ] && [ "$n_any" -ge 2 ]; then
  PASS=$((PASS+1)); echo "PASS T1.b 분류 구성 (total=$total spec=$n_spec ana=$n_ana none=$n_none any=$n_any)"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.b (total=$total spec=$n_spec ana=$n_ana none=$n_none any=$n_any)"
fi

# T2.a stub — STUB_PLAN 1째 줄 skill 지정 시 tool_use 이벤트 + result 이벤트 출력
TD=$(mktemp -d)
export STUB_STATE="$TD/count" STUB_PLAN="$TD/plan.jsonl"
echo '{"skill":"specops-auto-ko:specifying-ko","args":"CSV CLI","cost":0.1}' > "$STUB_PLAN"
out=$(bash "$STUB" -p "아무 프롬프트" --output-format stream-json 2>/dev/null)
got_skill=$(printf '%s\n' "$out" | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill' | head -1)
got_cost=$(printf '%s\n' "$out" | jq -r 'select(.type=="result") | .total_cost_usd' | head -1)
if [ "$got_skill" = "specops-auto-ko:specifying-ko" ] && [ "$got_cost" = "0.1" ] && [ "$(cat "$STUB_STATE")" = "1" ]; then
  PASS=$((PASS+1)); echo "PASS T2.a stub tool_use + result + 카운터"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.a (skill=$got_skill cost=$got_cost)"
fi
rm -rf "$TD"

# ── T3 runner 코어 (stub 기반) ──
mk_fx() { # $1=파일 $2...=jsonl 줄들
  local f="$1"; shift; : > "$f"
  for l in "$@"; do printf '%s\n' "$l" >> "$f"; done
}

# T3.a 일치 → PASS + exit 0
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" '{"id":"new-1","prompt":"CLI 만들어줘","expect_skill":"specifying-ko","expect_flag":"new"}'
mk_fx "$STUB_PLAN" '{"skill":"specops-auto-ko:specifying-ko","args":"CLI","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '^PASS new-1'; then
  PASS=$((PASS+1)); echo "PASS T3.a 일치 판정"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.a (rc=$rc out=$out)"
fi
rm -rf "$TD"

# T3.b skill 불일치 → FAIL + exit 1 (재시도 2회 모두 불일치)
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" '{"id":"new-1","prompt":"CLI 만들어줘","expect_skill":"specifying-ko","expect_flag":"new"}'
mk_fx "$STUB_PLAN" '{"skill":"specops-auto-ko:analyzing-ko","args":"x","cost":0}' '{"skill":"specops-auto-ko:analyzing-ko","args":"x","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q '^FAIL new-1'; then
  PASS=$((PASS+1)); echo "PASS T3.b 불일치 판정"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.b (rc=$rc out=$out)"
fi
rm -rf "$TD"

# T3.c expect_skill=none 인데 Skill 호출 → FAIL
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" '{"id":"none-1","prompt":"jq 어디서 써?","expect_skill":"none","expect_flag":"none"}'
mk_fx "$STUB_PLAN" '{"skill":"specops-auto-ko:specifying-ko","args":"x","cost":0}' '{"skill":"specops-auto-ko:specifying-ko","args":"x","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q '^FAIL none-1'; then
  PASS=$((PASS+1)); echo "PASS T3.c none 위반 판정"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.c (rc=$rc out=$out)"
fi
rm -rf "$TD"

# T3.d none + Skill 미호출 → PASS / maintain flag 누락 → FAIL (AC-4)
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" \
  '{"id":"none-2","prompt":"개념 설명해줘","expect_skill":"none","expect_flag":"none"}' \
  '{"id":"maint-1","prompt":"버그 고쳐줘","expect_skill":"analyzing-ko","expect_flag":"maintain"}'
mk_fx "$STUB_PLAN" \
  '{"skill":null}' \
  '{"skill":"specops-auto-ko:analyzing-ko","args":"버그 고쳐줘 (flag 없음)","cost":0}' \
  '{"skill":"specops-auto-ko:analyzing-ko","args":"버그 고쳐줘 (flag 없음)","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q '^PASS none-2' && echo "$out" | grep -q '^FAIL maint-1'; then
  PASS=$((PASS+1)); echo "PASS T3.d none-PASS + maintain flag 누락 FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.d (rc=$rc out=$out)"
fi
rm -rf "$TD"

# T3.e maintain flag 첫 줄 포함 → PASS (AC-4 양성) + 요약 포맷 (AC-5)
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" '{"id":"maint-1","prompt":"버그 고쳐줘","expect_skill":"analyzing-ko","expect_flag":"maintain"}'
mk_fx "$STUB_PLAN" '{"skill":"specops-auto-ko:analyzing-ko","args":"<!-- entry: maintain -->\n버그 고쳐줘","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '^PASS maint-1' \
   && echo "$out" | grep -qE 'PASS=[0-9]+ FAIL=[0-9]+ SKIP=[0-9]+ BORDERLINE=[0-9]+ COST=\$'; then
  PASS=$((PASS+1)); echo "PASS T3.e maintain flag PASS + 요약 포맷"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.e (rc=$rc out=$out)"
fi
rm -rf "$TD"

# T3.f claude 부재 → SKIP + exit 0 (AC-3)
out=$(CLAUDE_BIN=/nonexistent-claude bash "$RUNNER" "$FIXTURES" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '^SKIP: claude CLI 부재' && echo "$out" | grep -q 'SKIP=10'; then
  PASS=$((PASS+1)); echo "PASS T3.f CLI 부재 graceful SKIP"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.f (rc=$rc out=$out)"
fi

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
