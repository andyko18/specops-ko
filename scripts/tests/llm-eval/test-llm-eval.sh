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

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
