#!/usr/bin/env bash
# specops-auto-ko LLM eval runner — 메타 skill 신호 감지 + 체인 진입 smoke eval
# 사용: bash scripts/tests/llm-eval/run-evals.sh [fixtures.jsonl]
# 환경: CLAUDE_BIN(기본 claude) · LLM_EVAL_MAX_TURNS(기본 2) · LLM_EVAL_TIMEOUT(기본 120초)
# ⚠️ 실 claude 실행은 토큰 비용 발생 (~$0.5/fixture) — run-all/CI 비포함, 수동 전용
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FIXTURES="${1:-$HERE/fixtures.jsonl}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
MAX_TURNS="${LLM_EVAL_MAX_TURNS:-2}"
TIMEOUT_S="${LLM_EVAL_TIMEOUT:-120}"

total=$(grep -c . "$FIXTURES" || echo 0)
if ! command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
  echo "SKIP: claude CLI 부재 (CLAUDE_BIN=$CLAUDE_BIN)"
  echo "PASS=0 FAIL=0 SKIP=$total BORDERLINE=0 COST=\$0.00"
  exit 0
fi

PASS=0; FAIL=0; BORDER=0; COST=0

run_once() {  # $1=prompt → stdout=stream-json. LLM_EVAL_TIMEOUT 워치독 (bash 3.2, GNU timeout 미의존)
  local out_f pid watcher
  out_f=$(mktemp)
  "$CLAUDE_BIN" -p "$1" --output-format stream-json --verbose \
    --max-turns "$MAX_TURNS" --allowedTools Skill > "$out_f" 2>/dev/null &
  pid=$!
  # 워치독 stdout/stderr 차단 필수 — 미차단 시 자식 sleep 이 명령치환 파이프를 물고 EOF 지연 (hang)
  ( sleep "$TIMEOUT_S" & wait $!; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  watcher=$!
  wait "$pid" 2>/dev/null || true
  pkill -P "$watcher" 2>/dev/null
  kill "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null || true
  cat "$out_f"; rm -f "$out_f"
}

parse_first_skill() {  # stdin=stream-json → "<skill>\t<args 첫 줄>" (없으면 빈)
  jq -r 'select(.type=="assistant") | .message.content[]?
         | select(.type=="tool_use" and .name=="Skill")
         | [.input.skill, ((.input.args // "") | split("\n")[0])] | @tsv' 2>/dev/null | head -1
}

extract_cost() {  # stdin=stream-json → 비용 (없으면 0)
  jq -r 'select(.type=="result") | .total_cost_usd // 0' 2>/dev/null | head -1 | grep . || echo 0
}

judge() {  # $1=expect_skill $2=expect_flag $3=got_skill $4=got_args_l1 → PASS|FAIL
  local want="$1" flag="$2" got="$3" l1="$4"
  if [ "$want" = "none" ]; then
    [ -z "$got" ] && echo PASS || echo FAIL
    return
  fi
  if [ "$got" != "specops-auto-ko:$want" ] && [ "$got" != "$want" ]; then
    echo FAIL; return
  fi
  if [ "$flag" = "maintain" ]; then
    case "$l1" in
      *"<!-- entry: maintain -->"*) ;;
      *) echo FAIL; return ;;
    esac
  fi
  echo PASS
}

attempt() {  # $1=prompt → 전역 G_SKILL/G_L1 설정 + COST 누적
  local out res c
  out=$(run_once "$1")
  c=$(printf '%s\n' "$out" | extract_cost)
  COST=$(awk -v a="$COST" -v b="$c" 'BEGIN{printf "%.4f", a+b}')
  res=$(printf '%s\n' "$out" | parse_first_skill)
  G_SKILL="${res%%$'\t'*}"
  G_L1="${res#*$'\t'}"; [ "$res" = "$G_SKILL" ] && G_L1=""
}

run_fixture() {  # $1=fixture json 1줄
  local fx="$1" id prompt want flag any short verdict retry=""
  id=$(printf '%s' "$fx" | jq -r '.id')
  prompt=$(printf '%s' "$fx" | jq -r '.prompt')
  any=$(printf '%s' "$fx" | jq -r '(.expect_any // []) | join(",")')
  want=$(printf '%s' "$fx" | jq -r '.expect_skill // "none"')
  flag=$(printf '%s' "$fx" | jq -r '.expect_flag // "none"')

  attempt "$prompt"

  if [ -n "$any" ]; then  # 경계 케이스 — judge 전 처리, 비차단·재시도 없음 (AC-11)
    short="${G_SKILL#specops-auto-ko:}"; [ -z "$G_SKILL" ] && short="none"
    case ",$any," in
      *",$short,"*) PASS=$((PASS+1)); echo "PASS $id (borderline-allowed)" ;;
      *) BORDER=$((BORDER+1)); echo "BORDERLINE $id (got=$short allow=[$any])" ;;
    esac
    return
  fi

  verdict=$(judge "$want" "$flag" "$G_SKILL" "$G_L1")
  if [ "$verdict" != "PASS" ]; then  # 재시도 cap=1 (AC-6)
    attempt "$prompt"
    verdict=$(judge "$want" "$flag" "$G_SKILL" "$G_L1")
    retry=" retry"
  fi
  if [ "$verdict" = "PASS" ]; then
    PASS=$((PASS+1)); echo "PASS $id$retry"
  else
    FAIL=$((FAIL+1)); echo "FAIL $id$retry (want=$want got=${G_SKILL:-none})"
  fi
}

while IFS= read -r fx; do
  [ -z "$fx" ] && continue
  run_fixture "$fx"
done < "$FIXTURES"

printf 'PASS=%d FAIL=%d SKIP=0 BORDERLINE=%d COST=$%.2f\n' "$PASS" "$FAIL" "$BORDER" "$COST"
[ "$FAIL" -eq 0 ]
