#!/usr/bin/env bash
# specops-auto-ko SKIP 추적 관측 도구 (읽기 전용)
# 사용: bash scripts/skip-tracker.sh [.specops 경로]
# 소스 가능 — 함수만 정의, main 은 가드. integration/performance 게이트 SKIP 비율 집계.
# 환경: SKIP_TRACKER_THRESHOLD (기본 70) — SKIP 비율 advisory 경고 임계
set -uo pipefail

skip::verdicts() {  # <file> <gate: integration|performance>
  local file="$1" gate="$2"
  [ -f "$file" ] || return 0
  awk -v hdr="^## /${gate}-test" '
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
  local dir="$1" thr="${SKIP_TRACKER_THRESHOLD:-70}"
  local any=0 file
  for file in "$dir"/*/evidence.md; do [ -f "$file" ] && { any=1; break; }; done
  [ "$any" -eq 0 ] && { echo "SKIP-TRACKER: evidence 없음 ($dir)"; return 0; }
  local g p s f total rate
  for g in integration performance; do
    read -r p s f <<EOF
$(skip::count "$dir" "$g")
EOF
    total=$(( p + s + f ))
    rate=$(skip::rate "$s" "$total")
    local warn=""
    [ "$total" -gt 0 ] && [ "$rate" -gt "$thr" ] && warn="  ⚠️ 형식화 의심 (>${thr}%)"
    echo "${g}: total=${total} PASS=${p} SKIP=${s} FAIL=${f} (SKIP ${rate}%)${warn}"
  done
  return 0
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  root="${1:-$(cd "$(dirname "$0")/.." && pwd)/.specops}"
  skip::report "$root"
fi
