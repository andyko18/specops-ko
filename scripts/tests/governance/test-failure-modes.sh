#!/usr/bin/env bash
# T13. 실패 내성 통합 (AC-7)
# posttool-governance.sh + stop-governance.sh 양쪽 모두
# rules.jsonl 부재 / transcript 부재 / stdin JSON 파싱 실패 3 시나리오 × 2 hook = 6 케이스
# 기대: exit 0 + {continue:true} 보장 + (파싱 실패 시) stderr ERROR 로그
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
POSTTOOL="$PLUGIN/hooks/posttool-governance.sh"
STOP="$PLUGIN/hooks/stop-governance.sh"

# ---------- PostToolUse 실패 내성 ----------

# T13.a rules.jsonl 부재 시 posttool exit 0 + {continue:true}
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
touch transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s", transcript_path:$tp, hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"ls"}, tool_response:{} }')
# rules.jsonl 임시 숨김
mv "$PLUGIN/hooks/rules.jsonl" "$PLUGIN/hooks/rules.jsonl.bak"
out=$(echo "$stdin_json" | bash "$POSTTOOL" 2>/dev/null); rc=$?
mv "$PLUGIN/hooks/rules.jsonl.bak" "$PLUGIN/hooks/rules.jsonl"
if [ "$rc" -eq 0 ] && echo "$out" | jq -e '.continue == true' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T13.a rules.jsonl 부재 → continue:true"
else
  FAIL=$((FAIL+1)); echo "FAIL T13.a (rc=$rc out=$out)"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T13.b transcript 부재 → exit 0 + continue
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
stdin_json='{"session_id":"s","transcript_path":"/tmp/nowhere-12345.jsonl","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"ls"},"tool_response":{}}'
out=$(echo "$stdin_json" | bash "$POSTTOOL" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | jq -e '.continue == true' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T13.b transcript 부재 → continue:true"
else
  FAIL=$((FAIL+1)); echo "FAIL T13.b (rc=$rc out=$out)"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T13.c stdin JSON 파싱 실패 → exit 0 + continue + stderr 로그
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
stderr_out=$(echo 'not-json-at-all' | bash "$POSTTOOL" 2>&1 >/dev/null); rc_exit=$?
out=$(echo 'not-json-at-all' | bash "$POSTTOOL" 2>/dev/null); rc=$?
has_error_log=$(echo "$stderr_out" | grep -c "governance-capture.*ERROR" || true)
if [ "$rc" -eq 0 ] && echo "$out" | jq -e '.continue == true' >/dev/null && [ "$has_error_log" -ge 1 ]; then
  PASS=$((PASS+1)); echo "PASS T13.c stdin 파싱 실패 → continue:true + stderr"
else
  FAIL=$((FAIL+1)); echo "FAIL T13.c (rc=$rc log=$has_error_log)"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# ---------- Stop 실패 내성 ----------

# T13.d Stop rules.jsonl 부재
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
touch transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s", transcript_path:$tp, hook_event_name:"Stop", stop_hook_active:false }')
mv "$PLUGIN/hooks/rules.jsonl" "$PLUGIN/hooks/rules.jsonl.bak"
out=$(echo "$stdin_json" | bash "$STOP" 2>/dev/null); rc=$?
mv "$PLUGIN/hooks/rules.jsonl.bak" "$PLUGIN/hooks/rules.jsonl"
if [ "$rc" -eq 0 ] && echo "$out" | jq -e '.continue == true' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T13.d Stop rules 부재 → continue:true"
else
  FAIL=$((FAIL+1)); echo "FAIL T13.d"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T13.e Stop transcript 부재
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
stdin_json='{"session_id":"s","transcript_path":"/tmp/nowhere-67890.jsonl","hook_event_name":"Stop","stop_hook_active":false}'
out=$(echo "$stdin_json" | bash "$STOP" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | jq -e '.continue == true' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T13.e Stop transcript 부재 → continue:true"
else
  FAIL=$((FAIL+1)); echo "FAIL T13.e"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T13.f Stop stdin JSON 파싱 실패
stderr_out=$(echo 'garbage' | bash "$STOP" 2>&1 >/dev/null); rc_exit=$?
out=$(echo 'garbage' | bash "$STOP" 2>/dev/null); rc=$?
has_error_log=$(echo "$stderr_out" | grep -c "governance-capture.*ERROR" || true)
if [ "$rc" -eq 0 ] && echo "$out" | jq -e '.continue == true' >/dev/null && [ "$has_error_log" -ge 1 ]; then
  PASS=$((PASS+1)); echo "PASS T13.f Stop stdin 파싱 실패 → continue + stderr"
else
  FAIL=$((FAIL+1)); echo "FAIL T13.f"
fi

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
