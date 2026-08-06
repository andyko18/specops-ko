#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SCRIPT="$PLUGIN/scripts/_internal/init-project.sh"

# T-split.a 임의 cwd 에서 source 시 헬퍼+phase 전 함수 로드 (main 미실행)
out=$(cd /tmp && source "$SCRIPT" 2>/dev/null; type -t _replace_line_prefix; type -t phase_8_artifacts; type -t phase_1_precheck)
if [ "$(printf '%s' "$out" | grep -c '^function$')" = "3" ]; then
  ok "T-split.a source 시 lib+early+artifacts 함수 로드"
else
  nope "T-split.a source 로드" "함수 미로드 (got: $out)"
fi

# T-split.b source 가드 — source 시 main 자동 실행 안 됨 (산출물 생성 없음)
tmpd=$(mktemp -d) || exit 1
( cd "$tmpd" && source "$SCRIPT" 2>/dev/null )
if [ ! -f "$tmpd/CLAUDE.md" ]; then ok "T-split.b source 가드 — main 미자동실행"; else nope "T-split.b 가드" "source 가 main 실행함"; fi
rm -rf "$tmpd"

# ── _parse_numbered 값 정확성 (20260806 init-project 정밀분석) ───────────────
# 실측 결함: 라벨 없는 `N. <값>` 형식이 번호를 벗기지 못해 값에 "1. " 이 그대로 남는다.
#   → PRD.md §1 · CLAUDE.md · README.md · requirements.md FR 시드행까지 전파.
#   기존 테스트는 파일 **존재·개수**만 봐서 이 형식을 먹이고도 전부 PASS 했다(값 미검증).
#   `_phase_4_count_filled` 는 "비어있지 않음"만 세므로 오파싱은 fallback 도 못 깨운다 —
#   silent garbage 경로.
# 두 형식 모두 지원해야 한다: 프롬프트가 보여주는 라벨형 + Phase 0 파이프의 자연스러운 무라벨형.
source "$SCRIPT" 2>/dev/null

_pn() { _parse_numbered "$1" "$2"; }

_LABELED='1. 한 줄 설명: 사내 일정 관리
2. 페르소나: 팀장
4. M1: 로그인'
[ "$(_pn "$_LABELED" 1)" = "사내 일정 관리" ] \
  && ok "T-pn.a 라벨형 — 번호+라벨 제거" || nope "T-pn.a" "got='$(_pn "$_LABELED" 1)'"
[ "$(_pn "$_LABELED" 4)" = "로그인" ] \
  && ok "T-pn.b 라벨형 M1" || nope "T-pn.b" "got='$(_pn "$_LABELED" 4)'"

_BARE='1. 사내 일정 관리
2. 팀장
4. 로그인'
[ "$(_pn "$_BARE" 1)" = "사내 일정 관리" ] \
  && ok "T-pn.c 무라벨형 — 번호 제거 (실측 결함)" || nope "T-pn.c" "got='$(_pn "$_BARE" 1)'"
[ "$(_pn "$_BARE" 4)" = "로그인" ] \
  && ok "T-pn.d 무라벨형 M1" || nope "T-pn.d" "got='$(_pn "$_BARE" 4)'"

# 값에 콜론이 늦게 등장하는 긴 문장은 라벨로 오인해 잘라내면 안 된다
_LONG='1. 사용자가 일정을 등록하고 팀원과 공유하는 서비스인데 목표는 다음과 같다: 빠른 조회'
[ "$(_pn "$_LONG" 1)" = "사용자가 일정을 등록하고 팀원과 공유하는 서비스인데 목표는 다음과 같다: 빠른 조회" ] \
  && ok "T-pn.e 긴 문장 내 콜론 보존 (라벨 오인 금지)" || nope "T-pn.e" "got='$(_pn "$_LONG" 1)'"

# 부재 번호는 빈 문자열
[ -z "$(_pn "$_BARE" 3)" ] && ok "T-pn.f 부재 번호 → 빈 값" || nope "T-pn.f" "got='$(_pn "$_BARE" 3)'"

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" = "0" ]
