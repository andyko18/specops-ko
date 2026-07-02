#!/usr/bin/env bash
# lint error 게이트 (shellcheck -S error) — CI(.github/workflows/test.yml shellcheck job)와 동일 명령의 로컬 parity
# CI 만 돌던 -S error 게이트가 로컬 run-all green 후 push 에서 최초 발각되던 비대칭 해소
# 도구(shellcheck) 미설치 환경은 graceful SKIP (CI 가 최종 게이트)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "PASS T1.a skipped — shellcheck 미설치 (CI shellcheck job 이 최종 게이트)"
  echo "---"; echo "PASS=1 FAIL=0"
  exit 0
fi

# T1.a CI parity: hooks/ + scripts/ 전체 *.sh 에 error 급 0건
out=$(cd "$PLUGIN" && find hooks scripts -name '*.sh' -print0 | xargs -0 shellcheck -S error 2>&1)
rc=$?
if [ "$rc" -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS T1.a shellcheck -S error 0건 (CI parity)"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a shellcheck error 검출:"; printf '%s\n' "$out" | head -20
fi

echo "---"; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
