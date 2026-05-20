#!/usr/bin/env bash
# v0.4-pre 측정 helper — friction-log 1개 또는 2개 (정정 전후) 비교
# Usage:
#   scripts/tests/v0.4-pre/measure-false-positives.sh <new-friction-log.jsonl> [baseline-friction-log.jsonl]
#
# 단일 인자: 해당 jsonl을 rule별로 카운트
# 두 인자: baseline 대비 new의 변화 (정정 효과 측정)
#
# 출력: rule별 카운트 + R-3/R-4 (false positive 후보) vs R-1/R-2/R-5 (true positive) 분류
#
# v0.4-pre 목표: R-3 + R-4 매칭이 ≤ 4건 (≥80% 감소, baseline 22건 → ≤4건)
# 참조: docs/case-studies/2026-04-26-slug-cli-dogfood-friction-analysis.md §7

set -u

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 <new-jsonl> [baseline-jsonl]" >&2
  exit 2
fi

NEW="$1"
BASELINE="${2:-}"

[ -f "$NEW" ] || { echo "ERROR: '$NEW' 파일 없음" >&2; exit 1; }

count_by_rule() {
  local file="$1"
  jq -s 'group_by(.rule_id) | map({rule_id: .[0].rule_id, count: length}) | from_entries | with_entries(.value = .value)' "$file" 2>/dev/null \
    || echo "{}"
}

count_total() {
  local file="$1"
  wc -l < "$file" | tr -d ' '
}

count_rule() {
  local file="$1" rule="$2"
  jq -s --arg r "$rule" 'map(select(.rule_id == $r)) | length' "$file" 2>/dev/null
}

print_summary() {
  local label="$1" file="$2"
  local total r1 r2 r3 r4 r5
  total=$(count_total "$file")
  r1=$(count_rule "$file" R-1)
  r2=$(count_rule "$file" R-2)
  r3=$(count_rule "$file" R-3)
  r4=$(count_rule "$file" R-4)
  r5=$(count_rule "$file" R-5)
  local fp=$((r3 + r4))
  local tp=$((r1 + r2 + r5))
  echo ""
  echo "=== $label ==="
  echo "총 매칭: $total"
  echo "  R-1 (commit 전 verify 부재):    $r1  (true positive 후보)"
  echo "  R-2 (PR 전 verify 부재):       $r2  (true positive 후보)"
  echo "  R-3 (Skill 호출 선언 부재):    $r3  (false positive 후보 — v0.4-pre W1 정정 대상)"
  echo "  R-4 (assertion + runner 부재): $r4  (false positive 후보 — v0.4-pre W2 정정 대상)"
  echo "  R-5 (Advisor 협의 미충족):     $r5  (true positive 후보)"
  echo "  -------------------------"
  echo "  False positive 후보 합계 (R-3+R-4): $fp"
  echo "  True positive 후보 합계 (R-1+R-2+R-5): $tp"
}

print_summary "NEW: $NEW" "$NEW"

if [ -n "$BASELINE" ] && [ -f "$BASELINE" ]; then
  print_summary "BASELINE: $BASELINE" "$BASELINE"

  # 비교
  base_fp=$(($(count_rule "$BASELINE" R-3) + $(count_rule "$BASELINE" R-4)))
  new_fp=$(($(count_rule "$NEW" R-3) + $(count_rule "$NEW" R-4)))
  if [ "$base_fp" -gt 0 ]; then
    reduction=$(( (base_fp - new_fp) * 100 / base_fp ))
    echo ""
    echo "=== 정정 효과 ==="
    echo "Baseline FP: $base_fp"
    echo "New FP:      $new_fp"
    echo "감소율:      ${reduction}%"
    if [ "$reduction" -ge 80 ]; then
      echo "✅ v0.4-pre PASS 기준 (≥80% 감소) 충족"
    else
      echo "⚠️  v0.4-pre PASS 기준 (≥80% 감소) 미달 — 추가 매처 보강 검토"
    fi
  else
    echo ""
    echo "Baseline FP=0 — 비교 의미 없음"
  fi
fi
