#!/usr/bin/env bash
# security-scan.sh 검증 (self-check 레이어 — FID 20260620-security-selfcheck)
set -u
PASS=0; FAIL=0
P=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$P/scripts/tests/harness.sh"
SC="$P/scripts/security-scan.sh"
[ -f "$SC" ] && [ -x "$SC" ] || nope "존재" "security-scan.sh 부재/비실행"

# AC-R-1: 깨끗한 디렉토리 → self-check 통과 (crit=0 exit 0, 도구 미설치여도 SKIP 아닌 crit=0)
T=$(mktemp -d); printf 'def f():\n    return 1\n' > "$T/clean.py"
out=$(bash "$SC" "$T" 2>&1); ec=$?
{ printf '%s' "$out" | grep -qE 'SECURITY: (crit=0 high=0|SKIP)' && [ "$ec" -eq 0 ]; } \
  && ok "AC-R-1 깨끗 디렉토리 통과 (exit 0)" || nope "AC-R-1" "out=$out ec=$ec"; rm -rf "$T"

# AC-2: secret 탐지 → crit, exit 1. ※ fixture 키는 런타임 조립 — 이 소스에 완전체 미노출(self-check 자기오탐 방지, C-1)
T=$(mktemp -d); printf 'aws=%s\n' "AKIA""IOSFODNN7EXAMPLE" > "$T/leak.py"
out=$(bash "$SC" "$T" 2>&1); ec=$?
{ printf '%s' "$out" | grep -qE 'crit=[1-9]' && [ "$ec" -ne 0 ]; } \
  && ok "AC-2 secret 탐지 차단" || nope "AC-2" "out=$out ec=$ec"; rm -rf "$T"

# AC-3a: 위험함수 비-bash(.py) 탐지 → high
T=$(mktemp -d); printf 'subprocess.run(cmd, shell=True)\n' > "$T/danger.py"
out=$(bash "$SC" "$T" 2>&1)
printf '%s' "$out" | grep -qE 'high=[1-9]' && ok "AC-3a 위험함수 비-bash 탐지" || nope "AC-3a" "out=$out"; rm -rf "$T"

# AC-3b: bash eval 오탐 0 (specops 자체 보호 핵심)
T=$(mktemp -d); printf '#!/usr/bin/env bash\neval "$cmd"\n' > "$T/script.sh"
out=$(bash "$SC" "$T" 2>&1); ec=$?
{ printf '%s' "$out" | grep -qE 'crit=0 high=0|SECURITY: SKIP' && [ "$ec" -eq 0 ]; } \
  && ok "AC-3b bash eval 오탐 0" || nope "AC-3b" "out=$out ec=$ec"; rm -rf "$T"

# AC-R-2: specops 자체 scripts/ 스캔 오탐 0 (tests 제외로 fixture·테스트소스 미스캔)
out=$(bash "$SC" "$P/scripts" 2>&1); ec=$?
{ printf '%s' "$out" | grep -qE 'crit=0 high=0|SECURITY: SKIP' && [ "$ec" -eq 0 ]; } \
  && ok "AC-R-2 specops scripts/ 오탐 0" || nope "AC-R-2" "자기코드 오탐 out=$out ec=$ec"

echo "── test-security-scan: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
