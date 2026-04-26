#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/hexdec.sh"

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1"; }

# T2.a: 인수 디코딩 "68656c6c6f" → "hello" (AC-4)
out=$("$SCRIPT" "68656c6c6f" 2>/dev/null)
[ "$out" = "hello" ] && ok "T2.a hexdec 인수" || fail "T2.a (got: $out)"

# T2.b: stdin 디코딩 (AC-5)
out=$(echo "68656c6c6f" | "$SCRIPT" 2>/dev/null)
[ "$out" = "hello" ] && ok "T2.b hexdec stdin" || fail "T2.b (got: $out)"

# T2.c: 비hex 문자 → exit 1 (AC-6)
"$SCRIPT" "xyz" 2>/dev/null; code=$?
[ "$code" -eq 1 ] && ok "T2.c 비hex 에러 exit 1" || fail "T2.c (exit: $code)"

# T2.d: 홀수 길이 → exit 1 (AC-7)
"$SCRIPT" "686" 2>/dev/null; code=$?
[ "$code" -eq 1 ] && ok "T2.d 홀수 길이 에러 exit 1" || fail "T2.d (exit: $code)"

# T2.e: 실행 권한 (AC-12)
[ -x "$SCRIPT" ] && ok "T2.e hexdec 실행 권한" || fail "T2.e"

# T2.f: 빈 입력 → 빈 줄 (AC-13)
out=$("$SCRIPT" "" 2>/dev/null)
[ "$out" = "" ] && ok "T2.f hexdec 빈 입력 → 빈 줄" || fail "T2.f (got: '$out')"

echo; echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
