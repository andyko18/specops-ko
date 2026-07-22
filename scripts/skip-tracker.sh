#!/usr/bin/env bash
# specops-ko SKIP 추적 관측 도구 (읽기 전용)
# 사용: bash scripts/skip-tracker.sh [.specops 경로]
# 소스 가능 — 함수만 정의, main 은 가드. integration/performance/security 게이트 SKIP 비율 집계.
# 환경: SKIP_TRACKER_THRESHOLD (기본 70) — SKIP 비율 advisory 경고 임계
set -uo pipefail

# 게이트 short 이름 → evidence.md 섹션 헤더 토큰 매핑.
#   integration/performance 는 '-test' 접미, security 는 '-review' 접미(헤더 불일치) — 하드코딩 '-test'
#   패턴은 security 를 못 잡았다(버그1: security-review-ko L42 관측 死문). 매핑으로 3게이트 정합.
skip::header() {  # <gate short> → 헤더 토큰
  case "$1" in
    integration) echo integration-test ;;
    performance) echo performance-test ;;
    security)    echo security-review ;;
    *)           echo "${1}-test" ;;   # 미지 게이트 하위호환(구 동작)
  esac
}

skip::verdicts() {  # <file> <gate: integration|performance|security>
  local file="$1" gate="$2"
  [ -f "$file" ] || return 0
  awk -v hdr="^## /$(skip::header "$gate")" '
    $0 ~ hdr {
      if ($0 ~ /SKIP/)      { print "SKIP"; pending=0 }
      else if ($0 ~ /PASS/) { print "PASS"; pending=0 }
      else if ($0 ~ /FAIL/) { print "FAIL"; pending=0 }
      else                  { pending=1 }
      next
    }
    /^## / { pending=0; next }   # 비게이트 섹션 헤더 도달 → pending 리셋 (인접 섹션 오연관 차단 — Phase C Important)
    pending && /^\*\*결과\*\*:/ {
      if ($0 ~ /SKIP/)      print "SKIP"
      else if ($0 ~ /PASS/) print "PASS"
      else if ($0 ~ /FAIL/) print "FAIL"
      pending=0
    }
  ' "$file"
}

skip::cite_status() {  # <file> <gate> → CITED|BARE per SKIP (라인인용 §...L<n> 또는 L<n> 유무)
  local file="$1" gate="$2"
  [ -f "$file" ] || return 0
  awk -v hdr="^## /$(skip::header "$gate")" -v cite='L[0-9]|§[^ ]*[0-9]' '
    $0 ~ hdr {
      if (skipwait) { print "BARE"; skipwait=0 }
      if ($0 ~ /SKIP/) { print ($0 ~ cite) ? "CITED" : "BARE"; pending=0; skipwait=0 }
      else            { pending=1; skipwait=0 }
      next
    }
    /^## / { if (skipwait) { print "BARE"; skipwait=0 } pending=0; next }
    pending && /^\*\*결과\*\*:/ {
      if ($0 ~ /SKIP/) { skipwait=1 } else { pending=0 }
      next
    }
    skipwait && /^\*\*근거\*\*:/ {
      print ($0 ~ cite) ? "CITED" : "BARE"
      skipwait=0; pending=0
    }
    END { if (skipwait) print "BARE" }
  ' "$file"
}

skip::count() {  # <dir> <gate> → "PASS SKIP FAIL"
  local dir="$1" gate="$2" p=0 s=0 f=0 v file
  for file in "$dir"/*/evidence.md; do
    [ -f "$file" ] || continue
    while IFS= read -r v; do
      case "$v" in PASS) p=$((p+1)) ;; SKIP) s=$((s+1)) ;; FAIL) f=$((f+1)) ;; esac
    done < <(skip::verdicts "$file" "$gate")
  done
  echo "$p $s $f"
}

skip::rate() {  # <skip> <total> → 백분율 정수
  local s="$1" total="$2"
  [ "$total" -eq 0 ] && { echo 0; return 0; }
  echo $(( s * 100 / total ))
}

skip::report() {  # <dir>
  local dir="$1" thr="${SKIP_TRACKER_THRESHOLD:-70}" bthr="${SKIP_TRACKER_BARE_THRESHOLD:-0}"
  local any=0 file
  for file in "$dir"/*/evidence.md; do [ -f "$file" ] && { any=1; break; }; done
  [ "$any" -eq 0 ] && { echo "SKIP-TRACKER: evidence 없음 ($dir)"; return 0; }
  local g p s f total rate bare v
  for g in integration performance security; do
    read -r p s f <<EOF
$(skip::count "$dir" "$g")
EOF
    total=$(( p + s + f ))
    rate=$(skip::rate "$s" "$total")
    bare=0
    for file in "$dir"/*/evidence.md; do
      [ -f "$file" ] || continue
      while IFS= read -r v; do [ "$v" = "BARE" ] && bare=$((bare+1)); done < <(skip::cite_status "$file" "$g")
    done
    local warn=""
    [ "$bare" -gt "$bthr" ] && warn="  ⚠️ 근거 없는 SKIP ${bare}건 (>${bthr})"
    echo "${g}: total=${total} PASS=${p} SKIP=${s} FAIL=${f} (SKIP ${rate}% 참고) bare=${bare}${warn}"
  done
  return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  root="${1:-$(cd "$(dirname "$0")/.." && pwd)/.specops}"
  skip::report "$root"
fi
