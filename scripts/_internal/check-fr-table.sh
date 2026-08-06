#!/usr/bin/env bash
# check-fr-table.sh — requirements.md FR 표의 **실 FR** 판정 (20260806)
# Usage: check-fr-table.sh [requirements 경로]
# Exit: 0 = 실 FR ≥1 (stdout 에 개수·placeholder 경고) · 1 = 실 FR 0건 · 2 = 파일 부재
#
# 왜 필요한가: `/start-all` Phase 0 는 `grep -E '^\| FR-[0-9]+ \|'` 로 FR 을 기계 파싱하고
#   **"FR 행 0건이면 중단"** 만 검사한다. 그런데 `templates/requirements.md` 는
#   `| FR-1 | <한 줄> | M1 | must | (TBD) |` placeholder 행 3건을 담고 배포되고,
#   init 의 `_seed_fr_row` 는 PRD 마일스톤이 비면 그 행을 그대로 둔다.
#   → 사용자가 FR 을 하나도 안 썼는데 `/start-all` 이 **3개 기능을 구현하겠다며 진입**하고,
#     Phase 1 이 specifying-ko 에 넘기는 "FR 원문" 이 `<한 줄>` 이 된다.
#   기존 가드는 **비어 있음** 은 잡지만 **의미 없음** 은 못 잡는다 —
#   골격 예시가 실데이터로 읽히는 동일 클래스(decisions·screens-overview·api-spec).
set -u

REQ="${1:-}"
if [ -z "$REQ" ]; then
  # /start-all Phase 0 과 동일 탐색 순서
  for c in ".specops/memory/requirements.md" "requirements.md"; do
    [ -f "$c" ] && { REQ="$c"; break; }
  done
fi
[ -n "$REQ" ] && [ -f "$REQ" ] || {
  echo "FR-TABLE: MISSING (requirements.md 부재)"
  exit 2
}

real=0; ph=0; ph_ids=""
while IFS= read -r line; do
  id=$(printf '%s' "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')
  desc=$(printf '%s' "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}')
  # 실 FR 로 인정하지 않는 설명: 빈칸 · <...> placeholder · 무정보 토큰
  if [ -z "$desc" ] \
     || printf '%s' "$desc" | grep -qE '^<[^>]*>$' \
     || printf '%s' "$desc" | grep -qE '^(TBD|tbd|N/A|n/a|-|—|\(미정\)|미정|미확정|\(TBD\))$'; then
    ph=$((ph + 1)); ph_ids="${ph_ids}${ph_ids:+, }${id}"
  else
    real=$((real + 1))
  fi
done <<EOF
$(grep -E '^\|[[:space:]]*FR-[0-9]+[[:space:]]*\|' "$REQ" 2>/dev/null)
EOF

if [ "$real" -eq 0 ]; then
  cat <<EOF
FR-TABLE: FAIL — 실 FR 0건 (placeholder ${ph}건: ${ph_ids:-none})
  $REQ 의 FR 행이 전부 미작성 상태입니다 — 골격 그대로면 /start-all 이
  존재하지 않는 기능을 구현하려 시도합니다.
  해법: requirements.md FR 표에 실제 기능 설명을 작성한 뒤 재실행하세요.
EOF
  exit 1
fi

echo "FR-TABLE: PASS — 실 FR ${real}건"
[ "$ph" -gt 0 ] && echo "  경고: placeholder ${ph}건 (${ph_ids}) — batch 대상에서 제외하거나 채우세요"
exit 0
