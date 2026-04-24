#!/usr/bin/env bash
# specops-auto-ko governance-capture 공용 함수 라이브러리 테스트
# source hooks/governance-lib.sh 후 detect_fid / read_recent_tool_events / log_friction / load_rules 검증
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
FIXTURES="$PLUGIN/scripts/tests/governance/fixtures"

# T1.a detect_fid: 최신 FID 헤더 반환
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
source "$PLUGIN/hooks/governance-lib.sh"
out=$(detect_fid); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "20260424-newest-feature" ]; then
  PASS=$((PASS+1)); echo "PASS T1.a detect_fid 최신 헤더"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a (rc=$rc out=$out)"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T1.b detect_fid: session-progress.md 부재 시 빈 문자열
tmp=$(mktemp -d); cd "$tmp"
out=$(detect_fid); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T1.b 부재 시 빈 문자열"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.b (rc=$rc out=[$out])"
fi
cd "$PLUGIN"; rm -rf "$tmp"

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
