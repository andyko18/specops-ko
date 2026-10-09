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
# 판정 범위: `## Task N: …` · `## 태스크 N: …`(2~3단 · 코드펜스 밖) 제목으로 구분된 각 절.
#   `## 의존 그래프` 이후(YAML DAG)는 대상 아님. 펜스 안의 선언은 선언으로 보지 않는다.
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

# 태스크 절 판정 (20261009) — 골격 생성기(plan-to-tasks.sh)와 **같은 규칙**으로 읽는다:
#   2~3단 제목 · `Task` 또는 `태스크` · 번호 · 코드펜스 밖.
#   종전엔 `## 태스크 N:` 만 절로 셌는데 플러그인이 가르치는 형식이 셋이라(templates/tasks.md `## 태스크` ·
#   decomposing-ko·planning-ko 예시 `### Task` · plan-to-tasks.sh 출력 `## Task`) 선언을 다 적고도 막혔다
#   (실기록: 실제 발화한 FAIL 7건이 전부 제목 표기였고 진짜 누락 적발은 0건).
#   펜스 추적이 없어 펜스 **안**의 선언·제목(문서 본문을 싣는 태스크)이 선언·절로 세어지기도 했다.
#   출력: `M|<제목>` = 선언 없는 절 · 마지막 줄 `N|<절 수>`.
scan=$(awk '
  function flush() { if (cur != "" && !ok) print "M|" cur; cur = "" }
  BEGIN { fence = 0; fch = ""; nsec = 0; cur = ""; ok = 0; fline = 0 }
  {
    sub(/\r$/, "")   # CRLF — 줄 끝 CR 이 값으로 남으면 빈 선언·placeholder 선언이 "값 있음"으로 읽힌다
    # 코드펜스 — 닫는 펜스는 여는 펜스 **이상** 길이(CommonMark · plan-to-tasks.sh 와 같은 조건)
    l = $0; sub(/^[ \t]+/, "", l)
    if (match(l, /^(`+|~+)/) && RLENGTH >= 3) {
      c = substr(l, 1, 1); n = RLENGTH; rest = substr(l, n + 1)
      if (fence == 0) {
        # 여는 줄의 나머지에 백틱이 있으면 펜스가 아니라 한 줄 인라인 코드다(```echo hi```) —
        #   펜스로 세면 닫히지 않아 뒤 태스크가 통째로 가려진다.
        if (!(c == "`" && index(rest, "`") > 0)) { fence = n; fch = c; fline = NR }
      } else if (c == fch && n >= fence && rest ~ /^[ \t]*$/) { fence = 0; fch = "" }
      if (fence != 0 || fline == NR || rest ~ /^[ \t]*$/) next
    }
    if (fence != 0) next
  }
  # `## 의존 그래프` 이후는 YAML DAG — 태스크 절이 아니다
  /^##[ \t]+의존 그래프/ { flush(); intasks = 0; next }
  /^###?[ \t]+(Task|태스크)[ \t]+[0-9]/ {
    flush()
    cur = $0; sub(/^#+[ \t]+/, "", cur); sub(/:.*$/, "", cur)
    ok = 0; intasks = 1; nsec++; next
  }
  intasks && /\*\*재사용 foundation\*\*:|\*\*미재사용 근거\*\*:/ {
    line = $0
    sub(/^.*\*\*(재사용 foundation|미재사용 근거)\*\*:[ \t]*/, "", line)
    gsub(/^[ \t]+|[ \t]+$/, "", line)
    # 빈 값·템플릿 placeholder(<...>)는 미기재로 본다 (형식만 갖춘 통과 차단)
    if (line != "" && line !~ /^<[^>]*>$/) ok = 1
  }
  END { flush(); print "N|" nsec; if (fence != 0) print "U|" fline }
' "$TASKS")
missing=$(printf '%s\n' "$scan" | sed -n 's/^M|//p')
_sections=$(printf '%s\n' "$scan" | sed -n 's/^N|//p' | tail -1)
_sections=${_sections:-0}
# 닫히지 않은 코드펜스 — 그 뒤의 절·선언은 전부 펜스 안으로 읽혀 **검사를 받지 않는다**.
#   YAML 대조가 있으면 절 수로 드러나지만 DAG 가 없거나 파싱이 빈손이면 조용히 통과하므로 여기서 막는다.
_unclosed=$(printf '%s\n' "$scan" | sed -n 's/^U|//p' | tail -1)
[ -n "$_unclosed" ] && missing="${missing}${missing:+
}닫히지 않은 코드펜스(tasks.md ${_unclosed}행에서 열림) — 그 뒤 태스크는 검사되지 않았다. 펜스를 닫은 뒤 재실행"

# 태스크 원천 대조 (20260806) — 본 게이트는 마크다운 **절**을 순회하는데,
#   `emit-context` 가 실제 dispatch 하는 원천은 **YAML DAG** 다. 절 수 < YAML 태스크 수면
#   나머지는 **검사 자체를 안 받고 통과**한다(실측: YAML 2 · 절 1 → PASS).
#   무인(`/start-all-auto`)에서는 사람이 눈으로 못 잡으므로 그대로 구현에 들어간다.
_yaml_ids=""
if [ -f "$PLUGIN_DIR/scripts/dag/parse-dag.sh" ]; then
  # shellcheck source=/dev/null
  . "$PLUGIN_DIR/scripts/dag/parse-dag.sh" 2>/dev/null || true
  _y=$(dag::extract_yaml "$TASKS" 2>/dev/null || true)
  [ -n "$_y" ] && _yaml_ids=$(printf '%s\n' "$_y" | grep -oE '^[[:space:]]*-[[:space:]]+id:[[:space:]]*[A-Za-z0-9._-]+' \
    | sed 's/.*id:[[:space:]]*//' || true)
fi
_ycount=$(printf '%s\n' "$_yaml_ids" | grep -c . || true)
_hdr_hint=""
if [ "${_ycount:-0}" -gt "${_sections:-0}" ]; then
  # 절이 없는 태스크 id 를 지목 — 절 제목에 id 가 없을 수 있으므로 개수 기준으로 뒤쪽 id 를 나열
  _uncovered=$(printf '%s\n' "$_yaml_ids" | tail -n "$(( _ycount - _sections ))" | tr '\n' ' ')
  missing="${missing}${missing:+
}YAML 태스크 절 누락(${_sections}/${_ycount}) — 미검사 태스크: ${_uncovered}"
  # 선언을 적었는데 여기 걸리면 원인은 선언이 아니라 **제목 표기**다 — 그 사실을 말한다.
  _hdr_hint=y
fi

if [ -n "$missing" ]; then
  echo "FOUNDATION-REUSE: FAIL — 재사용 선언 누락·무효"
  printf '%s\n' "$missing" | sed 's/^/  - /'
  echo "  각 태스크에 다음 중 하나를 기재하세요 (decomposing-ko 계약):"
  echo "    **재사용 foundation**: <foundation-manifest.md 의 모듈명>"
  echo "    **미재사용 근거**: <이 태스크가 공통부를 쓰지 않는 이유>"
  if [ -n "$_hdr_hint" ]; then
    echo "  ★ 태스크 절을 ${_sections}개만 찾았습니다(YAML ${_ycount}개). 선언을 이미 적었다면 원인은 **절 제목 표기**입니다."
    echo "    인정하는 제목: \`## Task N: …\` · \`## 태스크 N: …\` (2~3단 · 번호 필수 · 코드펜스 밖)"
  fi
  exit 1
fi

echo "FOUNDATION-REUSE: PASS"
exit 0
