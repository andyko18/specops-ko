#!/usr/bin/env bash
# plan A/B 측정 하니스 — 집계 로직 stub 단위 테스트 (토큰 0)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "$0")/../../.." && pwd)
EVAL="$PLUGIN/scripts/tests/llm-eval"
FXDIR="$EVAL/plan-ab-fixtures"
RUNNER="$EVAL/run-plan-ab.sh"

# T1.a fixture 2개 구조 + defects jsonl 유효 + 3유형 분포
ok=1; tot_def=0; types=""
for d in cov-miss placeholder; do
  [ -f "$FXDIR/$d/plan.md" ] && [ -f "$FXDIR/$d/defects.jsonl" ] || ok=0
  if [ -f "$FXDIR/$d/defects.jsonl" ]; then
    while IFS= read -r l; do [ -z "$l" ] && continue; printf '%s' "$l" | jq -e . >/dev/null 2>&1 || ok=0; tot_def=$((tot_def+1)); types="$types $(printf '%s' "$l"|jq -r '.type')"; done < "$FXDIR/$d/defects.jsonl"
  fi
done
nt=$(printf '%s' "$types" | tr ' ' '\n' | grep -c . )
ut=$(printf '%s' "$types" | tr ' ' '\n' | sort -u | grep -c .)
if [ "$ok" = 1 ] && [ "$tot_def" -ge 4 ] && [ "$ut" -ge 3 ]; then
  PASS=$((PASS+1)); echo "PASS T1.a fixtures (defects=$tot_def types=$ut)"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a (ok=$ok def=$tot_def ut=$ut)"
fi

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
