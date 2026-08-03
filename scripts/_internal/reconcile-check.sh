#!/usr/bin/env bash
# reconcile-check.sh — 기록 frontier ↔ 증거 frontier 대조 (show-fid-status FR-6 추출·공유 SoT)
# Usage: reconcile-check.sh <FID> [--hook]
#   default : '## 실제 진행 대조 (reconcile)' 블록 출력 — show-fid-status 가 위임(출력 byte-동일)
#   --hook  : DESYNC 시에만 간결 경고+재개점 1줄 출력, 정합/무효 FID/디렉토리 부재 시 무출력·exit 0
#             (SessionStart 훅이 재개 desync 를 자동표면화 — dogfood test1 FR-3 의 24h 오판 정체 방지)
# 배경: 정체 후 재개 시 session-progress 단독은 현실을 과소보고한다(주 breadcrumb 만 읽으면 "미구현"
#   오판). git·dispatch·산출물로 진짜 frontier 를 계산해 desync 를 경고하고 재개점을 준다.
set -u

FID="${1:-}"
MODE="${2:-}"
SPECOPS="${SPECOPS_ROOT:-.specops}"
PROGRESS="$SPECOPS/session-progress.md"
FID_DIR="$SPECOPS/$FID"
STATE_SH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/verification-state.sh"

# --hook 은 훅 additionalContext 주입용 — 무효 FID/디렉토리 부재는 silent (훅 출력 오염 금지)
if [ "$MODE" = "--hook" ]; then
  printf '%s' "$FID" | grep -qE '^[0-9]{8}-[a-z0-9-]+$' || exit 0
  [ -d "$FID_DIR" ] || exit 0
fi

# 단계 rank (유지보수 analyze=5·specify=10·clarify=20·plan=30·tasks=40·implement=50·verify=60·review=70·finishing=80)
_stage_name() { case "$1" in 5) echo analyze;; 10) echo specify;; 20) echo clarify;; 30) echo plan;; 40) echo tasks;; 50) echo implement;; 60) echo verify;; 70) echo review;; 80) echo finishing;; *) echo "-";; esac; }
_stage_next() { case "$1" in 5) echo 10;; 10) echo 20;; 20) echo 30;; 30) echo 40;; 40) echo 50;; 50) echo 60;; 60) echo 70;; 70) echo 80;; *) echo 999;; esac; }

# 기록 frontier — session-progress FID 섹션에서 등장한 최고 단계
recorded=0
if [ -f "$PROGRESS" ] && grep -qE "^## $FID([[:space:]]|$)" "$PROGRESS"; then
  section=$(awk "/^## $FID([[:space:]]|\$)/{f=1;next} f&&/^## /{exit} f{print}" "$PROGRESS")
  printf '%s' "$section" | grep -qE '/analyze' && recorded=5
  printf '%s' "$section" | grep -qE '/specify' && [ "$recorded" -lt 10 ] && recorded=10
  printf '%s' "$section" | grep -qE '/clarify' && [ "$recorded" -lt 20 ] && recorded=20
  printf '%s' "$section" | grep -qE '/plan' && [ "$recorded" -lt 30 ] && recorded=30
  printf '%s' "$section" | grep -qE '/tasks' && [ "$recorded" -lt 40 ] && recorded=40
  printf '%s' "$section" | grep -qE '/implement' && [ "$recorded" -lt 50 ] && recorded=50
  printf '%s' "$section" | grep -qE '/verify' && [ "$recorded" -lt 60 ] && recorded=60
  printf '%s' "$section" | grep -qE '/(request-review|receive-review|review)' && [ "$recorded" -lt 70 ] && recorded=70
  printf '%s' "$section" | grep -qE '/finishing|/lifecycle' && [ "$recorded" -lt 80 ] && recorded=80
fi

# 증거 frontier — 파일시스템 산출물 + git 브랜치 커밋
evidence=0
{ [ -f "$FID_DIR/current-state.md" ] || [ -f "$FID_DIR/impact-analysis.md" ]; } && evidence=5
[ -f "$FID_DIR/spec.md" ] && [ "$evidence" -lt 10 ] && evidence=10
[ -f "$FID_DIR/clarifications.md" ] && [ "$evidence" -lt 20 ] && evidence=20
[ -f "$FID_DIR/plan.md" ] && [ "$evidence" -lt 30 ] && evidence=30
[ -f "$FID_DIR/tasks.md" ] && [ "$evidence" -lt 40 ] && evidence=40
impl_ev=0
[ -f "$FID_DIR/dispatch-log.md" ] && grep -qE 'DONE|IMPL' "$FID_DIR/dispatch-log.md" 2>/dev/null && impl_ev=1
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  base=$(git show-ref --verify --quiet refs/heads/main && echo main || { git show-ref --verify --quiet refs/heads/master && echo master; })
  if [ -n "$base" ] && git show-ref --verify --quiet "refs/heads/feat/$FID"; then
    n=$(git rev-list --count "$base..feat/$FID" 2>/dev/null || echo 0)
    [ "${n:-0}" -gt 0 ] 2>/dev/null && impl_ev=1
  fi
fi
[ "$impl_ev" -eq 1 ] && [ "$evidence" -lt 50 ] && evidence=50
verify_complete=0
if [ -f "$FID_DIR/verification-state.json" ] && [ -f "$STATE_SH" ]; then
  verify_verdict=$(SPECOPS_ROOT="$SPECOPS" bash "$STATE_SH" current "$FID" 2>/dev/null || echo NOT_RUN)
  case "$verify_verdict" in PASS|WAIVED) verify_complete=1 ;; esac
elif [ -s "$FID_DIR/evidence.md" ]; then
  # 기존 FID 읽기 호환: 구조화 상태가 없는 과거 evidence는 기존 frontier 의미를 유지한다.
  verify_complete=1
fi
[ "$verify_complete" -eq 1 ] && [ "$evidence" -lt 60 ] && evidence=60
{ [ -f "$FID_DIR/review-request.md" ] || { [ -d "$FID_DIR/reviews" ] && [ -n "$(ls -A "$FID_DIR/reviews" 2>/dev/null)" ]; }; } && [ "$evidence" -lt 70 ] && evidence=70

# ── --hook 모드: DESYNC 시에만 간결 1줄 (정합 시 무출력) ──
if [ "$MODE" = "--hook" ]; then
  if [ "$evidence" -gt "$recorded" ]; then
    printf '⚠️ 재개 DESYNC — session-progress 가 실제 진행보다 과소보고 중. 기록 frontier=%s, 증거 frontier=%s (산출물/dispatch/git 이 더 진행됨). → 재개점: %s 부터. 미기록 구간(%s~%s)은 session-progress-append.sh 로 보정할 것.\n' \
      "$(_stage_name "$recorded")" "$(_stage_name "$evidence")" \
      "$(_stage_name "$(_stage_next "$evidence")")" \
      "$(_stage_name "$(_stage_next "$recorded")")" "$(_stage_name "$evidence")"
  fi
  exit 0
fi

# ── default 모드: show-fid-status 위임 (출력 byte-동일) ──
printf '\n## 실제 진행 대조 (reconcile)\n\n'
if [ "$evidence" -gt "$recorded" ]; then
  printf '  \xe2\x9a\xa0\xef\xb8\x8f  DESYNC — session-progress 과소보고\n'
  printf '     기록 frontier: %s (단계 %s)\n' "$(_stage_name "$recorded")" "$recorded"
  printf '     증거 frontier: %s (단계 %s) — 산출물/dispatch/git 이 더 진행됨\n' "$(_stage_name "$evidence")" "$evidence"
  printf '     → 재개점: %s 부터 (증거상 %s 까지 완료 — 그 다음 단계).\n' \
    "$(_stage_name "$(_stage_next "$evidence")")" "$(_stage_name "$evidence")"
  printf '     → 먼저 기록 보정: %s~%s 단계가 실제 완료됐으나 session-progress 미기록 — session-progress-append.sh 로 채울 것.\n' \
    "$(_stage_name "$(_stage_next "$recorded")")" "$(_stage_name "$evidence")"
else
  printf '  \xe2\x9c\x85 정합 — 기록(%s) = 증거(%s)\n' "$(_stage_name "$recorded")" "$(_stage_name "$evidence")"
fi
