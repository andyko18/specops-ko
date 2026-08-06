#!/usr/bin/env bash
# check-stack-decided.sh — foundation 기술스택 확정 증거 게이트 (20260806, clarify 층 봉합)
# Usage: check-stack-decided.sh <FID>
# Exit: 0 = PASS 또는 해당 없음(skip) · 1 = FAIL(스택 결정 증거 전무)
#
# 배경: clarifying-ko 는 "§유형=foundation 이고 architecture 문서에 placeholder 가 있으면
#   기술 프레임워크 확정을 BLOCKING 으로 강제, RESOLVED 전 planning 진입 차단" 을 선언한다.
#   판정기(check-decisions-ledger.sh)를 만들어 눈대중은 없앴지만 **호출은 산문 의무**로 남았다 —
#   clarify 단계엔 스크립트가 반드시 지나는 관문이 없기 때문(specify→clarify→plan 모두 대화).
#   그래서 결정의 **증거**를 다음 하드 관문(emit-context = 구현 직전)에서 검사한다.
#
# 증거로 인정하는 것 (둘 중 하나):
#   ① `.specops/memory/decisions.md` 에 스택 확정 행 — clarifying HARD 규약이
#      "RESOLVED 된 아키텍처·스택 결정은 decisions.md 에 행 upsert" 를 요구하므로 이게 정규 경로.
#   ② `.specops/<FID>/clarifications.md` 에 스택 관련 **RESOLVED** 기록 —
#      원장 upsert 를 빠뜨린 경우의 구제(경고 출력). `status: ASSUMED` 는 불인정(가정은 결정이 아님).
#
# 발동 조건(전부 충족): §유형=foundation · architecture 문서 존재 · 그 문서에 raw placeholder 잔존.
#   placeholder 가 없으면 스택은 이미 문서로 확정된 것이므로 물을 게 없다.
# fail-open: spec.md 부재 등 판정 불가.
set -u

FID="${1:?usage: $0 <FID>}"
SPECOPS="${SPECOPS_ROOT:-.specops}"
SPEC="$SPECOPS/$FID/spec.md"
CLARIF="$SPECOPS/$FID/clarifications.md"
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
SCAN="$PLUGIN/scripts/_internal/scan-enrich-placeholders.sh"
LEDGER_SH="$PLUGIN/scripts/_internal/check-decisions-ledger.sh"

[ -f "$SPEC" ] || { echo "STACK-DECIDED: SKIP (spec.md 부재)"; exit 0; }

grep -qE '^\*\*§유형\*\*:[[:space:]]*foundation' "$SPEC" 2>/dev/null || {
  echo "STACK-DECIDED: SKIP (§유형≠foundation)"; exit 0
}

# architecture 문서에 미해소 placeholder 가 있는가
arch_docs=""
for d in "$SPECOPS/memory/frontend-architecture.md" "$SPECOPS/memory/backend-architecture.md"; do
  [ -f "$d" ] && arch_docs="${arch_docs} $d"
done
[ -n "$arch_docs" ] || { echo "STACK-DECIDED: SKIP (architecture 문서 부재)"; exit 0; }

has_ph=1
if [ -f "$SCAN" ]; then
  # shellcheck disable=SC2086
  bash "$SCAN" $arch_docs >/dev/null 2>&1 && has_ph=0
else
  # shellcheck disable=SC2086
  grep -qE '<[^>]{1,40}>' $arch_docs 2>/dev/null || has_ph=0
fi
[ "$has_ph" -eq 1 ] || { echo "STACK-DECIDED: SKIP (architecture placeholder 없음 — 이미 확정)"; exit 0; }

# ① 원장 — 정규 경로
if [ -f "$LEDGER_SH" ] \
   && SPECOPS_ROOT="$SPECOPS" bash "$LEDGER_SH" '스택|프레임워크|프론트|백엔드' >/dev/null 2>&1; then
  echo "STACK-DECIDED: PASS (decisions.md 확정 행)"
  exit 0
fi

# ② clarifications.md 의 스택 RESOLVED — upsert 누락 구제(경고)
if [ -f "$CLARIF" ] && awk '
    /^##/ { blk = $0; st = "" }
    /^[[:space:]]*status:/ { st = $0 }
    { if (blk ~ /스택|프레임워크|framework|아키텍처/ && st ~ /RESOLVED/) { found = 1 } }
    END { exit(found ? 0 : 1) }
  ' "$CLARIF"; then
  echo "STACK-DECIDED: PASS (clarifications.md RESOLVED)"
  echo "  WARN: decisions.md 원장 upsert 누락 — clarifying-ko HARD 규약상 RESOLVED 결정은" >&2
  echo "        .specops/memory/decisions.md 에 행 upsert 해야 후속 FR 이 재질문하지 않는다." >&2
  exit 0
fi

cat <<EOF
STACK-DECIDED: FAIL — foundation 인데 기술스택 확정 증거가 없습니다.
  architecture 문서에 미해소 placeholder 가 남아 있고,
  decisions.md 에도 clarifications.md 에도 RESOLVED 스택 결정이 없습니다.
  (status: ASSUMED 는 결정이 아니므로 인정되지 않습니다.)

  해법: clarifying-ko BLOCKING 으로 기술 프레임워크를 확정하고
        .specops/memory/decisions.md 에 행을 upsert 하세요.
        확인: bash scripts/_internal/check-decisions-ledger.sh --list
EOF
exit 1
