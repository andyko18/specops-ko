#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/hexenc.sh"

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1"; }

# T1.a: 인수 인코딩 "hello" → "68656c6c6f" (AC-1)
out=$("$SCRIPT" "hello" 2>/dev/null)
[ "$out" = "68656c6c6f" ] && ok "T1.a hexenc 인수 hello" || fail "T1.a (got: $out)"

# T1.b: stdin 인코딩 (AC-2)
out=$(echo "hello" | "$SCRIPT" 2>/dev/null)
[ "$out" = "68656c6c6f" ] && ok "T1.b hexenc stdin hello" || fail "T1.b (got: $out)"

# T1.c: 인수 없음 → exit 1 (AC-3)
"$SCRIPT" </dev/null 2>/dev/null; code=$?
[ "$code" -eq 1 ] && ok "T1.c hexenc 빈 입력 exit 1" || fail "T1.c (exit: $code)"

# T1.d: "world" → "776f726c64" (AC-9)
out=$("$SCRIPT" "world" 2>/dev/null)
[ "$out" = "776f726c64" ] && ok "T1.d hexenc world" || fail "T1.d (got: $out)"

# T1.e: 빈 문자열 → 빈 줄 (AC-10)
out=$("$SCRIPT" "" 2>/dev/null)
[ "$out" = "" ] && ok "T1.e hexenc 빈 문자열 → 빈 줄" || fail "T1.e (got: '$out')"

# T1.f: 실행 권한 (AC-12)
[ -x "$SCRIPT" ] && ok "T1.f hexenc 실행 권한" || fail "T1.f"

echo; echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
