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

# T8.e ★ 감사 스코프 회귀 (20260718-posttool-audit-silence): 커밋 직후 잔여 dirty 가
#   tracked .specops/session-progress.md 뿐인 실전 상태에서, 방금 커밋(코드)의 감사가 침묵하면 안 된다.
#   구버전은 is_docs_only_change(working-tree)가 .specops/* 면제에 걸려 R-1 감사를 통째로 skip —
#   #214 이후 R-1 posttool warn 전 repo 0건의 실물 원인 (T8.a 는 git repo 부재 fixture 라 못 잡았다).
tmp=$(mktemp -d); cd "$tmp"; git init -q
mkdir -p .specops
cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
echo 'echo v1' > a.sh
git add a.sh .specops/session-progress.md && git -c user.email=t@t -c user.name=t commit -qm init
echo 'echo v2' > a.sh && git add a.sh && git -c user.email=t@t -c user.name=t commit -qm "feat: code"
printf '\n- dirty line\n' >> .specops/session-progress.md   # tracked+modified — 실전 잔여 dirty
cp "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s1", transcript_path:$tp, hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"git commit -m \"x\""}, tool_response:{} }')
out=$(echo "$stdin_json" | bash "$HOOK" 2>/dev/null); rc=$?
log_path=".specops/20260424-newest-feature/friction-log.jsonl"
if [ "$rc" -eq 0 ] && [ -f "$log_path" ] && jq -e '.rule_id == "R-1"' "$log_path" >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "PASS T8.e ★ 코드 커밋 + .specops 잔여 dirty → 감사 실행 (침묵 봉합)"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.e 감사 침묵 (rc=$rc log=$(ls $log_path 2>/dev/null))"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T8.f 방금 커밋이 docs-only → 감사 skip 유지 (스코프 의미론 — tree 에 코드 dirt 가 있어도 커밋 기준)
tmp=$(mktemp -d); cd "$tmp"; git init -q
mkdir -p .specops
cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
echo 'echo v1' > a.sh
git add a.sh .specops/session-progress.md && git -c user.email=t@t -c user.name=t commit -qm init
echo docs > README.md && git add README.md && git -c user.email=t@t -c user.name=t commit -qm "docs: readme"
echo 'echo dirty' > b.sh   # untracked 코드 dirt — 커밋 스코프 판정엔 무관해야 함
cp "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s1", transcript_path:$tp, hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"git commit -m \"x\""}, tool_response:{} }')
out=$(echo "$stdin_json" | bash "$HOOK" 2>/dev/null); rc=$?
log_path=".specops/20260424-newest-feature/friction-log.jsonl"
if [ "$rc" -eq 0 ] && [ ! -f "$log_path" ]; then
  PASS=$((PASS+1)); echo "PASS T8.f docs-only 커밋 → 감사 skip (커밋 기준 스코프)"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.f (rc=$rc log=$(ls $log_path 2>/dev/null))"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T8.g ★ scope_class 배선 (20260814-friction-scope-posttool): posttool 이 남기는 R-1 행에
#   커밋 범위 분류가 들어가야 한다. 없으면 gbrain-friction 집계에서 warn 계열이 영구 `판정불가`.
#   구조상 posttool 행은 docs-only 가 될 수 없으므로(면제면 기록 자체가 없음) 기대값은 code 다.
tmp=$(mktemp -d); cd "$tmp"; git init -q
mkdir -p .specops
cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
echo 'echo v1' > a.sh
git add a.sh .specops/session-progress.md && git -c user.email=t@t -c user.name=t commit -qm init
echo 'echo v2' > a.sh && git add a.sh && git -c user.email=t@t -c user.name=t commit -qm "feat: code"
printf '\n- dirty line\n' >> .specops/session-progress.md
cp "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s1", transcript_path:$tp, hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"git commit -m \"x\""}, tool_response:{} }')
echo "$stdin_json" | bash "$HOOK" >/dev/null 2>&1
log_path=".specops/20260424-newest-feature/friction-log.jsonl"
got=$(jq -r 'select(.rule_id=="R-1") | .scope_class // "<부재>"' "$log_path" 2>/dev/null | head -1)
if [ "$got" = "code" ]; then
  PASS=$((PASS+1)); echo "PASS T8.g ★ posttool R-1 행에 scope_class=code 기록"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.g scope_class got=$got 기대=code"
fi
cd "$PLUGIN"; rm -rf "$tmp"

STOP_HOOK="$PLUGIN/hooks/stop-governance.sh"

# T11.a stop_hook_active=true → 즉시 exit 0, append 없음
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
touch transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s1", transcript_path:$tp, hook_event_name:"Stop", stop_hook_active:true }')
out=$(echo "$stdin_json" | bash "$STOP_HOOK" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | jq -e '.continue == true' >/dev/null && [ ! -f ".specops/friction-log.jsonl" ]; then
  PASS=$((PASS+1)); echo "PASS T11.a stop_hook_active 멱등"
else
  FAIL=$((FAIL+1)); echo "FAIL T11.a"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T11.b R-4 트리거 → friction-log append + continue:true
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
cp "$FIXTURES/transcripts/r4-claim-without-runner.jsonl" transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s1", transcript_path:$tp, hook_event_name:"Stop", stop_hook_active:false }')
out=$(echo "$stdin_json" | bash "$STOP_HOOK" 2>/dev/null); rc=$?
log_path=".specops/20260424-newest-feature/friction-log.jsonl"
if [ "$rc" -eq 0 ] && echo "$out" | jq -e '.continue == true' >/dev/null && [ -f "$log_path" ] && jq -e '.rule_id == "R-4"' "$log_path" >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T11.b R-4 append"
else
  FAIL=$((FAIL+1)); echo "FAIL T11.b (rc=$rc log=$(ls $log_path 2>/dev/null))"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T11.c 매칭 없음 (빈 transcript) → append 없음, continue:true
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
touch transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s1", transcript_path:$tp, hook_event_name:"Stop", stop_hook_active:false }')
out=$(echo "$stdin_json" | bash "$STOP_HOOK" 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | jq -e '.continue == true and (has("additionalContext") | not)' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T11.c 매칭 없음 continue only"
else
  FAIL=$((FAIL+1)); echo "FAIL T11.c"
fi
cd "$PLUGIN"; rm -rf "$tmp"

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
