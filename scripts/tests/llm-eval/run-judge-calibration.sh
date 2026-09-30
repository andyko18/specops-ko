#!/usr/bin/env bash
# 채점기 보정 러너 — judge-calibration/cases.jsonl 의 (응답, 기준, 기대 판정) 을 eval::judge_rubric 에 넣어 일치율을 잰다.
# 사용: bash scripts/tests/llm-eval/run-judge-calibration.sh
# 환경: CLAUDE_BIN(기본 claude) · JUDGE_CAL_FILE(기본 이 디렉터리의 judge-calibration/cases.jsonl) · JUDGE_CAL_RUNS(기본 2) ·
#       LLM_EVAL_TIMEOUT(기본 300초) · LLM_EVAL_JUDGE_MODEL(지정 시 --model)
# ⚠️ 실 claude 실행은 토큰 비용 발생(채점 호출당 ~$0.25~0.4) — run-all/CI 비포함, 수동 전용.
# 채택 기준: 오답(expect=FAIL)을 PASS 로 낸 케이스 0 이고 일치 ≥ 90% 일 때만 CALIBRATION-VERDICT: ADOPT.
#   일치 = 모든 회차의 판정이 기대와 같음(ERROR 는 일치가 아님). 관대한 채점기는 키워드 정규식보다 나쁘다 — 오통과 0 이 핵심.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$HERE/eval-lib.sh"

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
CASES="${JUDGE_CAL_FILE:-$HERE/judge-calibration/cases.jsonl}"
RUNS="${JUDGE_CAL_RUNS:-2}"
TIMEOUT_S="${LLM_EVAL_TIMEOUT:-300}"

[ -f "$CASES" ] || { echo "SKIP: 보정 세트 부재 ($CASES)"; exit 0; }
command -v "$CLAUDE_BIN" >/dev/null 2>&1 || { echo "SKIP: claude CLI 부재 (CLAUDE_BIN=$CLAUDE_BIN)"; exit 0; }

agree=0; total=0; false_pass=0; errors=0; COST=0; model=""
while IFS= read -r o; do
  id=$(printf '%s' "$o" | jq -r .id); expect=$(printf '%s' "$o" | jq -r .expect)
  resp=$(printf '%s' "$o" | jq -r .response); rubric=$(printf '%s' "$o" | jq -r .rubric); question=$(printf '%s' "$o" | jq -r '.prompt // ""')
  got=""; ok=1; fp=0; total=$((total + 1))
  i=0
  while [ "$i" -lt "$RUNS" ]; do
    i=$((i + 1))
    eval::judge_rubric "$CLAUDE_BIN" "$resp" "$rubric" "$TIMEOUT_S" "$question"
    [ -n "$model" ] || model="$JUDGE_MODEL"
    COST=$(awk -v a="$COST" -v b="$JUDGE_COST" 'BEGIN{printf "%.6f", a+b}')
    got="$got${got:+,}$JUDGE_VERDICT"
    [ "$JUDGE_VERDICT" = "$expect" ] || ok=0
    [ "$JUDGE_VERDICT" = ERROR ] && errors=$((errors + 1))
    [ "$expect" = FAIL ] && [ "$JUDGE_VERDICT" = PASS ] && fp=1
  done
  agree=$((agree + ok)); false_pass=$((false_pass + fp))
  printf 'CASE %s expect=%s got=%s\n' "$id" "$expect" "$got"
done < <(jq -c '.' "$CASES")

printf 'CALIBRATION-MODEL: %s (보정은 이 채점 모델에 묶인다 — 모델을 바꾸면 재보정)\n' "${model:-unknown}"
printf 'CALIBRATION: agree=%s/%s false_pass=%s error=%s cost=$%s\n' "$agree" "$total" "$false_pass" "$errors" "$(awk -v c="$COST" 'BEGIN{printf "%.2f", c}')"
if [ "$false_pass" -eq 0 ] && [ "$total" -gt 0 ] && [ $((agree * 10)) -ge $((total * 9)) ]; then
  echo "CALIBRATION-VERDICT: ADOPT"
else
  echo "CALIBRATION-VERDICT: REJECT"
fi
exit 0
