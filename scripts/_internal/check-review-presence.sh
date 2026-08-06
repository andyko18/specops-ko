#!/usr/bin/env bash
# check-review-presence.sh — Phase B/C **수행 존재** 관측 (20260806)
# Usage: check-review-presence.sh <FID>
# Exit: 항상 0 — **warn-only (비차단)**. 관측 결과는 stdout + friction-log.
#
# 왜 필요한가: skill 은 "Phase B/C 생략 금지" 를 여러 곳에서 HARD 로 선언한다
#   (§lite 불변 · risk-profile allowlist · implementing-ko §리뷰 규약). 그런데
#   `check-review-audit.sh` 는 **정합 검사**(reviews ↔ dispatch-log)지 **존재 검사**가 아니다 —
#   리뷰를 0회 하면 검사 대상 자체가 없어 `SKIP` rc=0 으로 통과한다(20260806 실측).
#   즉 "생략 금지" 선언에 대응하는 관측조차 없었다.
#
# 왜 차단이 아니라 warn 인가: 그 fail-open 은 의도된 설계다
#   ("산출물 부재는 SKIP — 무관 repo·초기 FID 월권 0"). presence 를 즉시 하드 차단하면
#   본 repo 기존 FID 20건 중 **7건(35%)이 소급 FAIL** 한다(실측). 1단계는 관측만 하고,
#   빈도를 본 뒤 차단 전환을 판단한다. **전환 시 바꿀 계약이 바로 이 exit 0 이다.**
#
# 관측 대상: `tasks.md` 가 있는 FID(= 구현에 도달). 없으면 초기 FID 라 월권하지 않는다.
# 수행 증거: `reviews/*-B-report.md|*-B-feedback.md` · 동일하게 C. FAIL 라운드의 feedback 도
#   "수행함" 의 증거다(implementing 규약상 FAIL 시 feedback 병기).
set -u

FID="${1:?usage: $0 <FID>}"
SPECOPS="${SPECOPS_ROOT:-.specops}"
DIR="$SPECOPS/$FID"

[ -d "$DIR" ] || exit 0                 # 무관 repo·부재 FID — 월권 0
[ -f "$DIR/tasks.md" ] || exit 0        # 구현 미도달 — 관측 대상 아님

_has() {  # $1=B|C → 수행 증거 유무
  ls "$DIR"/reviews/*-"$1"-report.md >/dev/null 2>&1 && return 0
  ls "$DIR"/reviews/*-"$1"-feedback.md >/dev/null 2>&1 && return 0
  return 1
}

miss=""
_has B || miss="Phase B(spec-reviewer-ko) 미수행"
_has C || miss="${miss}${miss:+ · }Phase C(code-reviewer-ko) 미수행"

if [ -z "$miss" ]; then
  echo "REVIEW-PRESENCE: OK (B·C 수행 흔적 확인)"
  exit 0
fi

echo "REVIEW-PRESENCE: WARN — $miss"
echo "  skill 계약상 Phase B/C 는 생략 금지다(end-loaded 는 시점 통합이지 생략이 아님)."
echo "  현재는 **관측만** 하고 chain 을 막지 않는다(warn-only). 리뷰 산출물은"
echo "  reviews/<tid>-B-report.md · <tid>-C-report.md 규약으로 남긴다."

# friction-log 기록 — 빈도 관측이 전환 판단의 근거다
log="$DIR/friction-log.jsonl"
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
if command -v jq >/dev/null 2>&1; then
  jq -nc --arg fid "$FID" --arg rule "REVIEW-PRESENCE" --arg ev "$miss" \
     --arg ts "$ts" --argjson principle 2 \
     '{fid:$fid,rule:$rule,severity:"warn",evidence:$ev,recorded_at:$ts,principle:$principle}' \
     >> "$log" 2>/dev/null || true
else
  printf '{"fid":"%s","rule":"REVIEW-PRESENCE","severity":"warn","evidence":"%s","recorded_at":"%s"}\n' \
    "$FID" "$miss" "$ts" >> "$log" 2>/dev/null || true
fi
exit 0
