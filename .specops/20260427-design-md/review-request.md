# Review Request — FID: 20260427-design-md

**요청 일시**: 2026-04-26
**BASE_SHA**: 5f325877736232563db99adacc6539c2086cdacd (tasks.md 완료 직후)
**HEAD_SHA**: ebd1272616913c48b0884051ca260db478f23b0a (evidence.md 커밋)

---

## WHAT_WAS_IMPLEMENTED

awesome-design-md (VoltAgent/awesome-design-md, 65K+ stars) 방식을 specops-auto-ko에 통합.

변경 파일 (4개):
1. `templates/DESIGN.md` — awesome-design-md 포맷 6섹션 템플릿 (신규)
2. `commands/start-design.md` — `/start-design` 슬래시 커맨드 (신규)
3. `skills/specifying-ko/SKILL.md` — DESIGN.md 자동 감지·참조 주입 (+3줄 수정)
4. `DESIGN.md` — specops-auto-ko dogfood 디자인 시스템 (Claude 브랜드, 신규)

## PLAN_OR_REQUIREMENTS

### 기능 요구사항 (FR)

- FR-1: `/start-design` 커맨드로 브랜드 선택 → DESIGN.md 생성
- FR-2: templates/DESIGN.md — 6개 섹션 구조 (Color/Typography/Spacing/Components/Principles/AI Usage)
- FR-3: specifying-ko 체크리스트 1번에 DESIGN.md 존재 감지 스텝 추가
- FR-4: DESIGN.md 감지 시 spec.md §참조에 "DESIGN.md 디자인 시스템 준수" 자동 주입
- FR-5 (should): 기존 DESIGN.md 덮어쓰기 방지 (y/n 확인)
- FR-6 (should): git commit 지시 포함

### Acceptance Criteria

| AC | must/should | 결과 |
|---|---|---|
| AC-1 | must | commands/start-design.md 존재 + Stripe 브랜드 + git commit |
| AC-2 | must | templates/DESIGN.md 존재 + ^## 섹션 6개 이상 |
| AC-3 | must | SKILL.md에 DESIGN.md 3회 이상 등장 |
| AC-4 | must | spec.md §참조 자동 주입 지시문 존재 |
| AC-5 | should | 덮어쓰기 방지 확인 질문 |
| AC-6 | should | specops-auto-ko 루트 DESIGN.md (Claude 브랜드) |

**모두 PASS** (evidence.md 기록)

## DESCRIPTION

awesome-design-md 포맷(AI 에이전트용 디자인 시스템 문서) specops-auto-ko 통합.
핵심: `/start-design` 커맨드로 DESIGN.md 생성, specifying-ko가 자동 감지해 spec.md §참조에 주입.
총 4 커밋, 3 신규 파일, 1 기존 파일 수정 (+3줄).
