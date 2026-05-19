<!-- FID: 20260518-context-adr-auto-ref -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260518-context-adr-auto-ref

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다.

## 계약 항목

### AC-1: CONTEXT.md 감지 지시 존재

**Given** `skills/specifying-ko/SKILL.md`가 수정되어 있고

**When** 파일 내용을 확인할 때

**Then** `CONTEXT.md` 자동 감지 지시 텍스트가 존재한다

**검증 방법**: `grep -c "CONTEXT\.md" skills/specifying-ko/SKILL.md` → 1 이상
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: ADR 감지 지시 존재

**Given** `skills/specifying-ko/SKILL.md`가 수정되어 있고

**When** 파일 내용을 확인할 때

**Then** `docs/adr/` 자동 감지 지시 텍스트가 존재한다

**검증 방법**: `grep -c "docs/adr" skills/specifying-ko/SKILL.md` → 1 이상
**관련 FR**: FR-2
**우선순위**: must

---

### AC-3: graceful skip 명시

**Given** `skills/specifying-ko/SKILL.md`가 수정되어 있고

**When** CONTEXT.md/ADR 감지 섹션을 확인할 때

**Then** 부재 시 graceful skip 동작이 명시되어 있다

**검증 방법**: `grep -A3 "CONTEXT\.md" skills/specifying-ko/SKILL.md | grep -c "graceful skip\|부재\|없으면"` → 1 이상
**관련 FR**: FR-3
**우선순위**: must

---

### AC-4: 테스트 T5.a T6.a 추가

**Given** `scripts/tests/test-memory-references.sh`가 수정되어 있고

**When** `bash scripts/tests/test-memory-references.sh`를 실행할 때

**Then** T5.a (CONTEXT.md 정적 검증) + T6.a (ADR 정적 검증) 케이스가 PASS된다

**검증 방법**: `bash scripts/tests/test-memory-references.sh 2>&1 | grep -E "T5\.a|T6\.a"` → 2건 PASS
**관련 FR**: FR-5
**우선순위**: must

---

### AC-5: validate-structure.sh PASS

**Given** 파일이 수정되어 있고

**When** `bash scripts/_internal/validate-structure.sh`를 실행할 때

**Then** 전 항목이 ✅ PASS이다

**검증 방법**: `bash scripts/_internal/validate-structure.sh` → 전 항목 ✅
**관련 FR**: NFR-1
**우선순위**: must

---

## 회귀 방지 AC (유지보수 FID 필수)

### AC-R-1: 기존 9종 memory 감지 무손상

**Given** `skills/specifying-ko/SKILL.md`가 수정되어 있고

**When** 기존 `.specops/memory/*.md` 감지 섹션을 확인하고 `bash scripts/tests/test-memory-references.sh`를 실행할 때

**Then** 기존 T1.a~T4.a 4건이 여전히 PASS이고, 9종 감지 표가 보존된다

**검증 방법**: `bash scripts/tests/test-memory-references.sh 2>&1 | grep -E "T[1-4]\.a"` → 4건 PASS
**관련 FR**: FR-4
**우선순위**: must

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md`에 사유 기록
- **nice-to-have**: 여유가 있으면 반영. 미충족 시 BLOCK 없음

---

*작성: specifying-ko [유지보수 분기] · 2026-05-18 · FID: 20260518-context-adr-auto-ref · 생성 커맨드: /specify*
