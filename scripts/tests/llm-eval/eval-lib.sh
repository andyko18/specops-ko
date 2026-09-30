#!/usr/bin/env bash
# library-only
# specops-ko llm-eval 공통 라이브러리 (promptfoo 방법론 bash 이식)
# 소스 전용 — assertion 어휘 4종 + 매트릭스 평가 primitive. 실 모델 선택(stub fallback).

eval::skip_guard() {  # <bin>
  if ! command -v "$1" >/dev/null 2>&1; then echo "SKIP: provider 부재 ($1)"; return 1; fi
  return 0
}

eval::extract_text() {  # stdin stream-json → assistant text 연결
  jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' 2>/dev/null | paste -sd' ' - | tr -s ' ' | sed 's/ *$//'
}

eval::extract_cost() {  # stdin stream-json → total_cost_usd (없으면 0)
  jq -r 'select(.type=="result") | .total_cost_usd // 0' 2>/dev/null | head -1 | grep . || echo 0
}

eval::assert_contains() {  # <out> <val> → PASS|FAIL
  [ -z "$2" ] && { echo FAIL; return; }   # 빈 needle → vacuous pass 차단 (Phase C Important)
  printf '%s' "$1" | grep -Fq -- "$2" && echo PASS || echo FAIL
}
eval::assert_regex() {  # <out> <val>
  printf '%s' "$1" | grep -Eq -- "$2" && echo PASS || echo FAIL
}
eval::assert_cost_lt() {  # <cost> <max>
  # 비숫자 cost → FAIL (조용한 0 강제로 false-green 차단 — Phase C Important)
  case "$1" in ''|*[!0-9.]*) echo FAIL; return ;; esac
  awk -v c="$1" -v m="$2" 'BEGIN{ exit !(c+0 < m+0) }' && echo PASS || echo FAIL
}
eval::assert_llm_rubric() {  # <out> <val> <bin> — stub: out 에 "rubric-pass" 포함
  printf '%s' "$1" | grep -Fq "rubric-pass" && echo PASS || echo FAIL
}

eval::assert() {  # <type> <out> <val> [bin] → 디스패처
  case "$1" in
    contains)   eval::assert_contains "$2" "$3" ;;
    regex)      eval::assert_regex "$2" "$3" ;;
    cost_lt)    eval::assert_cost_lt "$2" "$3" ;;
    llm_rubric) eval::assert_llm_rubric "$2" "$3" "${4:-stub}" ;;
    *)          echo FAIL ;;
  esac
}

eval::run_matrix() {  # <fixtures.jsonl> <bin>
  local fixtures="$1" bin="$2"
  [ -f "$fixtures" ] || { echo "SKIP: fixtures 부재 ($fixtures)"; return 0; }
  local rows=0 pass=0 fail=0 line text cost asserts a atype aval averdict row_ok firstfail
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    rows=$((rows+1))
    text="${EVAL_STUB_TEXT:-}"; cost="${EVAL_STUB_COST:-0}"
    row_ok=1; firstfail=""
    asserts=$(printf '%s' "$line" | jq -c '.asserts[]?' 2>/dev/null)
    while IFS= read -r a; do
      [ -z "$a" ] && continue
      atype=$(printf '%s' "$a" | jq -r '.type')
      aval=$(printf '%s' "$a" | jq -r '.value')
      case "$atype" in
        cost_lt) averdict=$(eval::assert cost_lt "$cost" "$aval") ;;
        *)       averdict=$(eval::assert "$atype" "$text" "$aval" "$bin") ;;
      esac
      if [ "$averdict" = FAIL ]; then row_ok=0; [ -z "$firstfail" ] && firstfail="${atype}:${aval}"; fi
    done <<EOF
$asserts
EOF
    if [ "$row_ok" -eq 1 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "  row $rows FAIL (첫 실패: $firstfail)"; fi
  done < "$fixtures"
  echo "matrix: $rows rows $pass pass $fail fail"
}

eval::all_skills() {  # stdin stream-json → 호출 순서대로 Skill 이름 한 줄씩 (0건이면 빈 출력)
  jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill // empty' 2>/dev/null
}

eval::run_claude() {  # <bin> <cwd> <timeout_s> <prompt> [추가 인자...] → stdout stream-json · rc 124=timeout · 3=result 이벤트 없음
  # 워치독: bash 3.2 · GNU timeout 미의존. < /dev/null: 호출자 루프 FD 0 상속 차단.
  # 신호 정리는 두 방식 모두 실측 결함 — kill watcher → pkill -P 순서는 재부모화된 sleep 을 고아로 남기고,
  # watcher 자신의 TERM trap 은 즉시 끝나는 대상 × 반복 부하에서 신호가 trap 설치 전후 창에 떨어져 부모의
  # wait 가 timeout 동안 멈춘다. 그래서 flag 폴링: 부모는 워치독에 신호를 보내지도 wait 하지도 않고 flag 만 지운다.
  # result 이벤트가 없으면(인증 실패·플래그 미지원·크래시로 빈 출력) rc 3 — 음성 질의가 "미호출 PASS" 로 위장되지 않게.
  local bin="$1" cwd="$2" to="$3" prompt="$4" out_f mark pid flag
  shift 4
  out_f=$(mktemp); mark="$out_f.timeout"; flag=$(mktemp)
  # stderr 는 버리지 않고 호출자 stderr 로 흘린다 — 실행 실패(rc 3) 사유 진단용(20260930-skill-eval-tool-lock). stdout 판정 경로 불변
  (cd "$cwd" && exec "$bin" -p "$prompt" --output-format stream-json --verbose "$@") < /dev/null > "$out_f" &
  pid=$!
  ( lim=$to; case "$lim" in ''|*[!0-9]*) lim=${lim%%.*}; case "$lim" in ''|*[!0-9]*) lim=0 ;; esac; lim=$((lim + 1)) ;; esac
    n=0; while [ "$n" -lt "$lim" ]; do [ -e "$flag" ] || exit 0; sleep 1; n=$((n + 1)); done
    [ -e "$flag" ] || exit 0; : > "$mark"; pkill -P "$pid" 2>/dev/null; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  wait "$pid" 2>/dev/null || true
  rm -f "$flag"
  cat "$out_f"
  if [ -f "$mark" ]; then rm -f "$mark" "$out_f"; return 124; fi
  if ! jq -r 'select(.type=="result") | .type' "$out_f" 2>/dev/null | grep -q .; then rm -f "$out_f"; return 3; fi
  rm -f "$out_f"; return 0
}
