#!/usr/bin/env bash
# check-foundation-reuse.sh — foundation 재사용 게이트 소비측 (20260806)
# Usage: check-foundation-reuse.sh <FID>
# Exit: 0 = PASS 또는 해당 없음(skip) · 1 = FAIL(선언 누락·무효)
#
# 계약(decomposing-ko): §유형이 foundation 이 **아니고** `.specops/memory/foundation-manifest.md`
#   가 존재하면, 각 task 는 다음 중 하나를 반드시 기재한다 — 누락 시 implementing-ko 호출 금지.
#     `**재사용 foundation**: <manifest 의 모듈명>`
#     `**미재사용 근거**: <이유>`
#
# 종전엔 이 계약이 decomposing-ko **산문뿐**이었다(검사 0곳). 생산측 manifest 게이트를
#   기계화(check-foundation-manifest.sh)해도, 소비측이 모델 재량이면 재사용 강제는 여전히
#   선언적 장식이다 — 공통부를 만들어 놓고 아무도 안 쓰는 상태가 조용히 통과한다.
#
# 판정 범위: `## 태스크 N: …` 헤더로 구분된 각 절. `## 의존 그래프` 이후(YAML DAG)는 대상 아님.
# fail-open: spec.md·tasks.md 부재 → 0 (무관 FID·초기 상태 월권 금지).
set -u

FID="${1:?usage: $0 <FID>}"
SPECOPS="${SPECOPS_ROOT:-.specops}"
SPEC="$SPECOPS/$FID/spec.md"
TASKS="$SPECOPS/$FID/tasks.md"
MANIFEST="$SPECOPS/memory/foundation-manifest.md"
PLUGIN_DIR=$(cd "$(dirname "$0")/../.." && pwd)

[ -f "$SPEC" ] && [ -f "$TASKS" ] || { echo "FOUNDATION-REUSE: SKIP (산출물 부재)"; exit 0; }

# foundation FID 자신에게는 재사용을 요구하지 않는다 (생산자)
if grep -qE '^\*\*§유형\*\*:[[:space:]]*foundation' "$SPEC" 2>/dev/null; then
  echo "FOUNDATION-REUSE: SKIP (§유형=foundation — 생산자)"
  exit 0
fi

# manifest 가 없으면 공통부가 없는 프로젝트 — 게이트 비발동
[ -f "$MANIFEST" ] || { echo "FOUNDATION-REUSE: SKIP (manifest 부재)"; exit 0; }

missing=$(awk '
  # `## 의존 그래프` 이후는 YAML DAG — 태스크 절이 아니다
  /^##[[:space:]]+의존 그래프/ { intasks = 0; if (cur != "" && !ok) print cur; cur = ""; next }
  /^##[[:space:]]+태스크[[:space:]]/ {
    if (cur != "" && !ok) print cur
    cur = $0; sub(/^##[[:space:]]+/, "", cur); sub(/:.*$/, "", cur)
    ok = 0; intasks = 1; next
  }
  intasks && /\*\*재사용 foundation\*\*:|\*\*미재사용 근거\*\*:/ {
    line = $0
    sub(/^.*\*\*(재사용 foundation|미재사용 근거)\*\*:[[:space:]]*/, "", line)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
    # 빈 값·템플릿 placeholder(<...>)는 미기재로 본다 (형식만 갖춘 통과 차단)
    if (line != "" && line !~ /^<[^>]*>$/) ok = 1
  }
  END { if (cur != "" && !ok) print cur }
' "$TASKS")

# 태스크 원천 대조 (20260806) — 본 게이트는 `## 태스크 N:` 마크다운 절을 순회하는데,
#   `emit-context` 가 실제 dispatch 하는 원천은 **YAML DAG** 다. 절 수 < YAML 태스크 수면
#   나머지는 **검사 자체를 안 받고 통과**한다(실측: YAML 2 · 절 1 → PASS).
#   무인(`/start-all-auto`)에서는 사람이 눈으로 못 잡으므로 그대로 구현에 들어간다.
_sections=$(grep -cE '^##[[:space:]]+태스크[[:space:]]' "$TASKS" 2>/dev/null || true)
_yaml_ids=""
if [ -f "$PLUGIN_DIR/scripts/dag/parse-dag.sh" ]; then
  # shellcheck source=/dev/null
  . "$PLUGIN_DIR/scripts/dag/parse-dag.sh" 2>/dev/null || true
  _y=$(dag::extract_yaml "$TASKS" 2>/dev/null || true)
  [ -n "$_y" ] && _yaml_ids=$(printf '%s\n' "$_y" | grep -oE '^[[:space:]]*-[[:space:]]+id:[[:space:]]*[A-Za-z0-9._-]+' \
    | sed 's/.*id:[[:space:]]*//' || true)
fi
_ycount=$(printf '%s\n' "$_yaml_ids" | grep -c . || true)
if [ "${_ycount:-0}" -gt "${_sections:-0}" ]; then
  # 절이 없는 태스크 id 를 지목 — 절 제목에 id 가 없을 수 있으므로 개수 기준으로 뒤쪽 id 를 나열
  _uncovered=$(printf '%s\n' "$_yaml_ids" | tail -n "$(( _ycount - _sections ))" | tr '\n' ' ')
  missing="${missing}${missing:+
}YAML 태스크 절 누락(${_sections}/${_ycount}) — 미검사 태스크: ${_uncovered}"
fi

if [ -n "$missing" ]; then
  echo "FOUNDATION-REUSE: FAIL — 재사용 선언 누락·무효"
  printf '%s\n' "$missing" | sed 's/^/  - /'
  echo "  각 태스크에 다음 중 하나를 기재하세요 (decomposing-ko 계약):"
  echo "    **재사용 foundation**: <foundation-manifest.md 의 모듈명>"
  echo "    **미재사용 근거**: <이 태스크가 공통부를 쓰지 않는 이유>"
  exit 1
fi

echo "FOUNDATION-REUSE: PASS"
exit 0
