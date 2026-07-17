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

# ── run-all.sh 인식 (20260716 false-block — self-maintenance dogfooding 적발) ──
# 플러그인 자기 repo 작업에서 정식 검증 러너는 run-all.sh(전체 스위트)인데, 러너 클래스가
# run-verification.sh·pytest 류만 인식해 run-all 95/95 세션이 deny 됐다(BYPASS 강요 = 신호 희석).
# fix: 러너 클래스에 `bash \S*tests/run-all\.sh` 추가 + run-all.sh 가 성공 시 `VERIFY: PASS`
# (실패 시 `VERIFY: FAIL`) 토큰을 출력해 기존 토큰 계약으로 판정 (게이트 출력검사 로직 무변경).
#   T14 = RED 드라이버 / T15 = 좁은 앵커 잠금(tests/ 경로 밖 run-all 불인정) / T16 = 실패 토큰 대칭

# T14: run-all 실행 + FAIL=0 + PASS 토큰 → 0 (실행증거 인정)
rarun=$(mktemp) || exit 1
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_RA1","name":"Bash","input":{"command":"bash scripts/tests/run-all.sh 2>&1 | tail -3"}}]}}' \
  '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_RA1","is_error":false,"content":"==== run-all: suites PASS=95 FAIL=0 (total=95) ====\nVERIFY: PASS"}]}}' > "$rarun"
_verify_exec_evidence "$rarun"; ck "T14 run-all.sh 실행 + PASS 토큰 → 0 (false-block 해소)" 0 $?
rm -f "$rarun"

# T15: tests/ 경로 밖 run-all.sh — 러너 클래스는 \S*tests/run-all\.sh 로 좁힌다.
#      downstream repo 의 무관한 ./run-all.sh(배포 스크립트 등)가 우연히 토큰을 출력해도 불인정.
raout=$(mktemp) || exit 1
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_RA2","name":"Bash","input":{"command":"bash ./run-all.sh"}}]}}' \
  '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_RA2","is_error":false,"content":"VERIFY: PASS"}]}}' > "$raout"
_verify_exec_evidence "$raout"; ck "T15 tests/ 밖 run-all.sh → 1 (좁은 앵커)" 1 $?
rm -f "$raout"

# T16: run-all 실패 — suite FAIL>0 이면 run-all.sh 가 VERIFY: FAIL 을 출력한다. 출력에
#      PASS 문자열이 섞여 있어도(suite 케이스명 등) negative check 가 전체 불인정해야 한다.
rafail=$(mktemp) || exit 1
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_RA3","name":"Bash","input":{"command":"bash scripts/tests/run-all.sh"}}]}}' \
  '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_RA3","is_error":false,"content":"PASS T1.a something\n==== run-all: suites PASS=94 FAIL=1 (total=95) ====\nVERIFY: FAIL"}]}}' > "$rafail"
_verify_exec_evidence "$rafail"; ck "T16 run-all 실패(FAIL 토큰) → 1 (negative check)" 1 $?
rm -f "$rafail"

# T-fresh: 신선도 게이트 (20260717-exec-evidence-staleness — dogfood test1 FR-3 실측: 세션 초반
#   FR-2 의 VERIFY: PASS 가 윈도우·스코프 없이 세션 끝까지 만능 면제표가 되어, 이후 FID 의
#   미검증 implement 커밋 전부(서브에이전트 포함)를 열었다. friction 무흔적의 실물 원인)
#   규칙: 마지막 실행증거 **이후** 비-.specops Edit/Write/NotebookEdit 가 있으면 stale → 1.
runner_ev='{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_F1","name":"Bash","input":{"command":"bash scripts/_internal/run-verification.sh 20260101-x"}}]}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_F1","is_error":false,"content":"VERIFY: PASS"}]}}'
fr=$(mktemp) || exit 1
# T-fresh.a ★ 증거 후 코드 Edit → stale(1)
printf '%s\n' "$runner_ev" '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_F2","name":"Edit","input":{"file_path":"src/app.ts","old_string":"a","new_string":"b"}}]}}' > "$fr"
_verify_exec_evidence "$fr"; ck "T-fresh.a ★ 증거 후 코드 Edit → 1 (stale)" 1 $?
# T-fresh.b 증거 후 .specops 아티팩트 Write 만 → 여전히 0 (정직 흐름: evidence.md 마무리)
printf '%s\n' "$runner_ev" '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_F3","name":"Write","input":{"file_path":".specops/20260101-x/evidence.md","content":"x"}}]}}' > "$fr"
_verify_exec_evidence "$fr"; ck "T-fresh.b 증거 후 .specops Write → 0 (아티팩트 제외)" 0 $?
# T-fresh.c 코드 Edit 후 증거 (정상 순서: 수정→재검증) → 0
printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_F4","name":"Edit","input":{"file_path":"src/app.ts","old_string":"a","new_string":"b"}}]}}' "$runner_ev" > "$fr"
_verify_exec_evidence "$fr"; ck "T-fresh.c Edit 후 증거(재검증 순서) → 0" 0 $?
# T-fresh.d 증거 후 Write(코드) → stale, 이후 재검증 → 다시 0 (최신 증거가 이김)
printf '%s\n' "$runner_ev" '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_F5","name":"Write","input":{"file_path":"src/new.ts","content":"x"}}]}}' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_F6","name":"Bash","input":{"command":"bash scripts/_internal/run-verification.sh 20260101-x"}}]}}' '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_F6","is_error":false,"content":"VERIFY: PASS"}]}}' > "$fr"
_verify_exec_evidence "$fr"; ck "T-fresh.d 수정 후 재검증 → 0 (최신 증거 우선)" 0 $?
rm -f "$fr"

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
