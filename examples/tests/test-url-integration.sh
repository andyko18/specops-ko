#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ENC="$PLUGIN/examples/scripts/urlencode.sh"
DEC="$PLUGIN/examples/scripts/urldecode.sh"

# T3.a 역함수: encode → decode = 원문
original="test & value=1"
out=$(echo "$original" | "$ENC" | "$DEC")
if [ "$out" = "$original" ]; then PASS=$((PASS+1)); echo "PASS T3.a encode→decode 역함수"
else FAIL=$((FAIL+1)); echo "FAIL T3.a (out=$out)"; fi

# T3.b 독립성: 상호 source 없음
if ! grep -q "urldecode" "$ENC" 2>/dev/null && ! grep -q "urlencode" "$DEC" 2>/dev/null; then
  PASS=$((PASS+1)); echo "PASS T3.b 독립성 (상호 source 없음)"
else FAIL=$((FAIL+1)); echo "FAIL T3.b (상호 참조 발견)"; fi

# T3.c + 보존 (unquote, not unquote_plus)
out=$("$DEC" "hello+world")
if [ "$out" = "hello+world" ]; then PASS=$((PASS+1)); echo "PASS T3.c + 그대로 보존"
else FAIL=$((FAIL+1)); echo "FAIL T3.c (out=$out)"; fi

echo; echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
