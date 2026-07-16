#!/usr/bin/env bash
# batch-state.sh — batch queue ↔ requirements parity 검사 (read-only 감지 도구)
# 사용: batch-state.sh <batch-dir> [requirements-path]
#   exit 0 = clean (전 FR 완료 + 드리프트 0 + 중복 0)
#   exit 1 = 불일치 (미완·드리프트·중복 목록 출력 — 차단 결정은 호출측 게이트 소관)
#   exit 2 = 사용 오류
# 완료 토큰: IMPL_DONE | MERGED (Status 마지막 컬럼 기준 — 설명 컬럼 오탐 방지)
# 파싱: 행 단위 grep — 2-테이블 분할 queue 견딤. FR suffix 변형(FR-3b) 허용
set -u

BATCH_DIR="${1:-}"
if [ -z "$BATCH_DIR" ] || [ ! -d "$BATCH_DIR" ]; then
  echo "Usage: $0 <batch-dir> [requirements-path]" >&2; exit 2
fi
QUEUE="$BATCH_DIR/queue.md"
[ -f "$QUEUE" ] || { echo "Error: $QUEUE 없음" >&2; exit 2; }

REQ="${2:-}"
if [ -z "$REQ" ]; then
  # start-all Phase 0 동일 fallback (clarify Q1)
  if [ -f ".specops/memory/requirements.md" ]; then REQ=".specops/memory/requirements.md"
  elif [ -f "requirements.md" ]; then REQ="requirements.md"
  else echo "Error: requirements.md 미발견 — 경로 인자로 지정" >&2; exit 2; fi
fi
[ -f "$REQ" ] || { echo "Error: $REQ 없음" >&2; exit 2; }

FR_RE='^\| *FR-[0-9][0-9A-Za-z]* *\|'
queue_rows=$(grep -E "$FR_RE" "$QUEUE" || true)
queue_ids=$(printf '%s\n' "$queue_rows" | sed -E 's/^\| *(FR-[0-9][0-9A-Za-z]*) *\|.*/\1/')
req_ids=$(grep -E "$FR_RE" "$REQ" | sed -E 's/^\| *(FR-[0-9][0-9A-Za-z]*) *\|.*/\1/' || true)

fail=0

# 1) queue FR-ID 중복
dups=$(printf '%s\n' "$queue_ids" | sort | uniq -d | grep -v '^$' || true)
if [ -n "$dups" ]; then
  echo "[중복] queue.md FR-ID 중복 — 상태 오갱신 위험:"
  printf '%s\n' "$dups" | sed 's/^/  - /'
  fail=1
fi

# 2) 드리프트 — requirements 에 있으나 queue 미추적
drift=$(printf '%s\n' "$req_ids" | while IFS= read -r id; do
  [ -z "$id" ] && continue
  printf '%s\n' "$queue_ids" | grep -qx "$id" || printf '%s\n' "$id"
done)
if [ -n "$drift" ]; then
  echo "[드리프트] requirements 에 있으나 queue 미추적:"
  printf '%s\n' "$drift" | sed 's/^/  - /'
  fail=1
fi

# 3) 미완 — Status(마지막 컬럼)가 IMPL_DONE|MERGED 아님
incomplete=""
if [ -n "$queue_rows" ]; then  # 빈 queue 가드 — awk 빈 줄 유입 시 "  - : " phantom 차단
incomplete=$(printf '%s\n' "$queue_rows" | awk -F'|' '{
  gsub(/\r$/, "")   # CRLF 방어 — $0 재분할로 IMPL_DONE\r 미완 오탐 차단
  # 마지막 비어있지 않은 필드 = Status (st 행두 초기화 — 이월 방지, plan-reviewer Minor)
  st = ""
  for (i = NF; i >= 1; i--) { gsub(/^ +| +$/, "", $i); if ($i != "") { st = $i; break } }
  id = $2; gsub(/^ +| +$/, "", id)
  if (st !~ /^(IMPL_DONE|MERGED)/) print "  - " id ": " st
}')
fi
if [ -n "$incomplete" ]; then
  echo "[미완] 완료(IMPL_DONE|MERGED) 아님:"
  printf '%s\n' "$incomplete"
  fail=1
fi

# 4) 산출물 뭉개짐 방지 teeth — IMPL_DONE FID 마다 per-FR 검증·리뷰 산출물 3종 필수
#    Phase 3 는 FR 당:
#      - review-base.sha    : review.diff 격리 base (부재→requesting-code-review 가 HEAD~1 로 silent
#                             fallback → 직전 FR 변경까지 끌어들여 내용 뭉개짐. layer 2 강제)
#      - evidence.md        : per-FR verify 산출 (layer 3 존재)
#      - review-request.md  : per-FR code-review 산출 (layer 3 존재)
#    를 개별 생성해야 한다. 하나라도 없으면 verify/review 가 뭉개졌거나 미실행 → batch PR 전 차단.
#    MERGED(타 사이클서 이미 shipped)는 batch 전용 review-base.sha 미보유 가능 → 제외(IMPL_DONE 한정).
#    FID = 첫 두 비어있지 않은 필드 중 둘째.
SPECOPS_ROOT=$(dirname "$BATCH_DIR")
done_pairs=""
if [ -n "$queue_rows" ]; then
  done_pairs=$(printf '%s\n' "$queue_rows" | awk -F'|' '{
    gsub(/\r$/, "")
    n = 0; delete a
    for (i = 1; i <= NF; i++) { gsub(/^ +| +$/, "", $i); if ($i != "") a[++n] = $i }
    if (n >= 2 && a[n] ~ /^IMPL_DONE/) print a[1] "|" a[2]
  }')
fi
missing_artifacts=""
if [ -n "$done_pairs" ]; then
  while IFS='|' read -r fr_id fid; do
    [ -z "$fr_id" ] && continue
    # FID 미확정 placeholder 는 미완 검사(3)가 이미 잡음 — 여기선 skip
    case "$fid" in ''|'—'|'-'|'TBD'|'tbd') continue ;; esac
    for art in review-base.sha evidence.md review-request.md; do
      [ -f "$SPECOPS_ROOT/$fid/$art" ] || \
        missing_artifacts="${missing_artifacts}  - ${fr_id} (${fid}): ${art} 없음"$'\n'
    done
  done <<EOF
$done_pairs
EOF
fi
if [ -n "$missing_artifacts" ]; then
  echo "[산출물 누락] IMPL_DONE FID 의 per-FR 검증·리뷰 산출물 부재 (뭉개짐 방지 teeth):"
  printf '%s' "$missing_artifacts"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "BATCH-STATE: OK (전 FR 완료 · 드리프트 0 · 중복 0 · 산출물 완비)"
  exit 0
fi
echo "BATCH-STATE: MISMATCH — batch PR 전 확인 필요" >&2
exit 1
