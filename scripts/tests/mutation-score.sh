#!/usr/bin/env bash
# specops-ko 간이 뮤테이션 하니스 (수동 측정 도구)
# 사용: bash scripts/tests/mutation-score.sh [config]
#       bash scripts/tests/mutation-score.sh --check-conf [config]   # 변이 없이 equivalent conf 정합만 검사 (1초)
# 소스 가능 — 함수만 정의, main 은 가드. run-all 미포함(test-*.sh 비매칭 명명).
set -uo pipefail

mut::catalog() {
  printf '%s\t%s\n' '-eq' 's/-eq/-ne/'
  printf '%s\t%s\n' '-ne' 's/-ne/-eq/'
  printf '%s\t%s\n' '-gt' 's/-gt/-lt/'
  printf '%s\t%s\n' '-lt' 's/-lt/-gt/'
  printf '%s\t%s\n' 'return 0' 's/return 0/return 1/'
  printf '%s\t%s\n' '&&' 's/&&/||/'
}

mut::judge() {  # <test_command> → killed|survived
  if bash -c "$1" >/dev/null 2>&1; then echo survived; else echo killed; fi
}

mut::score() {  # <killed> <survived> → 백분율 정수
  local killed="$1" survived="$2" total=$(( $1 + $2 ))
  [ "$total" -eq 0 ] && { echo 0; return 0; }
  echo $(( killed * 100 / total ))
}

# equivalent-mutant 판정 — config 의 <target>|<line>|<pattern>| 매칭 (return-code/관찰불가 변형 제외용)
# config: MUT_EQUIV_CONF env 또는 스크립트 디렉토리 mutation-equivalent.conf
mut::is_equivalent() {  # <target> <line> <pattern> → 0(equivalent) | 1
  local target="$1" line="$2" pattern="$3" conf
  conf="${MUT_EQUIV_CONF:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mutation-equivalent.conf}"
  [ -f "$conf" ] || return 1
  grep -Fq -- "${target}|${line}|${pattern}|" "$conf"
}

# 주석 줄 판정 — 선행 공백 제거 후 첫 문자가 '#'
#   ★ 줄 안 '#' 존재로 판정하면 안 된다: `[ "$x" = "true" ] && return 0  # PASS` 는 **코드**이고,
#     이걸 skip 하면 정상 변이가 사라져 score 가 거짓 상승한다.
#   ★ 한계 고백: lexical 판정이라 heredoc·문자열 리터럴 안에서 '#' 로 시작하는 **데이터** 줄도
#     주석으로 보고 skip 한다 (현 target 2개에는 해당 줄이 없어 실측 무영향).
mut::is_comment_line() {  # <line text> → 0(주석) | 1
  case "${1#"${1%%[![:space:]]*}"}" in \#*) return 0 ;; *) return 1 ;; esac
}

# 변이 사이트 실재 확인 — 주석 줄·범위 밖은 사이트가 아니다
mut::site_exists() {  # <target> <line> <pattern> → 0(존재) | 1
  local txt; txt=$(sed -n "${2}p" "$1" 2>/dev/null)
  [ -n "$txt" ] || return 1
  mut::is_comment_line "$txt" && return 1
  printf '%s' "$txt" | grep -qF -- "$3"
}

# equivalent conf 정합 검사 — 매칭 사이트 0건인 항목을 stdout 에 'STALE ...' 로 보고
#   ★ mut::run_target 의 baseline sanity 검사와 **대칭**이다. 그쪽은 stale 로 인한 거짓 '통과'를,
#     이쪽은 stale 로 인한 무음 'red' 를 막는다. 종전엔 방향이 하나뿐이라 equivalent 18건이
#     전량 무음 사망해도 아무도 몰랐다(실측: score 64% → 50%).
mut::check_conf() {  # <targets_conf> → 0(전건 매칭) | 1(stale 1건 이상)
  local tconf="$1" equiv rc=0 target testcmd etarget eline epat ereason n ok
  equiv="${MUT_EQUIV_CONF:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mutation-equivalent.conf}"
  [ -f "$equiv" ] || return 0
  while IFS='|' read -r target testcmd; do
    [ -z "$target" ] && continue
    case "$target" in \#*) continue ;; esac
    [ -f "$target" ] || continue
    n=0; ok=0
    # ereason 은 4번째 필드를 흡수해 epat 이 reason 까지 슬러핑하는 것을 막는 자리표시자다 (읽기 전용).
    # shellcheck disable=SC2034
    while IFS='|' read -r etarget eline epat ereason; do
      [ -z "$etarget" ] && continue
      case "$etarget" in \#*) continue ;; esac
      [ "$etarget" = "$target" ] || continue
      n=$(( n + 1 ))
      # 빈 pattern 은 무조건 stale — `grep -qF -- ""` 가 아무 줄에나 매칭해 '건강'으로 오보하지만,
      #   is_equivalent 의 키(`t|l|p|`)에는 절대 안 맞는 죽은 항목이다. 가드를 site_exists 가 아니라
      #   여기 두는 이유: site_exists 는 "그 줄에 그 텍스트가 있나" 만 답하는 순수 술어로 남기고,
      #   conf 행의 유효성(스키마) 판정은 conf 를 읽는 쪽 책임이기 때문이다.
      if [ -z "$epat" ]; then
        echo "STALE ${etarget}|${eline}|${epat}| (pattern 필드 비어 있음)"
        rc=1; continue
      fi
      if mut::site_exists "$target" "$eline" "$epat"; then
        ok=$(( ok + 1 ))
      else
        echo "STALE ${etarget}|${eline}|${epat}|"
        rc=1
      fi
    done < "$equiv"
    [ "$n" -gt 0 ] && echo "CONF-CHECK: $target ${ok}/${n} 매칭"
  done < "$tconf"
  return $rc
}

mut::run_target() {  # <target> <test_command>
  local target="$1" testcmd="$2"
  [ -f "$target" ] || { echo "SKIP: $target 부재"; return 0; }
  local bak; bak=$(mktemp)
  cp "$target" "$bak"
  trap 'cp "$bak" "$target" 2>/dev/null; rm -f "$bak"' RETURN INT TERM
  # ★ baseline sanity (20260714): 무변형 상태(원본 target)에서 testcmd 는 green 이어야 한다
  #   (mut::judge → survived = testcmd 성공). testcmd 파손(스위트 rename 등)이면 무변형에서도
  #   FAIL(killed) → 전 mutant 가 killed 로 오집계돼 score 100% 거짓 통과한다. 이 게이트가 잡으려는
  #   stale conf 의 역방향이 게이트를 무음 무력화하는 것 — self-check 로 차단.
  if [ "$(mut::judge "$testcmd")" = "killed" ]; then
    echo "ERROR: $target — baseline testcmd 가 무변형 상태에서 FAIL (conf/스위트 파손?)" >&2
    MUT_BELOW_MIN=1
    return 0
  fi
  local killed=0 survived=0 invalid=0 equivalent=0 survived_list=""
  local pat sedexpr lines ln
  while IFS=$'\t' read -r pat sedexpr; do
    [ -z "$pat" ] && continue
    lines=$(grep -nF -- "$pat" "$bak" 2>/dev/null | cut -d: -f1)
    for ln in $lines; do
      # 주석 줄은 변이 사이트가 아니다 — killed·survived·equivalent·invalid 어디에도 넣지 않는다
      mut::is_comment_line "$(sed -n "${ln}p" "$bak")" && continue
      if mut::is_equivalent "$target" "$ln" "$pat"; then
        equivalent=$(( equivalent + 1 )); continue
      fi
      cp "$bak" "$target"
      sed "${ln}${sedexpr}" "$bak" > "$target" 2>/dev/null
      # 빈 결과(sed 실패) 또는 문법 오류 → invalid (거짓 survived 차단 — Phase C Important)
      if [ ! -s "$target" ] || ! bash -n "$target" 2>/dev/null; then
        invalid=$(( invalid + 1 )); continue
      fi
      case "$(mut::judge "$testcmd")" in
        killed)   killed=$(( killed + 1 )) ;;
        survived) survived=$(( survived + 1 ))
                  survived_list="${survived_list}${target}:${ln}:${pat}"$'\n' ;;
      esac
    done
  done < <(mut::catalog)
  cp "$bak" "$target"
  local score; score=$(mut::score "$killed" "$survived")
  echo "MUTATION $target: killed=$killed survived=$survived invalid=$invalid equivalent=$equivalent score=${score}%"
  [ -n "$survived_list" ] && printf 'SURVIVED:\n%s' "$survived_list"
  # threshold (20260714): MUTATION_MIN_SCORE 설정 시 미달 target 을 기록 → main 이 exit 1.
  #   미설정 시 기존 동작(측정만) — 하위호환. cron 강제화용 (governance 커버리지 회귀 감지).
  if [ -n "${MUTATION_MIN_SCORE:-}" ] && [ "$score" -lt "$MUTATION_MIN_SCORE" ]; then
    echo "FAIL: $target score ${score}% < MUTATION_MIN_SCORE ${MUTATION_MIN_SCORE}%" >&2
    MUT_BELOW_MIN=1
  fi
  trap - RETURN INT TERM
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  check_only=0
  if [ "${1:-}" = "--check-conf" ]; then check_only=1; shift; fi
  conf="${1:-$(dirname "$0")/mutation-targets.conf}"
  [ -f "$conf" ] || { echo "SKIP: config 부재 ($conf)"; exit 0; }
  root=$(cd "$(dirname "$0")/../.." && pwd); cd "$root"

  # conf 정합 — 변이 판정 **전에** 검사한다(fail-fast). 사이트 열거는 즉시 끝나고,
  #   18분을 먹는 건 mutant 별 judge 다. stale 이면 score 자체가 틀린 값이라 기다릴 이유가 없다.
  if ! conf_out=$(mut::check_conf "$conf"); then
    if [ "$check_only" = 1 ]; then
      # ★ STALE 원문을 stdout 에 보존한다 — 사용자 승인 포맷이 `CONF-CHECK: STALE <entry>` 이고,
      #   ERROR 로만 치환하면 스크립트 레벨 출력에서 'STALE' 토큰이 사라져 어서션이 잠글 대상을 잃는다.
      # ★ `-n ... p` 를 쓰지 않는다 — sed 는 두 치환을 같은 pattern space 에 순차 적용하므로
      #   STALE 줄이 1번째에서 바뀐 뒤 2번째 `^CONF-CHECK: ` 에 재매칭돼 **2회 출력**된다(실측 36줄).
      #   conf_out 은 STALE·CONF-CHECK 두 종류뿐이라 전체 통과 출력이 곧 의도한 형태다.
      printf '%s\n' "$conf_out" | sed 's/^STALE /CONF-CHECK: STALE /'
      echo "CONF-CHECK: FAIL ($(printf '%s\n' "$conf_out" | grep -c '^STALE ')건 stale)" >&2
    else
      printf '%s\n' "$conf_out" | grep '^STALE ' \
        | sed 's/^STALE /ERROR: mutation-equivalent.conf stale — /; s/$/ 매칭 사이트 0건/' >&2
      echo "ABORT: stale conf — 채점을 진행하지 않는다 (수정 후 재실행: bash $0 --check-conf)" >&2
    fi
    exit 1
  fi
  if [ "$check_only" = 1 ]; then
    printf '%s\n' "$conf_out" | grep '^CONF-CHECK: ' || true
    echo "CONF-CHECK: PASS"
    exit 0
  fi

  MUT_BELOW_MIN=0
  while IFS='|' read -r target testcmd; do
    [ -z "$target" ] && continue
    case "$target" in \#*) continue ;; esac
    mut::run_target "$target" "$testcmd"
  done < "$conf"
  # threshold 미달 target 존재 → exit 1 (MUTATION_MIN_SCORE 설정 시). if 필수 —
  #   `[ ... ] && exit 1` 을 마지막 명령으로 두면 조건 false 시 `[` 의 exit 1 이 스크립트 코드가 된다.
  if [ "${MUT_BELOW_MIN:-0}" = 1 ]; then exit 1; fi
fi
