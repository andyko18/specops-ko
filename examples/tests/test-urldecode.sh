#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SRC="$PLUGIN/examples/scripts/urldecode.sh"

out=$("$SRC" "hello%20world" 2>/dev/null)
if [ "$out" = "hello world" ]; then PASS=$((PASS+1)); echo "PASS T2.a hello%20world → hello world"
else FAIL=$((FAIL+1)); echo "FAIL T2.a (out=$out)"; fi

out=$("$SRC" "a%26b%3Dc" 2>/dev/null)
if [ "$out" = "a&b=c" ]; then PASS=$((PASS+1)); echo "PASS T2.b a%26b%3Dc → a&b=c"
else FAIL=$((FAIL+1)); echo "FAIL T2.b (out=$out)"; fi

out=$(echo "%ED%95%9C%EA%B5%AD%EC%96%B4" | "$SRC" 2>/dev/null)
if [ "$out" = "한국어" ]; then PASS=$((PASS+1)); echo "PASS T2.c percent → 한국어"
else FAIL=$((FAIL+1)); echo "FAIL T2.c (out=$out)"; fi

"$SRC" >/dev/null 2>&1 </dev/null
if [ $? -eq 1 ]; then PASS=$((PASS+1)); echo "PASS T2.d 인자 없음 → exit 1"
else FAIL=$((FAIL+1)); echo "FAIL T2.d"; fi

out=$("$SRC" "%ZZ" 2>/dev/null)
if [ "$out" = "%ZZ" ]; then PASS=$((PASS+1)); echo "PASS T2.e %ZZ 그대로 통과"
else FAIL=$((FAIL+1)); echo "FAIL T2.e (out=$out)"; fi

if [ -x "$SRC" ]; then PASS=$((PASS+1)); echo "PASS T2.f exec-bit"
else FAIL=$((FAIL+1)); echo "FAIL T2.f (exec-bit 없음)"; fi

echo; echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
