#!/usr/bin/env bash
# specops-auto-ko 전체 테스트 aggregator
# 사용: bash scripts/tests/run-all.sh [--quiet]
# 대상: scripts/tests/{,dag/,governance/,test-convention/}test-*.sh + validate-structure.sh
# 제외: bench-hook.sh(벤치마크), v0.4-pre/·v0.4a/(측정·가이드), fixtures/, dogfood-parallel-harness.sh
set -uo pipefail

PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# 재귀 가드: test-release.sh 의 release.sh dry-run 이 pre-flight 로 run-all 을 재호출하는 무한 재귀 차단
export SPECOPS_RUN_ALL=1
QUIET=false
[ "${1:-}" = "--quiet" ] && QUIET=true

SUITES=()
SUITES+=("scripts/_internal/validate-structure.sh")
for f in "$PLUGIN"/scripts/tests/test-*.sh \
         "$PLUGIN"/scripts/tests/dag/test-*.sh \
         "$PLUGIN"/scripts/tests/governance/test-*.sh \
         "$PLUGIN"/scripts/tests/test-convention/test-*.sh; do
  [ -f "$f" ] || continue
  SUITES+=("${f#"$PLUGIN"/}")
done

PASS=0; FAIL=0; FAILED_SUITES=()
for suite in "${SUITES[@]}"; do
  if $QUIET; then
    out=$(cd "$PLUGIN" && bash "$suite" 2>&1); rc=$?
  else
    echo "--- $suite"
    out=$(cd "$PLUGIN" && bash "$suite" 2>&1); rc=$?
    printf '%s\n' "$out" | tail -1
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
if [ $FAIL -gt 0 ]; then
  printf 'FAILED: %s\n' "${FAILED_SUITES[@]}"
  exit 1
fi
exit 0
