#!/usr/bin/env bash
# command description 라벨 규약 검증 (FID 20260904-design-cmd-scope-desc)
#   ① 대괄호 접두를 쓰는 description 은 YAML 배열 오파싱을 막기 위해 따옴표 필수
#   ② /maintain 은 형제 8건과 동일하게 모드 라벨 접두를 갖는다
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }

# CDL-1: /maintain description 이 모드 라벨 접두를 갖는다 (spec AC-5)
grep -m1 '^description:' "$PLUGIN/commands/maintain.md" | grep -q '\[유지보수·대화형\]' \
  && ok "CDL-1[spec AC-5] /maintain 모드 라벨 접두" || nope "CDL-1[spec AC-5]" "접두 없음 — maintain-lite 와 비대칭"

# CDL-2: 대괄호 접두 description 은 전부 따옴표로 감싼다
#   따옴표가 없으면 YAML 이 `[...]` 를 **배열**로 파싱해 description 이 문자열이 아니게 된다.
_bad=""
for _f in "$PLUGIN"/commands/*.md; do
  _d=$(grep -m1 '^description:' "$_f" 2>/dev/null) || continue
  case "$_d" in
    'description: ['*) _bad="${_bad}${_bad:+ }$(basename "$_f")" ;;
  esac
done
[ -z "$_bad" ] && ok "CDL-2 대괄호 접두 description 따옴표 규약" || nope "CDL-2" "따옴표 없는 대괄호 접두: $_bad"

finish
