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

# T3.a log_friction: FID 제공 → .specops/<FID>/friction-log.jsonl
tmp=$(mktemp -d); cd "$tmp"
source "$PLUGIN/hooks/governance-lib.sh"
log_friction "20260424-x" "R-1" 5 "git commit" 7
log_path=".specops/20260424-x/friction-log.jsonl"
if [ -f "$log_path" ] && jq -e '.rule_id == "R-1" and .principle == 5 and .fid == "20260424-x"' "$log_path" >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T3.a log_friction FID 스코프"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.a"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T3.b log_friction: FID 빈 문자열 → .specops/friction-log.jsonl, fid=null
tmp=$(mktemp -d); cd "$tmp"
source "$PLUGIN/hooks/governance-lib.sh"
log_friction "" "R-2" 5 "gh pr create" 3
if [ -f ".specops/friction-log.jsonl" ] && jq -e '.fid == null and .rule_id == "R-2"' ".specops/friction-log.jsonl" >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T3.b log_friction 전역 fallback"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.b"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T4.a load_rules: matcher + enabled 필터
out=$(load_rules "$FIXTURES/rules-test.jsonl" "posttool"); rc=$?
count=$(echo "$out" | grep -c '^{')
has_ra=$(echo "$out" | jq -e 'select(.id == "R-A")' >/dev/null 2>&1 && echo 1 || echo 0)
if [ "$rc" -eq 0 ] && [ "$count" -eq 1 ] && [ "$has_ra" -eq 1 ]; then
  PASS=$((PASS+1)); echo "PASS T4.a load_rules 필터"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.a (rc=$rc count=$count has_ra=$has_ra)"
fi

# T-M1 log_friction: 잘못된 FID → rc=1, 파일 생성 없음
tmp=$(mktemp -d); cd "$tmp"
source "$PLUGIN/hooks/governance-lib.sh"
log_friction "../evil" "R-X" 5 "x" 0 2>/dev/null; rc=$?
if [ "$rc" -eq 1 ] && [ ! -e "../evil" ] && [ ! -d ".specops/../evil" ]; then
  PASS=$((PASS+1)); echo "PASS T-M1 FID 경로 탈출 가드"
else
  FAIL=$((FAIL+1)); echo "FAIL T-M1 (rc=$rc)"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T-M2 log_friction: 공백·특수문자 FID → rc=1
tmp=$(mktemp -d); cd "$tmp"
source "$PLUGIN/hooks/governance-lib.sh"
log_friction "bad fid" "R-X" 5 "x" 0 2>/dev/null; rc=$?
if [ "$rc" -eq 1 ]; then
  PASS=$((PASS+1)); echo "PASS T-M2 공백 FID 거부"
else
  FAIL=$((FAIL+1)); echo "FAIL T-M2 (rc=$rc)"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T-M3 log_friction: 유효 FID (20260424-x) → rc=0 + 파일 생성 (회귀 방지)
tmp=$(mktemp -d); cd "$tmp"
source "$PLUGIN/hooks/governance-lib.sh"
log_friction "20260424-valid" "R-X" 5 "x" 0; rc=$?
if [ "$rc" -eq 0 ] && [ -f ".specops/20260424-valid/friction-log.jsonl" ]; then
  PASS=$((PASS+1)); echo "PASS T-M3 유효 FID 수용"
else
  FAIL=$((FAIL+1)); echo "FAIL T-M3 (rc=$rc)"
fi
cd "$PLUGIN"; rm -rf "$tmp"

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
