<!-- FID: 20260609-design-screens -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260609-design-screens

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다.

## 계약 항목

### AC-1: design-screens.md 파일 존재 + frontmatter 필수 필드

**Given** 프로젝트 루트에서 `commands/design-screens.md` 가 없는 상태

**When** 구현 완료 후

**Then** `commands/design-screens.md` 파일이 존재하고, frontmatter 에 `name: design-screens`, `description`, `triggers`, `mode: ask`, `specops_version`, `specops_layer: Lifecycle-Tool`, `reference_upstream: specops-auto-ko 독자 추가` 필드가 모두 있다

**검증 방법**: `grep -c -E '^name:|^description:|^triggers:|^mode:|^specops_version:|^specops_layer:|^reference_upstream:' commands/design-screens.md` → 7
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: Step 1 화면 목록 자동 판단 + 승인 게이트 명시

**Given** `commands/design-screens.md` 파일이 존재

**When** Step 1 섹션을 읽었을 때

**Then** 화면 목록 자동 도출 로직, 이름 정규식 제약, 승인/편집 루프 가 모두 명시되어 있다

**검증 방법**: `grep -c 'A-Za-z0-9\|승인\|자동' commands/design-screens.md` → 1 이상
**관련 FR**: FR-1, FR-2, FR-3
**우선순위**: must

---

### AC-3: Step 2 ui-ux-pro-max 1회 공유 호출 조건 명시

**Given** `commands/design-screens.md` 파일이 존재

**When** Step 2 섹션을 읽었을 때

**Then** ui-ux-pro-max 를 첫 화면 전 1회만 호출하고 결과를 모든 화면에 공유한다는 내용이 명시되어 있다

**검증 방법**: `grep 'ui-ux-pro-max' commands/design-screens.md | wc -l` → 1 이상
**관련 FR**: FR-4
**우선순위**: should

---

### AC-4: Step 3 화면별 순차 루프 5단계 명시

**Given** `commands/design-screens.md` 파일이 존재

**When** Step 3 섹션을 읽었을 때

**Then** 각 화면에 대해 scaffold → 질문 → HTML → 저장 → commit 이 순서대로 명시되어 있다

**검증 방법**: `grep -c 'design-screen.sh\|목적\|HTML\|저장\|commit' commands/design-screens.md` → 3 이상
**관련 FR**: FR-5
**우선순위**: must

---

### AC-5: 충돌 시 --force 확인 흐름 명시

**Given** `commands/design-screens.md` 파일이 존재

**When** Step 3 충돌 처리 부분을 읽었을 때

**Then** --force 옵션과 사용자 확인 절차가 명시되어 있다

**검증 방법**: `grep '\-\-force' commands/design-screens.md | wc -l` → 1 이상
**관련 FR**: FR-6
**우선순위**: must

---

### AC-6: README 13건 갱신 + file tree 추가

**Given** README.md 에 12건 이 있고 file tree 에 design-screens.md 항목이 없는 상태

**When** 구현 완료 후

**Then** README.md 에 13건 이 있고, file tree 에 design-screens.md 항목이 추가되어 있다

**검증 방법**: `grep '13건' README.md` 출력 존재 AND `grep 'design-screens' README.md` 출력 존재
**관련 FR**: FR-1 (파일 신설 동반 문서 동기화)
**우선순위**: must

---

### AC-7: .structure-baseline commands count=13

**Given** `.structure-baseline` 에 commands count:12 가 있는 상태

**When** 구현 완료 후

**Then** `.structure-baseline` 의 commands count 가 13 이다

**검증 방법**: `grep '"category":"commands"' scripts/_internal/.structure-baseline | grep '"count":13'` 출력 존재
**관련 FR**: NFR-3
**우선순위**: must

---

### AC-R-1: validate-structure.sh 전 항목 ✅

**Given** 구현 완료 상태

**When** `bash scripts/_internal/validate-structure.sh` 실행

**Then** 전 항목 OK (특히 file_counts: commands=13)

**검증 방법**: `bash scripts/_internal/validate-structure.sh` exit 0
**관련 FR**: NFR-3
**우선순위**: must

---

### AC-R-2: test-design-screen.sh PASS (백엔드 회귀 보호)

**Given** `scripts/_internal/design-screen.sh` 가 무수정인 상태

**When** `bash scripts/tests/test-design-screen.sh` 실행

**Then** FAIL=0

**검증 방법**: `bash scripts/tests/test-design-screen.sh` 출력 마지막 줄 FAIL=0
**관련 FR**: NFR-2
**우선순위**: must

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 evidence.md에 사유 기록

---

*작성: specifying-ko · 2026-06-09 · FID: 20260609-design-screens · 생성 커맨드: /start*
