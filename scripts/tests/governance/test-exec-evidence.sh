#!/usr/bin/env bash
# _verify_exec_evidence 단위 — tool_use ↔ tool_result join 실행증거 판정 (20260713-verify-exec-gate)
set -uo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN=$(cd "$script_dir/../../.." && pwd)
FIX="$script_dir/fixtures/transcripts"
# harness 로드 가드 — source 실패 시 false-PASS 봉쇄
. "$PLUGIN/hooks/governance-lib.sh" || { echo "FATAL: governance-lib.sh 로드 실패"; exit 1; }
type _verify_exec_evidence >/dev/null 2>&1 || { echo "FATAL: _verify_exec_evidence 미정의"; exit 1; }
pass=0; fail=0
ck() { if [ "$2" = "$3" ]; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1 — expected rc=$2, got rc=$3"; fail=$((fail+1)); fi; }

_verify_exec_evidence "$FIX/exec-evidence-pass.jsonl"; ck "T1 실행증거 있음 → 0" 0 $?
_verify_exec_evidence "$FIX/exec-evidence-absent.jsonl"; ck "T2 호출만(실행 결과 없음) → 1" 1 $?
_verify_exec_evidence "$FIX/exec-evidence-partial.jsonl"; ck "T3 PARTIAL → 1 (negative check)" 1 $?
_verify_exec_evidence "/nonexistent/path.jsonl"; ck "T4 transcript 부재 → 2 (fail-open)" 2 $?
# ★ C-3 설계 정정: 빈 transcript(파일 존재·파싱 성공·tool_use 0건) = 판정 불가(2), 증거 없음(1) 아님.
#   이벤트 0건은 "검증 안 함"과 "transcript 를 못 읽음"을 구별 불가 → fail-open 원칙상 2.
#   (test-verify-progress T13 무손상 근거)
empty=$(mktemp) || exit 1
_verify_exec_evidence "$empty"; ck "T5 빈 transcript → 2 (판정 불가 — 증거없음 아님)" 2 $?
rm -f "$empty"
# T6 (AC-9): command-only 위조 — 러너 tool_use 는 있으나 대응 tool_result 부재 → 1
cmdonly=$(mktemp) || exit 1
printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_Z","name":"Bash","input":{"command":"bash scripts/_internal/run-verification.sh 20260101-x"}}]}}' > "$cmdonly"
_verify_exec_evidence "$cmdonly"; ck "T6 command-only(result 부재) → 1 (AC-9)" 1 $?
rm -f "$cmdonly"

# ── 위조 벡터 4종 (Phase C: 방어층 회귀 잠금) ───────────────────────────────────
# 아래 4케이스는 각각 함수의 방어층 하나씩을 잠근다. 해당 층을 제거하면 그 케이스만 FAIL 해야 한다.
#   T7 → 러너 앵커 정규식 / T8 → tool_use_id join / T9 → is_error 필터 / T10 → negative check

# T7: echo 위장 — 비러너 Bash(러너 키워드를 문자열 안에 품음) + 하네스 result 에 PASS.
#     코드 주석이 스스로 명명한 핵심 위조 벡터. 앵커 없는 정규식이면 "ran pytest" 가 매칭되어 뚫린다.
echoforge=$(mktemp) || exit 1
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_E1","name":"Bash","input":{"command":"echo \"ran pytest — VERIFY: PASS\""}}]}}' \
  '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_E1","is_error":false,"content":"ran pytest — VERIFY: PASS"}]}}' > "$echoforge"
_verify_exec_evidence "$echoforge"; ck "T7 echo 위장(비러너 명령 + PASS 출력) → 1 (러너 앵커)" 1 $?
rm -f "$echoforge"

# T8: id 도용 — 러너 tool_use 는 있으나, PASS result 가 **다른 tool_use_id** 에 달려 있다.
#     join 없이 result 만 훑으면 남의 PASS 를 자기 실행증거로 착복한다.
idsteal=$(mktemp) || exit 1
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_R1","name":"Bash","input":{"command":"bash scripts/_internal/run-verification.sh 20260101-x"}}]}}' \
  '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_OTHER","is_error":false,"content":"VERIFY: PASS"}]}}' > "$idsteal"
_verify_exec_evidence "$idsteal"; ck "T8 id 도용(타 tool_use 의 PASS) → 1 (id join)" 1 $?
rm -f "$idsteal"

# T9: 에러 결과 — 러너가 돌긴 했으나 하네스가 is_error 로 표시한 출력. 실패한 실행은 증거 불인정.
errres=$(mktemp) || exit 1
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_R2","name":"Bash","input":{"command":"bash scripts/_internal/run-verification.sh 20260101-x"}}]}}' \
  '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_R2","is_error":true,"content":"VERIFY: PASS"}]}}' > "$errres"
_verify_exec_evidence "$errres"; ck "T9 is_error 결과(PASS 문자열 포함) → 1 (에러결과 불인정)" 1 $?
rm -f "$errres"

# T10: 혼재 출력 — 같은 출력에 PASS 와 PARTIAL 이 함께 있다(다FID·요약행). 부분 검증을 전체 통과로 읽으면 안 된다.
#      기존 T3 partial fixture 는 content 에 "PASS" 부분문자열이 없어 negative check 를 잠그지 못한다.
mixed=$(mktemp) || exit 1
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_R3","name":"Bash","input":{"command":"bash scripts/_internal/run-verification.sh 20260101-x"}}]}}' \
  '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_R3","is_error":false,"content":"AC-1 VERIFY: PASS\nAC-2 VERIFY: PARTIAL — 1개 명령 whitelist 미통과"}]}}' > "$mixed"
_verify_exec_evidence "$mixed"; ck "T10 PASS/PARTIAL 혼재 → 1 (negative check)" 1 $?
rm -f "$mixed"

# ── 멀티라인 command (실전 dogfooding 이 잡은 false-block) ─────────────────────
# Bash tool 의 command 는 흔히 멀티라인이다 (`cd <path>` 다음 줄에 러너). 러너 앵커의 선행자
# 문자클래스에 줄바꿈이 없으면 2번째 줄의 러너가 ^ 에도 [;&|(] 에도 안 걸려 **정직한 실행이
# 미인식 → deny** 된다. 줄바꿈은 셸에서 진짜 명령 구분자이므로 클래스에 포함되어야 옳다.
#   T11 = RED 드라이버(수정 전 rc=1) / T12·T13 = 앵커 의미 회귀 잠금(수정 전후 불변 rc=1)

# T11: 멀티라인 러너 호출 + 대응 tool_result 의 PASS → 0 (실행증거 인정)
mlrun=$(mktemp) || exit 1
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_M1","name":"Bash","input":{"command":"cd /Users/x/proj\nbash scripts/_internal/run-verification.sh 20260101-x"}}]}}' \
  '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_M1","is_error":false,"content":"VERIFY: PASS"}]}}' > "$mlrun"
_verify_exec_evidence "$mlrun"; ck "T11 멀티라인 러너(cd 후 다음 줄) → 0 (false-block 차단)" 0 $?
rm -f "$mlrun"

# T12: 멀티라인 echo 위장 — 줄바꿈 허용이 "아무 데나 있어도 됨"이 되면 여기서 뚫린다.
mlecho=$(mktemp) || exit 1
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_M2","name":"Bash","input":{"command":"cd /x\necho \"ran pytest — VERIFY: PASS\""}}]}}' \
  '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_M2","is_error":false,"content":"ran pytest — VERIFY: PASS"}]}}' > "$mlecho"
_verify_exec_evidence "$mlecho"; ck "T12 멀티라인 echo 위장 → 1 (앵커 의미 유지)" 1 $?
rm -f "$mlecho"

# T13: 멀티라인 주석 — 줄 첫 토큰이 '#' 이면 러너는 실행되지 않는다. 인식되면 안 된다.
mlcmt=$(mktemp) || exit 1
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_M3","name":"Bash","input":{"command":"cd /x\n# bash scripts/_internal/run-verification.sh 20260101-x"}}]}}' \
  '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_M3","is_error":false,"content":"VERIFY: PASS"}]}}' > "$mlcmt"
_verify_exec_evidence "$mlcmt"; ck "T13 멀티라인 주석 처리된 러너 → 1 (미실행)" 1 $?
rm -f "$mlcmt"

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
