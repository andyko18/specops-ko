#!/usr/bin/env bash
# check-foundation-present.sh — /start-all Phase 0 foundation 선행 게이트 (20260812)
# Usage: check-foundation-present.sh
# Exit: 0 = PASS | SKIP(비필수) | WARN(비필수·부재)
#       1 = FAIL (필수인데 부재·미채움, 또는 파일은 있으나 미채움 — 비필수 포함)
#
# 왜 필요한가: check-foundation-reuse.sh 는 manifest 부재 시 SKIP 한다. start-all Phase 0 이
#   foundation 을 검사하지 않으면 init 만 한 채 batch 가 들어가 재사용 강제가 침묵 무발동한다
#   (attendance 직전 상태). check-foundation-manifest.sh 는 FID+§유형=foundation 전용(verify)이라
#   프로젝트 입구 검사에 쓸 수 없다.
#
# 필수 KIND: FE/BE arch 파일 · decisions(프로젝트 종류 UI/BE/풀스택/모바일 · UI 유무 있음) ·
#   project-context §2 실값. 없으면 CLI/기타 → 부재 시 WARN rc=0.
# 채움: 파일이 있으면 scan-enrich-placeholders 통과 필수(비필수 KIND 도 raw 템플릿 FAIL).
set -u

SPECOPS="${SPECOPS_ROOT:-.specops}"
MEM="$SPECOPS/memory"
MANIFEST="$MEM/foundation-manifest.md"
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
SCAN="$PLUGIN/scripts/_internal/scan-enrich-placeholders.sh"
LEDGER="$MEM/decisions.md"
CTX="$MEM/project-context.md"

_is_uninformative_value() {
  local v="$1"
  [ -z "$v" ] && return 0
  printf '%s' "$v" | grep -qE '^<[^>]*>$' && return 0
  printf '%s' "$v" | grep -qE '^(TBD|tbd|N/A|n/a|-|—|\(미정\)|미정|미확정|해당없음|해당 없음|\?\?\?)$' && return 0
  printf '%s' "$v" | grep -qE '^<미확정' && return 0
  return 1
}

# decisions.md 표에서 확정 행만 topic|value (예시·미확정 제외 — check-decisions-ledger 정신)
_decision_rows() {
  [ -f "$LEDGER" ] || return 0
  awk -F'|' '
    /^\|/ {
      if ($2 ~ /DECISION-ID/) next
      if ($2 ~ /^[[:space:]]*-+[[:space:]]*$/) next
      if (NF < 4) next
      topic = $3; value = $4
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", topic)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (topic == "") next
      if (topic ~ /^\(예시\)/) next
      if (value == "") next
      if (value ~ /^<[^>]*>$/) next
      if (value ~ /^(TBD|tbd|N\/A|n\/a|-|—|\(미정\)|미정|미확정|해당없음|해당 없음|\?\?\?)$/) next
      print topic "|" value
    }
  ' "$LEDGER"
}

_required_from_decisions() {
  local topic value
  while IFS='|' read -r topic value; do
    [ -n "$topic" ] || continue
    if printf '%s' "$topic" | grep -q 'UI 유무'; then
      printf '%s' "$value" | grep -q '있음' && return 0
    fi
    if printf '%s' "$topic" | grep -q '프로젝트 종류'; then
      printf '%s' "$value" | grep -qE '풀스택|Web|UI|BE|API|모바일|Mobile|프론트|백엔드' && return 0
    fi
  done <<EOF
$(_decision_rows)
EOF
  return 1
}

_required_from_context() {
  [ -f "$CTX" ] || return 1
  local area value
  while IFS='|' read -r _ area value _; do
    area=$(printf '%s' "$area" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if printf '%s' "$area" | grep -q 'UI 유무'; then
      printf '%s' "$value" | grep -q '있음' && return 0
    fi
    if printf '%s' "$area" | grep -qE '^(프론트|백엔드)$'; then
      _is_uninformative_value "$value" && continue
      printf '%s' "$value" | grep -qiE '없음|해당[[:space:]]*없음|N/A' && continue
      [ -n "$value" ] && return 0
    fi
  done <<EOF
$(grep -E '^\|[[:space:]]*[^|]+[[:space:]]*\|' "$CTX" 2>/dev/null)
EOF
  return 1
}

_is_required() {
  [ -f "$MEM/frontend-architecture.md" ] && return 0
  [ -f "$MEM/backend-architecture.md" ] && return 0
  _required_from_decisions && return 0
  _required_from_context && return 0
  return 1
}

_fail_missing() {
  echo "FOUNDATION-PRESENT: FAIL — $MANIFEST 부재"
  echo "  UI/BE/풀스택/모바일 프로젝트는 /start-foundation 으로 공통부를 만든 뒤"
  echo "  .specops/memory/foundation-manifest.md 를 채워야 /start-all 에 진입할 수 있습니다."
  echo "  (부재 시 재사용 게이트 check-foundation-reuse 가 SKIP 되어 공통 재구현이 침묵 통과합니다.)"
  exit 1
}

_fail_unfilled() {
  local scan_out="$1"
  echo "FOUNDATION-PRESENT: FAIL — 템플릿 placeholder 잔존(미채움)"
  printf '%s\n' "$scan_out" | sed 's/^/  /'
  echo "  /start-foundation 완주 또는 manifest 를 실제 모듈 경로로 채운 뒤 재실행하세요."
  exit 1
}

_check_filled() {
  if [ -f "$SCAN" ]; then
    if ! scan_out=$(bash "$SCAN" "$MANIFEST" 2>/dev/null); then
      _fail_unfilled "$scan_out"
    fi
  else
    if grep -q '<경로>' "$MANIFEST" 2>/dev/null; then
      _fail_unfilled "(scan-enrich-placeholders.sh 부재 — <경로> 검출)"
    fi
  fi
}

required=0
_is_required && required=1

if [ ! -f "$MANIFEST" ]; then
  if [ "$required" -eq 1 ]; then
    _fail_missing
  fi
  echo "FOUNDATION-PRESENT: SKIP (foundation 비필수 — FE/BE 신호 없음)"
  echo "FOUNDATION-PRESENT: WARN — manifest 부재 (비필수). /start-foundation 권장"
  exit 0
fi

# 파일 있으면 채움 항상 요구 (비필수 KIND 의 raw 템플릿도 FAIL)
_check_filled

echo "FOUNDATION-PRESENT: PASS"
exit 0
