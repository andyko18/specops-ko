<!-- FID: 20260427-e2e-testing -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260427-e2e-testing

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다.

## 계약 항목

### AC-1: e2e-testing-ko 스킬 파일 + /e2e-test 커맨드 존재

**Given** specops-auto-ko 프로젝트 루트

**When** `ls skills/e2e-testing-ko/SKILL.md && ls commands/e2e-test.md` 실행

**Then** 두 파일 모두 exit 0으로 존재

**검증 방법**: `ls skills/e2e-testing-ko/SKILL.md && ls commands/e2e-test.md`
**관련 FR**: FR-8
**우선순위**: must

---

### AC-2: screens/ Interactions → 웹 테스트 시나리오 자동 생성 로직

**Given** `screens/{name}.md`에 `## Interactions` 섹션이 존재

**When** `e2e-testing-ko` 스킬의 시나리오 생성 섹션을 확인

**Then** Interactions 항목을 Puppeteer 테스트 코드로 변환하는 절차가 스킬 본문에 명시됨

**검증 방법**: `grep -c "Interactions" skills/e2e-testing-ko/SKILL.md` → 1 이상
**관련 FR**: FR-1
**우선순위**: must

---

### AC-3: AC Given/When/Then → 테스트 시나리오 자동 생성 로직

**Given** `.specops/<FID>/acceptance-criteria.md`에 Given/When/Then 항목이 존재

**When** `e2e-testing-ko` 스킬의 시나리오 생성 섹션을 확인

**Then** Given/When/Then을 테스트 시나리오로 변환하는 절차가 스킬 본문에 명시됨

**검증 방법**: `grep -c "Given" skills/e2e-testing-ko/SKILL.md` → 1 이상
**관련 FR**: FR-2
**우선순위**: must

---

### AC-4: Chrome(Puppeteer) + Appium 두 채널 실행 흐름 명시

**Given** `skills/e2e-testing-ko/SKILL.md` 존재

**When** 파일 내용 확인

**Then** Puppeteer(웹/모바일 웹)와 Appium(네이티브) 두 채널이 모두 명시되고 각각의 실행 절차가 구분되어 기술됨

**검증 방법**: `grep -c "Puppeteer" skills/e2e-testing-ko/SKILL.md` ≥ 1, `grep -c "Appium" skills/e2e-testing-ko/SKILL.md` ≥ 1
**관련 FR**: FR-4, FR-5, FR-6
**우선순위**: must

---

### AC-5: e2e-results.md 출력 포맷 명시

**Given** E2E 테스트 실행 완료

**When** `.specops/<FID>/e2e-results.md` 파일 확인

**Then** PASS/FAIL 결과 테이블 + 스크린샷 경로 목록이 기록됨

**검증 방법**: `grep -c "e2e-results" skills/e2e-testing-ko/SKILL.md` → 1 이상
**관련 FR**: FR-7
**우선순위**: must

---

### AC-6: Lifecycle verifying-evidence-ko 이후 통합 위치 명시

**Given** `skills/e2e-testing-ko/SKILL.md` 존재

**When** "다음 skill" 섹션 확인

**Then** `verifying-evidence-ko` 이후에 호출되는 위치가 명시됨

**검증 방법**: `grep -c "verifying-evidence-ko" skills/e2e-testing-ko/SKILL.md` → 1 이상
**관련 FR**: FR-9
**우선순위**: should

---

### AC-7: 모바일 웹(Puppeteer 에뮬레이션) + 네이티브(Appium) 구분 명시

**Given** `skills/e2e-testing-ko/SKILL.md` 존재

**When** 모바일 테스트 섹션 확인

**Then** 모바일 웹(반응형 웹의 모바일 뷰)과 네이티브 앱 테스트가 명확히 구분되어 기술됨

**검증 방법**: `grep -c "모바일 웹" skills/e2e-testing-ko/SKILL.md` ≥ 1, `grep -c "네이티브" skills/e2e-testing-ko/SKILL.md` ≥ 1
**관련 FR**: FR-5, FR-6
**우선순위**: should

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md`에 사유 기록
- **nice-to-have**: 여유가 있으면 반영. 미충족 시 BLOCK 없음

## 참조

- `skills/sprint-contracts-ko/SKILL.md` — 계약서 운용 규약
- `templates/spec.md` — 연계 스펙

---

*작성: kohaedong · 2026-04-27 · FID: 20260427-e2e-testing · 생성 커맨드: /specify*
