<!-- FID: <YYYYMMDD-kebab-slug> -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — <FID>

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다. Evaluator(clarifier-ko, analyzer-ko, code-reviewer-ko, verifier-ko)는 이 계약만을 판정 기준으로 삼습니다.

## 계약 항목

각 AC는 Given/When/Then 형식으로 **관찰 가능한 결과**를 기술합니다. 구현 세부사항은 포함하지 않습니다.

### AC-1: <기능 이름>

**Given** <전제 조건·초기 상태>

**When** <사용자/시스템 동작>

**Then** <관찰 가능한 결과>

**검증 방법**: <수동 재현 단계 또는 자동 테스트 경로>
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: <기능 이름>

**Given** ...

**When** ...

**Then** ...

**검증 방법**: ...
**관련 FR**: FR-2
**우선순위**: must

---

### AC-3: <기능 이름>

**Given** ...

**When** ...

**Then** ...

**검증 방법**: ...
**관련 FR**: FR-3
**우선순위**: should

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md`에 사유 기록
- **nice-to-have**: 여유가 있으면 반영. 미충족 시 BLOCK 없음

## 참조

- `skills/harness/sprint-contracts.md` — 계약서 운용 규약
- `templates/analysis.md`, `templates/session-progress.md` — 판정 기록 포맷

---

*작성: <작성자> · <날짜> · FID: <FID> · 생성 커맨드: /specify*
