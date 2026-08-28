#!/usr/bin/env bash
# record-batch-gate.sh — batch 레벨 게이트 verdict 를 전 IMPL_DONE FID 로 전파 (20260806)
# Usage: record-batch-gate.sh <batch-dir> <security|integration|performance> <PASS|SKIP> [SKIP 근거]
# Exit: 0 = 기록 완료 · 1 = 사용 오류·전파 대상 없음
#
# 왜 필요한가: `/start-all` Phase 3 완료 Step A/B/C 는 batch 전체를 **1회** 실행하고,
#   각 skill 은 호출된 **대표 FID 1곳**의 evidence.md 에만 verdict 를 남긴다. 그런데
#   RELEASE_READY(`gh pr create` hard gate)는 ACTIVE batch 의 **전 IMPL_DONE FID** 각각에
#   security/integration/performance = PASS|SKIP 을 요구한다 — 하나라도 MISSING 이면
#   NOT_READY → hard deny(인라인 BYPASS 불가). 정직한 /start-all 완주가 구조적으로
#   batch PR 에서 막히는 설계 간 충돌(20260806 실측 — RR 게이트 v1.60 도입 이후).
#
# 규칙:
#   - PASS·SKIP 만 전파. **FAIL 은 거부** — FAIL 은 systematic-debugging 후 재실행이 정도이지
#     전 FID 로 낙인 찍는 값이 아니다.
#   - SKIP 은 근거 필수 (skip-tracker CITED 규약 — 무근거 SKIP 은 관측 도구가 BARE 로 집계).
#   - 멱등: 해당 게이트 섹션이 이미 있는 FID 는 건드리지 않는다(대표 FID 원본 보존 포함).
#   - 섹션 포맷은 skip::verdicts 파서 계약(`## /<헤더> <VERDICT>` + `**결과**:` 줄)을 따른다.
set -u

BATCH_DIR="${1:?usage: $0 <batch-dir> <gate> <PASS|SKIP> [근거]}"
GATE="${2:?usage: $0 <batch-dir> <gate> <PASS|SKIP> [근거]}"
VERDICT="${3:?usage: $0 <batch-dir> <gate> <PASS|SKIP> [근거]}"
REASON="${4:-}"

case "$GATE" in
  security)    HDR="security-review" ;;
  integration) HDR="integration-test" ;;
  performance) HDR="performance-test" ;;
  *) echo "record-batch-gate: 미지 게이트 '$GATE' (security|integration|performance)" >&2; exit 1 ;;
esac
case "$VERDICT" in
  PASS) ;;
  SKIP)
    [ -n "$REASON" ] || {
      echo "record-batch-gate: SKIP 은 근거 필수 (skip-tracker CITED 규약)" >&2; exit 1
    } ;;
  FAIL)
    echo "record-batch-gate: FAIL 은 전파 대상이 아니다 — systematic-debugging 후 재실행" >&2
    exit 1 ;;
  *) echo "record-batch-gate: 미지 verdict '$VERDICT' (PASS|SKIP)" >&2; exit 1 ;;
esac

QUEUE="$BATCH_DIR/queue.md"
[ -f "$QUEUE" ] || { echo "record-batch-gate: queue.md 부재 ($BATCH_DIR)" >&2; exit 1; }

SPECOPS=$(dirname "$BATCH_DIR")
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/queue-lib.sh"

# Status 정규화 (20260828-queue-label-drift) — 모델이 `**IMPL_DONE**` 로 손편집하면
#   종전 `|IMPL_DONE|` 리터럴 매칭이 전건 불일치해 **대상 0건**이 됐다.
fids=$(awk -F'|' "$QUEUE_AWK_QNORM"'
{
  st = ""
  for (i = NF; i >= 1; i--) { if (qnorm($i) != "") { st = qnorm($i); break } }
  if (st ~ /^IMPL_DONE$/) print qnorm($3)
}' "$QUEUE" | grep -E '^[0-9]{8}-[a-z0-9-]+$' || true)
[ -n "$fids" ] || { echo "record-batch-gate: IMPL_DONE FID 0건 ($QUEUE)" >&2; exit 1; }

wrote=0
for fid in $fids; do
  ev="$SPECOPS/$fid/evidence.md"
  [ -f "$ev" ] || { echo "  WARN: $fid evidence.md 부재 — skip" >&2; continue; }
  # 멱등 — 이미 그 게이트 섹션이 있으면(대표 FID 포함) 보존
  if grep -q "^## /$HDR" "$ev" 2>/dev/null; then
    continue
  fi
  {
    echo ""
    echo "## /$HDR $VERDICT"
    echo "**결과**: $VERDICT"
    [ -n "$REASON" ] && echo "**근거**: $REASON"
    echo "**출처**: batch $(basename "$BATCH_DIR") Step 게이트 1회 실행 — record-batch-gate.sh 전파"
  } >> "$ev"
  wrote=$((wrote + 1))
done

echo "BATCH-GATE: $GATE $VERDICT → ${wrote}개 FID 전파 (기존 기록 보존)"
exit 0
