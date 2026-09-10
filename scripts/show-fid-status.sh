#!/usr/bin/env bash
# show-fid-status.sh — FID Lifecycle 진행 단계 + 아티팩트 현황 표시
# Usage: bash scripts/show-fid-status.sh <FID>
# specops-ko: FR-1~FR-5 (spec.md §4)
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

# 단계 소요 (20260911-stage-timing-derive) — 원장에서 **도출**한다(새 계측 없음).
#   원장은 prepend(최신 우선)라 정렬이 필수다 — 안 하면 인접 차이가 음수가 된다.
#   날짜→epoch 는 scripts/epoch.sh 재사용(macOS/GNU 분기 소유자). main guard 가 없어
#   source 불가라 인자 호출만 쓰고, **distinct 날짜당 1회**만 부른다(15회 162ms → 2회 ≈22ms 실측).
printf '## 단계 소요\n\n'
_ts_rows=""
if [ -f "$PROGRESS" ] && grep -qE "^## $FID([[:space:]]|$)" "$PROGRESS"; then
  _ts_rows=$(awk "/^## $FID([[:space:]]|\$)/{found=1; next} found && /^## /{exit} found" "$PROGRESS" \
    | grep -oE '^- [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} /[a-z-]+' \
    | sed 's/^- //' | sort)
fi
_ts_n=$(printf '%s' "$_ts_rows" | grep -c . )
if [ "${_ts_n:-0}" -lt 2 ]; then
  printf '  (구간 없음 — 진행 기록 %s행. 소요는 인접 2행부터 계산됩니다)\n\n' "${_ts_n:-0}"
else
  printf '  측정: 완료시각 기준 **인접 행 차이** · **분 해상도** · **경과 시간**이지 작업량이 아닙니다\n'
  printf '        (대기·중단 시간이 포함됩니다 — 사람 응답 대기가 최대 구간인 경우가 실제로 있습니다)\n\n'
  _ts_prev_cmd=""; _ts_prev_min=""
  _ts_cache_date=""; _ts_cache_base=""
  printf '%s\n' "$_ts_rows" | while IFS= read -r _ts_line; do
    [ -n "$_ts_line" ] || continue
    _ts_d=${_ts_line%% *}                      # YYYY-MM-DD
    _ts_rest=${_ts_line#* }                    # HH:MM /command
    _ts_hm=${_ts_rest%% *}                     # HH:MM
    _ts_cmd=${_ts_rest#* }                     # /command
    if [ "$_ts_d" != "$_ts_cache_date" ]; then
      _ts_cache_base=$(bash "$(dirname "${BASH_SOURCE[0]}")/epoch.sh" "${_ts_d}T00:00:00Z" 2>/dev/null)
      _ts_cache_date="$_ts_d"
    fi
    if [ -z "$_ts_cache_base" ]; then
      # 변환 실패를 조용히 건너뛰면 다음 행이 **두 칸 건너뛴 구간**을 인접인 양 출력한다.
      printf '  %-20s → %-20s %8s\n' "$_ts_prev_cmd" "$_ts_cmd" "(변환 실패)"
      _ts_prev_cmd=""; _ts_prev_min=""; continue
    fi
    # 10# 강제 필수 — bash 는 `08`·`09` 를 8진수로 읽어 `value too great for base` 에러를 낸다.
    #   실측(plan-reviewer): 없이 돌리면 `21:09` 에서 죽고 4행 중 1행만 나온다.
    _ts_min=$(( _ts_cache_base / 60 + 10#${_ts_hm%%:*} * 60 + 10#${_ts_hm##*:} ))
    if [ -n "$_ts_prev_cmd" ]; then
      _ts_dm=$(( _ts_min - _ts_prev_min ))
      # `sort` 는 문자열 사전순이고 형식이 고정폭(YYYY-MM-DD HH:MM)이라 정상 데이터에서는
      #   시간순과 일치한다. 그래도 음수를 표에 내지는 않는다 — 손상된 원장 행이 섞이면
      #   `-13m` 이 출력돼 계기판이 거짓말한다(관측 아님, 방어).
      if [ "$_ts_dm" -lt 0 ]; then _ts_fmt="(역순)"
      elif [ "$_ts_dm" -ge 60 ]; then _ts_fmt="$(( _ts_dm / 60 ))h$(( _ts_dm % 60 ))m"
      else _ts_fmt="${_ts_dm}m"; fi
      printf '  %-20s → %-20s %8s\n' "$_ts_prev_cmd" "$_ts_cmd" "$_ts_fmt"
    fi
    _ts_prev_cmd="$_ts_cmd"; _ts_prev_min="$_ts_min"
  done
  printf '\n'
fi

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
