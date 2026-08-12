#!/usr/bin/env bash
# check-fr-table.sh — requirements.md FR 표의 **실 FR** 판정 + batch 분류 (20260806 / 시드 SKIP 20260812)
# Usage:
#   check-fr-table.sh [requirements 경로]           # 인간 요약 (현행)
#   check-fr-table.sh --classify [requirements 경로] # 기계 레코드 (ELIGIBLE|SKIP|SUMMARY)
# Exit: 0 = 실 FR ≥1 · 1 = 실 FR 0건 · 2 = 파일 부재
#
# 왜 필요한가: `/start-all` Phase 0 는 `grep -E '^\| FR-[0-9]+ \|'` 로 FR 을 기계 파싱하고
#   **"FR 행 0건이면 중단"** 만 검사한다. 그런데 `templates/requirements.md` 는
#   `| FR-1 | <한 줄> | M1 | must | (TBD) |` placeholder 행 3건을 담고 배포되고,
#   init 의 `_seed_fr_row` 는 PRD 마일스톤이 비면 그 행을 그대로 둔다.
#   → 사용자가 FR 을 하나도 안 썼는데 `/start-all` 이 **3개 기능을 구현하겠다며 진입**하고,
#     Phase 1 이 specifying-ko 에 넘기는 "FR 원문" 이 `<한 줄>` 이 된다.
#
# 시드 SKIP (20260812): init 가 FR-1~3 을 M1~M3 시드로 넣고 세부 FR-4+ 를 붙인 뒤에도
#   시드 행이 실 FR 로 남아 batch PENDING 에 들어가면 이중 구현된다(attendance·Argus 실측).
#   문서에 시드 마커가 있고 같은 마일스톤에 비시드 실 FR(≥FR-4) 이 있으면 FR-1|2|3 만 SKIP.
#
# 공통부 SKIP (20260812): 설명 선두 [공통] 또는 <!-- foundation-fr: FR-N,... --> 목록에
#   있으면 SKIP|…|foundation-scope — /start-all 이 공통 FR 을 PENDING 에 넣지 않는다(선택 A).
#   bash 3.2 호환 (연관 배열 미사용 — macOS /bin/bash).
set -u

CLASSIFY=0
REQ=""
for arg in "$@"; do
  case "$arg" in
    --classify) CLASSIFY=1 ;;
    -*) echo "FR-TABLE: unknown option: $arg" >&2; exit 2 ;;
    *) REQ="$arg" ;;
  esac
done

if [ -z "$REQ" ]; then
  for c in ".specops/memory/requirements.md" "requirements.md"; do
    [ -f "$c" ] && { REQ="$c"; break; }
  done
fi
[ -n "$REQ" ] && [ -f "$REQ" ] || {
  echo "FR-TABLE: MISSING (requirements.md 부재)"
  exit 2
}

_is_placeholder_desc() {
  local desc="$1"
  [ -z "$desc" ] && return 0
  printf '%s' "$desc" | grep -qE '^<[^>]*>$' && return 0
  printf '%s' "$desc" | grep -qE '^(TBD|tbd|N/A|n/a|-|—|\(미정\)|미정|미확정|\(TBD\))$' && return 0
  return 1
}

_is_seed_id() {
  case "$1" in FR-1|FR-2|FR-3) return 0 ;; *) return 1 ;; esac
}

_has_seed_marker() {
  grep -qE '<!--[[:space:]]*seed-fr:[[:space:]]*FR-1[[:space:]]*,[[:space:]]*FR-2[[:space:]]*,[[:space:]]*FR-3[[:space:]]*-->' "$REQ" 2>/dev/null && return 0
  grep -q '마일스톤 시드' "$REQ" 2>/dev/null && return 0
  grep -qE 'PRD §4 마일스톤' "$REQ" 2>/dev/null && grep -q '시드' "$REQ" 2>/dev/null && return 0
  return 1
}

_has_nonseed_sibling() {
  local ms="$1"
  [ -n "$nonseed_ms_list" ] || return 1
  printf '%s\n' "$nonseed_ms_list" | grep -qxF "$ms"
}

# 설명 선두 [공통] / **[공통]** (앞 공백·볼드 허용)
_is_common_desc() {
  printf '%s' "$1" | grep -qE '^[[:space:]]*(\*\*)?\[공통\]'
}

# HTML <!-- foundation-fr: FR-4, FR-27 --> 목록에 id 포함 여부
_in_foundation_fr_list() {
  local id="$1" list
  list=$(grep -oE '<!--[[:space:]]*foundation-fr:[[:space:]]*[^>]+-->' "$REQ" 2>/dev/null | head -1) || true
  [ -n "$list" ] || return 1
  printf '%s' "$list" | grep -qE "(^|[^A-Za-z0-9-])${id}([^0-9]|$)"
}

_is_foundation_scope() {
  local id="$1" desc="$2"
  _is_common_desc "$desc" && return 0
  _in_foundation_fr_list "$id" && return 0
  return 1
}

tmp=$(mktemp)
classify_out=$(mktemp)
trap 'rm -f "$tmp" "$classify_out"' EXIT

real=0; ph=0; ph_ids=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  id=$(printf '%s' "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')
  desc=$(printf '%s' "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}')
  ms=$(printf '%s' "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$4); print $4}')
  if _is_placeholder_desc "$desc"; then
    ph=$((ph + 1)); ph_ids="${ph_ids}${ph_ids:+, }${id}"
    printf 'placeholder|%s|%s|%s\n' "$id" "$desc" "$ms" >>"$tmp"
  else
    real=$((real + 1))
    printf 'real|%s|%s|%s\n' "$id" "$desc" "$ms" >>"$tmp"
  fi
done <<EOF
$(grep -E '^\|[[:space:]]*FR-[0-9]+[[:space:]]*\|' "$REQ" 2>/dev/null)
EOF

nonseed_ms_list=""
while IFS='|' read -r kind id desc ms; do
  [ "$kind" = "real" ] || continue
  _is_seed_id "$id" && continue
  [ -n "$ms" ] || continue
  if ! printf '%s\n' "$nonseed_ms_list" | grep -qxF "$ms" 2>/dev/null; then
    if [ -z "$nonseed_ms_list" ]; then
      nonseed_ms_list="$ms"
    else
      nonseed_ms_list="$nonseed_ms_list
$ms"
    fi
  fi
done <"$tmp"

if [ "$real" -eq 0 ]; then
  if [ "$CLASSIFY" -eq 1 ]; then
    while IFS='|' read -r kind id desc ms; do
      [ "$kind" = "placeholder" ] && echo "SKIP|${id}|placeholder|"
    done <"$tmp"
    echo "SUMMARY|real=0|eligible=0|seed_skip=0|placeholder=${ph}|foundation_skip=0"
  fi
  cat <<EOF
FR-TABLE: FAIL — 실 FR 0건 (placeholder ${ph}건: ${ph_ids:-none})
  $REQ 의 FR 행이 전부 미작성 상태입니다 — 골격 그대로면 /start-all 이
  존재하지 않는 기능을 구현하려 시도합니다.
  해법: requirements.md FR 표에 실제 기능 설명을 작성한 뒤 재실행하세요.
EOF
  exit 1
fi

seed_marker=0
_has_seed_marker && seed_marker=1

eligible=0; seed_skip=0; seed_ids=""
foundation_skip=0; foundation_ids=""
while IFS='|' read -r kind id desc ms; do
  if [ "$kind" = "placeholder" ]; then
    echo "SKIP|${id}|placeholder|" >>"$classify_out"
    continue
  fi
  if [ "$seed_marker" -eq 1 ] && _is_seed_id "$id" && [ -n "$ms" ] && _has_nonseed_sibling "$ms"; then
    seed_skip=$((seed_skip + 1))
    seed_ids="${seed_ids}${seed_ids:+, }${id}"
    echo "SKIP|${id}|seed-decomposed|${ms}" >>"$classify_out"
    continue
  fi
  if _is_foundation_scope "$id" "$desc"; then
    foundation_skip=$((foundation_skip + 1))
    foundation_ids="${foundation_ids}${foundation_ids:+, }${id}"
    echo "SKIP|${id}|foundation-scope|${ms}" >>"$classify_out"
    continue
  fi
  eligible=$((eligible + 1))
  echo "ELIGIBLE|${id}|${desc}|${ms}" >>"$classify_out"
done <"$tmp"

if [ "$CLASSIFY" -eq 1 ]; then
  cat "$classify_out"
  echo "SUMMARY|real=${real}|eligible=${eligible}|seed_skip=${seed_skip}|placeholder=${ph}|foundation_skip=${foundation_skip}"
  exit 0
fi

echo "FR-TABLE: PASS — 실 FR ${real}건"
[ "$ph" -gt 0 ] && echo "  경고: placeholder ${ph}건 (${ph_ids}) — batch 대상에서 제외하거나 채우세요"
[ "$seed_skip" -gt 0 ] && echo "  시드 SKIP ${seed_skip}건: ${seed_ids} (같은 마일스톤 세부 FR 존재 — batch PENDING 제외)"
[ "$foundation_skip" -gt 0 ] && echo "  공통부 SKIP ${foundation_skip}건: ${foundation_ids} (/start-foundation 담당 — batch PENDING 제외)"
exit 0
