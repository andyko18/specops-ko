#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/b64val.sh"

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1"; }

# T3.a: 유효한 base64 "aGVsbG8=" → "valid" exit 0 (AC-7)
out=$("$SCRIPT" "aGVsbG8="); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "valid" ] \
  && ok "T3.a valid base64" || fail "T3.a (rc=$rc out='$out')"

# T3.b: 허용 안 되는 문자 "hello!" → "invalid: invalid characters" (AC-8)
out=$("$SCRIPT" "hello!"); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: invalid characters" ] \
  && ok "T3.b invalid characters" || fail "T3.b (rc=$rc out='$out')"

# T3.c: 패딩 누락 "aGVsbG8" (길이 7) → "invalid: invalid padding" (AC-9)
out=$("$SCRIPT" "aGVsbG8"); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: invalid padding" ] \
  && ok "T3.c invalid padding" || fail "T3.c (rc=$rc out='$out')"

# T3.d: 빈 문자열 → "invalid: empty input" exit 1 (AC-12)
out=$("$SCRIPT" ""); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: empty input" ] \
  && ok "T3.d empty input" || fail "T3.d (rc=$rc out='$out')"

# T3.e: 중간에 = 포함 "aG=sbG8=" → "invalid: invalid padding"
out=$("$SCRIPT" "aG=sbG8="); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: invalid padding" ] \
  && ok "T3.e = in middle" || fail "T3.e (rc=$rc out='$out')"

# T3.f: stdin 유효 입력 "dGVzdA==" → "valid" exit 0 (AC-7 stdin)
out=$(printf '%s' "dGVzdA==" | "$SCRIPT"); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "valid" ] \
  && ok "T3.f stdin valid" || fail "T3.f (rc=$rc out='$out')"

# T3.g: 패딩 3개 "aGVs===" → "invalid: invalid padding"
out=$("$SCRIPT" "aGVs==="); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "invalid: invalid padding" ] \
  && ok "T3.g triple padding" || fail "T3.g (rc=$rc out='$out')"

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
