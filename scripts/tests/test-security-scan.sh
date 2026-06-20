#!/usr/bin/env bash
# security-scan.sh 검증 (FID 20260620-security-review-gate)
set -u
PASS=0; FAIL=0
P=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
nope() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }
SC="$P/scripts/security-scan.sh"

# AC-2/AC-R-1: 도구 미설치 시 graceful skip (exit 0 + SKIP)
[ -f "$SC" ] && [ -x "$SC" ] || nope "존재" "security-scan.sh 부재/비실행"
out=$(bash "$SC" "$P" 2>&1); ec=$?
if ! command -v semgrep >/dev/null 2>&1 && ! command -v gitleaks >/dev/null 2>&1; then
  { printf '%s' "$out" | grep -q 'SECURITY: SKIP' && [ "$ec" -eq 0 ]; } \
    && ok "AC-R-1 도구 미설치 graceful skip (exit 0)" || nope "AC-R-1" "skip 실패 (ec=$ec, out=$out)"
else
  printf '%s' "$out" | grep -qE 'SECURITY: (SKIP|crit=)' && ok "AC-2 스캔 실행/판정 출력" || nope "AC-2" "출력 형식 오류"
fi
# AC-2: 출력 형식 (SKIP 또는 crit/high/med 집계)
printf '%s' "$out" | grep -qE 'SECURITY: (SKIP|crit=[0-9])' && ok "AC-2 출력 형식" || nope "AC-2" "형식 불일치"

echo "── test-security-scan: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
