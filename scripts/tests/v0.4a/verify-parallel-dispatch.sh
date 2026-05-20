#!/usr/bin/env bash
# v0.4a W7 — 병렬 dispatch 실측 검증 helper
# Usage: verify-parallel-dispatch.sh <FID>
# 검증 항목 (W7 PASS 기준):
#   1. tasks.md DAG에 절대 leaf ≥ 2 (depends_on=[] task 2개+)
#   2. dispatch-log.md에 "phase=parallel" 또는 "batch_size=" 기록 1건+
#   3. .specops/<FID>/dispatch/ 디렉터리에 leaf별 context.md 파일 ≥ 2
#   4. friction-log false positive ≤ 4 (v0.4a PASS 기준 ≥80% 감소)
#
# Exit: 0 = W7 PASS / 1 = 미달 (stderr에 누락 항목)
# 참조: 마스터 plan §6 v0.4a W7 PASS 기준

set -u

if [ "$#" -ne 1 ]; then
  echo "usage: verify-parallel-dispatch.sh <FID>" >&2
  exit 2
fi

FID=$1
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
FID_DIR=".specops/$FID"

if [ ! -d "$FID_DIR" ]; then
  echo "error: FID 디렉터리 없음 — $FID_DIR" >&2
  exit 2
fi

PASS_COUNT=0
FAIL_COUNT=0

check() {
  local label="$1" condition="$2" detail="$3"
  if eval "$condition"; then
    PASS_COUNT=$((PASS_COUNT+1))
    echo "✅ $label"
  else
    FAIL_COUNT=$((FAIL_COUNT+1))
    echo "❌ $label" >&2
    [ -n "$detail" ] && echo "   $detail" >&2
  fi
}

# 검증 1: 절대 leaf ≥ 2
echo "=== 검증 1: tasks.md DAG 절대 leaf ≥ 2 ==="
# shellcheck disable=SC1091
source "$PLUGIN/scripts/dag/parse-dag.sh"
yaml=$(dag::extract_yaml "$FID_DIR/tasks.md" 2>/dev/null || echo "")
leaves=$(printf '%s' "$yaml" | dag::list_leaves 2>/dev/null | wc -l | tr -d ' ')
check "tasks.md 절대 leaf 수: $leaves (≥2 필요)" "[ '$leaves' -ge 2 ]" "DAG가 chain 구조면 leaf 1개만 — 의도적으로 disjoint outputs 3개 leaf 설계 필요"

# 검증 2: dispatch-log에 phase=parallel 또는 batch_size=
echo ""
echo "=== 검증 2: dispatch-log.md 병렬 dispatch 증거 ==="
DISPATCH="$FID_DIR/dispatch-log.md"
if [ -f "$DISPATCH" ]; then
  parallel_marker=$(grep -E "(phase=parallel|batch_size=[0-9]+|병렬 dispatch)" "$DISPATCH" 2>/dev/null | wc -l | tr -d ' ')
  check "dispatch-log 병렬 마커 수: $parallel_marker (≥1 필요)" "[ '$parallel_marker' -ge 1 ]" "F-12 집약 (sequential 1 dispatch) 도 v0.4a 병렬 미검증. dispatching-parallel-agents-ko 호출 흔적 필요"
else
  check "dispatch-log.md 존재" "false" "$DISPATCH 없음"
fi

# 검증 3: .specops/<FID>/dispatch/ leaf별 context.md ≥ 2
echo ""
echo "=== 검증 3: dispatch 디렉터리 leaf별 context.md ≥ 2 ==="
DISPATCH_DIR="$FID_DIR/dispatch"
if [ -d "$DISPATCH_DIR" ]; then
  context_count=$(ls "$DISPATCH_DIR"/*-context.md 2>/dev/null | wc -l | tr -d ' ')
  check "dispatch/ context.md 파일 수: $context_count (≥2 필요)" "[ '$context_count' -ge 2 ]" "AC injection 5 컨텍스트 파일이 leaf별로 작성되어야 함 (W2 표준)"

  # 각 context 파일 5 컨텍스트 검증
  if [ "$context_count" -ge 2 ]; then
    valid_ctx=0
    for ctx in "$DISPATCH_DIR"/*-context.md; do
      if bash "$PLUGIN/scripts/dag/validate-context.sh" "$ctx" 2>/dev/null; then
        valid_ctx=$((valid_ctx+1))
      fi
    done
    check "context 파일 5 컨텍스트 모두 충족: $valid_ctx/$context_count" "[ '$valid_ctx' -eq '$context_count' ]" "validate-context.sh 통과 안 한 context 있음 — leaf NEEDS_CONTEXT 위험"
  fi
else
  check "dispatch/ 디렉터리 존재" "false" "$DISPATCH_DIR 없음 — DAG-AWARE PARALLEL 분기 미트리거"
fi

# 검증 4: friction-log false positive ≤ 4
echo ""
echo "=== 검증 4: friction-log false positive (R-3 + R-4 + R-5) ≤ 4 ==="
FLOG="$FID_DIR/friction-log.jsonl"
if [ -f "$FLOG" ]; then
  fp_count=$(jq -s '[.[] | select(.rule_id == "R-3" or .rule_id == "R-4" or .rule_id == "R-5")] | length' "$FLOG" 2>/dev/null || echo "0")
  check "false positive 후보 (R-3+R-4+R-5): $fp_count (≤4 필요, v0.4a PASS 기준 ≥80% 감소)" "[ '$fp_count' -le 4 ]" "v0.4-pre 매처 정정 후 회귀 — 추가 매처 보강 필요"
else
  check "friction-log.jsonl 존재 여부" "true" "파일 없음 = 매칭 0건 (이상적)"
fi

# 종합 판정
echo ""
echo "==== Results: PASS=$PASS_COUNT FAIL=$FAIL_COUNT ===="
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "✅ v0.4a W7 PASS 기준 모두 충족 — DAG 자동 라우팅 + AC injection 실측 검증 완료"
  exit 0
else
  echo "❌ v0.4a W7 PASS 기준 미달 ($FAIL_COUNT 항목)"
  exit 1
fi
