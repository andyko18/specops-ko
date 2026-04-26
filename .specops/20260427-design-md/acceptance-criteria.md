<!-- FID: 20260427-design-md -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260427-design-md

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다.

## 계약 항목

### AC-1: start-design 커맨드 파일 존재

**Given** specops-auto-ko 레포지토리가 클론된 상태

**When** `ls commands/start-design.md` 실행

**Then** 파일이 존재하고, 파일 내에 브랜드 선택 옵션(Stripe 포함)과 git commit 지시가 포함됨

**검증 방법**: `ls commands/start-design.md && grep -c "Stripe" commands/start-design.md`
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: DESIGN.md 템플릿 6섹션 구조

**Given** specops-auto-ko 레포지토리가 클론된 상태

**When** `ls templates/DESIGN.md` 실행 후 파일 내용 확인

**Then** 파일이 존재하고, `## ` 로 시작하는 섹션이 6개 이상 존재 (Color/Typography/Spacing/Components/Principles/AI Usage)

**검증 방법**: `grep -c "^## " templates/DESIGN.md` → 출력: 6 이상
**관련 FR**: FR-2
**우선순위**: must

---

### AC-3: specifying-ko DESIGN.md 감지 스텝

**Given** `skills/specifying-ko/SKILL.md` 현재 상태

**When** 파일 내 "DESIGN.md" 키워드 검색

**Then** "DESIGN.md" 키워드가 3회 이상 등장 (감지 스텝 + 참조 주입 지시 + 안내 문구)

**검증 방법**: `grep -c "DESIGN.md" skills/specifying-ko/SKILL.md` → 출력: 3 이상
**관련 FR**: FR-3
**우선순위**: must

---

### AC-4: specifying-ko DESIGN.md 감지 시 spec.md 참조 주입 지시

**Given** `skills/specifying-ko/SKILL.md` 수정 후

**When** 파일 내 "DESIGN.md" 관련 구절 확인

**Then** spec.md §참조에 DESIGN.md를 포함하라는 지시문이 존재

**검증 방법**: `grep "spec.md.*참조\|참조.*DESIGN" skills/specifying-ko/SKILL.md` → 1줄 이상 출력
**관련 FR**: FR-4
**우선순위**: must

---

### AC-5: 기존 DESIGN.md 덮어쓰기 방지

**Given** `commands/start-design.md` 파일 내용

**When** 파일 내 덮어쓰기 관련 로직 확인

**Then** 기존 DESIGN.md 존재 시 "덮어쓸까요?" 또는 "overwrite" 확인 질문 로직이 포함됨

**검증 방법**: `grep -i "덮어\|overwrite\|exists" commands/start-design.md` → 1줄 이상
**관련 FR**: FR-5
**우선순위**: should

---

### AC-6: dogfood — 실제 DESIGN.md 생성

**Given** specops-auto-ko 프로젝트 루트

**When** `ls DESIGN.md` 실행

**Then** 파일이 존재하고, 6개 섹션 + "specops-auto-ko" 프로젝트명이 포함됨

**검증 방법**: `ls DESIGN.md && grep -c "^## " DESIGN.md` → 6 이상
**관련 FR**: FR-1, FR-2
**우선순위**: should

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `evidence.md`에 사유 기록
- **nice-to-have**: 여유가 있으면 반영. 미충족 시 BLOCK 없음

## 참조

- `skills/sprint-contracts-ko/SKILL.md` — 계약서 운용 규약
- spec.md: `.specops/20260427-design-md/spec.md`

---

*작성: specops-auto-ko · 2026-04-26 · FID: 20260427-design-md · 생성 커맨드: /specify*
