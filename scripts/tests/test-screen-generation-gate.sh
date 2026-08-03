#!/usr/bin/env bash
# test-screen-generation-gate.sh — 화면 생성 지시 2경로의 껍데기 판정 앵커 검증
# AC-3(Phase 2.5 재사용 판정) · AC-4(Step 5.5 판정 + 채움 요건) · AC-12 ③(마커 제거 명시)
set -u

PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
BATCH="$PLUGIN/commands/start-all.md"
SPECIFY="$PLUGIN/skills/specifying-ko/SKILL.md"
PASS=0; FAIL=0

# T1: Phase 2.5 — 구 판정 문구 부재 (AC-3, 양방향 단언 ①)
[ "$(grep -cF '경로가 이미 인용돼 있으면 재사용' "$BATCH")" -eq 0 ] \
  && ok  "T1.a start-all.md 구 재사용 문구('경로가 이미 인용') 부재" \
  || nope "T1.a 구 문구 부재" "경로 존재 기반 재사용 판정이 잔존"

# T1.b: 신 판정 문구 존재 — grep -c 로 정확히 1회 (tautology 방지)
[ "$(grep -cF 'design-screen.sh --check' "$BATCH")" -eq 1 ] \
  && ok  "T1.b start-all.md 에 --check 판정 호출 정확히 1회" \
  || nope "T1.b --check 판정 호출" "count=$(grep -cF 'design-screen.sh --check' "$BATCH")"

grep -qF '재사용 금지' "$BATCH" \
  && ok  "T1.c 껍데기 시 재사용 금지 + 재생성 경로 명시" \
  || nope "T1.c 재생성 경로" "'재사용 금지' 앵커 없음"

# T1.d: batch Step 5.5 SKIP 계약 (프로세스 축소 — Phase 2.5 단일 화면 경로)
grep -qE 'Step 5\.5 SKIP' "$BATCH" && grep -qE 'Step 5\.5.*SKIP|5\.5 SKIP' "$SPECIFY" \
  && ok  "T1.d batch Step 5.5 SKIP (start-all + specifying)" \
  || nope "T1.d batch 5.5 skip" "SKIP 앵커 부재"

# T2: Step 5.5 — 동일 판정 (AC-4 ①)
[ "$(grep -cF 'design-screen.sh --check' "$SPECIFY")" -eq 1 ] \
  && ok  "T2.a specifying-ko 에 --check 판정 호출 정확히 1회" \
  || nope "T2.a Step 5.5 판정" "count=$(grep -cF 'design-screen.sh --check' "$SPECIFY")"

# T2.b: 필수 섹션 완성 요건 (AC-4 ② — lifecycle 안/밖 비대칭 해소)
grep -qF '필수 8섹션' "$SPECIFY" \
  && ok  "T2.b Step 5.5 에 .md 필수 8섹션 완성 요건 명시" \
  || nope "T2.b 채움 요건" "'필수 8섹션' 앵커 없음 — 비대칭 잔존"

# T3: 마커 제거 명시 (AC-12 ③) — 두 경로 모두
for f in "$BATCH" "$SPECIFY"; do
  n=$(basename "$f")
  grep -qF '마커 줄을 삭제' "$f" \
    && ok  "T3.$n 마커 제거 지시 명시" \
    || nope "T3.$n 마커 제거 지시" "'마커 줄을 삭제' 앵커 없음"
done

finish
