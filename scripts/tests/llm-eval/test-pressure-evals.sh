#!/usr/bin/env bash
# 압박 eval runner 판정 단위 테스트 (stub, 토큰 0)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "$0")/../../.." && pwd)
EVAL="$PLUGIN/scripts/tests/llm-eval"
FX="$EVAL/pressure-fixtures.jsonl"
RUNNER="$EVAL/run-pressure-evals.sh"

# T1.a fixtures jsonl 유효 + ≥6 + 3유형 (impl/test/spec) 각 ≥1
ok=1
while IFS= read -r l; do [ -z "$l" ] && continue; printf '%s' "$l" | jq -e . >/dev/null 2>&1 || ok=0; done < "$FX"
n=$(grep -c . "$FX")
ni=$(jq -s '[.[]|select(.id|startswith("impl"))]|length' "$FX")
nt=$(jq -s '[.[]|select(.id|startswith("test"))]|length' "$FX")
ns=$(jq -s '[.[]|select(.id|startswith("spec"))]|length' "$FX")
if [ "$ok" = 1 ] && [ "$n" -ge 6 ] && [ "$ni" -ge 1 ] && [ "$nt" -ge 1 ] && [ "$ns" -ge 1 ]; then
  PASS=$((PASS+1)); echo "PASS T1.a fixtures (n=$n impl=$ni test=$nt spec=$ns)"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a (ok=$ok n=$n i=$ni t=$nt s=$ns)"
fi

# T1.b 필드 완결성 (forbidden_tools 배열·gate_phrases 문자열)
miss=$(jq -s '[.[]|select((.forbidden_tools|type)!="array" or (.gate_phrases|type)!="string")]|length' "$FX")
if [ "$miss" = 0 ]; then
  PASS=$((PASS+1)); echo "PASS T1.b 필드 완결"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.b (miss=$miss)"
fi

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
