<!-- FID: 20260609-design-screens -->
<!-- layer: Lifecycle-Artifact -->

# Review Request — 20260609-design-screens

**작성일**: 2026-06-09
**요청자**: requesting-code-review-ko

---

## WHAT_WAS_IMPLEMENTED

`/design-screens` (복수) 신규 슬래시 커맨드 신설 — 여러 화면을 한 번에 standalone으로 디자인하는 오케스트레이터.

변경 파일 (production):
- `commands/design-screens.md` — 신규 생성 (복수 커맨드 정의)
- `commands/design-screen.md` — 참조 섹션에 cross-ref 1줄 추가
- `scripts/_internal/.structure-baseline` — commands count 12 → 13
- `README.md` — commands 건수 갱신 + file tree 항목 추가

## PLAN_OR_REQUIREMENTS

`.specops/20260609-design-screens/plan.md` + `acceptance-criteria.md`

핵심 요구사항:
- AC-1: design-screens.md frontmatter 7개 필드 포함
- AC-2: Step 1 화면목록 자동판단 + 승인/편집 게이트
- AC-3: design-screen.sh CLI 계약(name regex, --force) 참조 정합
- AC-4: Step 3 화면별 순차루프 5단계(scaffold→questions→HTML→save→commit)
- AC-5: 충돌 시 --force 확인 흐름
- AC-6: README 갱신
- AC-7: .structure-baseline count 갱신
- AC-8: 기능설명 부족 시 예시 목록 제안

## BASE_SHA

a2238d883904a4799accde3b913b5ac4dba75236 (main HEAD)

## HEAD_SHA

8435db7db09c5f5e36cd2bbcaa9dd3c2fe1fb1f3

## DESCRIPTION

4 태스크 TDD 구현 완료. Wave 1(T1+T4 병렬) → Wave 2(T2+T3 병렬). 전체 AC 9/9 must PASS + should 1/1 PASS. validate-structure.sh 전 항목 ✅.
