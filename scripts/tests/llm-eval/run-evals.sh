#!/usr/bin/env bash
# specops-auto-ko LLM eval runner — 메타 skill 신호 감지 + 체인 진입 smoke eval
# 사용: bash scripts/tests/llm-eval/run-evals.sh [fixtures.jsonl]
# 환경: CLAUDE_BIN(기본 claude) · LLM_EVAL_MAX_TURNS(기본 4) · LLM_EVAL_TIMEOUT(기본 120초)
# ⚠️ 실 claude 실행은 토큰 비용 발생 (~$0.5/fixture) — run-all/CI 비포함, 수동 전용
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FIXTURES="${1:-$HERE/fixtures.jsonl}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
# 기본 4: 모델이 Skill 호출 전 타 도구 사용 가능 — Skill 이벤트는 어느 턴에든 잡히면 됨
MAX_TURNS="${LLM_EVAL_MAX_TURNS:-4}"
TIMEOUT_S="${LLM_EVAL_TIMEOUT:-120}"

# I-1: fixtures 부재 시 false green 차단
[ -f "$FIXTURES" ] || { echo "FAIL: fixtures 없음: $FIXTURES"; exit 1; }

total=$(grep -c . "$FIXTURES" || true)
if ! command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
  echo "SKIP: claude CLI 부재 (CLAUDE_BIN=$CLAUDE_BIN)"
  echo "PASS=0 FAIL=0 SKIP=$total BORDERLINE=0 COST=\$0.00"
  exit 0
fi

PASS=0; FAIL=0; BORDER=0; COST=0

# sandbox 격리 — headless lifecycle 부작용 (브랜치 생성·체크아웃·.specops 오염) 을 temp repo 에 가둠
# CLAUDE.md + .specops 존재 시 메타 skill 의 프로젝트 최초 진입(부트스트랩 안내) 분기 회피 — 정상 specifying 진입
SANDBOX=$(mktemp -d)
git -C "$SANDBOX" init -q
mkdir -p "$SANDBOX/.specops"
printf '# sandbox\n' > "$SANDBOX/CLAUDE.md"
cleanup() {  # M-4: mktemp trap — sandbox + attempt 잔여 임시파일 정리
  rm -rf "$SANDBOX"
  [ -n "${R_MARK:-}" ] && rm -f "$R_MARK"
  [ -n "${R_ERR:-}" ] && rm -f "$R_ERR"
  return 0
}
trap cleanup EXIT

run_once() {  # $1=prompt → stdout=stream-json. LLM_EVAL_TIMEOUT 워치독 (bash 3.2, GNU timeout 미의존)
  # I-2: stderr 는 R_ERR 에 보존, timeout kill 은 R_MARK 마커 기록 (호출자 attempt 가 경로 준비)
  # < /dev/null: while 루프의 fixtures FD 0 상속 차단 / cd "$SANDBOX": 부작용 격리 (exec 으로 pid=claude 유지)
  local out_f pid watcher
  out_f=$(mktemp)
  (cd "$SANDBOX" && exec "$CLAUDE_BIN" -p "$1" --output-format stream-json --verbose \
    --max-turns "$MAX_TURNS" --allowedTools Skill) < /dev/null > "$out_f" 2>"$R_ERR" &
  pid=$!
  # 워치독 stdout/stderr 차단 필수 — 미차단 시 자식 sleep 이 명령치환 파이프를 물고 EOF 지연 (hang)
  # 마커는 kill 직전 기록 — 정상 종료 후엔 watcher 를 먼저 kill 해 false 마커 차단
  ( sleep "$TIMEOUT_S" & wait $!; : > "$R_MARK"; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  watcher=$!
  wait "$pid" 2>/dev/null || true
  kill "$watcher" 2>/dev/null
  pkill -P "$watcher" 2>/dev/null
  wait "$watcher" 2>/dev/null || true
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

attempt() {  # $1=prompt → 전역 G_SKILL/G_L1/G_TIMEOUT/G_ERR1 설정 + COST 누적
  local out res c
  R_MARK=$(mktemp); rm -f "$R_MARK"   # 부재 = timeout 없음
  R_ERR=$(mktemp)
  out=$(run_once "$1")
  G_TIMEOUT=0; [ -f "$R_MARK" ] && G_TIMEOUT=1
  G_ERR1=$(head -1 "$R_ERR" 2>/dev/null || true)
  rm -f "$R_MARK" "$R_ERR"
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
    if [ "$G_TIMEOUT" = "1" ]; then  # I-2: timeout 빈 출력의 'none' 가양성 차단 (비차단 유지)
      BORDER=$((BORDER+1)); echo "BORDERLINE $id (TIMEOUT ${TIMEOUT_S}s)"; return
    fi
    short="${G_SKILL#specops-auto-ko:}"; [ -z "$G_SKILL" ] && short="none"
    case ",$any," in
      *",$short,"*) PASS=$((PASS+1)); echo "PASS $id (borderline-allowed)" ;;
      *) BORDER=$((BORDER+1)); echo "BORDERLINE $id (got=$short allow=[$any])" ;;
    esac
    return
  fi

  verdict=$(judge "$want" "$flag" "$G_SKILL" "$G_L1")
  [ "$G_TIMEOUT" = "1" ] && verdict=TIMEOUT  # I-2: timeout 시도는 판정 불성립 — none PASS 차단
  if [ "$verdict" != "PASS" ]; then  # 재시도 cap=1 (AC-6)
    attempt "$prompt"
    verdict=$(judge "$want" "$flag" "$G_SKILL" "$G_L1")
    [ "$G_TIMEOUT" = "1" ] && verdict=TIMEOUT
    retry=" retry"
  fi
  if [ "$verdict" = "PASS" ]; then
    PASS=$((PASS+1)); echo "PASS $id$retry"
  elif [ "$verdict" = "TIMEOUT" ]; then
    FAIL=$((FAIL+1)); echo "FAIL $id$retry (TIMEOUT ${TIMEOUT_S}s)${G_ERR1:+ — stderr: $G_ERR1}"
  else
    FAIL=$((FAIL+1)); echo "FAIL $id$retry (want=$want got=${G_SKILL:-none})${G_ERR1:+ — stderr: $G_ERR1}"
  fi
}

while IFS= read -r fx; do
  [ -z "$fx" ] && continue
  run_fixture "$fx"
done < "$FIXTURES"

printf 'PASS=%d FAIL=%d SKIP=0 BORDERLINE=%d COST=$%.2f\n' "$PASS" "$FAIL" "$BORDER" "$COST"
[ "$FAIL" -eq 0 ]
