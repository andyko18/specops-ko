#!/usr/bin/env bash
# show-fid-status.sh — FID Lifecycle 진행 단계 + 아티팩트 현황 표시
# Usage: bash scripts/show-fid-status.sh <FID>
# specops-auto-ko: FR-1~FR-5 (spec.md §4)
set -u

FID="${1:-}"

# 테스트 환경 오버라이드 (SPECOPS_ROOT 미설정 시 기본 .specops)
SPECOPS="${SPECOPS_ROOT:-.specops}"
PROGRESS="$SPECOPS/session-progress.md"

# FR-1: FID 형식 검증 (^\d{8}-[a-z0-9-]+$)
if ! printf '%s' "$FID" | grep -qE '^[0-9]{8}-[a-z0-9-]+$'; then
  printf 'Error: FID 형식 오류 — 올바른 형식: YYYYMMDD-kebab-slug (got: %s)\n' "${FID:-<비어있음>}" >&2
  exit 1
fi

# FR-3: FID 디렉토리 확인
FID_DIR="$SPECOPS/$FID"
if [ ! -d "$FID_DIR" ]; then
  printf 'Error: FID 디렉토리 없음 — %s\n' "$FID_DIR" >&2
  exit 1
fi

# 헤더 출력
printf '=== FID: %s ===\n\n' "$FID"

# FR-2 / FR-5: session-progress.md에서 FID 섹션 추출
# FID는 위에서 [0-9a-z-] 로 검증됨 — grep/awk regex 메타문자 없음
printf '## Lifecycle 진행 이력\n\n'
if [ ! -f "$PROGRESS" ]; then
  printf '(진행 이력 없음)\n'
elif grep -qE "^## $FID([[:space:]]|$)" "$PROGRESS"; then
  awk "/^## $FID([[:space:]]|\$)/{found=1; next} found && /^## /{exit} found && NF{print}" "$PROGRESS"
else
  printf '(진행 이력 없음)\n'
fi

printf '\n'

# FR-4: 아티팩트 현황
printf '## 아티팩트 현황\n\n'
for artifact in spec.md acceptance-criteria.md plan.md tasks.md evidence.md; do
  if [ -f "$FID_DIR/$artifact" ]; then
    printf '  \xe2\x9c\x85 %s\n' "$artifact"
  else
    printf '  \xe2\x9d\x8c %s\n' "$artifact"
  fi
done

# FR-6 (20260718-status-reconcile): 기록 frontier ↔ 실제 증거(산출물·dispatch·git) 대조.
#   정체 후 재개 시 session-progress 단독은 현실을 과소보고한다 — dogfood test1 FR-3: /tasks 기록
#   상태에서 12커밋+dispatch T7까지 존재했으나, 주 breadcrumb 만 읽으면 "구현 안 됨"으로 오판돼
#   24h+ 방치됐다(실제 잔여 작업은 5분). 진짜 frontier 를 계산해 desync 를 경고하고 재개점을 준다.
_stage_name() { case "$1" in 1) echo specify;; 2) echo clarify;; 3) echo plan;; 4) echo tasks;; 5) echo implement;; 6) echo verify;; 7) echo review;; 8) echo finishing;; *) echo "-";; esac; }

# 기록 frontier — session-progress FID 섹션에서 등장한 최고 단계
recorded=0
if [ -f "$PROGRESS" ] && grep -qE "^## $FID([[:space:]]|$)" "$PROGRESS"; then
  section=$(awk "/^## $FID([[:space:]]|\$)/{f=1;next} f&&/^## /{exit} f{print}" "$PROGRESS")
  printf '%s' "$section" | grep -qE '/specify' && recorded=1
  printf '%s' "$section" | grep -qE '/clarify' && [ "$recorded" -lt 2 ] && recorded=2
  printf '%s' "$section" | grep -qE '/plan' && [ "$recorded" -lt 3 ] && recorded=3
  printf '%s' "$section" | grep -qE '/tasks' && [ "$recorded" -lt 4 ] && recorded=4
  printf '%s' "$section" | grep -qE '/implement' && [ "$recorded" -lt 5 ] && recorded=5
  printf '%s' "$section" | grep -qE '/verify' && [ "$recorded" -lt 6 ] && recorded=6
  printf '%s' "$section" | grep -qE '/(request-review|receive-review|review)' && [ "$recorded" -lt 7 ] && recorded=7
  printf '%s' "$section" | grep -qE '/finishing|/lifecycle' && [ "$recorded" -lt 8 ] && recorded=8
fi

# 증거 frontier — 파일시스템 산출물 + git 브랜치 커밋
evidence=0
[ -f "$FID_DIR/spec.md" ] && evidence=1
[ -f "$FID_DIR/clarifications.md" ] && [ "$evidence" -lt 2 ] && evidence=2
[ -f "$FID_DIR/plan.md" ] && [ "$evidence" -lt 3 ] && evidence=3
[ -f "$FID_DIR/tasks.md" ] && [ "$evidence" -lt 4 ] && evidence=4
# implement 증거: dispatch-log 에 DONE 행 OR feat/<FID> 브랜치 커밋 존재
impl_ev=0
[ -f "$FID_DIR/dispatch-log.md" ] && grep -qE 'DONE|IMPL' "$FID_DIR/dispatch-log.md" 2>/dev/null && impl_ev=1
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  base=$(git show-ref --verify --quiet refs/heads/main && echo main || { git show-ref --verify --quiet refs/heads/master && echo master; })
  if [ -n "$base" ] && git show-ref --verify --quiet "refs/heads/feat/$FID"; then
    n=$(git rev-list --count "$base..feat/$FID" 2>/dev/null || echo 0)
    [ "${n:-0}" -gt 0 ] 2>/dev/null && impl_ev=1
  fi
fi
[ "$impl_ev" -eq 1 ] && [ "$evidence" -lt 5 ] && evidence=5
# verify 증거: evidence.md 가 존재하고 PASS stamp 또는 비어있지 않음
[ -s "$FID_DIR/evidence.md" ] && [ "$evidence" -lt 6 ] && evidence=6
# review 증거: review-request.md 또는 reviews/ 비어있지 않음
{ [ -f "$FID_DIR/review-request.md" ] || { [ -d "$FID_DIR/reviews" ] && [ -n "$(ls -A "$FID_DIR/reviews" 2>/dev/null)" ]; }; } && [ "$evidence" -lt 7 ] && evidence=7

printf '\n## 실제 진행 대조 (reconcile)\n\n'
if [ "$evidence" -gt "$recorded" ]; then
  printf '  \xe2\x9a\xa0\xef\xb8\x8f  DESYNC — session-progress 과소보고\n'
  printf '     기록 frontier: %s (단계 %s)\n' "$(_stage_name "$recorded")" "$recorded"
  printf '     증거 frontier: %s (단계 %s) — 산출물/dispatch/git 이 더 진행됨\n' "$(_stage_name "$evidence")" "$evidence"
  printf '     → 재개점: %s 부터 (증거상 %s 까지 완료 — 그 다음 단계).\n' \
    "$(_stage_name $((evidence+1)))" "$(_stage_name "$evidence")"
  printf '     → 먼저 기록 보정: %s~%s 단계가 실제 완료됐으나 session-progress 미기록 — session-progress-append.sh 로 채울 것.\n' \
    "$(_stage_name $((recorded+1)))" "$(_stage_name "$evidence")"
else
  printf '  \xe2\x9c\x85 정합 — 기록(%s) = 증거(%s)\n' "$(_stage_name "$recorded")" "$(_stage_name "$evidence")"
fi
