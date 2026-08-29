#!/usr/bin/env bash
# specops-ko 전체 테스트 aggregator
# 사용: bash scripts/tests/run-all.sh [--quiet]
# 대상: scripts/tests/{,dag/,governance/,llm-eval/,test-convention/,freecomment/,promote/}test-*.sh + validate-structure.sh
# 제외: bench-hook.sh(벤치마크), fixtures/, dogfood-parallel-harness.sh
set -uo pipefail

PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# 재귀 가드: test-release.sh 의 release.sh dry-run 이 pre-flight 로 run-all 을 재호출하는 무한 재귀 차단
export SPECOPS_RUN_ALL=1
# 네트워크 금지 계약 (20260828-sast-timeout): 스위트는 외부 SAST 스캐너를 부르지 않는다.
#   왜: test-security-scan·test-self-config-collect 가 실 `semgrep --config auto` 를 불렀고,
#   그건 레지스트리 왕복이라 **테스트 결과가 네트워크 상태에 좌우**됐다 — 실측으로 이 두 스위트가
#   99s·8분+ 를 먹거나 통째로 정지했고, pre-push 게이트가 그대로 멈췄다.
#   외부 스캐너 자체의 동작은 stub 으로 검증한다(test-security-scan AC-4·5·8 이 =1 로 되돌려 쓴다).
export SPECOPS_SAST_EXTERNAL=0
# 엔진 금지 계약 (20260829-uiux-engine-bridge): 스위트는 실 promax 엔진을 부르지 않는다.
#   격리 없으면 test-init-project UI KIND 가 개발기의 실 search.py 를 호출해 결과가
#   외부 repo 상태에 좌우되고, 신규 read 가 기존 stdin 픽스처를 shift 시킨다.
#   엔진 동작 자체는 test-uiux-assets 가 stub(fixtures/uiux-engine)으로 검증한다.
export UIUX_ENGINE_DISABLE=1
QUIET=false
[ "${1:-}" = "--quiet" ] && QUIET=true

# ── 스위트별 시간 상한 (FID 20260828-sast-timeout) ──
# 왜: 한 스위트가 무한 대기하면 aggregator 전체가 멈추고, 이 게이트는 pre-push 훅과 릴리즈
#   pre-flight 가 그대로 쓴다 — 즉 `git push` 가 정지한다(실측: test-security-scan 8분+ 무출력).
#   상한은 "느린 스위트를 벌주는 것" 이 아니라 **정지를 실패로 바꾸는 것**이다.
# 왜 300 인가: 스위트별 실측 최대가 test-validate-structure 73s(전체 322s / 147 스위트 / 평균 2.2s).
#   300s 는 그 4배 여유라 정상 스위트를 절대 못 끊고, 정지는 확실히 끊는다. 느린 CI 러너 대비도 같다.
SUITE_TIMEOUT="${SPECOPS_SUITE_TIMEOUT:-300}"
if [ -f "$PLUGIN/scripts/_internal/run-bounded.sh" ]; then
  # shellcheck source=/dev/null
  . "$PLUGIN/scripts/_internal/run-bounded.sh"
else
  # 헬퍼 부재(트리밍된 트리·sandbox) = 상한 없음. **조용히** 무제한이 되지 않도록 경고한다 —
  # 무음 fallback 은 이 FID 가 고치는 결함(상한이 있다는 착각)을 그대로 재생산한다.
  echo "WARN: run-bounded.sh 부재 — 스위트별 상한 없이 진행 (무한 정지 미방지)" >&2
  bounded_run() { shift; "$@"; }
  bounded_timed_out() { return 1; }
fi

SUITES=()
SUITES+=("scripts/_internal/validate-structure.sh")
for f in "$PLUGIN"/scripts/tests/test-*.sh \
         "$PLUGIN"/scripts/tests/dag/test-*.sh \
         "$PLUGIN"/scripts/tests/governance/test-*.sh \
         "$PLUGIN"/scripts/tests/llm-eval/test-*.sh \
         "$PLUGIN"/scripts/tests/test-convention/test-*.sh \
         "$PLUGIN"/scripts/tests/freecomment/test-*.sh \
         "$PLUGIN"/scripts/tests/promote/test-*.sh; do
  [ -f "$f" ] || continue
  SUITES+=("${f#"$PLUGIN"/}")
done

PASS=0; FAIL=0; FAILED_SUITES=()
for suite in "${SUITES[@]}"; do
  if $QUIET; then
    out=$(cd "$PLUGIN" && bounded_run "$SUITE_TIMEOUT" bash "$suite" 2>&1); rc=$?
  else
    echo "--- $suite"
    out=$(cd "$PLUGIN" && bounded_run "$SUITE_TIMEOUT" bash "$suite" 2>&1); rc=$?
    printf '%s\n' "$out" | tail -1
  fi
  # 시간초과는 조용한 rc 가 아니라 **명시 실패**다 — 상한이 걸렸다는 사실 자체가 진단 정보다.
  if bounded_timed_out "$rc"; then
    out="${out}
FAIL TIMEOUT — ${SUITE_TIMEOUT}s 상한 초과 (무한 정지 차단). 재현: bash $suite"
    printf '%s\n' "⏱  TIMEOUT: $suite (>${SUITE_TIMEOUT}s)" >&2
  fi
  if [ $rc -eq 0 ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); FAILED_SUITES+=("$suite")
    printf '%s\n' "$out" | grep '^FAIL' | head -5
  fi
done

echo ""
echo "==== run-all: suites PASS=$PASS FAIL=$FAIL (total=${#SUITES[@]}) ===="
# VERIFY 토큰 — R-1/R-2 실행-근거 게이트(governance-lib _verify_exec_evidence)가 transcript 에서
# 이 토큰으로 실행증거를 판정한다 (러너 계약: PASS 만 인정, FAIL/PARTIAL 불인정). 20260716 false-block fix.
if [ $FAIL -gt 0 ]; then
  printf 'FAILED: %s\n' "${FAILED_SUITES[@]}"
  echo "VERIFY: FAIL"
  exit 1
fi
echo "VERIFY: PASS"
exit 0
