#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SCRIPT="$PLUGIN/scripts/_internal/init-project.sh"

# T-split.a 임의 cwd 에서 source 시 헬퍼+phase 전 함수 로드 (main 미실행)
out=$(cd /tmp && source "$SCRIPT" 2>/dev/null; type -t _replace_line_prefix; type -t phase_8_artifacts; type -t phase_1_precheck)
if [ "$(printf '%s' "$out" | grep -c '^function$')" = "3" ]; then
  ok "T-split.a source 시 lib+early+artifacts 함수 로드"
else
  nope "T-split.a source 로드" "함수 미로드 (got: $out)"
fi

# T-split.b source 가드 — source 시 main 자동 실행 안 됨 (산출물 생성 없음)
tmpd=$(mktemp -d) || exit 1
( cd "$tmpd" && source "$SCRIPT" 2>/dev/null )
if [ ! -f "$tmpd/CLAUDE.md" ]; then ok "T-split.b source 가드 — main 미자동실행"; else nope "T-split.b 가드" "source 가 main 실행함"; fi
rm -rf "$tmpd"

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]
