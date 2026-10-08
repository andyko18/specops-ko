#!/usr/bin/env bash
# init-batch-queue.sh — Phase 0 queue.md 기계 초기화 (20260812)
# Usage: init-batch-queue.sh <batch-dir> [requirements-path]
# Exit: 0 = CREATED|REUSE · 1 = FAIL · 2 = usage
#
# 왜: check-fr-table --classify 는 ELIGIBLE/SKIP 을 이미 내지만, queue.md 표는
#   산문 지시만 있어 모델이 시드·공통을 PENDING 에 넣거나 헤더를 빼먹을 수 있다.
#   신규 batch 만 작성하고, 기존 queue 는 재개 규약상 덮어쓰지 않는다.
set -u

BATCH_DIR="${1:-}"
REQ="${2:-}"
SELF=$(cd "$(dirname "$0")" && pwd)
CHK="$SELF/check-fr-table.sh"

usage() {
  echo "usage: $0 <batch-dir> [requirements-path]" >&2
  exit 2
}

[ -n "$BATCH_DIR" ] || usage
[ -x "$CHK" ] || [ -f "$CHK" ] || {
  echo "QUEUE-INIT: FAIL — check-fr-table.sh 부재: $CHK" >&2
  exit 1
}

mkdir -p "$BATCH_DIR" || {
  echo "QUEUE-INIT: FAIL — batch-dir 생성 실패: $BATCH_DIR"
  exit 1
}

QUEUE="$BATCH_DIR/queue.md"
BATCH_NAME=$(basename "$BATCH_DIR")

if [ -f "$QUEUE" ]; then
  echo "QUEUE-INIT: REUSE ($QUEUE)"
  exit 0
fi

if [ -z "$REQ" ]; then
  for c in ".specops/memory/requirements.md" "requirements.md"; do
    [ -f "$c" ] && { REQ="$c"; break; }
  done
fi
[ -n "$REQ" ] && [ -f "$REQ" ] || {
  echo "QUEUE-INIT: FAIL — requirements.md 부재"
  exit 1
}

classify_raw=$(bash "$CHK" --classify "$REQ" 2>&1)
cls_rc=$?
if [ "$cls_rc" -ne 0 ]; then
  echo "QUEUE-INIT: FAIL — check-fr-table --classify rc=$cls_rc"
  printf '%s\n' "$classify_raw" | sed 's/^/  /'
  exit 1
fi

summary=$(printf '%s\n' "$classify_raw" | grep -E '^SUMMARY\|' | tail -1)
[ -n "$summary" ] || {
  echo "QUEUE-INIT: FAIL — SUMMARY 줄 없음"
  exit 1
}

# SUMMARY|real=N|eligible=N|...
real=$(printf '%s' "$summary" | sed -n 's/.*real=\([0-9]*\).*/\1/p')
eligible=$(printf '%s' "$summary" | sed -n 's/.*eligible=\([0-9]*\).*/\1/p')
[ -n "$real" ] || real=0
[ -n "$eligible" ] || eligible=0

if [ "$eligible" -eq 0 ] && [ "$real" -ge 1 ]; then
  echo "QUEUE-INIT: FAIL — batch 대상 FR 0건 (시드·공통부만 — /start-foundation 또는 기능 FR 추가 후 재실행)"
  echo "  $summary"
  exit 1
fi
if [ "$eligible" -eq 0 ]; then
  echo "QUEUE-INIT: FAIL — eligible=0"
  echo "  $summary"
  exit 1
fi

_escape_cell() {
  # table cell — pipe would break markdown columns
  printf '%s' "$1" | tr '|' '/'
}

# collect rows + skip header bullets
# FR 처럼 보이나 읽지 못한 행 — 조용히 버리지 않고 출력과 queue 머리말에 남긴다 (20261009).
unp_list=$(printf '%s\n' "$classify_raw" | sed -n 's/^UNPARSED|//p' | tr '|' '/' | awk '{ printf "%s%s", (NR > 1 ? " · " : ""), $0 }')
unp_n=$(printf '%s\n' "$classify_raw" | grep -c '^UNPARSED|' || true)

rows_tmp=$(mktemp)
skip_notes=$(mktemp)
trap 'rm -f "$rows_tmp" "$skip_notes"' EXIT

while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in
    SUMMARY\|*) continue ;;
    SKIP\|*|ELIGIBLE\|*) ;;
    *) continue ;;
  esac
  kind=${line%%|*}
  rest=${line#*|}
  id=${rest%%|*}
  rest2=${rest#*|}
  case "$kind" in
    ELIGIBLE)
      ms=${rest2##*|}
      desc=${rest2%|*}
      desc=$(_escape_cell "$desc")
      printf '| %s | TBD | %s | PENDING |\n' "$id" "$desc" >>"$rows_tmp"
      ;;
    SKIP)
      reason=${rest2%%|*}
      ms=${rest2#*|}
      case "$reason" in
        placeholder)
          # v1: 행 생략
          continue
          ;;
        seed-decomposed)
          printf '| %s | — | (마일스톤 시드 — 세부 FR로 분해됨) | SKIP |\n' "$id" >>"$rows_tmp"
          printf -- '- **%s = SKIP** — seed-decomposed (%s)\n' "$id" "$ms" >>"$skip_notes"
          ;;
        foundation-scope)
          # original desc may be lost in classify — keep reason suffix only
          printf '| %s | — | (공통부 — /start-foundation 담당) | SKIP |\n' "$id" >>"$rows_tmp"
          printf -- '- **%s = SKIP** — foundation-scope (%s)\n' "$id" "$ms" >>"$skip_notes"
          ;;
        *)
          printf '| %s | — | (%s) | SKIP |\n' "$id" "$reason" >>"$rows_tmp"
          ;;
      esac
      ;;
  esac
done <<EOF
$classify_raw
EOF

{
  printf '# %s 큐\n\n' "$BATCH_NAME"
  cat <<'HDR'
> `/start-all` 오케스트레이터가 관리. Phase 1 은 `PENDING` 만, Phase 3 은 `PLAN_DONE` 만 처리한다.
> 초기화: `init-batch-queue.sh` (check-fr-table --classify).

HDR
  if [ -n "$unp_list" ]; then
    # 표 행으로 쓰지 않는다(`|` 로 시작하면 batch-state 가 FR 행으로 읽는다) — 머리말 산문 한 줄.
    printf '> **해석하지 못한 FR 행** %s건: %s — requirements 에서 줄 맨 앞 `| FR-<숫자> |` 꼴로 고친 뒤 이 큐에 추가하세요(지금은 batch 대상이 아니다).\n\n' "$unp_n" "$unp_list"
  fi
  if [ -s "$skip_notes" ]; then
    echo '**초기 SKIP 사유** (기계):'
    echo
    cat "$skip_notes"
    echo
  fi
  cat <<'TBL'
| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
TBL
  cat "$rows_tmp"
} >"$QUEUE"

echo "QUEUE-INIT: CREATED ($QUEUE) eligible=$eligible"
[ -n "$unp_list" ] && echo "QUEUE-INIT: WARN — 해석하지 못한 FR 행 ${unp_n}건: ${unp_list} (FR 처럼 보이나 ID 형식이 다르거나 들여쓴 행이라 큐에 넣지 않았다 — queue 머리말에 기록)"
exit 0
