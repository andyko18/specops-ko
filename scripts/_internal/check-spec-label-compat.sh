#!/usr/bin/env bash
# check-spec-label-compat.sh — §유형=foundation 과 §batch 동시 금지 (20260812)
# Usage: check-spec-label-compat.sh <FID|spec.md경로>
# Exit: 0 = PASS | SKIP(spec 부재) · 1 = FAIL (hybrid)
#
# 왜: specifying-ko 생산표는 foundation↔batch entry 배타인데, 모델이
#   **§유형**: foundation + **§batch**: … 를 겹치면 (Argus FR-28 실측)
#   batch halt · manifest verify · reuse 계약이 충돌한다.
set -u

ARG="${1:?usage: $0 <FID|spec.md경로>}"
SPECOPS="${SPECOPS_ROOT:-.specops}"

if [ -f "$ARG" ]; then
  SPEC="$ARG"
elif [ -f "$SPECOPS/$ARG/spec.md" ]; then
  SPEC="$SPECOPS/$ARG/spec.md"
else
  echo "SPEC-LABEL: SKIP (spec 부재)"
  exit 0
fi

has_foundation=0
has_batch=0
grep -qE '^\*\*§유형\*\*:[[:space:]]*foundation([[:space:]]|$)' "$SPEC" 2>/dev/null && has_foundation=1
grep -qE '^\*\*§batch\*\*:' "$SPEC" 2>/dev/null && has_batch=1

if [ "$has_foundation" -eq 1 ] && [ "$has_batch" -eq 1 ]; then
  echo "SPEC-LABEL: FAIL — §유형=foundation 과 §batch 동시 (hybrid 금지)"
  echo "  공통부는 /start-foundation (§유형=foundation, §batch 없음)."
  echo "  기능 FR 은 /start-all batch (§유형=신규 + §batch). 둘을 한 spec 에 섞지 마세요."
  exit 1
fi

echo "SPEC-LABEL: PASS"
exit 0
