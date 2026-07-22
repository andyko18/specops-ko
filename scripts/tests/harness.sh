#!/usr/bin/env bash
# specops-ko 공통 테스트 하네스 — PASS/FAIL 카운터 표준 헬퍼 (통일 출력 포맷)
#
# 사용: 호출 측 PLUGIN 변수 정의 후
#   source "$PLUGIN/scripts/tests/harness.sh"
#
# 카운터는 `: "${PASS:=0}"` 로 초기화 — 호출 측이 `PASS=0; FAIL=0` 을 source 전에
# 선언했어도 보존(0), 미선언이면 0 시작. 집계는 호출 측이 유지하거나 finish 사용.
#
# 헬퍼 시그니처:
#   ok   "<desc>"            → PASS++ , "PASS <desc>"
#   fail "<desc>"            → FAIL++ , "FAIL <desc>"
#   nope "<desc>" [<detail>] → FAIL++ , "FAIL <desc> — <detail>"  (detail 없으면 "FAIL <desc>")
#   run  "<desc>" <cmd...>   → cmd 성공 시 ok, 실패 시 fail (stderr 억제)
#   finish                   → "PASS=N FAIL=M" 출력 + FAIL==0 이면 exit 0, 아니면 1
#
# ⚠️ source 직후 로드 가드 필수: `command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }`

: "${PASS:=0}"
: "${FAIL:=0}"

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1"; }
nope() { FAIL=$((FAIL+1)); echo "FAIL $1${2:+ — $2}"; }
run()  { local d="$1"; shift; if "$@" 2>/dev/null; then ok "$d"; else fail "$d"; fi; }
finish() { echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
