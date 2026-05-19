<!-- FID: 20260518-plan-doc-reviewer -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260518-plan-doc-reviewer

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다.

## 계약 항목

### AC-1: 서브에이전트 dispatch 지시 존재

**Given** `planning-ko` SKILL.md §자체 검토 섹션이 수정되어 있고

**When** planning-ko가 plan.md 작성 + 자체 체크리스트 완료 후 단계를 진행할 때

**Then** SKILL.md §자체 검토 섹션에 `plan-document-reviewer-prompt.md` 기반 서브에이전트 dispatch 지시가 텍스트로 명시되어 있다

**검증 방법**: `grep -n "plan-document-reviewer" skills/planning-ko/SKILL.md` — 1건 이상 출력
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: plan-document-reviewer-prompt.md 파일 존재 및 4축 포함

**Given** `skills/planning-ko/plan-document-reviewer-prompt.md` 파일이 생성되어 있고

**When** 파일 내용을 확인할 때

**Then** Completeness·Spec Alignment·Task Decomposition·Buildability 4개 검토 축이 모두 포함되어 있다

**검증 방법**: `grep -E "Completeness|Spec Alignment|Task Decomposition|Buildability" skills/planning-ko/plan-document-reviewer-prompt.md | wc -l` → 4 이상
**관련 FR**: FR-2
**우선순위**: must

---

### AC-3: 판정 반환 형식 명시

**Given** `plan-document-reviewer-prompt.md`가 존재할 때

**When** 파일 내용을 확인할 때

**Then** `APPROVED` 또는 `ISSUES FOUND:` 두 가지 판정 형식이 프롬프트에 명시되어 있다

**검증 방법**: `grep -E "APPROVED|ISSUES FOUND" skills/planning-ko/plan-document-reviewer-prompt.md` — 1건 이상
**관련 FR**: FR-3
**우선순위**: must

---

### AC-4: validate-structure.sh PASS

**Given** `plan-document-reviewer-prompt.md`가 추가되어 있고

**When** `bash scripts/_internal/validate-structure.sh`를 실행할 때

**Then** 모든 항목이 ✅ PASS이다 (파일 카운트 기대값 포함)

**검증 방법**: `bash scripts/_internal/validate-structure.sh` → 전 항목 ✅
**관련 FR**: FR-5
**우선순위**: must

---

## 회귀 방지 AC (유지보수 FID 필수)

### AC-R-1: 기존 planning-ko chain 무손상

**Given** planning-ko가 plan.md를 작성하고 session-progress append + decomposing-ko 호출 지시가 존재할 때

**When** SKILL.md §자체 검토 이후 섹션(실행 전환, session-progress append, 다음 skill)을 확인할 때

**Then** 기존 decomposing-ko 호출 지시, session-progress append 지시가 수정 없이 그대로 존재한다

**검증 방법**: `grep -n "decomposing-ko\|session-progress-append" skills/planning-ko/SKILL.md` — 기존 라인 보존 확인
**관련 FR**: 회귀 방지
**우선순위**: must

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md`에 사유 기록
- **nice-to-have**: 여유가 있으면 반영. 미충족 시 BLOCK 없음

---

*작성: andyko · 2026-05-18 · FID: 20260518-plan-doc-reviewer · 생성 커맨드: /specify*
