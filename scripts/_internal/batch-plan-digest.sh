#!/usr/bin/env bash
# batch-plan-digest.sh — Phase 2 짧은 digest (전 plan 본문 덤프 금지)
# Usage: batch-plan-digest.sh <batch-dir>
#   batch-dir = .specops/<BATCH_ID> (queue.md 포함)
# stdout: FID | §유형 | 태스크수 | AC수 | plan | tasks
# exit 0 = 출력 완료, 2 = 사용 오류
set -u

BATCH_DIR="${1:-}"
if [ -z "$BATCH_DIR" ] || [ ! -d "$BATCH_DIR" ]; then
  echo "Usage: $0 <batch-dir>" >&2
  exit 2
fi
QUEUE="$BATCH_DIR/queue.md"
[ -f "$QUEUE" ] || { echo "Error: $QUEUE 없음" >&2; exit 2; }

SPECOPS_ROOT=$(dirname "$BATCH_DIR")
FR_RE='^\| *FR-[0-9][0-9A-Za-z]* *\|'

printf '%s\n' "FID | §유형 | 태스크수 | AC수 | plan | tasks"
printf '%s\n' "---|---|---|---|---|---"

# queue 행에서 FID 추출 (비어있지 않은 두 번째 필드, Status 무관 — PLAN_DONE+ 대상)
while IFS= read -r line; do
  [ -z "$line" ] && continue
  fid=$(printf '%s\n' "$line" | awk -F'|' '{
    gsub(/\r$/, "")
    n=0; delete a
    for (i=1;i<=NF;i++) { gsub(/^ +| +$/,"",$i); if ($i!="") a[++n]=$i }
    if (n>=2) print a[2]
  }')
  case "$fid" in ''|'—'|'-'|'TBD'|'tbd') continue ;; esac
  fdir="$SPECOPS_ROOT/$fid"
  typ="—"
  if [ -f "$fdir/spec.md" ]; then
    typ=$(grep -E '^\*\*§유형\*\*:' "$fdir/spec.md" 2>/dev/null | head -1 | sed -E 's/^\*\*§유형\*\*:[[:space:]]*//' | tr -d '\r' || true)
    [ -z "$typ" ] && typ="—"
  fi
  tasks_n=0
  ac_n=0
  if [ -f "$fdir/tasks.md" ]; then
    tasks_n=$(grep -E '^[[:space:]]*-[[:space:]]*id:[[:space:]]*' "$fdir/tasks.md" 2>/dev/null | wc -l | tr -d ' ')
    ac_n=$(grep -oE 'AC-[0-9]+' "$fdir/tasks.md" 2>/dev/null | sort -u | wc -l | tr -d ' ')
  fi
  plan_p="missing"
  [ -f "$fdir/plan.md" ] && plan_p="plan.md"
  tasks_p="missing"
  [ -f "$fdir/tasks.md" ] && tasks_p="tasks.md"
  printf '%s | %s | %s | %s | %s | %s\n' "$fid" "$typ" "${tasks_n:-0}" "${ac_n:-0}" "$plan_p" "$tasks_p"
done <<EOF
$(grep -E "$FR_RE" "$QUEUE" || true)
EOF
