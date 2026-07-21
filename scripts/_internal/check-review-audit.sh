#!/usr/bin/env bash
# 리뷰 산출물 ↔ dispatch-log 기록 대조 — Generator↔Evaluator 감사 추적 teeth
# Usage: check-review-audit.sh <FID>
#
# 동작: `.specops/<FID>/reviews/<task-id>-[BC]-{report,feedback}.md` 각각에 대해
#       `.specops/<FID>/dispatch-log.md` 에 해당 task-id 행이 있는지 확인.
#   - 전건 기록 → "REVIEW-AUDIT: PASS (N건)" exit 0
#   - 미기록 존재 → "REVIEW-AUDIT: FAIL" + task-id 목록 exit 1
#   - reviews/dispatch-log/대상 리포트 부재 → "REVIEW-AUDIT: SKIP" exit 0 (fail-open)
#
# 배경 (dogfood test1 20260717-approval-rbac, 2026-07-21): implementing-ko 는 Evaluator
#   degradation(fable 불가 → 모델 override 재dispatch)을 dispatch-log 에 기록하도록
#   명문화했는데, T10 은 `reviews/T10-B-report.md` 만 남기고 dispatch-log 행이 없었다.
#   규칙은 본문에만 있고 산출물을 보는 층이 없어 위반이 조용히 통과했다.
#
# 스코프 한계 (5원칙 5 — 정직): **누락(omission) 전용**이다.
#   dispatch-log 행이 있으나 내용이 거짓인 falsification(부모 인라인 판정을 서브에이전트로
#   기재)은 자기보고라 파일 대조로 판별 불가하다. transcript join(_verify_exec_evidence 패턴)은
#   context-resets-ko 의 implement↔verify 리셋 경계 때문에 대부분 fail-open 이라 실효가 낮다
#   (#120 자기보고 구조적 한계와 동일 클래스). 본 검사는 "기록조차 안 한" 층만 막는다.
set -u

FID="${1:?usage: $0 <FID>}"
REVIEWS=".specops/$FID/reviews"
LOG=".specops/$FID/dispatch-log.md"

# dispatch-log 부재 = dispatch 루프를 돌지 않은 작업(직접 TDD·self-maintenance·e2e fixture).
#   리뷰 산출물을 요구할 근거가 없다 → SKIP. 실측(20260721): reviews 0건 FID 5건 중 4건이 이 경우다.
if [ ! -f "$LOG" ]; then
  echo "REVIEW-AUDIT: SKIP (dispatch-log.md 부재)"
  exit 0
fi

# ── 역방향 대조 (20260721 HIGH-4) — dispatch-log 가 **참조하는** reviews 파일이 실재하는가.
#   정방향(reviews → log)만 있으면, 리뷰 리포트를 아예 파일로 안 남긴 경우 `reviews/ 부재 = SKIP`
#   으로 통째로 비껴간다. 실물: 20260713-llm-eval-nrun 이 dispatch-log 에 reviews/all-B-report.md·
#   all-C-report.md 를 기록해 놓고 그 파일이 없었다 — 판정을 대화로만 흘린 것이다.
#   로그가 있다 = 루프를 돌았다 = 판정 산출물이 있어야 한다.
#   꺾쇠 placeholder(`reviews/<task-id>-B-feedback.md`)는 제외 — 템플릿을 복사한 모든 FID 가
#   즉시 FAIL 하는 false-block 이 된다.
dangling=""
refs=$(grep -oE 'reviews/[^ |)`]+\.md' "$LOG" 2>/dev/null | sort -u || true)
for ref in $refs; do
  case "$ref" in *"<"*|*">"*) continue ;; esac
  [ -f ".specops/$FID/$ref" ] || dangling="${dangling}${dangling:+ }${ref}"
done
if [ -n "$dangling" ]; then
  echo "REVIEW-AUDIT: FAIL — dispatch-log.md 가 기록한 리뷰 산출물이 없습니다: $dangling"
  echo "  Phase B/C 판정은 PASS 여도 파일로 남겨야 합니다 (implementing-ko §B/C 판정 file-based 감사 추적)."
  echo "  대화 선언만으로 흘리면 다음 단계가 검증 불가능한 부모 말을 근거로 삼게 되고 사후 감사가 비어버립니다."
  exit 1
fi

if [ ! -d "$REVIEWS" ]; then
  echo "REVIEW-AUDIT: SKIP (reviews/ 부재)"
  exit 0
fi

missing=""
checked=0
# 대상 = Phase B/C 판정 산출물만. review.diff·code-review.md 등 종합 문서는 task-id 가 없어 제외.
for f in "$REVIEWS"/*-[BC]-report.md "$REVIEWS"/*-[BC]-feedback.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  # <task-id>-B-report.md → <task-id>
  tid="${base%-[BC]-report.md}"
  tid="${tid%-[BC]-feedback.md}"
  [ -n "$tid" ] || continue
  checked=$((checked + 1))
  # 경계 매칭 — T1 행이 T10 리포트를 덮지 않도록 앞뒤를 비-영숫자로 고정.
  if ! grep -Eq "(^|[^A-Za-z0-9])${tid}([^A-Za-z0-9]|$)" "$LOG"; then
    missing="${missing}${missing:+ }${tid}"
  fi
done

if [ "$checked" -eq 0 ]; then
  echo "REVIEW-AUDIT: SKIP (Phase B/C 리포트 0건)"
  exit 0
fi

if [ -n "$missing" ]; then
  echo "REVIEW-AUDIT: FAIL — dispatch-log.md 미기록 리뷰: $missing"
  echo "  리뷰 판정은 dispatch-log.md 에 행으로 남겨야 감사 추적이 성립합니다 (implementing-ko §dispatch-log)."
  echo "  Evaluator 를 모델 override 로 재dispatch 했거나 degradation 이 있었다면 그 사실도 같은 행에 기록하세요."
  exit 1
fi

echo "REVIEW-AUDIT: PASS (${checked}건 대조)"
exit 0
