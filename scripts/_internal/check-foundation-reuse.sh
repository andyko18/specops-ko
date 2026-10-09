#!/usr/bin/env bash
# check-foundation-reuse.sh — foundation 재사용 게이트 소비측 (20260806)
# Usage: check-foundation-reuse.sh <FID>
#        check-foundation-reuse.sh --declarations <FID>   # 태스크별 선언을 기계가 읽을 꼴로 (emit-context 가 소비)
# Exit: 0 = PASS 또는 해당 없음(skip) · 1 = FAIL(선언 누락·무효)
#   --declarations: 게이트가 발동하는 FID 면 `MANIFEST|<경로>` 1줄 + `<태스크 번호>|<필드명>|<값>` 줄들, 아니면 무출력. rc 0(FID 인자 누락만 usage 오류).
#   경고(`FOUNDATION-REUSE: WARN`)는 차단이 아니다 — 재사용 선언이 manifest 의 모듈명·경로·심볼을 하나도 담지 않을 때 낸다.
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

MODE=check
if [ "${1:-}" = "--declarations" ]; then MODE=decl; shift; fi
FID="${1:?usage: $0 [--declarations] <FID>}"
SPECOPS="${SPECOPS_ROOT:-.specops}"
SPEC="$SPECOPS/$FID/spec.md"
TASKS="$SPECOPS/$FID/tasks.md"
MANIFEST="$SPECOPS/memory/foundation-manifest.md"
PLUGIN_DIR=$(cd "$(dirname "$0")/../.." && pwd)

# --declarations 는 게이트가 발동하지 않으면 아무것도 내지 않는다(소비자가 출력 유무로 분기한다)
_skip() { [ "$MODE" = decl ] || echo "FOUNDATION-REUSE: SKIP ($1)"; exit 0; }

[ -f "$SPEC" ] && [ -f "$TASKS" ] || _skip "산출물 부재"

# foundation FID 자신에게는 재사용을 요구하지 않는다 (생산자)
if grep -qE '^\*\*§유형\*\*:[[:space:]]*foundation' "$SPEC" 2>/dev/null; then
  _skip "§유형=foundation — 생산자"
fi

# manifest 가 없으면 공통부가 없는 프로젝트 — 게이트 비발동
[ -f "$MANIFEST" ] || _skip "manifest 부재"

# manifest 의 **이름들** — 선언값 대조용. 표의 모듈명(첫 칸 · 머리 행과 구분선 제외)과
#   문서 어디든 백틱으로 감싼 표기(경로·심볼)를 모은다. 선언이 이 가운데 하나라도 담으면 manifest 에 근거한 선언이다.
#   첫 칸만 보면 경로·심볼로 적은 정상 선언까지 경고가 났다(실기록 재생: 227줄 중 20줄).
#   이름이 하나도 안 나오는 산문형 manifest 면 빈 목록 → 대조하지 않는다(판정할 근거가 없다).
_modules=$(LC_ALL=C awk '
  function commit() { if (pend != "") print tolower(pend); pend = "" }
  # 백틱 표기는 5바이트 이상만 근거로 삼는다 — `app`·`src`·`npm` 같은 짧은 표기는 아무 문장에나 걸려 경고를 무력화한다.
  #   manifest 자신의 경로는 근거가 아니다(선언에 "foundation-manifest.md" 라고만 적는 경우).
  function emit(x) { if (length(x) >= 5 && x !~ /foundation-manifest/ && x !~ /^<.*>$/) print tolower(x) }
  { sub(/\r$/, "") }
  {
    r = $0
    while (match(r, /`[^`]+`/)) {
      t = substr(r, RSTART + 1, RLENGTH - 2); r = substr(r, RSTART + RLENGTH)
      gsub(/^[ \t]+|[ \t]+$/, "", t)
      emit(t)
      # 경로는 파일 이름만으로도(`src/router.ts` → router.ts), 호출 표기는 이름만으로도(`withAuth(handler)` → withAuth) 근거다
      if (index(t, "/") > 0) { x = t; sub(/^.*\//, "", x); emit(x) }
      if (index(t, "(") > 1) emit(substr(t, 1, index(t, "(") - 1))
    }
  }
  /^[ \t]*\|/ {
    split($0, c, "|"); name = c[2]; gsub(/[`*]/, "", name); gsub(/^[ \t]+|[ \t]+$/, "", name)
    if (name ~ /^:?-+:?$/) { pend = ""; next }
    commit(); if (length(name) >= 2) pend = name
    next
  }
  { commit() }
  END { commit() }
' "$MANIFEST" 2>/dev/null | LC_ALL=C sort -u)
# LC_ALL=C 두 곳: ① 로케일 정렬은 서로 다른 한글 문자열을 같다고 보아 -u 가 이름을 지운다(macOS en_US.UTF-8 실측)
#   ② length 가 awk 구현마다 글자·바이트로 갈려 짧은 한글 이름의 판정이 달라진다 — 바이트로 통일한다.
# 이름 목록은 환경변수로 넘긴다 — 지나치게 크면(리눅스의 인자 1개 상한 근처) 대조를 생략한다(경고만 사라지고 판정은 그대로).
[ "${#_modules}" -gt 100000 ] && _modules=""

# 태스크 절 판정 (20261009) — 골격 생성기(plan-to-tasks.sh)와 **같은 규칙**으로 읽는다:
#   2~3단 제목 · `Task` 또는 `태스크` · 번호 · 코드펜스 밖.
#   종전엔 `## 태스크 N:` 만 절로 셌는데 플러그인이 가르치는 형식이 셋이라(templates/tasks.md `## 태스크` ·
#   decomposing-ko·planning-ko 예시 `### Task` · plan-to-tasks.sh 출력 `## Task`) 선언을 다 적고도 막혔다
#   (실기록: 실제 발화한 FAIL 7건이 전부 제목 표기였고 진짜 누락 적발은 0건).
#   펜스 추적이 없어 펜스 **안**의 선언·제목(문서 본문을 싣는 태스크)이 선언·절로 세어지기도 했다.
#   출력: `M|<제목>` = 선언 없는 절 · `S|<번호>` = 절 · `D|<번호>|<필드>|<값>` = 유효 선언 · `W|<제목>|<값>` = 모듈명 없는 재사용 선언
#         · `N|<절 수>` · `U|<행>` = 닫히지 않은 펜스가 열린 행.
scan=$(FND_MODULES="$_modules" LC_ALL=C awk '
  function flush() { if (cur != "" && !ok) print "M|" cur; cur = "" }
  BEGIN {
    fence = 0; fch = ""; nsec = 0; cur = ""; ok = 0; fline = 0
    nn = split(ENVIRON["FND_MODULES"], nm, "\n"); if (ENVIRON["FND_MODULES"] == "") nn = 0
  }
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
    num = cur; sub(/^(Task|태스크)[ \t]+/, "", num); match(num, /^[0-9]+/); num = substr(num, 1, RLENGTH)
    ok = 0; intasks = 1; nsec++; print "S|" (num + 0); next
  }
  intasks && /\*\*재사용 foundation\*\*:|\*\*미재사용 근거\*\*:/ {
    line = $0
    sub(/^.*\*\*(재사용 foundation|미재사용 근거)\*\*:[ \t]*/, "", line)
    gsub(/^[ \t]+|[ \t]+$/, "", line)
    kind = ($0 ~ /\*\*재사용 foundation\*\*:/) ? "재사용 foundation" : "미재사용 근거"
    # 빈 값·템플릿 placeholder(<...>)·문장부호뿐인 값(`-`·`—`·`...`)은 미기재로 본다 (형식만 갖춘 통과 차단)
    #   여러 바이트 문자는 대괄호에 넣지 않는다 — 바이트 단위 awk(mawk)가 다른 글자의 바이트까지 지운다.
    v = line; gsub(/—|–|·|…/, "", v); gsub(/[-_.~*,;:!?()\/ \t`"]/, "", v)
    if (line != "" && line !~ /^<[^>]*>$/ && v != "") {
      ok = 1
      print "D|" (num + 0) "|" kind "|" line
      if (kind == "재사용 foundation" && nn > 0) {
        plain = tolower(line); gsub(/[`*]/, "", plain); hit = 0   # 영문 대소문자는 가리지 않는다
        for (i = 1; i <= nn; i++) if (nm[i] != "" && index(plain, nm[i]) > 0) { hit = 1; break }
        if (!hit) print "W|" cur "|" line
      }
    }
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

# 절 번호 ↔ task id 번호 대조 — 선언을 태스크에 대응시키는 근거다(`## Task 3` ↔ `T3`).
#   어긋나면(예: id 는 T0~T9 인데 절은 1~10 · 같은 번호의 절이 둘) 다른 태스크의 선언이 그 태스크 것으로 읽힌다.
#   차단하지 않는다 — 실기록 93건 중 1건이 이 꼴로 정상 완주했다. 대신 알리고, 컨텍스트에는 대응시키지 않는다.
_nummis=""
if [ "${_ycount:-0}" -gt 0 ] && [ "${_sections:-0}" -gt 0 ]; then
  _sec_nums=$(printf '%s\n' "$scan" | sed -n 's/^S|//p' | sort -n | tr '\n' ' ')
  _id_nums=$(printf '%s\n' "$_yaml_ids" | sed 's/[^0-9]//g' | grep . | sed 's/^0*\([0-9]\)/\1/' | sort -n | tr '\n' ' ')
  [ "$_sec_nums" = "$_id_nums" ] || _nummis=y
fi

if [ "$MODE" = decl ]; then
  printf 'MANIFEST|%s\n' "$MANIFEST"
  if [ -n "$_nummis" ]; then echo "NOMAP|절 번호(${_sec_nums% })와 task id 번호(${_id_nums% })가 어긋난다"
  else printf '%s\n' "$scan" | sed -n 's/^D|//p'; fi
  exit 0
fi
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

# manifest 에 근거가 없는 재사용 선언 — 통과시키되 알린다. 차단하지 않는 이유: manifest 가 낡았거나(새 공통 모듈 미등재)
#   규약 이름으로 적은 정상 선언이 실기록에 있다(차단하면 거짓 차단 → 우회 관성).
_warn=$(printf '%s\n' "$scan" | sed -n 's/^W|//p')
if [ -n "$_warn" ]; then
  echo "FOUNDATION-REUSE: WARN — 재사용 선언이 manifest 의 어떤 모듈명·경로·심볼도 담지 않습니다 (차단 아님)"
  printf '%s\n' "$_warn" | sed 's/|/ → /; s/^/  - /'
  echo "  manifest 에 적힌 이름으로 선언하면 구현자·리뷰어가 그 행(경로·사용법)을 찾습니다: $MANIFEST"
fi
if [ -n "$_nummis" ]; then
  echo "FOUNDATION-REUSE: WARN — 태스크 절 번호와 task id 번호가 어긋납니다 (차단 아님)"
  echo "  - 절: ${_sec_nums% } · id: ${_id_nums% }"
  echo "  선언을 태스크에 대응시킬 수 없어 구현자 컨텍스트에는 선언 없이 manifest 경로만 실립니다 — 절 번호를 task id 에 맞추세요(\`## Task 3\` ↔ \`T3\`)."
fi

echo "FOUNDATION-REUSE: PASS"
exit 0
