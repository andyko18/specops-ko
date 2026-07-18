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
# 20260719: frontier 사다리·reconcile 로직은 scripts/_internal/reconcile-check.sh 로 추출(단일 SoT).
#   SessionStart 훅도 동일 스크립트(--hook 모드)로 재개 desync 를 자동표면화 — 사다리 변경 시 drift 방지.
_RC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_internal/reconcile-check.sh"
SPECOPS_ROOT="$SPECOPS" bash "$_RC" "$FID"
