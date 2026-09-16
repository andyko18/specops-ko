#!/usr/bin/env bash
# check-intent.sh — 기능 단위 intent.md 게이트 (20260917)
# Usage: check-intent.sh <FID>
# Exit: 0 = PASS 또는 해당 없음(skip) · 1 = FAIL(부재·미채움)
#
# 왜 필요한가: Anthropic AI-Native SDLC 의 intent 는 "설계 전에 승인된 요청" 이다.
#   specifying 체크리스트 1.5 가 산문으로 지시하지만, 산문만으로는 빠져도 아무도 모른다
#   (같은 클래스: check-maintain-baseline 도입 전 analyzing 산출물 0개 통과).
#   사용자 승인(대화)은 기계화 불가 — **존재·채움만** 판정한다.
set -u

FID="${1:?usage: $0 <FID>}"
SPECOPS="${SPECOPS_ROOT:-.specops}"
SPEC="$SPECOPS/$FID/spec.md"
INTENT="$SPECOPS/$FID/intent.md"
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
SCAN="$PLUGIN/scripts/_internal/scan-enrich-placeholders.sh"

# 도입 cutoff — 이 날짜 미만으로 시작한 FID 는 면제한다(진행 중 작업 보호).
#   env override 를 두지 않는다: 모델이 스스로 여는 면제 경로는 §auto 자기발급 면제표와 같은 병이다.
CUTOFF=20260918

_d=${FID%%-*}
case "$_d" in
  [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) ;;
  *) echo "INTENT: SKIP (비날짜 FID — fixture)"; exit 0 ;;
esac
[ "$_d" -lt "$CUTOFF" ] && { echo "INTENT: SKIP (도입 전 FID — cutoff $CUTOFF)"; exit 0; }
[ -f "$SPEC" ] || { echo "INTENT: SKIP (spec.md 부재)"; exit 0; }

if [ ! -f "$INTENT" ]; then
  cat <<EOF
INTENT: FAIL — intent.md 부재: $INTENT
  기능 단위 intent(문제·기대 결과·영향 사용자·시스템·제약·열린 질문)는 spec 이전에 승인되는 산출물이다.
  해법: specifying-ko 체크리스트 1.5 를 수행하거나 templates/intent.md 를 복사해 채우세요.
EOF
  exit 1
fi

if [ -f "$SCAN" ]; then
  if ! scan_out=$(bash "$SCAN" "$INTENT" 2>/dev/null); then
    echo "INTENT: FAIL — intent 미채움(템플릿 placeholder 잔존)"
    printf '%s\n' "$scan_out" | sed 's/^/  /'
    exit 1
  fi
fi

grep -q 'intent\.md' "$SPEC" 2>/dev/null \
  || echo "INTENT: WARN spec.md 가 intent.md 를 참조하지 않음 — spec §1 Intent 줄 확인" >&2

if [ -f "$SPECOPS/memory/intent.md" ] && grep -q '트리거' "$SPECOPS/memory/intent.md" 2>/dev/null; then
  echo "INTENT: WARN 구 프로세스 설계서 이름 — git mv $SPECOPS/memory/intent.md $SPECOPS/memory/process-design.md 권장(자동 변경 안 함)" >&2
fi

echo "INTENT: PASS"
exit 0
