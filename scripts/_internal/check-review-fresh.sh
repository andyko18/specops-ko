#!/usr/bin/env bash
# check-review-fresh.sh — end-loaded 리뷰 skip 의 신선도 판정 (20261008-review-reentry)
# Usage: check-review-fresh.sh FID
# Exit: 0 = FRESH (B/C 리포트가 최신 코드 변경 이후) · 1 = STALE (리포트 이후 코드가 바뀜) · 2 = 판정 불가
#
# 왜 필요한가: requesting-code-review-ko Step 0 의 SKIP 조건은 "모든 tid 의 B·C 리포트가 *존재*" 였다. 리뷰 뒤
#   security/integration/performance FAIL 을 systematic-debugging 으로 고치면 리포트는 그대로 남아 있어서,
#   재진입한 리뷰 단계가 "이미 리뷰됨" 으로 통과했다 — 수정 커밋이 어떤 리뷰도 받지 못했다.
# 판정: 가장 최근 B/C 리포트의 mtime 과, `.specops/` 밖 마지막 커밋 시각·미커밋 추적 변경을 비교한다.
#   리포트가 없으면 STALE(= SKIP 불가). 판정 불가(git 부재 등)는 rc 2 — 호출자는 SKIP 하지 않는다(리뷰 비용 < 무리뷰).
set -u
FID="${1:?usage: $0 FID}"
DIR=".specops/$FID"
[ -d "$DIR/reviews" ] || { echo "REVIEW-FRESH: STALE (reviews/ 부재)"; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "REVIEW-FRESH: UNKNOWN (git 작업트리 아님)"; exit 2; }

# GNU 먼저 — GNU stat 의 `-f` 는 파일시스템 상태라 성공하며 쓰레기를 낸다(BSD/macOS 는 `-c` 가 실패해 fallback)
_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }

newest=0
for f in "$DIR"/reviews/*-B-report.md "$DIR"/reviews/*-C-report.md; do
  [ -f "$f" ] || continue
  m=$(_mtime "$f"); case "$m" in ''|*[!0-9]*) continue ;; esac
  [ "$m" -gt "$newest" ] && newest=$m
done
[ "$newest" -gt 0 ] || { echo "REVIEW-FRESH: STALE (B/C 리포트 없음)"; exit 1; }

# 미커밋 추적 변경(.specops 제외) — 리포트 뒤에 손댄 코드
if [ -n "$(git status --porcelain --untracked-files=no -- . ':(exclude).specops' 2>/dev/null)" ]; then
  echo "REVIEW-FRESH: STALE (미커밋 코드 변경 존재)"; exit 1
fi

last=$(git log -1 --format=%ct -- . ':(exclude).specops' 2>/dev/null)
case "$last" in ''|*[!0-9]*) echo "REVIEW-FRESH: UNKNOWN (커밋 시각 판정 불가)"; exit 2 ;; esac

if [ "$last" -gt "$newest" ]; then
  echo "REVIEW-FRESH: STALE (마지막 코드 커밋이 최신 리뷰 리포트보다 나중 — 리뷰 이후 수정)"; exit 1
fi
echo "REVIEW-FRESH: FRESH"
exit 0
