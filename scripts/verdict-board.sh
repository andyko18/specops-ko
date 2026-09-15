#!/usr/bin/env bash
# specops-ko verdict-board — FID별 게이트 결과 매트릭스 (읽기전용 관측).
# 사용: bash scripts/verdict-board.sh [.specops 경로]   (인자 없음 → 호출 위치 git 루트의 .specops)
# gate-coverage.sh source — gc::gate_class(skip::verdicts 경유)·gc::verify_verdict 재활용. 판정 해석 사본 없음.
# 게이트 칸: ✅ PASS · ⏭ SKIP · ❌ FAIL · · 헤더 없음(무기록) · ? 헤더 있으나 판정 해석 불가 · - evidence.md 없음
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=/dev/null
source "$HERE/gate-coverage.sh"

vb::symbol() {  # <verify verdict> → 기호
  case "$1" in
    PASS) printf '✅' ;;
    PARTIAL) printf '🟡' ;;
    FAIL) printf '❌' ;;
    STALE) printf '⚠️' ;;
    WAIVED) printf '◻' ;;
    SKIP) printf '⏭' ;;
    NOT_RUN|"") printf '-' ;;
    *) printf '?' ;;
  esac
}

vb::gate_cell() {  # <evidence file> <gate> → 기호
  [ -f "$1" ] || { printf -- '-'; return 0; }
  case "$(gc::gate_class "$1" "$2")" in
    P) printf '✅' ;; S) printf '⏭' ;; F) printf '❌' ;; M) printf '·' ;; *) printf '?' ;;
  esac
}

ROOT="${1:-$(skip::default_root)}"
[ -d "$ROOT" ] && ROOT=$(cd "$ROOT" && pwd)

printf '%-30s %-8s %-8s %-8s %-8s\n' "FID" "verify" "sec" "integ" "perf"

while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  fid=$(basename "$dir")
  case "$fid" in [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*) ;; *) continue ;; esac
  ev="${dir%/}/evidence.md"
  v=$(gc::verify_verdict "$ev" "$fid" "$ROOT" | tail -1)
  printf '%-30s %-8s %-8s %-8s %-8s\n' "${fid:0:28}" "$(vb::symbol "$v")" \
    "$(vb::gate_cell "$ev" security)" "$(vb::gate_cell "$ev" integration)" "$(vb::gate_cell "$ev" performance)"
done < <(ls -d "$ROOT"/*/ 2>/dev/null | sort -r)
exit 0
