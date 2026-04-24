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

# T2.a read_recent_tool_events: 최근 3 개 tool_use
out=$(read_recent_tool_events "$FIXTURES/transcripts/basic-tools.jsonl" 3); rc=$?
count=$(echo "$out" | grep -c '^{')
last_has_skill=$(echo "$out" | tail -1 | grep -c '"tool_name":"Skill"')
if [ "$rc" -eq 0 ] && [ "$count" -eq 3 ] && [ "$last_has_skill" -eq 1 ]; then
  PASS=$((PASS+1)); echo "PASS T2.a read_recent_tool_events 3건 + Skill 마지막"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.a (rc=$rc count=$count skill=$last_has_skill)"
fi

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
