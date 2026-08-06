#!/usr/bin/env bash
# check-tdd-red.sh — TDD RED 증거 관측 (20260806)
# Usage: check-tdd-red.sh <FID> <task-id>
# Exit: 0 = RED→GREEN 증거 있음 · 1 = RED 증거 없음(GREEN만) · 2 = 판정 불가(fail-open)
#
# 왜 필요한가: `record-task-receipt.sh` 는 test_command 가 **PASS 일 때만** receipt 를 남긴다.
#   GREEN 은 증명되지만 **"구현 전에 실패했는가"(RED)** 는 아무도 안 본다 —
#   빠지는 것은 **공허한 테스트**(구현 없이도 통과하는 테스트)다. 이번 세션에서
#   작성자 본인의 테스트가 공허하게 통과한 사례가 7번 나왔고 전부 mutation 에서만 드러났다.
#
# ★ 판정 근거는 **내용 토큰**이다 (is_error 아님) — 실측:
#   본 세션 transcript 의 tool_result 658건 중 `FAIL=` 를 담은 187건의 `is_error` 는
#   **전부 false**. 실패한 테스트 실행은 is_error 를 세우지 않는다. advisor 게이트와
#   같은 교훈으로, 형태를 추측했다면 영구 0-hit 이 됐다.
#
# 판정: 같은 test_command 의 결과들을 시간 순으로 보고 **FAIL 이 PASS 보다 먼저** 나오면 RED 인정.
#   PASS 먼저 → 나중 FAIL 은 "구현 후 깨짐" 이라 RED 아님.
#
# **warn-only (비차단)**: 호출자(record-task-receipt)는 이 결과를 receipt 필드로 남길 뿐
#   커밋을 막지 않는다. transcript 부재·명령 미발견 등 판정 불가가 흔하고(이전 세션 실행·
#   명령 문자열 변형), 즉시 하드화하면 정직한 흐름까지 막는다. 차단 전환 시 바꿀 계약이
#   호출자의 비차단 처리와 이 exit 코드 해석이다.
set -u

FID="${1:?usage: $0 <FID> <task-id>}"
TASK="${2:?usage: $0 <FID> <task-id>}"
SPECOPS="${SPECOPS_ROOT:-.specops}"
TASKS="$SPECOPS/$FID/tasks.md"
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)

command -v jq >/dev/null 2>&1 || { echo "TDD-RED: UNKNOWN (jq 부재)"; exit 2; }
[ -f "$TASKS" ] || { echo "TDD-RED: UNKNOWN (tasks.md 부재)"; exit 2; }

# shellcheck source=/dev/null
source "$PLUGIN/scripts/dag/parse-dag.sh" 2>/dev/null || { echo "TDD-RED: UNKNOWN (parse-dag 로드 실패)"; exit 2; }
yaml=$(dag::extract_yaml "$TASKS" 2>/dev/null) || yaml=""
[ -n "$yaml" ] || { echo "TDD-RED: UNKNOWN (DAG YAML 없음)"; exit 2; }
cmd=$(dag::get_task_test_command "$yaml" "$TASK" 2>/dev/null) || cmd=""
[ -n "$cmd" ] || { echo "TDD-RED: UNKNOWN (test_command 없음 — task=$TASK)"; exit 2; }

# transcript 탐색 — 명시 env 우선, 없으면 프로젝트 슬러그의 최신 세션
TR="${SPECOPS_TRANSCRIPT:-}"
if [ -z "$TR" ]; then
  slug=$(pwd | sed 's|/|-|g')
  TR=$(ls -t "$HOME/.claude/projects/$slug"/*.jsonl 2>/dev/null | head -1 || true)
fi
[ -n "$TR" ] && [ -f "$TR" ] || { echo "TDD-RED: UNKNOWN (transcript 부재)"; exit 2; }

verdicts=$(CMD="$cmd" jq -rn --slurpfile a "$TR" '
  ($a | map(select(.type=="assistant") | .message.content[]?
            | select(.type=="tool_use" and .name=="Bash"))) as $uses
  | ($a | map(select(.type=="user") | .message.content[]?
              | select(.type=="tool_result")
              | {id: .tool_use_id,
                 out: (.content | if type=="string" then . else tostring end)})) as $res
  | ($ENV.CMD) as $c
  | [ $uses[]
      | select((.input.command // "") | contains($c))
      | .id as $i
      | ($res[] | select(.id == $i) | .out) ]
  | map(
      if   test("FAIL=[1-9]|[0-9]+ failed|(^|\\n)FAIL\\b|FAILED") then "FAIL"
      elif test("FAIL=0|[0-9]+ passed|(^|\\n)ok\\b|PASS=[0-9]+ FAIL=0") then "PASS"
      else "?" end)
  | join(",")' 2>/dev/null) || verdicts=""

[ -n "$verdicts" ] || { echo "TDD-RED: UNKNOWN (해당 명령 실행 기록 없음: $cmd)"; exit 2; }

# FAIL 이 첫 PASS 보다 앞서면 RED 인정
first_fail=$(printf '%s' "$verdicts" | tr ',' '\n' | grep -n '^FAIL$' | head -1 | cut -d: -f1 || true)
first_pass=$(printf '%s' "$verdicts" | tr ',' '\n' | grep -n '^PASS$' | head -1 | cut -d: -f1 || true)

if [ -n "$first_fail" ] && { [ -z "$first_pass" ] || [ "$first_fail" -lt "$first_pass" ]; }; then
  echo "TDD-RED: OK — RED 관측(순서: $verdicts)"
  exit 0
fi

echo "TDD-RED: WARN — RED 증거 없음 (GREEN만 관측: $verdicts)"
echo "  이 테스트가 구현 전에 실패했다는 기록이 없습니다 — 구현 없이도 통과하는"
echo "  '공허한 테스트' 일 수 있습니다. RED 를 먼저 확인하는 흐름을 권장합니다."
exit 1
