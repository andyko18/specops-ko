#!/usr/bin/env bash
# 원장 패턴 판별력 lint — must_match 가 **주석 줄에서만** 매치하는 edge 를 잡는다.
# Usage: bash scripts/_internal/check-matrix-patterns.sh [matrix-path]
# exit 0 = 위반 0 · exit 1 = 위반 존재
#
# 왜: 패턴이 대상 파일 주석에만 걸리면 **실제 배선을 지우고 주석만 남겨도 통과**한다.
#   즉 edge 가 태어날 때부터 무음이다. gbrain 20260814 가 이 클래스를 기록했으나
#   강제층이 0곳이라 원장에 2건이 살아남았다(실측) — 이 스크립트가 그 강제층이다.
#
# ★ 한계 3종 (과대 주장 금지 — "이 클래스는 기계가 본다"이지 "이제 안전하다"가 아니다):
#   1. **코드 안 문자열 리터럴** 매치는 못 잡는다. 변이 테스트가 쓴 문자열이 잠금 패턴에
#      매치하는 자기참조 클래스가 그것이다(20260831-propagation-contract-record 실측).
#   2. **몸통을 도려낸 패턴**은 못 잡는다 — `^cp_out=` 는 코드 줄에 매치하므로 통과한다.
#   3. **줄끝 주석**(`cmd  # 설명`)에만 패턴이 있으면 그 줄을 비주석으로 계상해 통과한다.
#      bash 에서 `#` 의 주석 시작 위치를 정확히 가르려면 문자열 안 `#`(`"a#b"`·`${v#p}`)을
#      구분해야 하고 그건 파서 작업이다. 단순 휴리스틱은 **정상 edge 를 차단**하는데,
#      차단 강도를 택했으므로 오탐 비용이 곧 push 차단이다(clarify Q2 — 의도적 수용).
set -uo pipefail

PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
MATRIX="${1:-$PLUGIN/scripts/_internal/propagation-matrix.jsonl}"
[ -f "$MATRIX" ] || { echo "MATRIX-PATTERN: FAIL matrix 부재 ($MATRIX)" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "MATRIX-PATTERN: SKIP jq 미설치" >&2; exit 0; }

fail=0; checked=0; skipped=0

while IFS= read -r line; do
  [ -n "$line" ] || continue
  id=$(printf '%s' "$line" | jq -r '.id // empty')
  [ -n "$id" ] || continue
  n=$(printf '%s' "$line" | jq -r '.edges|length')
  i=0
  while [ "$i" -lt "$n" ]; do
    path=$(printf '%s' "$line" | jq -r --argjson i "$i" '.edges[$i].path')
    pat=$(printf '%s' "$line" | jq -r --argjson i "$i" '.edges[$i].must_match')
    i=$((i+1))
    f="$PLUGIN/$path"
    [ -f "$f" ] || continue   # 파일 부재는 check-propagation 의 관할 — 여기서 중복 보고 안 한다
    # 게이팅: 코드 파일만. `.md` 는 **전체가 산문**이라 "주석 전용"이 정의되지 않는다.
    #   실측 분포(2026-08-31): .sh 109 · 확장자없음 2(훅) · .md 67
    case "$path" in
      *.sh|.githooks/*) ;;
      *) skipped=$((skipped+1)); continue ;;
    esac
    checked=$((checked+1))
    # 선언형 주석 앵커 — 의도적으로 주석을 잠그는 경우다. **면제 필드가 아니라 패턴 자체가
    #   선언**이므로 git diff 에 남고 리뷰어가 본다(자기발급 면제표 회피).
    case "$pat" in '^[[:space:]]*#'*) continue ;; esac
    hits=$(grep -cE "$pat" "$f" 2>/dev/null || true)
    [ "${hits:-0}" -gt 0 ] || continue   # 매치 0건은 check-propagation 이 FAIL 낸다
    nc=$(grep -E "$pat" "$f" 2>/dev/null | grep -vcE '^[[:space:]]*#' || true)
    if [ "${nc:-0}" -eq 0 ]; then
      echo "MATRIX-PATTERN: FAIL [$id] $path ~ /$pat/ — 주석 줄에서만 매치 (${hits}건)"
      fail=$((fail+1))
    fi
  done
done < "$MATRIX"

if [ "$fail" -gt 0 ]; then
  echo "MATRIX-PATTERN: FAIL ($fail 위반 · 검사 $checked · 산문 skip $skipped)"
  exit 1
fi
echo "MATRIX-PATTERN: OK (검사 $checked · 산문 skip $skipped)"
exit 0
