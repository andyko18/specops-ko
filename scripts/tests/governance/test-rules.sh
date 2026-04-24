#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
RULES="$PLUGIN/hooks/rules.jsonl"

# T5.a rules.jsonl 존재 + 5 룰
if [ -f "$RULES" ]; then
  count=$(jq -s 'length' "$RULES" 2>/dev/null)
  if [ "$count" = "5" ]; then
    PASS=$((PASS+1)); echo "PASS T5.a rules.jsonl 5 룰"
  else
    FAIL=$((FAIL+1)); echo "FAIL T5.a (count=$count expect=5)"
  fi
else
  FAIL=$((FAIL+1)); echo "FAIL T5.a (rules.jsonl 부재)"
fi

# T5.b R-1 ~ R-5 각 룰 필수 필드 완비
for id in R-1 R-2 R-3 R-4 R-5; do
  hit=$(jq -e --arg id "$id" 'select(.id == $id and .enabled == true and (.principle == 1 or .principle == 5) and (.matcher == "posttool" or .matcher == "stop") and (.severity == "warn"))' "$RULES" 2>/dev/null)
  if [ -n "$hit" ]; then
    PASS=$((PASS+1)); echo "PASS T5.b $id 완비"
  else
    FAIL=$((FAIL+1)); echo "FAIL T5.b $id"
  fi
done

# T5.c matcher 분류: posttool 3개 (R-1/R-2/R-3), stop 2개 (R-4/R-5)
posttool_count=$(jq -s '[.[] | select(.matcher == "posttool")] | length' "$RULES" 2>/dev/null)
stop_count=$(jq -s '[.[] | select(.matcher == "stop")] | length' "$RULES" 2>/dev/null)
if [ "$posttool_count" = "3" ] && [ "$stop_count" = "2" ]; then
  PASS=$((PASS+1)); echo "PASS T5.c matcher 분류 posttool=3 stop=2"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.c (posttool=$posttool_count stop=$stop_count)"
fi

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
