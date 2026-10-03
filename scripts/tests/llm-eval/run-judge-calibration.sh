#!/usr/bin/env bash
# 채점기 보정 러너 — judge-calibration/cases.jsonl 의 (응답, 기준, 기대 판정) 을 eval::judge_rubric 에 넣어 일치율을 잰다.
# 사용: bash scripts/tests/llm-eval/run-judge-calibration.sh
# 환경: CLAUDE_BIN(기본 claude) · JUDGE_CAL_FILE(기본 이 디렉터리의 judge-calibration/cases.jsonl) · JUDGE_CAL_RUNS(기본 2) ·
#       LLM_EVAL_TIMEOUT(기본 300초) · LLM_EVAL_JUDGE_MODEL(지정 시 --model)
# ⚠️ 실 claude 실행은 토큰 비용 발생(채점 호출당 ~$0.25~0.4) — run-all/CI 비포함, 수동 전용.
# 채택 기준: 오답(expect=FAIL)을 PASS 로 낸 케이스 0 이고 일치 ≥ 90% 일 때만 CALIBRATION-VERDICT: ADOPT.
#   일치 = 모든 회차의 판정이 기대와 같음(ERROR 는 일치가 아님). 관대한 채점기는 키워드 정규식보다 나쁘다 — 오통과 0 이 핵심.
# 증거 0·부분 증거로 ADOPT 하지 않는다: JUDGE_CAL_RUNS 가 1 이상 정수가 아님 · 세트 빈/손상/스키마 위반 → 채점 전 `ERROR:` + REJECT,
#   회차 간 채점 모델 변동 → CALIBRATION-MODEL: mixed(...) + REJECT.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$HERE/eval-lib.sh"

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
CASES="${JUDGE_CAL_FILE:-$HERE/judge-calibration/cases.jsonl}"
RUNS="${JUDGE_CAL_RUNS-2}"   # 미설정만 기본 2 — 명시적 빈값은 아래 가드가 거절
TIMEOUT_S="${LLM_EVAL_TIMEOUT:-300}"

reject() {  # <사유> → ERROR 사유 + REJECT 출력 후 종료 (러너 exit 0 관례 — 판정은 VERDICT 줄이 전달한다)
  echo "ERROR: $1"; echo "CALIBRATION-VERDICT: REJECT"; exit 0
}
# 증거 0 으로 ADOPT 금지 — 회차 0·비정수면 채점 루프가 0회 돌아 agree=total 이 된다
case "$RUNS" in ''|*[!0-9]*) reject "JUDGE_CAL_RUNS 는 1 이상 정수여야 한다 (현재: '$RUNS')" ;; esac
[ "$RUNS" -ge 1 ] || reject "JUDGE_CAL_RUNS 는 1 이상 정수여야 한다 (현재: '$RUNS')"

[ -f "$CASES" ] || { echo "SKIP: 보정 세트 부재 ($CASES)"; exit 0; }
command -v "$CLAUDE_BIN" >/dev/null 2>&1 || { echo "SKIP: claude CLI 부재 (CLAUDE_BIN=$CLAUDE_BIN)"; exit 0; }

# 부분 증거로 ADOPT 금지 — 채점(유료) 전에 세트 전체를 파싱·스키마 검증한다. 손상 행에서 jq 가 멈추면 앞 행만 채점되던 경로 차단
grep -q '[^[:space:]]' "$CASES" || reject "보정 세트가 비어 있다 ($CASES)"
PARSED=$(mktemp) || reject "임시 파일 생성 실패"
trap 'rm -f "$PARSED"' EXIT
jq -e -c '.' "$CASES" > "$PARSED" 2>/dev/null || reject "보정 세트 파싱 실패 — 손상된 JSON 행 또는 null/false 행 ($CASES)"
# 행마다 id·rubric·response 비어있지 않은 문자열 · expect PASS|FAIL · prompt 는 선택(있으면 문자열)
bad=$(jq -r 'select((type != "object")
  or ((.id | type) != "string") or (.id == "")
  or ((.rubric | type) != "string") or (.rubric == "")
  or ((.response | type) != "string") or (.response == "")
  or ((.expect != "PASS") and (.expect != "FAIL"))
  or (has("prompt") and ((.prompt | type) != "string")))
  | if type == "object" then (.id // "?" | tostring) else "(객체 아님)" end' "$PARSED" 2>/dev/null) \
  || reject "보정 세트 스키마 검사 실행 실패 ($CASES)"
[ -z "$bad" ] || reject "보정 세트 스키마 위반 — id·rubric·response(문자열)·expect(PASS|FAIL) 필수: $(printf '%s' "$bad" | tr '\n' ' ')"
# id 중복 거절 — 오버라이드 세트에서 같은 id 가 분모를 부풀리지 않게, 채점(유료) 전에 전부 나열해 한 번에 고치게 한다 (문자열 완전 일치·대소문자 구분)
dups=$(jq -r '.id' "$PARSED" | LC_ALL=C sort | uniq -d | tr '\n' ' ') || reject "보정 세트 id 중복 검사 실행 실패 ($CASES)"
[ -z "$dups" ] || reject "보정 세트 id 중복 — ${dups% }"
rows=$(wc -l < "$PARSED" | tr -d ' ')

agree=0; total=0; false_pass=0; errors=0; COST=0; models=""
while IFS= read -r o; do
  id=$(printf '%s' "$o" | jq -r .id); expect=$(printf '%s' "$o" | jq -r .expect)
  resp=$(printf '%s' "$o" | jq -r .response); rubric=$(printf '%s' "$o" | jq -r .rubric); question=$(printf '%s' "$o" | jq -r '.prompt // ""')
  got=""; ok=1; fp=0; total=$((total + 1))
  i=0
  while [ "$i" -lt "$RUNS" ]; do
    i=$((i + 1))
    eval::judge_rubric "$CLAUDE_BIN" "$resp" "$rubric" "$TIMEOUT_S" "$question"
    # 모델 ID 는 비어있지 않은 값만 모은다 — 호출 실패(init 이벤트 없음)는 다른 모델이 아니다
    case ",$models," in *",$JUDGE_MODEL,"*) ;; *) [ -z "$JUDGE_MODEL" ] || models="$models${models:+,}$JUDGE_MODEL" ;; esac
    COST=$(awk -v a="$COST" -v b="$JUDGE_COST" 'BEGIN{printf "%.6f", a+b}')
    got="$got${got:+,}$JUDGE_VERDICT"
    [ "$JUDGE_VERDICT" = "$expect" ] || ok=0
    [ "$JUDGE_VERDICT" = ERROR ] && errors=$((errors + 1))
    [ "$expect" = FAIL ] && [ "$JUDGE_VERDICT" = PASS ] && fp=1
  done
  # 방어 심층 — JUDGE_CAL_RUNS ≥ 1 가드(위)가 회차 0 을 이미 거절하므로 이 줄은 현재 도달 불가(단독 변이로 검출 불가). 가드가 완화될 때를 위해 남긴다
  [ -n "$got" ] || ok=0   # 채점 0회는 일치가 아니다 (낙관 초기화 ok=1 이 증거 없이 통과되지 않게)
  agree=$((agree + ok)); false_pass=$((false_pass + fp))
  printf 'CASE %s expect=%s got=%s\n' "$id" "$expect" "$got"
done < "$PARSED"

mixed=0
case "$models" in *,*) mixed=1 ;; esac
if [ "$mixed" -eq 1 ]; then model_label="mixed($models)"; else model_label="${models:-unknown}"; fi
printf 'CALIBRATION-MODEL: %s (보정은 이 채점 모델에 묶인다 — 모델을 바꾸면 재보정)\n' "$model_label"
printf 'CALIBRATION: agree=%s/%s false_pass=%s error=%s cost=$%s\n' "$agree" "$total" "$false_pass" "$errors" "$(awk -v c="$COST" 'BEGIN{printf "%.2f", c}')"
[ "$mixed" -eq 0 ] || echo "ERROR: 회차 간 채점 모델이 바뀌었다 ($models) — 보정이 어느 한 모델에 묶이지 않는다"
# 방어 심층 — jq -c 가 행마다 개행 1개를 내 행 수(wc -l)와 채점 루프 수가 항상 같아 현재 도달 불가. 파싱 방식이 바뀌어 부분 채점이 생기면 ADOPT 되지 않게 남긴다
[ "$total" -eq "$rows" ] || echo "ERROR: 파싱한 행 수($rows) 와 채점한 케이스 수($total) 불일치"
if [ "$mixed" -eq 0 ] && [ "$total" -eq "$rows" ] && [ "$false_pass" -eq 0 ] && [ "$total" -gt 0 ] && [ $((agree * 10)) -ge $((total * 9)) ]; then
  echo "CALIBRATION-VERDICT: ADOPT"
else
  echo "CALIBRATION-VERDICT: REJECT"
fi
exit 0
