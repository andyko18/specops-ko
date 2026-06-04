<!-- FID: 20260604-start-foundation -->
<!-- OWNER_COMMAND: /request-review -->
<!-- reference_upstream: specops-auto-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# Review Request — 20260604-start-foundation

## WHAT_WAS_IMPLEMENTED

specops-auto-ko 에 `/start-foundation` 독립 슬래시 커맨드 신설. 한국 SI 표준 "공통부 먼저 개발" 단계 지원.

신규 파일 2개 + 기존 SKILL.md 4개 편집 + `.structure-baseline` 카운트 갱신 (신규 코드 없음 — Markdown 문서 편집만).

## PLAN_OR_REQUIREMENTS

`.specops/20260604-start-foundation/spec.md` + `.specops/20260604-start-foundation/acceptance-criteria.md`

AC 요약:
- AC-1: `commands/start-foundation.md` 에 `<!-- entry: foundation -->` 마커 존재
- AC-2: `skills/specifying-ko/SKILL.md` 에 foundation 분기 + Step 5.5 skip 지시
- AC-3: `skills/clarifying-ko/SKILL.md` 에 §유형=foundation 시 기술스택 BLOCKING 게이트
- AC-4: `skills/planning-ko/SKILL.md` 에 foundation-manifest.md 산출 지시
- AC-5: `skills/decomposing-ko/SKILL.md` HARD GATE 에 재사용 선언 의무 조건
- AC-6: `validate-structure.sh` 전항목 ✅ (commands 9, templates 27)
- AC-7: governance PASS=70 FAIL=0 · DAG PASS=16 FAIL=0

## BASE_SHA

f36e07183456f06fc0ffecb0fc60e7de51aafab1 (origin/main)

## HEAD_SHA

78b4a0a6b3ff39cef8368efa61446867e6a19859

## DESCRIPTION

- `commands/start-foundation.md` 신규 — foundation 분기 진입 슬래시 커맨드
- `templates/foundation-manifest.md` 신규 — 공통부 모듈 목록 템플릿
- `skills/specifying-ko/SKILL.md` 편집 — foundation 분기 signal check + §유형 표 + 프로세스 흐름 다이어그램 갱신
- `skills/clarifying-ko/SKILL.md` 편집 — BLOCKING 기술스택 게이트 1줄 추가
- `skills/planning-ko/SKILL.md` 편집 — foundation-manifest 산출 지시 섹션 추가
- `skills/decomposing-ko/SKILL.md` 편집 — HARD GATE 재사용 선언 조건 추가
- `scripts/_internal/.structure-baseline` 편집 — commands 8→9, templates 26→27

## 검증 결과 (evidence.md 요약)

모든 must AC 7/7 PASS. governance FAIL=0, DAG FAIL=0, validate-structure 전항목 ✅.

---

*생성: specops-auto-ko requesting-code-review-ko · 2026-06-04 · FID: 20260604-start-foundation*
