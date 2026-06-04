<!-- FID: 20260604-start-foundation -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: specops-auto-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260604-start-foundation

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다.

## 계약 항목

### AC-1: `/start-foundation` 커맨드 진입

**Given** specops-auto-ko 플러그인이 활성 상태이고 `commands/start-foundation.md` 파일이 존재한다

**When** 사용자가 `/start-foundation [<공통부 설명>]` 을 입력한다

**Then** specifying-ko 가 args 첫 줄 `<!-- entry: foundation -->` 마커와 함께 호출된다

**검증 방법**: `grep -qF 'entry: foundation' commands/start-foundation.md && echo PASS`
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: specifying-ko foundation 분기 — Step 5.5 skip

**Given** specifying-ko 가 `<!-- entry: foundation -->` args 로 호출된다

**When** specifying-ko Step 1 분기 검사가 실행된다

**Then** `<!-- entry: foundation -->` 분기가 명시되고 Step 5.5 화면 루프를 skip 한다는 지시가 SKILL.md 에 존재한다

**검증 방법**: `grep -qF 'entry: foundation' skills/specifying-ko/SKILL.md && echo PASS`
**관련 FR**: FR-2
**우선순위**: must

---

### AC-3: clarifying-ko 기술스택 BLOCKING 게이트

**Given** clarifying-ko 가 §유형=`foundation` spec.md 를 처리한다

**When** `frontend-architecture.md` 또는 `backend-architecture.md` 에 `<...>` 형태의 미해소 placeholder 가 있다

**Then** clarifying-ko SKILL.md 에 기술 프레임워크를 BLOCKING 질문으로 강제한다는 조건이 기재되어 있다

**검증 방법**: `grep -qF 'foundation' skills/clarifying-ko/SKILL.md && grep -qF 'BLOCKING' skills/clarifying-ko/SKILL.md && echo PASS`
**관련 FR**: FR-3
**우선순위**: must

---

### AC-4: planning-ko foundation-manifest.md 산출 지시

**Given** planning-ko 가 §유형=`foundation` spec 의 구현을 완료한다

**When** planning-ko 가 구현 결과를 산출한다

**Then** planning-ko SKILL.md 에 `.specops/memory/foundation-manifest.md` 작성 지시가 포함된다

**검증 방법**: `grep -qF 'foundation-manifest' skills/planning-ko/SKILL.md && echo PASS`
**관련 FR**: FR-4
**우선순위**: must

---

### AC-5: decomposing-ko 재사용 HARD GATE

**Given** decomposing-ko 가 §유형이 `foundation` 이 아닌 일반 기능 spec 을 처리하고 `.specops/memory/foundation-manifest.md` 가 존재한다

**When** decomposing-ko 가 tasks.md 를 생성한다

**Then** decomposing-ko SKILL.md 의 HARD-GATE 조건에 `foundation-manifest.md` 존재 시 재사용 선언(`**재사용 foundation**` 또는 `**미재사용 근거**`) 누락 task 를 차단한다는 조건이 기재되어 있다

**검증 방법**: `grep -qF 'foundation-manifest' skills/decomposing-ko/SKILL.md && echo PASS`
**관련 FR**: FR-5
**우선순위**: must

---

### AC-6: validate-structure 통과

**Given** `commands/start-foundation.md` 와 `templates/foundation-manifest.md` 가 추가되고 `.structure-baseline` 이 갱신된다

**When** `bash scripts/_internal/validate-structure.sh` 를 실행한다

**Then** 전 항목 ✅ 출력, exit 0

**검증 방법**: `bash scripts/_internal/validate-structure.sh 2>&1 | grep -c '✅'`
**관련 FR**: FR-6
**우선순위**: must

---

### AC-7: 거버넌스·DAG 회귀 없음

**Given** 모든 SKILL.md 편집이 완료된다

**When** `bash scripts/tests/governance/test-rules.sh` 와 `bash scripts/tests/dag/test-parse-dag.sh` 를 실행한다

**Then** 두 스크립트 모두 FAIL=0 으로 종료한다

**검증 방법**: `bash scripts/tests/governance/test-rules.sh 2>&1 | tail -1` → FAIL=0 포함 확인
**관련 FR**: FR-7
**우선순위**: must

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md`에 사유 기록
- **nice-to-have**: 여유가 있으면 반영. 미충족 시 BLOCK 없음
