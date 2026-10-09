#!/usr/bin/env bash
# foundation-manifest-content.sh — manifest 가 **무엇을 담고 있는지** 읽는다 (20261009)
# source 전용. check-foundation-manifest(verify) · check-foundation-present(/start-all 입구)가 공유한다.
#
# 왜: 두 게이트는 자리표시자가 남았는지만 봤다 — 내용이 `x` 한 줄이어도, 모듈 행이 0개여도,
#   저장소에 없는 경로만 적어도 통과했다(재현 20261009). 공통부가 있다는 최소 증거를 요구한다.
#
# 함수:
#   fmc_scan <manifest> <repo-root>
#     FMC_TOTAL   표에 적힌 경로 표기 수
#     FMC_REAL    그중 저장소에 실재하는 수
#     FMC_MISSING 실재하지 않는 경로(줄바꿈 구분)
#   fmc_module_names <manifest|->  표 첫 칸의 모듈명(머리 행·구분선 제외)을 한 줄씩 (`-` 는 stdin)
#   fmc_template_leftovers <문서> <템플릿>
#     템플릿의 자리표시자가 문서에 그대로 남은 줄을 `파일:행:내용` 으로 낸다. 남은 것이 없으면 rc 0, 있으면 rc 1,
#     템플릿을 읽을 수 없으면 rc 2(호출자가 다른 판정으로 물러난다).
#     범용 미채움 스캐너(scan-enrich-placeholders.sh)를 쓰지 않는 이유: 그 스캐너는 꺾쇠 모양을 전부 세는데,
#     manifest 는 사용 예(`<AppShell …>` · `apiFetch<T>(path)` · `<input>`)를 적는 문서다 — 실 프로젝트의
#     다 채운 226줄 manifest 가 "템플릿 placeholder 잔존" 으로 막혔다(20261009 재생). 이 게이트가 묻는 것은
#     "템플릿의 자리표시자가 남았는가"이므로 **템플릿이 실제로 가진 토큰**만 찾는다.
#     템플릿에 없더라도 미채움을 뜻하는 표기(`<TODO…`·`<TBD…`·`<todo>`·`<tbd>`·`<미정…`·`<미확정…`)는 함께 본다
#     (`<Todo />`·`<TodoList>` 같은 컴포넌트 표기는 아니다).
#
# 경로 표기 = 표 행(`|` 로 시작)의 백틱 표기 가운데 경로처럼 생긴 것:
#   공백·중괄호·`=`·`;`·`,`·`*`·`<>`·따옴표가 없고 · `/`·`@`·`http`·`-`·`~`·`$` 로 시작하지 않는다.
#   (`import { x } from '@/y'` 같은 사용 예 · `/stocks/[ticker]` 같은 라우트는 경로가 아니다. 뒤의 `:12` 줄 번호는 떼고 본다.)
#   - `/` 가 든 표기 → 경로로 센다(FMC_TOTAL). 없으면 FMC_MISSING.
#   - `/` 없이 `이름.확장자` 꼴 · 괄호·대괄호가 든 경로 → 실재하면 FMC_REAL 에만 더한다. 없다고 해서 누락으로 보지 않는다 —
#     `yf.download`(심볼)·`openapi.naver.com`(호스트)·`.field`(CSS)·`fn(a/b)`(호출)와 모양으로 가를 수 없다(실 manifest 재생).
#   - 위에서 실재하는 것이 하나도 안 나오면 **넓게 다시 찾는다**: 백틱 없이 적은 표 칸 · 표 밖의 백틱 표기 · 공백이 든 경로 ·
#     역슬래시 경로까지, 그대로 저장소에 있는 것이 있으면 근거로 센다(형식이 달라서 막는 일을 줄인다 — 누락 목록은 늘리지 않는다).
# 실재 = <root>/<경로> 가 있거나, 추적 파일 중 그 경로로 **끝나는** 것이 있다(표가 하위 패키지 기준 상대경로로 적힌 경우).
# shellcheck shell=bash

fmc_template_leftovers() {
  local doc="$1" tpl="$2" toks pats out
  [ -f "$tpl" ] || return 2
  toks=$(LC_ALL=C grep -oE '<[^<>]{1,60}>' "$tpl" 2>/dev/null | LC_ALL=C grep -v '^<!--' | LC_ALL=C sort -u)
  [ -n "$toks" ] || return 2
  # 한글이 든 토큰은 닫는 꺾쇠를 뗀 **앞머리**로 찾는다 — `<경로 입력>`·`<설명 작성>` 처럼 고쳐 쓴 미채움도 잡는다.
  #   영문만으로 된 토큰(`<FID>`)은 그대로 찾는다(앞머리로 찾으면 `<FIDBadge />` 같은 코드 표기에 걸린다).
  pats=$(printf '%s\n' "$toks" | LC_ALL=C awk '{ if ($0 ~ /[\200-\377]/) sub(/>$/, ""); print }')
  pats="${pats}
<미정
<미확정"
  # 꺾쇠 안쪽 가장자리의 공백은 지우고 대조한다(`< 경로 >`). 줄 번호는 원문과 같다.
  out=$( { LC_ALL=C sed -e 's/<[ 	]*/</g' -e 's/[ 	]*>/>/g' "$doc" 2>/dev/null | LC_ALL=C grep -nF -e "$pats"
           LC_ALL=C grep -nE '<(TODO|TBD)([ :>]|$)|<(todo|tbd)>' "$doc" 2>/dev/null; } | LC_ALL=C sort -t: -k1,1n -u | sed "s|^|$doc:|")
  [ -z "$out" ] && return 0
  printf '%s\n' "$out"
  return 1
}

fmc_module_names() {
  LC_ALL=C awk '
    function commit() { if (pend != "") print pend; pend = "" }
    { sub(/\r$/, "") }
    /^[ \t]*\|/ {
      split($0, c, "|"); name = c[2]; gsub(/[`*]/, "", name); gsub(/^[ \t]+|[ \t]+$/, "", name)
      if (name ~ /^:?-+:?$/) { pend = ""; next }
      commit(); if (length(name) >= 2) pend = name
      next
    }
    { commit() }
    END { commit() }
  ' "$1" 2>/dev/null
}

_fmc_path_tokens() {
  LC_ALL=C awk '
    { sub(/\r$/, "") }
    /^[ \t]*\|/ {
      r = $0
      while (match(r, /`[^`]+`/)) {
        t = substr(r, RSTART + 1, RLENGTH - 2); r = substr(r, RSTART + RLENGTH)
        if (t ~ /[ \t{}=;,*<>"\047]/) continue
        if (t ~ /^(\/|@|http|-|~|\$)/) continue
        sub(/:[0-9]+(-[0-9]+)?$/, "", t)
        odd = (index(t, "(") > 0 || index(t, ")") > 0 || index(t, "[") > 0 || index(t, "]") > 0)
        if (t ~ /\// && !odd) print "P|" t
        # 괄호·대괄호가 든 경로(`src/app/(main)/layout.tsx` · `[id]/page.tsx`)는 호출·라우트 표기와 모양이 같다 —
        #   실재하면 근거로 세고, 없다고 누락으로 보지는 않는다.
        else if (t ~ /\// || t ~ /^[^.]+\.[A-Za-z0-9]+$/ || t ~ /^\.[A-Za-z0-9_-]+$/) print "F|" t
      }
    }
  ' "$1" 2>/dev/null | LC_ALL=C sort -u
}

fmc_scan() {
  local manifest="$1" root="${2:-.}" line kind tok
  FMC_TOTAL=0; FMC_REAL=0; FMC_MISSING=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    kind=${line%%|*}; tok=${line#*|}
    if [ "$kind" = F ]; then
      [ -e "$root/$tok" ] && FMC_REAL=$((FMC_REAL + 1))
      continue
    fi
    FMC_TOTAL=$((FMC_TOTAL + 1))
    if [ -e "$root/$tok" ]; then
      FMC_REAL=$((FMC_REAL + 1))
    elif [ -n "$(git -C "$root" ls-files -- ":(glob)**/${tok%/}" ":(glob)**/${tok%/}/**" 2>/dev/null | head -1)" ]; then
      FMC_REAL=$((FMC_REAL + 1))
    else
      FMC_MISSING="${FMC_MISSING}${FMC_MISSING:+
}${tok}"
    fi
  done <<EOF
$(_fmc_path_tokens "$manifest")
EOF
  [ "$FMC_REAL" -gt 0 ] && return 0
  # 넓게 다시 찾기 — 표 칸 전체와 문서의 모든 백틱 표기 가운데 경로처럼 생기고(`/` 또는 `.` 포함) 그대로 실재하는 것
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    case "$tok" in /*|*..*) continue ;; esac
    if [ -e "$root/$tok" ]; then FMC_REAL=$((FMC_REAL + 1)); fi
  done <<EOF
$(LC_ALL=C awk '
    function out(x) { gsub(/^[ \t]+|[ \t\r]+$/, "", x); gsub(/\\/, "/", x); if (x ~ /[\/.]/ && length(x) >= 3) print x }
    { sub(/\r$/, ""); r = $0
      while (match(r, /`[^`]+`/)) { out(substr(r, RSTART + 1, RLENGTH - 2)); r = substr(r, RSTART + RLENGTH) } }
    /^[ \t]*\|/ { n = split($0, c, "|"); for (i = 2; i <= n; i++) { x = c[i]; gsub(/[`*]/, "", x); out(x) } }
  ' "$manifest" 2>/dev/null | LC_ALL=C sort -u)
EOF
}
