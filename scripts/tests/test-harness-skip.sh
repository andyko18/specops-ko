#!/usr/bin/env bash
# test-harness-skip.sh — harness skip() 헬퍼 + finish SKIP 출력 계약 (20260830-silent-failure-surfacing)
# 왜: 환경 조건부 skip 이 ok() 로 계상돼 15 어서션이 가짜 PASS 1개로 붕괴해도 안 보였다.
# SKIP=0 일 때 finish 출력이 종전과 바이트 동일해야 한다 — 91 스위트가 이 형식을 tail 로 읽는다.
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
PASS=0; FAIL=0

# ── T1.a: skip() 존재 ──
if command -v skip >/dev/null 2>&1; then
  ok "T1.a skip() 헬퍼 정의됨"
else
  nope "T1.a" "skip() 미정의 — 환경 조건부 skip 이 ok() 로 계상된다"
fi

# ── T1.b: skip() 은 PASS 를 올리지 않고 SKIP 을 올린다 (AC-4) ──
out=$(
  PASS=0; FAIL=0; SKIP=0
  source "$PLUGIN/scripts/tests/harness.sh"
  skip "dummy" >/dev/null
  echo "$PASS $FAIL $SKIP"
)
if [ "$out" = "0 0 1" ]; then
  ok "T1.b skip() → PASS=0 FAIL=0 SKIP=1 (AC-4)"
else
  nope "T1.b" "기대 '0 0 1' 실측 '$out'"
fi

# ── T1.c: skip 출력 접두는 'SKIP ' (기존 test-init-project:620·test-notify:68 규약 복제) ──
line=$(
  PASS=0; FAIL=0; SKIP=0
  source "$PLUGIN/scripts/tests/harness.sh"
  skip "T9 뭔가"
)
if [ "$line" = "SKIP T9 뭔가" ]; then
  ok "T1.c skip 출력 접두 'SKIP ' (run-all grep '^SKIP ' 앵커)"
else
  nope "T1.c" "실측 '$line'"
fi

# ── T1.d: SKIP=0 이면 finish 출력이 종전과 바이트 동일 (AC-4 후단·AC-R-1) ──
fout=$(
  PASS=3; FAIL=0; SKIP=0
  source "$PLUGIN/scripts/tests/harness.sh"
  finish
)
if [ "$fout" = "PASS=3 FAIL=0" ]; then
  ok "T1.d SKIP=0 → 'PASS=3 FAIL=0' 바이트 동일 (91 스위트 회귀 보호)"
else
  nope "T1.d" "실측 '$fout' — 기존 스위트의 tail 단언이 깨진다"
fi

# ── T1.e: SKIP>0 이면 SKIP=K 를 덧붙인다 ──
fout=$(
  PASS=2; FAIL=1; SKIP=4
  source "$PLUGIN/scripts/tests/harness.sh"
  finish
)
if [ "$fout" = "PASS=2 FAIL=1 SKIP=4" ]; then
  ok "T1.e SKIP>0 → 'PASS=2 FAIL=1 SKIP=4'"
else
  nope "T1.e" "실측 '$fout'"
fi

# ── T1.f: finish 판정은 FAIL 만 본다 — SKIP 은 rc 에 관여하지 않는다 (AC-5 정신) ──
( PASS=1; FAIL=0; SKIP=9
  source "$PLUGIN/scripts/tests/harness.sh"
  finish >/dev/null ) && ok "T1.f SKIP=9 여도 FAIL=0 이면 rc=0 (판정 무관여)" \
  || nope "T1.f" "SKIP 이 판정을 바꿨다 — VERIFY: PASS 가 막혀 전 사용자 커밋이 잠긴다"

# ── T2: run-all 이 스위트 출력의 SKIP 을 합산하고, VERIFY 토큰은 불변 (AC-5) ──
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/scripts/tests" "$TMP/scripts/_internal"
cp "$PLUGIN/scripts/tests/run-all.sh" "$TMP/scripts/tests/run-all.sh"
cp "$PLUGIN/scripts/_internal/run-bounded.sh" "$TMP/scripts/_internal/run-bounded.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/scripts/_internal/validate-structure.sh"
printf '#!/usr/bin/env bash\necho "SKIP a1"\necho "SKIP a2"\necho "PASS a3"\nexit 0\n' > "$TMP/scripts/tests/test-s1.sh"
printf '#!/usr/bin/env bash\necho "SKIP b1"\necho "PASS b2"\nexit 0\n' > "$TMP/scripts/tests/test-s2.sh"

rout=$(bash "$TMP/scripts/tests/run-all.sh" --quiet 2>&1); rcode=$?
rlast=$(printf '%s\n' "$rout" | tail -1)

if printf '%s\n' "$rout" | grep -q 'SKIP.*3'; then
  ok "T2.a run-all 이 SKIP 3건을 합산 보고 (AC-5 a)"
else
  nope "T2.a" "SKIP 합계 미표시 — 축소 실행이 green 뒤에 숨는다"
fi

if [ "$rcode" -eq 0 ] && [ "$rlast" = "VERIFY: PASS" ]; then
  ok "T2.b SKIP 존재해도 마지막 줄 'VERIFY: PASS' + exit 0 (AC-5 b · AC-R-1)"
else
  nope "T2.b" "exit=$rcode last=$rlast — R-1/R-2 면제가 막혀 전 사용자 커밋이 잠긴다"
fi

finish
