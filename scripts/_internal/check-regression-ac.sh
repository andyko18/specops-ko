#!/usr/bin/env bash
# check-regression-ac.sh — 회귀 AC(AC-R-1/AC-R-2) 게이트 (20260806, /maintain 정밀분석)
# Usage: check-regression-ac.sh <FID>
# Exit: 0 = PASS 또는 해당 없음(skip) · 1 = FAIL(회귀 AC 누락·미채움)
#
# 왜 스크립트인가: "/maintain 의 존재 이유" 인 회귀 안전망이 전부 산문이었다 —
#   specifying-ko "유지보수 → AC-R-1 강제(스키마면 AC-R-2)", 템플릿 "evaluator 가
#   누락 시 verdict=BLOCK". 그런데 검사 구현이 0곳이라 모델이 빠뜨리면 회귀 AC 없이
#   구현이 진행됐다. 결과는 "새 기능이 이상함" 이 아니라 "멀쩡하던 것이 깨짐" 클래스.
#
# 판정 규칙:
#   need AC-R-1 ⇐ spec.md `**§유형**: 유지보수`  (신규·trivial·foundation 면제 — 템플릿 계약)
#   need AC-R-2 ⇐ current-state.md §1 `스키마 override` 마커 (analyzing Step 1 산출)
#     — §유형과 **독립**: trivial 이어도 파괴적 스키마면 강제 (데이터 안전은 라인수 면제 불가)
#   채움 판정: 헤더 존재 + Given/When/Then 의 **템플릿 문구 잔존 없음**.
#     템플릿이 AC-R 섹션을 기본 포함하므로 "헤더 존재" 만으론 템플릿 복사로 뚫린다.
# fail-open: spec.md 부재 → skip.
set -u

FID="${1:?usage: $0 <FID>}"
SPECOPS="${SPECOPS_ROOT:-.specops}"
SPEC="$SPECOPS/$FID/spec.md"
AC="$SPECOPS/$FID/acceptance-criteria.md"
CS="$SPECOPS/$FID/current-state.md"

[ -f "$SPEC" ] || { echo "REGRESSION-AC: SKIP (spec.md 부재)"; exit 0; }

need_r1=0
grep -qE '^\*\*§유형\*\*:[[:space:]]*유지보수' "$SPEC" 2>/dev/null && need_r1=1

need_r2=0
[ -f "$CS" ] && grep -q '스키마 override' "$CS" 2>/dev/null && need_r2=1

if [ "$need_r1" -eq 0 ] && [ "$need_r2" -eq 0 ]; then
  echo "REGRESSION-AC: SKIP (§유형≠유지보수 · 스키마 override 없음)"
  exit 0
fi

if [ ! -f "$AC" ]; then
  echo "REGRESSION-AC: FAIL — acceptance-criteria.md 부재 (회귀 AC 를 쓸 곳이 없다)"
  exit 1
fi

# 섹션 추출 + 채움 판정. 템플릿 잔존 문구(대괄호 placeholder)는 미채움.
_section() {  # $1=AC-R-N → 섹션 본문
  awk -v h="### $1" '
    index($0, h) == 1 { f=1; next }
    f && /^### / { exit }
    f { print }
  ' "$AC"
}
_check_ac() {  # $1=AC-R-N $2=설명
  local body
  body=$(_section "$1")
  if [ -z "$body" ]; then
    echo "REGRESSION-AC: FAIL — $1 부재 ($2)"
    return 1
  fi
  # 템플릿 placeholder 잔존 — templates/acceptance-criteria.md 의 원문 대괄호 문구
  if printf '%s' "$body" | grep -qE '\[(구체적|현재와 동일한|기존 회귀 테스트|마이그레이션 적용 전|마이그레이션 테스트|대상 테이블)'; then
    echo "REGRESSION-AC: FAIL — $1 템플릿 placeholder 잔존 (미채움 — 실제 회귀 시나리오로 채우세요)"
    return 1
  fi
  # 최소 구조: Given/When/Then 셋 다
  local g w t
  g=$(printf '%s' "$body" | grep -c '^\*\*Given\*\*') || true
  w=$(printf '%s' "$body" | grep -c '^\*\*When\*\*') || true
  t=$(printf '%s' "$body" | grep -c '^\*\*Then\*\*') || true
  if [ "${g:-0}" -eq 0 ] || [ "${w:-0}" -eq 0 ] || [ "${t:-0}" -eq 0 ]; then
    echo "REGRESSION-AC: FAIL — $1 Given/When/Then 불완전 ($2)"
    return 1
  fi
  return 0
}

fail=0
if [ "$need_r1" -eq 1 ]; then
  _check_ac "AC-R-1" "유지보수 FID 는 기존 동작 보존 AC 필수" || fail=1
fi
if [ "$need_r2" -eq 1 ]; then
  _check_ac "AC-R-2" "파괴적 스키마 변경 — 데이터 보존·역가역성 AC 필수 (라인수 면제 불가)" || fail=1
fi

[ "$fail" -eq 0 ] && { echo "REGRESSION-AC: PASS"; exit 0; }
cat >&2 <<'EOF'
  해법: templates/acceptance-criteria.md 의 '회귀 방지 AC' 섹션을 실제 시나리오로 채우세요.
        AC-R-1 = 기존 동작 보존 (유지보수) · AC-R-2 = 데이터 보존·역가역성 (스키마 override)
EOF
exit 1
