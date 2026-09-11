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


# ── Bash 사전 필터 (20260911-posttool-matcher-narrow) ─────────────────────────
#   posttool 은 동기 훅이라 모든 Bash 호출 뒤에 붙는다. 커밋·PR 이 아닌 명령에서
#   git·jq 비용을 다 치른 뒤 버리던 것을, 판정과 **같은 전처리·같은 정규식**으로 먼저 거른다.
#   아래 케이스는 "필터가 판정을 바꾸지 않았다"(T8.i·T8.j·T8.k)와
#   "필터가 실제로 비용을 없앴다"(T8.h)를 따로 잠근다 — 앞의 것만 있으면 필터를 지워도 통과한다.

# git shim — 호출될 때마다 1줄을 남기고 진짜 git 으로 넘긴다.
#   ★ PATH 앞에만 끼운다. 통째로 교체하면 bash·jq 를 못 찾아 훅이 다른 이유로 끝난다.
_real_git=$(command -v git)
_mk_git_shim() {  # $1=shim dir  $2=log file
  mkdir -p "$1"
  printf '#!/bin/sh\necho "$*" >> "%s"\nexec "%s" "$@"\n' "$2" "$_real_git" > "$1/git"
  chmod +x "$1/git"
}
# $1=tool_name $2=command(또는 skill) [$3=훅 경로] → stdout. cwd 는 호출자의 $tmp.
_post() {
  local _h="${3:-$HOOK}" _in
  if [ "$1" = "Skill" ]; then
    _in=$(jq -nc --arg tp "$tmp/transcript.jsonl" --arg s "$2" '{session_id:"s1", transcript_path:$tp, hook_event_name:"PostToolUse", tool_name:"Skill", tool_input:{skill:$s}, tool_response:{}}')
  else
    _in=$(jq -nc --arg tp "$tmp/transcript.jsonl" --arg t "$1" --arg c "$2" '{session_id:"s1", transcript_path:$tp, hook_event_name:"PostToolUse", tool_name:$t, tool_input:{command:$c}, tool_response:{}}')
  fi
  printf '%s' "$_in" | PATH="$tmp/shim:$PATH" bash "$_h" 2>/dev/null
}

# T8.h ★ 비트리거 Bash 는 git 을 부르기 전에 끝난다 (AC-2)
#   음성 3형: 평범한 명령 · 인자에 commit 이 없는 grep · heredoc **본문**에만 git commit(비실행자 cat).
#   기록 없음·출력 동일은 필터가 없어도 성립한다 — **git 호출 0회**가 필터의 유일한 관측 증거다.
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
cp "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" transcript.jsonl
_mk_git_shim "$tmp/shim" "$tmp/git-calls.log"
_heredoc_cmd=$(printf "cat > note.md <<'EOF'\ngit commit -m x\nEOF")
_h_bad=""
for _c in "ls" "grep -rn foo ." "$_heredoc_cmd"; do
  : > "$tmp/git-calls.log"
  _o=$(_post Bash "$_c")
  _n=$(wc -l < "$tmp/git-calls.log" | tr -d ' ')
  _logs=$(find .specops -name friction-log.jsonl 2>/dev/null | wc -l | tr -d ' ')
  if [ "$_o" != '{"continue":true}' ] || [ "$_n" -ne 0 ] || [ "$_logs" -ne 0 ]; then
    _h_bad="$_h_bad [$(printf '%s' "$_c" | head -1): out=$_o git=$_n logs=$_logs]"
  fi
done
if [ -z "$_h_bad" ]; then
  PASS=$((PASS+1)); echo "PASS T8.h ★ 비트리거 Bash 3형 → git 0회 · 기록 0 · continue only"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.h 필터 미작동:$_h_bad"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T8.i ★ 트리거 판정 동치 코퍼스 (AC-3)
#   양성 5형은 **필터 추가 전과 같은 규칙**이 기록돼야 하고, 음성 3형은 기록이 없어야 한다.
#   기대 규칙은 2026-09-11 main 훅(필터 추가 전) 실측값이다 — 필터가 정규식을 좁히면 양성이 떨어진다.
#   heredoc **본문** 음성(AC-3)은 git 호출 0회까지 보는 T8.h 가 담당한다.
_i_bad=""
while IFS='|' read -r _exp _c; do
  [ -n "$_c" ] || continue
  tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
  cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
  cp "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" transcript.jsonl
  _o=$(_post Bash "$_c")
  _got=$(printf '%s' "$_o" | jq -r '.additionalContext // ""' 2>/dev/null | grep -oE 'R-[12]' | sort -u | tr '\n' ' ' | sed 's/ $//')
  [ "$_got" = "$_exp" ] || _i_bad="$_i_bad [$_c: got='$_got' exp='$_exp']"
  cd "$PLUGIN"; rm -rf "$tmp"
done <<'CORPUS'
R-1|git commit -m x
R-1|FOO='a b' git commit -m x
R-1|rtk proxy git commit -m x
R-1|git -C . commit -m x
R-2|gh pr create --title t
|git commit-tree HEAD^{tree}
|echo "git commit -m x"
|ls
CORPUS
if [ -z "$_i_bad" ]; then
  PASS=$((PASS+1)); echo "PASS T8.i ★ 트리거 동치 코퍼스 8형 (양성 5 · 음성 3)"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.i 판정 변화:$_i_bad"
fi

# T8.j ★ 필터를 못 만들면 감사를 건너뛰지 않는다 (AC-4)
#   두 손상형 모두 main 은 R-1 을 기록한다 — load_rules(jq -c)는 스트림이라 깨진 줄 앞의 규칙을 살리고,
#   apply_lookback_rule 은 규칙마다 따로 grep 해 한 규칙의 정규식 오류가 다른 규칙을 막지 않는다.
#   필터는 jq -s(통째 실패)·정규식 합치기(한 개 오류 = 전체 rc=2)라 **더 쉽게 깨진다** — 그때 조기 종료하면
#   main 이 남기던 감사가 사라진다.
source "$PLUGIN/scripts/tests/lib/isolated-tree.sh" 2>/dev/null || true
_j_bad=""
if ! command -v iso::make_tree >/dev/null 2>&1; then
  _j_bad=" isolated-tree 미로드"
else
  for _dmg in broken-json bad-regex; do
    T=$(iso::make_tree "$PLUGIN") || { _j_bad="$_j_bad [$_dmg: 사본 실패]"; continue; }
    case "$_dmg" in
      broken-json) printf '{broken\n' >> "$T/hooks/rules.jsonl" ;;
      bad-regex)   printf '%s\n' '{"id":"R-X","matcher":"posttool","enabled":false,"trigger_tool":"Bash","trigger_pattern":"("}' >> "$T/hooks/rules.jsonl" ;;
    esac
    tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
    cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
    cp "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" transcript.jsonl
    _o=$(_post Bash "git commit -m x" "$T/hooks/posttool-governance.sh")
    printf '%s' "$_o" | jq -e '.additionalContext | contains("R-1")' >/dev/null 2>&1 \
      || _j_bad="$_j_bad [$_dmg: out=$_o]"
    cd "$PLUGIN"; rm -rf "$tmp" "$T"
  done
fi
if [ -z "$_j_bad" ]; then
  PASS=$((PASS+1)); echo "PASS T8.j ★ 손상 rules 2형(깨진 JSON · 정규식 오류) → 조기 종료 없이 R-1 감사 유지"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.j 감사 소실:$_j_bad"
fi

# T8.k Skill 은 필터 대상이 아니다 — R-3 경로 유지 (AC-R-1 ①)
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
cp "$FIXTURES/transcripts/r3-skill-without-declaration.jsonl" transcript.jsonl
_o=$(_post Skill "specops-ko:planning-ko")
if printf '%s' "$_o" | jq -e '.additionalContext | contains("R-3")' >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "PASS T8.k Skill 선언 부재 → R-3 기록 유지"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.k (out=$_o)"
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
