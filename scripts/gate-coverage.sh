#!/usr/bin/env bash
# specops-ko gate-coverage — verify 도달 FID 의 게이트 판정 보유율 (다중 repo · 읽기 전용)
# 사용: bash scripts/gate-coverage.sh [repo 루트 또는 .specops 경로]...
#   인자 없음 → 호출 위치 git 루트의 .specops (git 밖이면 ./.specops). 측정 목적이면 경로를 명시하라.
# 소스 가능 — gc:: 함수만 정의, main 은 가드. 판정 해석은 skip-tracker.sh 의 skip::verdicts 를 재사용한다
#   (사본을 만들지 않는다 — release-ready 와 같은 해석기).
# verified = .specops 직속 YYYYMMDD-* 디렉토리 중 spec·plan·tasks·evidence 4파일 (6회차 평가 '완주' 술어).
#   그 술어는 마지막 3게이트를 보지 않았다 — held 가 그 빈칸이다.
set -uo pipefail

GC_HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=/dev/null
source "$GC_HERE/skip-tracker.sh"
GC_STATE_SH="$GC_HERE/_internal/verification-state.sh"
GC_GATES="security integration performance"
GC_FMT='%-24s %8s %8s %10s %8s %6s %20s %22s %22s\n'

gc::resolve() {  # <arg> → "<label>\t<abs specops root>" · 디렉토리가 아니면 rc=1
  local arg="$1" abs parent
  [ -d "$arg" ] || return 1
  abs=$(cd "$arg" && pwd)
  # basename 검사가 먼저다 — .specops 안에 실수로 생긴 .specops/.specops 가 있으면(이 repo 실재)
  #   자식 검사를 먼저 할 때 빈 중첩 디렉토리를 root 로 잡아 전부 0 이 나온다 (plan-review 1회차 I-1).
  if [ "${abs##*/}" = ".specops" ]; then parent=${abs%/*}; printf '%s\t%s\n' "${parent##*/}" "$abs"; return 0; fi
  if [ -d "$abs/.specops" ]; then printf '%s\t%s\n' "${abs##*/}" "$abs/.specops"; return 0; fi
  printf '%s\t%s\n' "${abs##*/}" "$abs"
}

gc::gate_class() {  # <evidence file> <gate> → P|S|F|M|U
  local file="$1" gate="$2" v
  grep -q "^## /$(skip::header "$gate")" "$file" 2>/dev/null || { echo M; return 0; }
  v=$(skip::verdicts "$file" "$gate" | tail -1)
  case "$v" in PASS) echo P ;; SKIP) echo S ;; FAIL) echo F ;; *) echo U ;; esac
}

gc::verify_verdict() {  # <evidence file> <fid> <abs specops root> → 판정 토큰 또는 빈값
  local file="$1" fid="$2" root="$3"
  if [ -f "$root/$fid/verification-state.json" ] && [ -f "$GC_STATE_SH" ]; then
    (cd "${root%/*}" 2>/dev/null && SPECOPS_ROOT="$root" bash "$GC_STATE_SH" current "$fid" 2>/dev/null)
    return 0
  fi
  [ -f "$file" ] || return 0
  awk '
    /^## \/verify/ {
      if ($0 ~ /SKIP/)      { print "SKIP"; pending=0 }
      else if ($0 ~ /PASS/) { print "PASS"; pending=0 }
      else if ($0 ~ /FAIL/) { print "FAIL"; pending=0 }
      else                  { pending=1 }
      next
    }
    /^## / { pending=0; next }
    pending && /^\*\*결과\*\*:/ {
      if ($0 ~ /SKIP/)      print "SKIP"
      else if ($0 ~ /PASS/) print "PASS"
      else if ($0 ~ /FAIL/) print "FAIL"
      pending=0
    }
  ' "$file"
}

gc::stats() {  # <abs specops root> → 19필드 (계약 §4)
  local root="$1" d fid ev=0 vr=0 vp=0 held=0 all gi ci c g v
  local -a cnt=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
  for d in "$root"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*/; do
    [ -d "$d" ] || continue
    d=${d%/}; fid=${d##*/}
    [ -f "$d/evidence.md" ] || continue
    ev=$((ev+1))
    { [ -f "$d/spec.md" ] && [ -f "$d/plan.md" ] && [ -f "$d/tasks.md" ]; } || continue
    vr=$((vr+1))
    v=$(gc::verify_verdict "$d/evidence.md" "$fid" "$root" | tail -1)
    [ "$v" = PASS ] && vp=$((vp+1))
    all=1; gi=0
    for g in $GC_GATES; do
      c=$(gc::gate_class "$d/evidence.md" "$g")
      case "$c" in P) ci=0 ;; S) ci=1 ;; F) ci=2 ;; M) ci=3; all=0 ;; *) ci=4; all=0 ;; esac
      cnt[$((gi*5+ci))]=$(( cnt[$((gi*5+ci))] + 1 ))
      gi=$((gi+1))
    done
    [ "$all" -eq 1 ] && held=$((held+1))
  done
  echo "$ev $vr $vp $held ${cnt[*]}"
}

gc::rate() {  # <held> <verified> → "N%" 또는 "-"
  [ "$2" -eq 0 ] && { echo "-"; return 0; }
  echo "$(( $1 * 100 / $2 ))%"
}

gc::row() {  # <label> <19필드>
  local label="$1"; shift
  printf "$GC_FMT" "$label" "$1" "$2" "$3" "$4" "$(gc::rate "$4" "$2")" \
    "$5/$6/$7/$8/$9" "${10}/${11}/${12}/${13}/${14}" "${15}/${16}/${17}/${18}/${19}"
}

gc::main() {
  [ "$#" -eq 0 ] && set -- "$(skip::default_root)"
  local nargs=$# arg res label root i
  local -a f sum=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
  printf "$GC_FMT" repo evidence verified verifyPASS held rate \
    'security(P/S/F/M/U)' 'integration(P/S/F/M/U)' 'performance(P/S/F/M/U)'
  echo "# verified=spec·plan·tasks·evidence 4파일(6회차 '완주' 술어) · held=세 게이트 판정 모두 읽힘 · rate=held/verified · M=헤더 없음 · U=헤더 있으나 판정 해석 불가"
  for arg in "$@"; do
    if ! res=$(gc::resolve "$arg"); then
      printf '%-24s 경로 없음 (%s)\n' "${arg##*/}" "$arg"
      continue
    fi
    label=${res%%$'\t'*}; root=${res#*$'\t'}
    read -r -a f <<< "$(gc::stats "$root")"
    gc::row "$label" "${f[@]}"
    i=0
    while [ "$i" -lt 19 ]; do sum[$i]=$(( sum[$i] + f[$i] )); i=$((i+1)); done
  done
  [ "$nargs" -ge 2 ] && gc::row "합계" "${sum[@]}"
  return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  gc::main "$@"
  exit 0
fi
