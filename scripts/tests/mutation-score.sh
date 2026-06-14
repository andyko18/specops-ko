#!/usr/bin/env bash
# specops-auto-ko 간이 뮤테이션 하니스 (수동 측정 도구)
# 사용: bash scripts/tests/mutation-score.sh [config]
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

mut::run_target() {  # <target> <test_command>
  local target="$1" testcmd="$2"
  [ -f "$target" ] || { echo "SKIP: $target 부재"; return 0; }
  local bak; bak=$(mktemp)
  cp "$target" "$bak"
  trap 'cp "$bak" "$target" 2>/dev/null; rm -f "$bak"' RETURN INT TERM
  local killed=0 survived=0 invalid=0 equivalent=0 survived_list=""
  local pat sedexpr lines ln
  while IFS=$'\t' read -r pat sedexpr; do
    [ -z "$pat" ] && continue
    lines=$(grep -nF -- "$pat" "$bak" 2>/dev/null | cut -d: -f1)
    for ln in $lines; do
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
  trap - RETURN INT TERM
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  conf="${1:-$(dirname "$0")/mutation-targets.conf}"
  [ -f "$conf" ] || { echo "SKIP: config 부재 ($conf)"; exit 0; }
  root=$(cd "$(dirname "$0")/../.." && pwd); cd "$root"
  while IFS='|' read -r target testcmd; do
    [ -z "$target" ] && continue
    case "$target" in \#*) continue ;; esac
    mut::run_target "$target" "$testcmd"
  done < "$conf"
fi
