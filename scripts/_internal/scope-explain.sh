#!/usr/bin/env bash
# scope-explain.sh — "이 커밋은 면제됩니까" 1줄 조회 (C-1, 20260910)
#   Usage: scope-explain.sh '<커밋 명령>'   또는   … | scope-explain.sh
#   출력: SCOPE=staged|conservative EXEMPT=yes|no REASON=<class>(<N> files)
#   판정 로직 사본을 두지 않는다 — 훅과 **같은 함수**를 부른다(#40 이 고친 두-판정기 drift 재발 금지).
#   rc: 0=판정 성공 · 2=입력 없음/읽기 불가 · 3=판정기 로드 불가 (판정 불가는 절대 1줄로 위장하지 않는다)
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# stdin 수집 상한(초). 무한 대기 금지 — 아래 _read_stdin 주석 참조.
STDIN_TIMEOUT_SEC=${SPECOPS_SCOPE_STDIN_TIMEOUT:-2}

_usage() { echo "usage: scope-explain.sh '<커밋 명령>'  또는  … | scope-explain.sh" >&2; }

# stdin 을 타임아웃과 함께 모은다 (여러 줄 입력 보존 — heredoc 커밋 형태가 이 repo 주력이다).
#   왜 `cat` 이 아닌가: `scope-explain.sh <&-` 처럼 fd 0 을 닫고 부르면 **fd 0 이 닫힌 채로 오지 않는다** —
#   쉘이 다음에 여는 파일이 그 자리에 들어앉는다(실측: 어떤 실행에선 일반 파일, 어떤 실행에선 쓰는 쪽이
#   열린 파이프). 후자면 `cat` 이 영원히 블록한다. 행(hang)은 틀린 답보다 나쁘다 — 사용자가 원인을 못 찾는다.
#   그래서 "닫힘을 감지"하지 않고 **읽기를 유한하게** 만든다: 아무것도 오지 않으면 rc=2 로 끝낸다.
#   rc: 0=성공 · 1=EOF 인데 내용 0 · 2=타임아웃
#   ★ 타임아웃 식별이 bash 판올림에 따라 다르다(실측 bash 3.2.57 = macOS 기본): bash 4+ 는 rc>128 로
#     알려주지만 **3.2 는 타임아웃도 rc=1** 이라 EOF 와 구별되지 않는다. rc 만 믿으면 "행을 막았다"는
#     보고가 원인을 EOF 로 잘못 적는다. 그래서 경과시간(`SECONDS`)을 함께 본다.
_read_stdin() {
  local line acc="" rc _NL=$'\n' _t0=$SECONDS
  while :; do
    IFS= read -r -t "$STDIN_TIMEOUT_SEC" line; rc=$?
    if [ "$rc" -eq 0 ]; then acc="$acc$line$_NL"; _t0=$SECONDS; continue; fi
    [ -n "$line" ] && acc="$acc$line$_NL"     # EOF 직전 개행 없는 마지막 조각
    [ "$rc" -gt 128 ] && return 2                                  # bash 4+
    [ $((SECONDS - _t0)) -ge "$STDIN_TIMEOUT_SEC" ] && return 2    # bash 3.2 (rc=1 로 옴)
    break
  done
  [ -n "$acc" ] || return 1
  printf '%s' "$acc"
}

# ── 판정기 로드: 실패하면 **답하지 않는다** ────────────────────────────────
#   왜 fail-open 이 아닌가: 이 도구의 존재 이유가 "훅이 내릴 판정을 미리 알려주는 것"이다.
#   라이브러리를 못 읽고도 그럴듯한 1줄을 뱉으면 **판정 불가를 판정으로 위장**한다 —
#   사용자는 그 답을 믿고 커밋했다가 훅에 막힌다. 정상 조회의 rc=0 계약(AC-5)은 그대로다.
LIB="$PLUGIN/hooks/governance-lib.sh"
if [ ! -r "$LIB" ]; then
  printf 'scope-explain: 판정 불가 — governance-lib.sh 를 읽을 수 없다 (%s)\n' "$LIB" >&2
  exit 3
fi
# shellcheck source=/dev/null
if ! . "$LIB"; then
  printf 'scope-explain: 판정 불가 — governance-lib.sh 로드 실패 (%s)\n' "$LIB" >&2
  exit 3
fi
for _fn in _commit_scope_is_staged is_docs_only_change _commit_scope_class; do
  if ! declare -F "$_fn" >/dev/null 2>&1; then
    printf 'scope-explain: 판정 불가 — 판정 함수 미정의 (%s)\n' "$_fn" >&2
    exit 3
  fi
done

cmd="${1:-}"
if [ -z "$cmd" ]; then
  [ -t 0 ] && { _usage; exit 2; }
  cmd=$(_read_stdin); _rc=$?
  if [ "$_rc" -eq 2 ]; then
    echo "scope-explain: stdin 을 ${STDIN_TIMEOUT_SEC}초 안에 읽지 못했다 — 판정 불가" >&2
    _usage; exit 2
  fi
  if [ -z "$cmd" ]; then
    echo "scope-explain: 입력이 비었다 (인자·stdin 모두 없음) — 판정 불가" >&2
    _usage; exit 2
  fi
fi

if _commit_scope_is_staged "$cmd"; then scope=staged; else scope=conservative; fi
if is_docs_only_change "$cmd"; then exempt=yes; else exempt=no; fi
files=${_SPECOPS_SCOPE_FILES:-}
n=$(printf '%s' "$files" | grep -c . 2>/dev/null || true)
[ -n "$files" ] || n=0
class=$(_commit_scope_class "$files")
[ -n "$class" ] || class="판정불가"
printf 'SCOPE=%s EXEMPT=%s REASON=%s(%s files)\n' "$scope" "$exempt" "$class" "$n"
exit 0
