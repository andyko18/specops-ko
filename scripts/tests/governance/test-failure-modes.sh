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

source "$PLUGIN/scripts/tests/lib/isolated-tree.sh" 2>/dev/null || true
command -v iso::make_tree >/dev/null 2>&1 && command -v iso::fingerprint >/dev/null 2>&1 \
  || { echo "FATAL: isolated-tree 미로드(또는 반쯤 로드)" >&2; exit 1; }
# ISO pathspec = 격리가 깨졌을 때 이 스위트가 쓸 경로
_iso_paths='hooks/rules.jsonl'
_iso_before=$(iso::fingerprint $_iso_paths)

# ---------- PostToolUse 실패 내성 ----------

# T13.a rules.jsonl 부재 시 posttool exit 0 + {continue:true}
#   ★ 격리: 실 hooks/rules.jsonl 을 mv 하지 않는다. 종전엔 trap 이 0건이라 중단 시
#     거버넌스 규칙이 **사라진 채 남았다**(소비자 5종). 사본에선 잔류할 손상이 없다.
#   ★ "출력이 비어 있지 않음" 은 아래 `jq -e '.continue == true'` 에 **포섭된다**
#     (빈 출력이면 jq 가 실패한다 — 실측: 훅 부재 시 rc=127 out= → FAIL).
#     별도 어서션을 두면 독립적으로 발화할 수 없는 vacuous 한 줄이 늘 뿐이다.
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
touch transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s", transcript_path:$tp, hook_event_name:"PostToolUse", tool_name:"Bash", tool_input:{command:"ls"}, tool_response:{} }')
T=$(iso::make_tree "$PLUGIN") || { FAIL=$((FAIL+1)); echo "FAIL T13.a 격리 사본 생성 실패"; T=""; }
if [ -n "$T" ]; then
  trap 'rm -rf "$T"' EXIT
  ISO_POSTTOOL="$T/hooks/posttool-governance.sh"
  # AC-10 ① 훅 경로가 사본에서 파생됐고 사본 하위인가 — 실 훅 호출로의 회귀를 **도달 불가**로 만든다
  _ac10a=0; case "$ISO_POSTTOOL" in "$T"/*) _ac10a=1 ;; esac
  rm -f "$T/hooks/rules.jsonl"
  # AC-10 ② 호출 직전 사본 rules 부재 사전조건 — rm 실패를 잡는다
  _ac10b=0; [ ! -f "$T/hooks/rules.jsonl" ] && _ac10b=1
  out=$(echo "$stdin_json" | bash "$ISO_POSTTOOL" 2>/dev/null); rc=$?
  rm -rf "$T"; trap - EXIT
  if [ "$_ac10a" -eq 1 ] && [ "$_ac10b" -eq 1 ] \
     && [ "$rc" -eq 0 ] && echo "$out" | jq -e '.continue == true' >/dev/null; then
    PASS=$((PASS+1)); echo "PASS T13.a rules.jsonl 부재 → continue:true (사본 격리 · AC-10 ①②)"
  else
    FAIL=$((FAIL+1)); echo "FAIL T13.a (경로사본하위=$_ac10a 사전조건=$_ac10b rc=$rc out=$out)"
  fi
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
#   ★ 격리: T13.a 와 동일 근거. **축마다 새 사본**을 뜬다(T13.a 사본 재사용 금지).
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
touch transcript.jsonl
stdin_json=$(jq -nc --arg tp "$tmp/transcript.jsonl" '{ session_id:"s", transcript_path:$tp, hook_event_name:"Stop", stop_hook_active:false }')
T=$(iso::make_tree "$PLUGIN") || { FAIL=$((FAIL+1)); echo "FAIL T13.d 격리 사본 생성 실패"; T=""; }
if [ -n "$T" ]; then
  trap 'rm -rf "$T"' EXIT
  ISO_STOP="$T/hooks/stop-governance.sh"
  # AC-10 ① 훅 경로가 사본에서 파생됐고 사본 하위인가
  _ac10c=0; case "$ISO_STOP" in "$T"/*) _ac10c=1 ;; esac
  rm -f "$T/hooks/rules.jsonl"
  # AC-10 ② 호출 직전 사본 rules 부재 사전조건
  _ac10d=0; [ ! -f "$T/hooks/rules.jsonl" ] && _ac10d=1
  out=$(echo "$stdin_json" | bash "$ISO_STOP" 2>/dev/null); rc=$?
  rm -rf "$T"; trap - EXIT
  if [ "$_ac10c" -eq 1 ] && [ "$_ac10d" -eq 1 ] \
     && [ "$rc" -eq 0 ] && echo "$out" | jq -e '.continue == true' >/dev/null; then
    PASS=$((PASS+1)); echo "PASS T13.d Stop rules 부재 → continue:true (사본 격리 · AC-10 ①②)"
  else
    FAIL=$((FAIL+1)); echo "FAIL T13.d (경로사본하위=$_ac10c 사전조건=$_ac10d rc=$rc out=$out)"
  fi
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

if [ "$_iso_before" = "$(iso::fingerprint $_iso_paths)" ]; then
  PASS=$((PASS+1)); echo "PASS ISO 실 트리 전후 지문 불변"
else
  FAIL=$((FAIL+1)); echo "FAIL ISO 실 트리가 변이됐다 (이 스위트 또는 동시 실행 중인 다른 프로세스)"
fi

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
