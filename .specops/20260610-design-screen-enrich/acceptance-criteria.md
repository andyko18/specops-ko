<!-- FID: 20260610-design-screen-enrich -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260610-design-screen-enrich

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다.

## 계약 항목

### AC-1: rationale 추출 — 핵심 결정 요약

**Given** `/design-screen {name}` 실행 시 available-skills에 `ui-ux-pro-max:ui-ux-pro-max`가 있음

**When** Step 2.5에서 ui-ux-pro-max 자문 호출 완료

**Then** style 이름, primary color, 폰트 페어링, anti-pattern 2-3개를 포함한 rationale 요약이 추출되어 이후 Step 4 저장에 사용 가능한 상태가 된다

**검증 방법**: Step 4 이후 생성된 `screens/{name}.md`에 `## Design Rationale` 섹션이 존재하고 4개 항목(Style/Color/Font pairing/Anti-patterns) 모두 채워져 있음 확인
**관련 FR**: FR-1, FR-2
**우선순위**: must

---

### AC-2: screen.md에 Design Rationale 섹션 저장

**Given** ui-ux-pro-max 자문이 호출되어 rationale가 추출된 상태

**When** Step 4에서 `screens/{name}.md` 저장

**Then** `## Design Rationale` 섹션이 다음 포맷으로 포함된다:
```
- **Style**: {style-name} — {근거 한 줄}
- **Color**: primary {hex} / surface {hex}
- **Font pairing**: {heading-font} / {body-font}
- **Anti-patterns (금지)**: {AP-1}, {AP-2}[, {AP-3}]
```

**검증 방법**: `grep -A6 "## Design Rationale" screens/{name}.md` 출력에 4개 항목 모두 존재
**관련 FR**: FR-2
**우선순위**: must

---

### AC-3: ui-ux-pro-max 없을 때 섹션 생략

**Given** available-skills에 `ui-ux-pro-max:ui-ux-pro-max`가 없음

**When** Step 4에서 `screens/{name}.md` 저장

**Then** `## Design Rationale` 섹션이 없고, 기존 섹션(목적/Layout/Components/States/Interactions)은 모두 정상 저장된다

**검증 방법**: `grep "## Design Rationale" screens/{name}.md` → 매칭 없음; 기존 5개 섹션 모두 존재
**관련 FR**: FR-3
**우선순위**: must

---

### AC-4: anti-pattern 위반 없음 — 자동 통과

**Given** rationale의 anti-pattern 목록이 존재하고 HTML에 위반 항목이 없음

**When** Step 3.5 anti-pattern 게이트 실행

**Then** `✅ Anti-pattern 체크 통과` 메시지 출력 후 사용자 입력 없이 Step 4 진행

**검증 방법**: 게이트 단계에서 [m/s] 확인 프롬프트 없이 Step 4로 넘어감 확인
**관련 FR**: FR-5
**우선순위**: must

---

### AC-5: anti-pattern 위반 발견 — 사용자 확인

**Given** rationale의 anti-pattern 목록 중 1개 이상이 HTML에서 감지됨

**When** Step 3.5 anti-pattern 게이트 실행

**Then** 위반 항목 목록과 함께 `⚠️ Anti-pattern 위반: {목록}. 수정 후 저장 / 그냥 저장 [m/s]` 프롬프트 표시

**검증 방법**: 위반 유발 HTML로 테스트 시 [m/s] 확인 프롬프트 출력 확인
**관련 FR**: FR-4
**우선순위**: must

---

### AC-6: [m] 선택 → HTML 수정 루프 복귀

**Given** anti-pattern 위반 발견 후 사용자가 `m` 선택

**When** Step 3.5 게이트에서 [m] 응답

**Then** Step 3(HTML artifact 생성 + 수정 루프)으로 복귀하여 재생성

**검증 방법**: m 선택 후 Step 3 수정 루프 재진입 확인
**관련 FR**: FR-8
**우선순위**: should

---

### AC-7: [s] 선택 → 위반 상태로 저장

**Given** anti-pattern 위반 발견 후 사용자가 `s` 선택

**When** Step 3.5 게이트에서 [s] 응답

**Then** 위반 상태 그대로 Step 4 저장 진행

**검증 방법**: s 선택 후 Step 4 정상 저장 확인
**관련 FR**: FR-8
**우선순위**: should

---

### AC-8: templates/screen.md Design Rationale placeholder

**Given** `templates/screen.md` 파일

**When** 내용 확인

**Then** `## Design Rationale` 섹션이 존재하고 placeholder 텍스트(ui-ux-pro-max 미사용 시 생략 안내 포함)가 있다

**검증 방법**: `grep "## Design Rationale" templates/screen.md` → 매칭 존재
**관련 FR**: FR-6
**우선순위**: must

---

### AC-9: /design-screens rationale 1회 공유

**Given** `/design-screens "기능설명"` 실행, ui-ux-pro-max 있음, 화면 N개

**When** Step 2에서 rationale 도출

**Then** ui-ux-pro-max가 1회만 호출되고 도출된 rationale가 N개 화면 모두에 동일하게 적용된다

**검증 방법**: 복수 화면 실행 시 Step 2 ui-ux-pro-max 호출 횟수 = 1, 각 화면 screen.md의 `## Design Rationale` 내용이 동일
**관련 FR**: FR-7
**우선순위**: must

---

### AC-10: ui-ux-pro-max 없을 때 게이트 skip

**Given** available-skills에 ui-ux-pro-max 없음

**When** Step 3.5 단계 도달

**Then** anti-pattern 체크 게이트를 완전히 skip하고 Step 4 직행

**검증 방법**: ui-ux-pro-max 없는 환경에서 [m/s] 프롬프트 미출력 확인
**관련 FR**: FR-3
**우선순위**: must

---

## 회귀 방지 AC (유지보수 FID 필수)

### AC-R-1: ui-ux-pro-max 없는 기존 경로 동작 보존

**Given** available-skills에 ui-ux-pro-max가 없고 `/design-screen foo` 실행

**When** 전체 플로우(Step 1 ~ Step 5) 완료

**Then** 기존과 동일하게 `screens/foo.md` + `screens/foo.html` 생성, git commit 완료. Design Rationale 섹션 없음. [m/s] 프롬프트 없음.

**검증 방법**: ui-ux-pro-max 없는 환경에서 `/design-screen` 전체 실행 — 기존 T1~T8 테스트 PASS 유지
**관련 FR**: 회귀 방지
**우선순위**: must

---

### AC-R-2: design-screen.sh 스크립트 무변경

**Given** `scripts/_internal/design-screen.sh` 파일

**When** 본 FID 구현 완료 후

**Then** `scripts/tests/test-design-screen.sh` PASS=12 FAIL=0 유지

**검증 방법**: `bash scripts/tests/test-design-screen.sh` → PASS=12 FAIL=0
**관련 FR**: 회귀 방지
**우선순위**: must

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md`에 사유 기록
- **nice-to-have**: 여유가 있으면 반영. 미충족 시 BLOCK 없음

---

### AC-8-override: templates/screen.md 변경 없음 (Q1 명확화)

> Q1 결정으로 AC-8 무효화. templates/screen.md에 Design Rationale 섹션을 추가하지 않는다.
> 대신 커맨드 Step 4에서 rationale 있을 때 screen.md 끝에 동적 append.

**Given** `templates/screen.md` 파일

**When** 본 FID 구현 완료 후 확인

**Then** `## Design Rationale` 섹션이 **존재하지 않는다**

**검증 방법**: `grep "## Design Rationale" templates/screen.md` → 매칭 없음
**관련 FR**: Q1 결정 (FR-6 무효화)
**우선순위**: must

---

### AC-11: [m/s] 기본값 = s (Q2 가정)

**Given** anti-pattern 위반 발견 후 사용자가 Enter만 누름 (입력 없음)

**When** Step 3.5 게이트 `[m/s, 기본=s]` 프롬프트

**Then** `s`(그냥 저장)로 처리하여 Step 4 진행

**검증 방법**: 프롬프트 표기에 `기본=s` 명시 확인
**관련 FR**: FR-8
**우선순위**: should

---

## 참조

- `skills/sprint-contracts-ko/SKILL.md` — 계약서 운용 규약
- `.specops/20260610-design-screen-enrich/spec.md` — 기능 명세
- `.specops/20260610-design-screen-enrich/clarifications.md` — 명확화 기록

---

*작성: andyko · 2026-06-10 · FID: 20260610-design-screen-enrich · 생성 커맨드: /specify*
