#!/usr/bin/env bash
# dast-scan.sh 검증 (FID 20260620-security-scan-command)
set -u
PASS=0; FAIL=0
P=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$P/scripts/tests/harness.sh"
DS="$P/scripts/dast-scan.sh"

[ -f "$DS" ] && [ -x "$DS" ] || nope "존재" "dast-scan.sh 부재/비실행"
# AC-2/AC-R-1: URL 인자 없으면 사용법 + exit (잘못된 호출 가드)
out=$(bash "$DS" 2>&1); ec=$?
printf '%s' "$out" | grep -qiE 'usage|URL|사용' && ok "AC-2 URL 인자 가드" || nope "AC-2" "인자 가드 없음"
# AC-R-1: graceful skip/dry — NO_RUN=1 로 실 docker run/nuclei 없이 분기·출력만 검증 (게이트 결정성)
out2=$(SPECOPS_DAST_NO_RUN=1 bash "$DS" "http://localhost:0" 2>&1); ec2=$?
{ printf '%s' "$out2" | grep -qE 'DAST: (SKIP|DRY)' && [ "$ec2" -eq 0 ]; } \
  && ok "AC-R-1 graceful skip/dry (NO_RUN, exit 0)" || nope "AC-R-1" "skip/dry 실패(ec=$ec2, out=$out2)"

echo "── test-dast-scan: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
