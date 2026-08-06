#!/usr/bin/env bash
# check-foundation-manifest.sh — foundation 산출물 게이트 (20260806)
# Usage: check-foundation-manifest.sh <FID>
# Exit: 0 = PASS 또는 해당 없음(skip) · 1 = FAIL(미산출·미채움)
#
# 왜 스크립트인가: `verifying-evidence-ko` 는 이 게이트를 **HARD** 로 선언하고, 그 근거로
#   "생산은 planning-ko 산문 지시뿐(강제 evaluator 부재)이라 verify 가 실제 산출물을 확인하지
#    않으면 후속 `/start` 재사용 게이트가 침묵 무발동(no-op) 한다" 고 적어 뒀다.
#   그런데 run-verification·release-ready·DAG 어디에도 구현이 없어서, **침묵 무발동을 막으려는
#   게이트 자체가 침묵 무발동**이었다(실측 20260806). 산문을 실행 가능한 판정으로 옮긴다.
#
# 채움 판정: 구 산문은 `grep -q '<경로>'` **단일 토큰**이라 경로만 채우고 `<설명>`·
#   `<import 예시>`·`<확정된 프레임워크>` 가 전부 남아도 통과했다. placeholder 판정의 SoT 인
#   scan-enrich-placeholders.sh 로 통일한다(HTML 주석 헤더 제외 규칙도 함께 상속).
#
# fail-open: spec.md 부재·§유형 판독 불가 → 0 (무관 FID·초기 상태에 월권 금지).
set -u

FID="${1:?usage: $0 <FID>}"
SPECOPS="${SPECOPS_ROOT:-.specops}"
SPEC="$SPECOPS/$FID/spec.md"
MANIFEST="$SPECOPS/memory/foundation-manifest.md"
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
SCAN="$PLUGIN/scripts/_internal/scan-enrich-placeholders.sh"

# 판정 불가 → skip (fail-open)
[ -f "$SPEC" ] || { echo "FOUNDATION-MANIFEST: SKIP (spec.md 부재)"; exit 0; }

# §유형=foundation 이 아니면 무관
if ! grep -qE '^\*\*§유형\*\*:[[:space:]]*foundation' "$SPEC" 2>/dev/null; then
  echo "FOUNDATION-MANIFEST: SKIP (§유형≠foundation)"
  exit 0
fi

if [ ! -f "$MANIFEST" ]; then
  echo "FOUNDATION-MANIFEST: FAIL — $MANIFEST 부재"
  echo "  foundation lifecycle 은 manifest 산출로 완료된다 (planning-ko 마지막 태스크)."
  echo "  이 파일이 없으면 후속 /start 의 재사용 게이트(decomposing-ko)가 침묵 무발동한다."
  exit 1
fi

# 채움 판정 — placeholder SoT 재사용
if [ -f "$SCAN" ]; then
  if ! scan_out=$(bash "$SCAN" "$MANIFEST" 2>/dev/null); then
    echo "FOUNDATION-MANIFEST: FAIL — 템플릿 placeholder 잔존(미채움)"
    printf '%s\n' "$scan_out" | sed 's/^/  /'
    exit 1
  fi
else
  # 스캐너 부재 시 최소 판정 (구 동작 보존 — fail-open 하지 않는다: 파일 존재는 이미 확인됨)
  if grep -q '<경로>' "$MANIFEST" 2>/dev/null; then
    echo "FOUNDATION-MANIFEST: FAIL — 템플릿 placeholder 잔존(<경로>)"
    exit 1
  fi
fi

echo "FOUNDATION-MANIFEST: PASS"
exit 0
