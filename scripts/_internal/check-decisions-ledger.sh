#!/usr/bin/env bash
# check-decisions-ledger.sh — 결정 원장의 "확정값" 기계 판정 (20260806)
#
# Usage:
#   check-decisions-ledger.sh <주제 regex>   # exit 0 = 확정됨 · 1 = 미확정
#   check-decisions-ledger.sh --list         # 확정된 주제만 줄단위 출력
#
# 왜 필요한가: `decisions.md` 소비 규칙(HARD)은 "확정값이 있는 주제는 BLOCKING 재질문 금지"
#   인데 판정이 모델 눈대중이었다. 그런데 `/init-project` Phase 10 이 만드는 **골격에 예시
#   행이 들어 있다** — `| D-001 | (예시) UI 유무 | 있음 | init Phase11.5 | YYYY-MM-DD |`.
#   빈 원장이 "행이 있는 원장" 처럼 보여서, foundation 의 기술스택 BLOCKING 면제가
#   근거 없이 열릴 수 있다(재질문 금지 → 미확정 스택으로 plan 진입).
#   소비처가 6곳(clarifying·specifying·start-all(-auto)·start-foundation·init-project)이라
#   판정을 한곳에 모은다.
#
# 확정으로 인정하지 않는 값:
#   - 주제가 `(예시)` 로 시작 (템플릿 골격 행)
#   - 확정값이 빈칸 · `<...>` placeholder · TBD/미정/해당없음 류 무정보 토큰
set -u

SPECOPS="${SPECOPS_ROOT:-.specops}"
LEDGER="$SPECOPS/memory/decisions.md"

_rows() {
  # 표 본문만 — 헤더·구분선·fence 주석 제외
  [ -f "$LEDGER" ] || return 0
  awk -F'|' '
    /^\|/ {
      # 헤더/구분선 제외
      if ($2 ~ /DECISION-ID/) next
      if ($2 ~ /^[[:space:]]*-+[[:space:]]*$/) next
      if (NF < 4) next
      topic = $3; value = $4
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", topic)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (topic == "" ) next
      # 템플릿 예시 행 — 실결정 아님
      if (topic ~ /^\(예시\)/) next
      # 무정보·미채움 확정값
      if (value == "") next
      if (value ~ /^<[^>]*>$/) next
      if (value ~ /^(TBD|tbd|N\/A|n\/a|-|—|\(미정\)|미정|미확정|해당없음|해당 없음|\?\?\?)$/) next
      print topic
    }
  ' "$LEDGER"
}

if [ "${1:-}" = "--list" ]; then
  _rows
  exit 0
fi

TOPIC="${1:?usage: $0 <주제 regex> | --list}"
if _rows | grep -qE "$TOPIC"; then
  echo "DECISIONS: RESOLVED — $TOPIC"
  exit 0
fi
echo "DECISIONS: UNRESOLVED — $TOPIC (확정 행 없음·예시 행·무정보 값)"
exit 1
