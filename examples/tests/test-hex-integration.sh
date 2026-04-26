#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ENC="$PLUGIN/scripts/hexenc.sh"
DEC="$PLUGIN/scripts/hexdec.sh"

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1"; }

# T3.a: 독립성 — 상호 source 없음 (AC-8)
if ! grep -qE 'source[[:space:]]|^\.[[:space:]]' "$ENC" && \
   ! grep -qE 'source[[:space:]]|^\.[[:space:]]' "$DEC"; then
  ok "T3.a 독립성 — 상호 source 없음"
else
  fail "T3.a (상호 source 발견)"
fi

# T3.b: 역함수 파이프 "hello" → hex → "hello" (AC-11)
out=$(echo "hello" | "$ENC" | "$DEC" 2>/dev/null)
[ "$out" = "hello" ] && ok "T3.b 역함수 파이프 hello" || fail "T3.b (got: $out)"

# T3.c: 역함수 파이프 다른 문자열
out=$(echo "specops" | "$ENC" | "$DEC" 2>/dev/null)
[ "$out" = "specops" ] && ok "T3.c 역함수 파이프 specops" || fail "T3.c (got: $out)"

echo; echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
