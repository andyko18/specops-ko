#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SRC="$PLUGIN/examples/scripts/urlencode.sh"

out=$("$SRC" "hello world" 2>/dev/null)
if [ "$out" = "hello%20world" ]; then PASS=$((PASS+1)); echo "PASS T1.a hello world → hello%20world"
else FAIL=$((FAIL+1)); echo "FAIL T1.a (out=$out)"; fi

out=$("$SRC" "a&b=c" 2>/dev/null)
if [ "$out" = "a%26b%3Dc" ]; then PASS=$((PASS+1)); echo "PASS T1.b a&b=c → a%26b%3Dc"
else FAIL=$((FAIL+1)); echo "FAIL T1.b (out=$out)"; fi

out=$(echo "한국어" | "$SRC" 2>/dev/null)
if [ "$out" = "%ED%95%9C%EA%B5%AD%EC%96%B4" ]; then PASS=$((PASS+1)); echo "PASS T1.c 한국어 → percent"
else FAIL=$((FAIL+1)); echo "FAIL T1.c (out=$out)"; fi

"$SRC" >/dev/null 2>&1 </dev/null
if [ $? -eq 1 ]; then PASS=$((PASS+1)); echo "PASS T1.d 인자 없음 → exit 1"
else FAIL=$((FAIL+1)); echo "FAIL T1.d"; fi

"$SRC" "" >/dev/null 2>&1; ec=$?
out=$("$SRC" "" 2>/dev/null)
if [ "$out" = "" ] && [ "$ec" -eq 0 ]; then PASS=$((PASS+1)); echo "PASS T1.e 빈 인자 → 빈 줄 + exit 0"
else FAIL=$((FAIL+1)); echo "FAIL T1.e (out='$out' exit=$ec)"; fi

if [ -x "$SRC" ]; then PASS=$((PASS+1)); echo "PASS T1.f exec-bit"
else FAIL=$((FAIL+1)); echo "FAIL T1.f (exec-bit 없음)"; fi

echo; echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
