#!/usr/bin/env bash
# scan-enrich-placeholders.sh — Phase 11 보강 후 원시 placeholder 스캔 (e2e V21 판정의 SoT)
# 사용: scan-enrich-placeholders.sh <file...>
#   exit 0 = 검출 없음(clean) · exit 1 = 검출 있음(file:line 출력) · exit 2 = 사용 오류
#
# 제외 2계층:
#   ① 줄 단위 — `미확정 — 근거 필요` 마커 줄 (Phase 11 계약상 허용)
#   ② 토큰 단위 — 규약 표기 (채움 대상 아닌 문서 본문 서술; 문맥 포함 매칭이라
#      같은 줄의 실 placeholder 는 검출 유지):
#      .specops/<FID> · screens/<name> · design-screen <name> · <YYYYMMDDHHMMSS>_<description>
#      · <feature> 경로/테스트 표기 · "<UI 기능>" · "<첫 기능>"
#      (`<화면A>`·`<화면B>` 는 화면 목록에서 도출 가능한 실 보강 대상 — 제외하지 않음)
set -u
[ $# -ge 1 ] || { echo "Usage: $0 <file...>" >&2; exit 2; }

out=$(grep -HnE '<[A-Za-z가-힣][^>]{0,40}>' "$@" 2>/dev/null \
  | grep -v '미확정 — 근거 필요' \
  | sed -e 's|\.specops/<FID>|.specops/FID|g' \
        -e 's|screens/<name>|screens/name|g' \
        -e 's|design-screen <name>|design-screen name|g' \
        -e 's|<YYYYMMDDHHMMSS>_<description>|TIMESTAMP_DESCRIPTION|g' \
        -e 's|test-<feature>|test-feature|g' \
        -e 's|src/<feature>|src/feature|g' \
        -e 's|tests/<feature>|tests/feature|g' \
        -e 's|<feature>/|feature/|g' \
        -e 's|"<UI 기능>"|"UI-기능"|g' \
        -e 's|"<첫 기능>"|"첫-기능"|g' \
  | grep -E '<[A-Za-z가-힣][^>]{0,40}>')

[ -z "$out" ] && exit 0
printf '%s\n' "$out"
exit 1
