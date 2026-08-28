#!/usr/bin/env bash
# security-scan.sh 검증 (self-check 레이어 — FID 20260620-security-selfcheck)
#   + 외부 스캐너 상한·강등 (FID 20260828-sast-timeout)
set -u
PASS=0; FAIL=0
P=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$P/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SC="$P/scripts/security-scan.sh"
[ -f "$SC" ] && [ -x "$SC" ] || nope "존재" "security-scan.sh 부재/비실행"

# self-check 레이어 검증에서는 외부 스캐너를 끈다 (20260828-sast-timeout).
#   왜: 종전엔 5개 케이스가 각각 실제 `semgrep --config auto` 를 불렀고, 그건 레지스트리에서
#   룰을 받는 **네트워크 호출**이라 run-all 이 여기서 무한 정지했다(실측 8분+ 무출력).
#   테스트 대상은 self-check 레이어이므로 외부 스캐너는 이 스위트의 관심사가 아니다.
#   한계 고백: 그 대신 "실 semgrep 이 specops 자체 코드에 오탐을 내지 않는가"(AC-R-2 의
#   부수 효과였다)는 더 이상 여기서 안 본다 — 네트워크 의존이라 애초에 신뢰할 수 없는 커버리지였다.
export SPECOPS_SAST_EXTERNAL=0

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


# ── 외부 스캐너 상한 (FID 20260828-sast-timeout) ──
# 느린 stub 으로 "네트워크에 걸린 semgrep" 을 재현한다. 실 semgrep 을 쓰면 이 테스트 자체가
# 고치려는 병에 걸린다 — 재현은 stub, 상한은 프로덕션 코드가 건다.
STUB=$(mktemp -d)
printf '#!/usr/bin/env bash\nsleep 99\n' > "$STUB/semgrep"; chmod +x "$STUB/semgrep"
printf '#!/usr/bin/env bash\nsleep 99\n' > "$STUB/gitleaks"; chmod +x "$STUB/gitleaks"
T=$(mktemp -d); printf 'def f():\n    return 1\n' > "$T/clean.py"

# AC-4: 느린 외부 스캐너가 스크립트를 정지시키지 못한다
s=$(date +%s)
out=$(PATH="$STUB:$PATH" SPECOPS_SAST_EXTERNAL=1 SPECOPS_SAST_TIMEOUT=2 bash "$SC" "$T" 2>&1); ec=$?
el=$(( $(date +%s) - s ))
[ "$el" -lt 20 ] && ok "AC-4 느린 스캐너 상한 작동 (${el}s < 20s)" \
  || nope "AC-4 상한" "${el}s 소요 — 상한 미작동(stub sleep 99 완주 의심)"

# AC-5: 시간초과가 crit=0 을 '깨끗한 SAST 통과' 로 위장하지 않는다
# 왜 별건인가: 상한만 걸고 표기를 안 하면 정지가 **조용한 오탐 통과**로 바뀐다 — 더 나쁘다.
printf '%s' "$out" | grep -q '시간초과' \
  && ok "AC-5 시간초과 명시 표기 (무음 통과 차단)" \
  || nope "AC-5 강등 표기" "out=$out ec=$ec"

# AC-6: SPECOPS_SAST_EXTERNAL=0 → 외부 스캐너 미실행 (느린 stub 이 PATH 에 있어도 즉시 종료)
s=$(date +%s)
out=$(PATH="$STUB:$PATH" SPECOPS_SAST_EXTERNAL=0 bash "$SC" "$T" 2>&1); ec=$?
el=$(( $(date +%s) - s ))
{ [ "$el" -lt 20 ] && [ "$ec" -eq 0 ] && printf '%s' "$out" | grep -qE 'crit=0 high=0'; } \
  && ok "AC-6 EXTERNAL=0 외부 스캐너 미실행 (${el}s)" \
  || nope "AC-6 EXTERNAL=0" "el=${el}s ec=$ec out=$out"

# AC-8: 외부 스캐너 하드 실패(rc≥2)도 강등 표기 — 무음 통과 차단
# 왜 별건인가: 시간초과만 표기하면, 네트워크 두절·설정 거부로 semgrep 이 **즉시 에러**를 낼 때
#   crit=0 이 그대로 나가 "스캔 안 함" 과 "통과" 가 구분되지 않는다. 실측 계기:
#   `--metrics=off` 를 붙였더니 semgrep 이 "Cannot create auto config…" 로 거부해 스캐너가
#   통째로 no-op 이 됐는데 출력은 `SECURITY: crit=0 high=0` 이었다.
FSTUB=$(mktemp -d)
printf '#!/usr/bin/env bash\necho "boom" >&2\nexit 2\n' > "$FSTUB/semgrep"; chmod +x "$FSTUB/semgrep"
out=$(PATH="$FSTUB:$PATH" SPECOPS_SAST_EXTERNAL=1 bash "$SC" "$T" 2>&1); ec=$?
{ printf '%s' "$out" | grep -q '실행실패' && [ "$ec" -eq 0 ]; } \
  && ok "AC-8 스캐너 하드 실패 강등 표기 (무음 통과 차단)" || nope "AC-8 하드 실패" "out=$out ec=$ec"
rm -rf "$FSTUB"

# AC-7: 외부 미실행 시에도 self-check 판정은 살아 있다 (강등이지 무력화가 아니다)
printf 'aws=%s\n' "AKIA""IOSFODNN7EXAMPLE" > "$T/leak.py"
out=$(PATH="$STUB:$PATH" SPECOPS_SAST_EXTERNAL=0 bash "$SC" "$T" 2>&1); ec=$?
{ printf '%s' "$out" | grep -qE 'crit=[1-9]' && [ "$ec" -ne 0 ]; } \
  && ok "AC-7 외부 미실행에도 self-check secret 차단 유지" || nope "AC-7" "out=$out ec=$ec"
rm -rf "$T" "$STUB"

echo "── test-security-scan: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
