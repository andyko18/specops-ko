#!/usr/bin/env bash
# fr-set-fid.sh — requirements.md FR 행의 `관련 spec` 칸에 FID 를 적는다 (20261009)
# Usage:
#   fr-set-fid.sh <FID> <FR-ID> [<FR-ID>...]   그 FR 행들의 마지막 칸에 FID 를 적는다
#   fr-set-fid.sh --pending-foundation         공통부 FR(`[공통]`·`foundation-fr`) 중 마지막 칸이 빈 것의 ID 를 한 줄씩
# Exit: 0 = 전부 처리(이미 적힌 것 포함) · 1 = 일부 FR 을 못 찾음·칸 없음 · 2 = 사용법·파일 부재
#
# 왜: 공통부 FR 은 `/start-all` queue 에서 SKIP 되어(구현은 `/start-foundation`) queue 의 FID 칸이 없다.
#   요구사항 표의 `관련 spec` 칸도 아무도 채우지 않아, 공통부를 다 만든 뒤에도 그 FR 들이 `(TBD)` 로 남았다
#   (실기록: foundation 완료 한 달 뒤에도 공통 FR 8건 전부 `(TBD)`) — 어느 FID 가 어느 FR 을 만들었는지 표에서 찾을 수 없다.
#
# 쓰는 규칙(사용자 문서를 고치므로 좁게):
#   - 줄 시작 `|` 인 FR 행만(첫 칸의 굵게·백틱 장식은 벗겨 읽는다 — check-fr-table.sh 와 같은 범위).
#   - **마지막 칸만** 바꾼다. 빈칸·`(TBD)`·`TBD`·`-`·`—` 면 FID 로 바꾸고, 다른 값이 있으면 뒤에 ` · <FID>` 를 덧붙인다
#     (한 FR 을 여러 FID 가 다룬 실기록 표기와 같다). 이미 그 FID 가 있으면 그대로 둔다.
#   - 칸이 5개 미만인 행에는 쓰지 않는다(`| ID | 요구사항 | 마일스톤 | 우선순위 | 관련 spec |` 꼴이 아니다).
#     칸 안의 `|`(`\|` 이스케이프 · 백틱 안)는 구분자로 세지 않는다.
#   - 코드펜스 안의 행은 표가 아니다(예시 행을 고치지 않는다).
#   - 지정한 행 밖은 한 바이트도 바꾸지 않는다(CRLF·끝 공백·파일 끝 개행 유무 보존).
set -u

SPECOPS="${SPECOPS_ROOT:-.specops}"
REQ="$SPECOPS/memory/requirements.md"
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)

_usage() {
  echo "usage: $0 <FID> <FR-ID>... | --pending-foundation" >&2
  exit 2
}

[ $# -ge 1 ] || _usage
[ -f "$REQ" ] || { echo "FR-SET-FID: MISSING ($REQ 부재)" >&2; exit 2; }

# 표 행 읽기의 공용 부분(awk) — 읽는 쪽(_rows)과 쓰는 쪽이 같은 규칙을 쓴다.
#   mask(): 칸 구분자가 아닌 `|` 를 같은 길이의 다른 글자로 가린 사본을 만든다 — `\|`(이스케이프)와 백틱 안의 `|`.
#     길이가 같으므로 사본에서 찾은 위치를 원문에 그대로 쓴다(원문은 한 바이트도 다시 조립하지 않는다).
#   lastcell(): 마지막 칸의 시작·끝 위치(P1 = 칸을 여는 `|` · P2 = 칸을 닫는 `|` 또는 줄 끝+1)와 칸 수(NC)를 낸다.
#   infence(): 코드펜스 안의 행은 표가 아니다(예시로 적은 `| FR-1 | … |` 를 고치지 않는다).
_AWK_LIB='
  function trim(v) { gsub(/^[ \t]+|[ \t\r]+$/, "", v); return v }
  function mask(line,   m, i, ch, inbt, out) {
    out = ""; inbt = 0
    for (i = 1; i <= length(line); i++) {
      ch = substr(line, i, 1)
      if (ch == "\\" && substr(line, i + 1, 1) == "|") { out = out "\001\001"; i++; continue }
      if (ch == "`") { inbt = !inbt; out = out ch; continue }
      if (ch == "|" && inbt) { out = out "\001"; continue }
      out = out ch
    }
    return out
  }
  function lastcell(m,   i, n, c) {
    P2 = length(m) + 1; CLOSED = 0
    if (substr(m, length(m), 1) == "|") { P2 = length(m); CLOSED = 1 }
    P1 = 0
    for (i = P2 - 1; i >= 1; i--) if (substr(m, i, 1) == "|") { P1 = i; break }
    n = split(m, c, "|"); NC = n - 1 - CLOSED
  }
  function infence(line,   l) {
    l = line; sub(/^[ \t]+/, "", l)
    if (l ~ /^(```|~~~)/) { FENCE = !FENCE; return 1 }
    return FENCE
  }
'

# FR 행의 `ID<US>칸 수<US>마지막 칸` — 첫 칸 장식 제거
_rows() {
  LC_ALL=C awk "$_AWK_LIB"'
    { line = $0; sub(/[ \t\r]+$/, "", line) }
    infence(line) { next }
    line ~ /^\|/ {
      m = mask(line); lastcell(m)
      split(m, c, "|"); id = c[2]; gsub(/[`*]/, "", id); id = trim(id)
      if (id !~ /^FR-[0-9][0-9A-Za-z]*$/) next
      printf "%s\037%d\037%s\n", id, NC, trim(substr(line, P1 + 1, P2 - P1 - 1))
    }' "$REQ"
}

_is_empty_cell() {
  case "$1" in ""|"(TBD)"|"TBD"|"tbd"|"-"|"—"|"(미정)") return 0 ;; *) return 1 ;; esac
}

if [ "$1" = "--pending-foundation" ]; then
  CLS="$PLUGIN/scripts/_internal/check-fr-table.sh"
  [ -f "$CLS" ] || exit 0
  ids=$(bash "$CLS" --classify "$REQ" 2>/dev/null | awk -F'|' '$1 == "SKIP" && $3 == "foundation-scope" { print $2 }')
  [ -n "$ids" ] || exit 0
  rows=$(_rows)
  printf '%s\n' "$ids" | while IFS= read -r id; do
    [ -n "$id" ] || continue
    cell=$(printf '%s\n' "$rows" | awk -F'\037' -v id="$id" '$1 == id { print $3; exit }')
    _is_empty_cell "$cell" && printf '%s\n' "$id"
  done
  exit 0
fi

FID="$1"; shift
printf '%s' "$FID" | grep -qE '^[0-9]{8}-[A-Za-z0-9][A-Za-z0-9._-]*$' || { echo "FR-SET-FID: FID 꼴이 아니다 — '$FID' (YYYYMMDD-slug)" >&2; exit 2; }
[ $# -ge 1 ] || _usage

rows=$(_rows)
rc=0
for fr in "$@"; do
  fr=$(printf '%s' "$fr" | tr -d '`*[:space:]')
  hit=$(printf '%s\n' "$rows" | awk -F'\037' -v id="$fr" '$1 == id { print $2 "\037" $3; exit }')
  if [ -z "$hit" ]; then
    echo "FR-SET-FID: $fr — 요구사항 표에 그 행이 없다(줄 시작 | FR-<숫자> | 꼴만 읽는다)" >&2; rc=1; continue
  fi
  ncell=${hit%%$'\037'*}; cell=${hit#*$'\037'}
  if [ "$ncell" -lt 5 ]; then
    echo "FR-SET-FID: $fr — 칸이 ${ncell}개뿐이라 \`관련 spec\` 칸이 없다. 표 꼴: | ID | 요구사항 | 마일스톤 | 우선순위 | 관련 spec |" >&2; rc=1; continue
  fi
  case " $(printf '%s' "$cell" | tr '·,`|\\' '     ') " in
    *" $FID "*) echo "FR-SET-FID: $fr — 이미 $FID"; continue ;;
  esac
  if _is_empty_cell "$cell"; then new="$FID"; else new="$cell · $FID"; fi
  [ -w "$REQ" ] || { echo "FR-SET-FID: $fr — $REQ 에 쓸 수 없다(읽기 전용)" >&2; rc=1; continue; }
  tmp=$(mktemp "${TMPDIR:-/tmp}/fr-set-fid.XXXXXX") || { echo "FR-SET-FID: 임시 파일을 만들 수 없다" >&2; exit 2; }
  if LC_ALL=C FR="$fr" NEW="$new" awk "$_AWK_LIB"'
      BEGIN { fr = ENVIRON["FR"]; newv = ENVIRON["NEW"]; done = 0 }
      {
        raw = $0; line = raw; cr = ""
        if (line ~ /\r$/) { cr = "\r"; sub(/\r$/, "", line) }
        tail = ""; if (match(line, /[ \t]+$/)) { tail = substr(line, RSTART); line = substr(line, 1, RSTART - 1) }
        if (infence(line)) { print raw; next }
        if (!done && line ~ /^\|/) {
          m = mask(line); lastcell(m)
          split(m, c, "|"); id = c[2]; gsub(/[`*]/, "", id); id = trim(id)
          if (id == fr && P1 > 0) {
            print substr(line, 1, P1) " " newv " " (CLOSED ? "|" : "") tail cr
            done = 1; next
          }
        }
        print raw
      }
      END { exit(done ? 0 : 1) }' "$REQ" > "$tmp"; then
    # 원문이 개행 없이 끝났으면 그대로 개행 없이 끝낸다(awk 는 마지막 줄에 개행을 붙인다)
    if [ -n "$(tail -c 1 "$REQ" 2>/dev/null)" ]; then
      printf '%s' "$(cat "$tmp")" > "$tmp.n" && mv "$tmp.n" "$tmp"
    fi
    # 내용만 바꿔 쓴다(mv 로 바꾸면 심볼릭 링크·권한이 끊긴다). 쓰기가 실패하면 성공이라 하지 않는다.
    if cat "$tmp" > "$REQ" 2>/dev/null; then
      echo "FR-SET-FID: $fr ← $new"
    else
      echo "FR-SET-FID: $fr — $REQ 에 쓰지 못했다" >&2; rc=1
    fi
    rm -f "$tmp"
  else
    rm -f "$tmp"
    echo "FR-SET-FID: $fr — 행을 고치지 못했다" >&2; rc=1
  fi
done
exit "$rc"
