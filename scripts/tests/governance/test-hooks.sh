#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
FIXTURES="$PLUGIN/scripts/tests/governance/fixtures"
HOOK="$PLUGIN/hooks/posttool-governance.sh"

# T8.a R-1 트리거 → additionalContext + friction-log append
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
cp "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s1", transcript_path:$tp, hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"git commit -m \"x\""}, tool_response:{} }')
out=$(echo "$stdin_json" | bash "$HOOK" 2>/dev/null); rc=$?
has_r1=$(echo "$out" | jq -e '.continue == true and (.additionalContext | contains("R-1"))' >/dev/null 2>&1 && echo 1 || echo 0)
log_path=".specops/20260424-newest-feature/friction-log.jsonl"
if [ "$rc" -eq 0 ] && [ "$has_r1" -eq 1 ] && [ -f "$log_path" ] && jq -e '.rule_id == "R-1"' "$log_path" >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T8.a R-1 additionalContext + append"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.a (rc=$rc has_r1=$has_r1 log=$(ls $log_path 2>/dev/null))"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T8.b 매칭 없음 → {continue:true} 만
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
cp "$FIXTURES/transcripts/r1-commit-with-verify.jsonl" transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s1", transcript_path:$tp, hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"git commit -m \"x\""}, tool_response:{} }')
out=$(echo "$stdin_json" | bash "$HOOK" 2>/dev/null); rc=$?
has_context=$(echo "$out" | jq -e 'has("additionalContext")' >/dev/null 2>&1 && echo 1 || echo 0)
continue_ok=$(echo "$out" | jq -e '.continue == true' >/dev/null 2>&1 && echo 1 || echo 0)
if [ "$rc" -eq 0 ] && [ "$continue_ok" -eq 1 ] && [ "$has_context" -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS T8.b 매칭 없음 → continue only"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.b (rc=$rc continue=$continue_ok context=$has_context)"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T8.c FID 감지 실패 (session-progress.md 부재) → 전역 .specops/friction-log.jsonl
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
cp "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s1", transcript_path:$tp, hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"git commit -m \"x\""}, tool_response:{} }')
echo "$stdin_json" | bash "$HOOK" >/dev/null 2>&1
if [ -f ".specops/friction-log.jsonl" ] && jq -e '.fid == null and .rule_id == "R-1"' ".specops/friction-log.jsonl" >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T8.c FID 없음 → 전역 fallback"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.c"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T8.d additionalContext 300자 제한
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
cp "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s1", transcript_path:$tp, hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"git commit -m \"x\""}, tool_response:{} }')
out=$(echo "$stdin_json" | bash "$HOOK" 2>/dev/null)
ctx_len=$(echo "$out" | jq -r '.additionalContext // ""' | wc -c | tr -d ' ')
if [ "$ctx_len" -le 301 ]; then  # wc -c 는 trailing newline 포함, +1 허용
  PASS=$((PASS+1)); echo "PASS T8.d additionalContext ≤ 300"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.d (len=$ctx_len)"
fi
cd "$PLUGIN"; rm -rf "$tmp"

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
