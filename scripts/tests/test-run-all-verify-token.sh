#!/usr/bin/env bash
# test-run-all-verify-token.sh — run-all.sh VERIFY 토큰 계약 (20260716 R-1 false-block fix)
# run-all.sh 는 성공 시 VERIFY: PASS, 실패 시 VERIFY: FAIL 을 마지막 줄로 출력해야 한다.
# governance-lib _verify_exec_evidence 가 이 토큰으로 실행증거를 판정한다 (test-exec-evidence T14~T16).
# 방식: run-all.sh 를 sandbox 플러그인 트리에 복사해 실행 (PLUGIN 은 BASH_SOURCE 기준이라 sandbox 로 격리).
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
PASS=0; FAIL=0
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/scripts/tests" "$TMP/scripts/_internal"
cp "$PLUGIN/scripts/tests/run-all.sh" "$TMP/scripts/tests/run-all.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/scripts/_internal/validate-structure.sh"
printf '#!/usr/bin/env bash\necho "PASS t1"\nexit 0\n' > "$TMP/scripts/tests/test-ok.sh"

# ── T1: 전 suite 성공 → 마지막 줄 VERIFY: PASS + exit 0 ──
out=$(bash "$TMP/scripts/tests/run-all.sh" --quiet 2>&1); code=$?
last=$(printf '%s\n' "$out" | tail -1)
if [ "$code" -eq 0 ] && [ "$last" = "VERIFY: PASS" ]; then
  ok "T1 성공 시 마지막 줄 VERIFY: PASS + exit 0"
else
  nope "T1 PASS 토큰" "exit=$code last=$last"
fi

# ── T2: suite 1개 실패 → 마지막 줄 VERIFY: FAIL + exit 1 (PASS 토큰 미출력) ──
printf '#!/usr/bin/env bash\necho "FAIL t9"\nexit 1\n' > "$TMP/scripts/tests/test-bad.sh"
out=$(bash "$TMP/scripts/tests/run-all.sh" --quiet 2>&1); code=$?
last=$(printf '%s\n' "$out" | tail -1)
if [ "$code" -eq 1 ] && [ "$last" = "VERIFY: FAIL" ] && ! printf '%s\n' "$out" | grep -qx "VERIFY: PASS"; then
  ok "T2 실패 시 마지막 줄 VERIFY: FAIL + exit 1 (PASS 토큰 없음)"
else
  nope "T2 FAIL 토큰" "exit=$code last=$last"
fi

# ── T3: 게이트 러너 앵커 계약 — governance-lib 정규식이 tests/run-all.sh 를 러너로 인식 (배선 grep) ──
n=$(grep -c 'tests/run-all\\\\\.sh' "$PLUGIN/hooks/governance-lib.sh")
[ "$n" -ge 1 ] && ok "T3 governance-lib 러너 클래스에 tests/run-all.sh 앵커 존재 ($n)" \
  || nope "T3 앵커 배선" "governance-lib 에 tests/run-all 앵커 없음"

finish
