#!/usr/bin/env bash
# specops-auto-ko verdict-board — FID별 게이트 결과 매트릭스 (읽기전용 관측).
# 사용: bash scripts/verdict-board.sh [.specops 경로]
# skip-tracker.sh source — skip::verdicts(integration/performance) 재활용. verify는 자체.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=/dev/null
source "$HERE/skip-tracker.sh"

vb::verify_verdict() {  # <file>
  local file="$1"
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

vb::symbol() {  # <verdict> → 기호
  case "$1" in
    PASS) printf '✅' ;; SKIP) printf '⏭' ;; FAIL) printf '❌' ;; *) printf '-' ;;
  esac
}

ROOT="${1:-$HERE/../.specops}"

printf '%-30s %-8s %-8s %-8s\n' "FID" "verify" "integ" "perf"

while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  fid=$(basename "$dir")
  case "$fid" in [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*) ;; *) continue ;; esac
  ev="${dir%/}/evidence.md"
  v=$(vb::verify_verdict "$ev" | tail -1)
  i=$(skip::verdicts "$ev" integration | tail -1)
  p=$(skip::verdicts "$ev" performance | tail -1)
  printf '%-30s %-8s %-8s %-8s\n' "${fid:0:28}" "$(vb::symbol "$v")" "$(vb::symbol "$i")" "$(vb::symbol "$p")"
done < <(ls -d "$ROOT"/*/ 2>/dev/null | sort -r)
exit 0
