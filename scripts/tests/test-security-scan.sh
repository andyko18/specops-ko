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

# self-check 레이어 검증에서는 외부 스캐너를 **기본** 차단한다 (20260828-sast-timeout).
#   왜: 종전엔 5개 케이스가 각각 실제 semgrep 을 종전 배선(레지스트리 자동 룰셋)으로 불렀고,
#   그건 **네트워크 호출**이라 run-all 이 여기서 무한 정지했다(실측 8분+ 무출력).
#   아래 self-check 레이어 케이스에는 외부 스캐너가 관심사가 아니므로 기본값을 0 으로 둔다.
# 원인 정정 (PR #58): 그 대기의 실체는 룰 수신이 아니라 semgrep.dev version-check 였다
#   (`--version` 만으로도 98.5s · `SEMGREP_ENABLE_VERSION_CHECK=0` 이면 1.8s — PR #58 실측).
# ★ 한계 고백 철회 (f313f8d): "실 semgrep 이 specops 자체 코드에 오탐을 내지 않는가" 는 더 이상
#   포기된 커버리지가 아니다 — 파일 하단 AC-5-sg·AC-6-sg·AC-3-sg 가 이 기본값을 =1 로 되돌려
#   **실 semgrep** 을 부른다. 로컬 룰셋 + version-check 차단이라 네트워크를 쓰지 않으므로
#   종전의 포기 사유(네트워크 의존)가 소멸했다(2026-09-24 실측: 1파일 스캔 1.9s).
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
{ printf '%s' "$out" | grep -q '실행실패' && [ "$ec" -eq 0 ] \
  && ! printf '%s' "$out" | grep -qF '(룰셋:'; } \
  && ok "AC-8 하드 실패 강등 표기 + 룰셋 표기 부재 (실행 receipt)" \
  || nope "AC-8 하드 실패" "out=$out ec=$ec"
rm -rf "$FSTUB"

# AC-7: 외부 미실행 시에도 self-check 판정은 살아 있다 (강등이지 무력화가 아니다)
printf 'aws=%s\n' "AKIA""IOSFODNN7EXAMPLE" > "$T/leak.py"
out=$(PATH="$STUB:$PATH" SPECOPS_SAST_EXTERNAL=0 bash "$SC" "$T" 2>&1); ec=$?
{ printf '%s' "$out" | grep -qE 'crit=[1-9]' && [ "$ec" -ne 0 ]; } \
  && ok "AC-7 외부 미실행에도 self-check secret 차단 유지" || nope "AC-7" "out=$out ec=$ec"
rm -rf "$T" "$STUB"

# ── 실 semgrep 스캔 (FID 20260917-sast-offline-ruleset) ──
#   라벨 접두 AC-*-sg = 이 스위트가 실 semgrep 으로 검증하는 spec AC. 기존 AC-3a/3b 와 충돌 없음.
if command -v semgrep >/dev/null 2>&1; then
  # AC-5-sg 양성 — 취약 픽스처에서 룰 2개가 정확히 2건 검출
  out=$(SPECOPS_SAST_EXTERNAL=1 bash "$SC" "$P/scripts/tests/fixtures/sast/vulnerable.sh" 2>&1); ec=$?
  #   `crit=2 ` 뒤 공백까지 요구한다 — `crit=2` 만이면 `crit=20` 도 만족하는 접두 일치다.
  { printf '%s' "$out" | grep -qE 'crit=2 ' && [ "$ec" = 1 ]; } \
    && ok "AC-5-sg 실 semgrep 취약 픽스처 crit=2 차단" || nope "AC-5-sg 양성" "out=$out ec=$ec"

  # AC-6-sg 음성 — 프로덕션 코드 오탐 0 + semgrep 이 실제로 돌았음
  #   :16-17 주석이 "네트워크 의존이라 신뢰할 수 없어 포기했다" 고 적은 커버리지를 되살린다.
  #   crit=0 high=0 만 보면 semgrep 미실행도 통과하므로 강등 부재를 함께 요구한다.
  #   검사 문자열을 semgrep( 로 좁힌다 — 외부 SAST 미반영 은 gitleaks 강등도 포함하는 공용 표기다.
  #   ⚠️ security-scan.sh 는 `TARGET="${1:-.}"` 로 **인자를 1개만** 받는다. `"$P/hooks" "$P/scripts"`
  #   처럼 두 경로를 넘기면 둘째가 조용히 버려져 "범위를 넓힌 척" 이 된다 — 실측(2026-09-24):
  #   hooks + 취약픽스처를 함께 넘겨도 `crit=0`, 픽스처 단독은 `crit=2`. 그래서 코퍼스마다 **호출을 분리**한다.
  #   T1.e 의 음성 코퍼스(hooks+scripts 102파일)와 범위를 맞춘다.
  out_hooks=""
  for corpus in hooks scripts; do
    o=$(SPECOPS_SAST_EXTERNAL=1 bash "$SC" "$P/$corpus" 2>&1); e=$?
    [ "$corpus" = hooks ] && out_hooks="$o"
    { printf '%s' "$o" | grep -qE 'crit=0 high=0' && [ "$e" = 0 ] \
      && ! printf '%s' "$o" | grep -q 'semgrep('; } \
      && ok "AC-6-sg 실 semgrep $corpus/ 오탐 0 (실행 확인 포함)" \
      || nope "AC-6-sg 오탐 ($corpus)" "out=$o ec=$e"
  done

  # AC-3-sg 룰셋 출처 표기 = 실행 receipt.
  #   대상을 hooks 출력으로 **고정**한다 — 루프의 마지막 $o 를 쓰면 코퍼스를 추가·재배치할 때
  #   검사 대상이 조용히 옮겨간다(무음 이동).
  printf '%s' "$out_hooks" | grep -qF '(룰셋: 로컬 bash-injection)' \
    && ok "AC-3-sg 룰셋 출처 표기" || nope "AC-3-sg 출처 표기" "out=$out_hooks"
else
  skip "AC-5-sg·AC-6-sg·AC-3-sg semgrep 미설치 — 실 스캔 미실행 (PASS 집계 제외)"
fi

# SKIP 을 요약에 드러낸다 — green 이 곧 전량 실행은 아니다(도구 부재로 축소 실행 가능).
#   SKIP=0 이면 종전 출력과 바이트 동일하다.
sk=""; [ "${SKIP:-0}" -gt 0 ] && sk=" SKIP=$SKIP"
echo "── test-security-scan: PASS=$PASS FAIL=$FAIL$sk ──"
[ "$FAIL" -eq 0 ]
