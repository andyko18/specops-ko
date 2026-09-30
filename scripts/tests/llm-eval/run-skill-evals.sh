#!/usr/bin/env bash
# specops-ko skill 별 활성화·행동 eval 러너 — skills/<name>/{trigger-queries,evals}.json
# 사용: bash scripts/tests/llm-eval/run-skill-evals.sh --trigger|--evals [skill...]
# 환경: CLAUDE_BIN(기본 claude) · SKILL_EVAL_DIR(기본 이 디렉터리의 skills/) · SKILL_EVAL_MODE(routed 강제)
#       ANTHROPIC_API_KEY(있으면 isolated) · LLM_EVAL_MAX_TURNS(기본 4) · LLM_EVAL_TIMEOUT(기본 300초)
# ⚠️ 실 claude 실행은 토큰 비용 발생(~$0.9/질의) — run-all/CI 비포함, 수동 전용. 질의당 1회, 재시도·N-run 없음.
# 측정 모드:
#   isolated — `--bare --plugin-dir <플러그인>`: 훅(SessionStart 메타 주입 포함)을 끄고 description 만으로
#              Skill 을 고르게 하려는 경로. --bare 는 OAuth 를 읽지 않아 ANTHROPIC_API_KEY 가 필요하다.
#              훅 차단·description 해석은 **실측 미확인**이라 요약줄에 `isolated(unverified)` 로 적는다
#              (20260929-skill-behavior-eval IQ-1 — 첫 키 보유 실행에서 확인 후 이 표기를 뗀다).
#   routed   — 현행 run-evals.sh 와 같은 인자: 메타 skill 라우팅이 섞인 측정. `--plugin-dir` 가 없으므로
#              사용자 전역에 specops-ko 가 설치·활성이어야 skill 이 존재하고, 사용자 훅도 그대로 발화한다.
# claude 가 result 이벤트 없이 끝나면(인증 실패·플래그 미지원 등) SKIP(error) — FAIL·PASS 로 세지 않는다.
# 통과율은 max_turns=4 편향을 상속한다(run-evals.sh 헤더) — 감지율이 아니라 신호로만 읽는다.
# 조사·우회 도구 차단(DENY): `--allowedTools Skill` 은 허용 목록일 뿐이라 모델이 Bash 로 빈 sandbox 를 조사하고
#   "코드 없음"으로 끝내 Skill 을 부르지 않았다(2026-09-30 라이브 1회 · 20260930-skill-eval-tool-lock). 두 모드 모두
#   조사·우회 도구를 막아 "Skill 을 부를지"만으로 응답하게 한다 — 이 변경 전 라이브 결과와는 측정 의미가 달라 비교 불가.
#   `--tools Skill` 은 Skill 이 내장 목록 밖이라 전 도구가 꺼져 쓰지 않는다(실측).
#   `--strict-mcp-config`: routed 는 사용자 전역 MCP 도구(실측 31개 · filesystem 포함)가 노출돼 차단을 우회한다 — MCP 서버를 올리지 않는다.
# 픽스처 repo(SKILL_EVAL_FIXTURE · 기본 skill-eval-fixture-repo/): 빈 sandbox 는 system 컨텍스트의 git status 로 드러나
#   기존 코드를 전제하는 질의가 "파일 없음"으로 끝났다(실측 빈 2/3 · 픽스처 커밋 3/3 — 20260930-skill-eval-fixture-repo).
#   질의마다 픽스처를 복사해 CLAUDE.md 까지 커밋한다(git status clean). 픽스처가 없으면 종전 빈 sandbox.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN=$(cd "$HERE/../../.." && pwd)
# shellcheck disable=SC1091
source "$HERE/eval-lib.sh"
# shellcheck disable=SC1091
source "$HERE/skill-evals-lib.sh"

CLAUDE_BIN="${CLAUDE_BIN:-claude}"
DATA_DIR="${SKILL_EVAL_DIR:-$HERE/skills}"
MAX_TURNS="${LLM_EVAL_MAX_TURNS:-4}"
TIMEOUT_S="${LLM_EVAL_TIMEOUT:-300}"
FIXTURE_DIR="${SKILL_EVAL_FIXTURE:-$HERE/skill-eval-fixture-repo}"
# 호출자 셸의 git 위치 변수는 sandbox 의 git·claude(자식 프로세스)를 sandbox 밖으로 끌고 간다(git 훅 안 실행 등) — 러너는 호출자
#   repo 를 쓰지 않으므로 전부 해제한다(pre-commit 은 GIT_INDEX_FILE 을 설정한다 — 실측)
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

case "${1:-}" in
  --trigger) KIND=trigger; FILE=trigger-queries.json ;;
  --evals)   KIND=evals;   FILE=evals.json ;;
  *) echo "사용: bash run-skill-evals.sh --trigger|--evals [skill...]" >&2; exit 0 ;;  # spec FR-8 — 항상 exit 0
esac
shift

MODE=routed; LABEL=routed
if [ "${SKILL_EVAL_MODE:-}" = routed ]; then
  echo "NOTE: SKILL_EVAL_MODE=routed 강제 — 메타 라우팅 혼합 측정"
elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  MODE=isolated; LABEL="isolated(unverified)"
else
  echo "NOTE: isolated 불가(ANTHROPIC_API_KEY 부재) — routed: 메타 라우팅 혼합 측정 (전역 설치 플러그인·사용자 훅 의존)"
fi
DENY=(Bash Read Glob Grep Agent Edit Write NotebookEdit WebFetch WebSearch ToolSearch)
EXTRA=(--max-turns "$MAX_TURNS" --allowedTools Skill --disallowedTools "${DENY[@]}" --strict-mcp-config)
[ "$MODE" = isolated ] && EXTRA+=(--bare --plugin-dir "$PLUGIN")

if [ "$#" -gt 0 ]; then SKILLS=("$@")
else SKILLS=(); for d in "$DATA_DIR"/*/; do [ -d "$d" ] && SKILLS+=("$(basename "$d")"); done; fi

PASS=0; FAIL=0; SKIP=0; COST=0
summary() { echo "SKILL-EVAL: mode=$LABEL $KIND pass=$PASS fail=$FAIL skip=$SKIP cost=\$$(awk -v c="$COST" 'BEGIN{printf "%.2f", c}')"; }

if ! command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
  echo "SKIP: claude CLI 부재 (CLAUDE_BIN=$CLAUDE_BIN)"
  SKIP=${#SKILLS[@]}; summary; exit 0
fi

emit() {  # <skill> <id> <verdict> [사유]
  printf 'MODE=%s  %s  %s  %s%s\n' "$MODE" "$1" "$2" "$3" "${4:+  ($4)}"
  case "$3" in PASS) PASS=$((PASS+1)) ;; FAIL) FAIL=$((FAIL+1)) ;; *) SKIP=$((SKIP+1)) ;; esac
}

ask() {  # <prompt> → 전역 OUT(stream-json) · ERR(stderr 첫 줄 ≤120자) · rc 124=timeout · 3=result 없음. 질의마다 격리 sandbox(부트스트랩 안내 회피용 시드)
  local sb rc ef
  ERR=""
  sb=$(mktemp -d) || { OUT=""; return 3; }
  # stderr 는 sandbox 밖에 받는다 — sandbox 안이면 claude 가 보는 git status 에 untracked 로 드러나 측정을 오염시킨다
  ef=$(mktemp) || ef=/dev/null
  git -C "$sb" init -q; mkdir -p "$sb/.specops"; printf '# sandbox\n' > "$sb/CLAUDE.md"
  if [ -d "$FIXTURE_DIR" ]; then  # 픽스처 복사 + 전부 커밋 — 실패해도 판정 경로는 그대로(sandbox 는 그대로 쓴다)
    # 사용자 git 설정에 흔들리지 않게: ignore 규칙 전부(전역 gitignore·templateDir 의 info/exclude) 무시(add -f) · hooksPath/templateDir 훅 · 서명을 끈다
    cp -R "$FIXTURE_DIR/." "$sb/" 2>/dev/null
    { git -C "$sb" add -Af \
        && git -C "$sb" -c user.email=eval@local -c user.name=skill-eval -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -qm fixture; } >/dev/null 2>&1
  fi
  OUT=$(eval::run_claude "$CLAUDE_BIN" "$sb" "$TIMEOUT_S" "$1" "${EXTRA[@]}" 2>"$ef"); rc=$?
  # 첫 줄만 · ANSI 색 시퀀스 → 나머지 제어문자 제거(≥0x80 바이트 보존) · 120자 절단(UTF-8 로케일 전제 — C 로케일이면 바이트 절단)
  ERR=$(head -1 "$ef" 2>/dev/null | sed $'s/\x1b\\[[0-9;]*[A-Za-z]//g' | LC_ALL=C tr -d '\000-\037\177'); ERR=${ERR:0:120}
  [ "$ef" = /dev/null ] || rm -f "$ef"
  rm -rf "$sb"
  COST=$(awk -v a="$COST" -v b="$(printf '%s\n' "$OUT" | eval::extract_cost)" 'BEGIN{printf "%.6f", a+b}')  # 반올림은 요약에서 1회
  return "$rc"
}

skip_reason() {  # <ask rc> [stderr 첫 줄] → SKIP 문구 (stderr 가 있으면 실행 실패 사유로 덧붙인다)
  case "$1" in 124) echo "SKIP(timeout)" ;; *) echo "SKIP(error: result 이벤트 없음 — 실행 실패)${2:+ — stderr: $2}" ;; esac
}

run_trigger() {  # <skill> <file> — 질의는 jq -c 한 줄 객체로 읽는다(@tsv 는 탭·개행·백슬래시를 이스케이프 문자열로 바꾼다)
  local s="$1" f="$2" o id q want calls rc
  while IFS= read -r o; do
    want=$(printf '%s' "$o" | jq -r .w); id=$(printf '%s' "$o" | jq -r .id); q=$(printf '%s' "$o" | jq -r .query)
    ask "$q"; rc=$?
    [ "$rc" -eq 0 ] || { emit "$s" "$id" "$(skip_reason "$rc" "$ERR")"; continue; }
    calls=$(printf '%s\n' "$OUT" | eval::all_skills)
    if [ "$want" = pos ]; then
      skill_evals::called "$s" "$calls" && emit "$s" "$id" PASS || emit "$s" "$id" FAIL "불려야 하는데 미호출"
    else
      skill_evals::called "$s" "$calls" && emit "$s" "$id" FAIL "불리면 안 되는데 호출됨" || emit "$s" "$id" PASS
    fi
  done < <(jq -c '(.should_trigger[] | {w:"pos", id, query}), (.should_not_trigger[] | {w:"neg", id, query})' "$f")
}

run_evals() {  # <skill> <file>
  local s="$1" f="$2" o id p asserts a t v verdict text cost first rc
  while IFS= read -r o; do
    id=$(printf '%s' "$o" | jq -r .id); p=$(printf '%s' "$o" | jq -r .prompt)
    ask "$p"; rc=$?
    [ "$rc" -eq 0 ] || { emit "$s" "$id" "$(skip_reason "$rc" "$ERR")"; continue; }
    text=$(printf '%s\n' "$OUT" | eval::extract_text)
    cost=$(printf '%s\n' "$OUT" | eval::extract_cost)
    first=""
    asserts=$(printf '%s' "$o" | jq -c '.asserts[]')
    while IFS= read -r a; do
      [ -z "$a" ] && continue
      t=$(printf '%s' "$a" | jq -r .type); v=$(printf '%s' "$a" | jq -r '.value|tostring')
      if [ "$t" = cost_lt ]; then verdict=$(eval::assert cost_lt "$cost" "$v")
      else verdict=$(eval::assert "$t" "$text" "$v" "$CLAUDE_BIN"); fi
      [ "$verdict" = FAIL ] && [ -z "$first" ] && first="$t:$v"
    done <<EOF
$asserts
EOF
    [ -z "$first" ] && emit "$s" "$id" PASS || emit "$s" "$id" FAIL "첫 실패 $first"
  done < <(jq -c '.cases[]' "$f")
}

for s in "${SKILLS[@]+"${SKILLS[@]}"}"; do
  f="$DATA_DIR/$s/$FILE"
  if [ ! -f "$f" ]; then emit "$s" - "SKIP(데이터 파일 부재: $FILE)"; continue; fi
  if ! why=$(skill_evals::check "$KIND" "$f" "$PLUGIN/skills"); then emit "$s" - "SKIP(스키마 위반: $why)"; continue; fi
  if [ "$KIND" = trigger ]; then run_trigger "$s" "$f"; else run_evals "$s" "$f"; fi
done
summary
exit 0
