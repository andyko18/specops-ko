<!-- FID: 20260610-design-screen-enrich -->
<!-- OWNER_COMMAND: /plan -->
<!-- reference_upstream: github/spec-kit plan-template.md + obra/superpowers writing-plans -->
<!-- layer: Lifecycle-Artifact -->

# design-screen(s) ui-ux-pro-max 심층 연동 강화 구현 플랜 — 20260610-design-screen-enrich

**목표**: `commands/design-screen.md`와 `commands/design-screens.md`에 ui-ux-pro-max 자문 결과를 rationale 변수로 보관하고, anti-pattern 게이트(Step 3.5/3-3.5)와 screen.md 동적 append(Step 4/3-4)를 추가해 설계 근거를 추적 가능하게 한다.

**아키텍처**: 커맨드 문서(md) 직접 편집 방식. 기존 Step 2.5(단수)/Step 2(복수) 후단에 rationale 추출 명세를 추가하고, Step 3과 Step 4 사이에 Step 3.5를 신설하며, Step 4/Step 3-4에 조건부 append 로직을 추가한다. templates/screen.md는 변경하지 않는다(Q1 결정).

**기술 스택**: Markdown 문서 편집

**관련 AC**: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8-override, AC-9, AC-10, AC-11, AC-R-1, AC-R-2

---

## 1. 가정 (5원칙 5번)

- ui-ux-pro-max SKILL 반환값에 anti-patterns 열거 필드가 존재한다고 가정 (SKILL.md description 기반). 없으면 `antipatterns: []` 처리로 게이트 skip.
- [m/s, 기본=s] 에서 Enter = s(그냥 저장) (Q2 ASSUMED 결정).
- 커맨드 md는 Claude 인터프리터가 해석하는 지시 문서 — 자동화 단위 테스트 없음. 검증은 내용 대조 + 회귀 스크립트 테스트(AC-R-2).

## 2. 파일 구조

### 수정
- `commands/design-screen.md:43-48` — Step 2.5 rationale 추출 명세 추가
- `commands/design-screen.md:49` (新) — Step 3.5 anti-pattern 게이트 섹션 신설
- `commands/design-screen.md:61-67` — Step 4 rationale 동적 append 로직 추가
- `commands/design-screens.md:35-39` — Step 2 rationale 추출 명세 추가
- `commands/design-screens.md:64-71` (新 Step 3-3.5) — 화면별 anti-pattern 게이트 신설
- `commands/design-screens.md:72-78` — Step 3-4 rationale append 로직 추가

### 변경 없음 (확인 대상)
- `templates/screen.md` — Q1 결정, 변경 금지. AC-8-override 검증 대상.
- `scripts/_internal/design-screen.sh` — 스크립트 무변경 (AC-R-2).

## 3. 데이터 모델

rationale 변수 구조 (커맨드 내 지시로만 존재 — 실제 코드 객체 아님):

```
rationale = {
  style:        "{style-name} — {근거 한 줄}",
  color:        "primary {hex} / surface {hex}",
  font:         "{heading-font} / {body-font}",
  antipatterns: ["{AP-1}", "{AP-2}"[, "{AP-3}"]]  # 없으면 []
}
# ui-ux-pro-max 미호출 시: rationale = null
```

## 4. 계약

Design Rationale 섹션 포맷 (screen.md에 append되는 내용):

```markdown
## Design Rationale

> ui-ux-pro-max 자문 기반 ({YYYY-MM-DD})

- **Style**: {rationale.style}
- **Color**: {rationale.color}
- **Font pairing**: {rationale.font}
- **Anti-patterns (금지)**: {rationale.antipatterns 쉼표 연결}
```

## 5. 태스크 개요

1. **T1 — design-screen.md 수정** (독립): Step 2.5 rationale 보관 + Step 3.5 신설 + Step 4 append
2. **T2 — design-screens.md 수정** (독립, T1과 병렬): Step 2 rationale 보관 + Step 3-3.5 신설 + Step 3-4 append
3. **T3 — 회귀 검증** (T1·T2 의존): test-design-screen.sh PASS=12 + AC-8-override 확인

## 6. 위험과 완화

| 위험 | 영향 | 완화 |
|---|---|---|
| design-screen.md 기존 Step 번호 충돌 (3.5 신설) | M | Step 3과 Step 4 사이에 명확히 삽입, 번호 충돌 없음 확인 |
| design-screens.md Step 3-3.5 삽입 시 Step 3-4 흐름 단절 | M | Step 3-3.5 → Step 3-4 전환 명세 명확히 |
| templates/screen.md 실수로 변경 | M | T3에서 grep 확인 — 변경 없음 검증 |
| ui-ux-pro-max anti-patterns 필드 부재 시 게이트 오작동 | L | `antipatterns: []` fallback → 게이트 자동 skip 명세 |

---

### Task 1: commands/design-screen.md — Step 2.5 rationale 보관 + Step 3.5 신설 + Step 4 append

**파일**:
- 수정: `commands/design-screen.md`

- [ ] **Step 1: Step 2.5 rationale 보관 명세 추가**

  현재 Step 2.5 마지막 줄:
  ```
  산출된 design system(style/colors/typography/effects + anti-patterns)을 Step 3 HTML artifact 의 레이아웃·컴포넌트·스타일 선택에 반영. **우선순위**: ui-ux-pro-max 결과 우선 채택 — DESIGN.md 토큰은 후순위 fallback.
  ```

  → 해당 bullet 뒤에 다음 내용 추가 (빈 줄 후):
  ```markdown
  자문 완료 후 아래 4개 항목을 **rationale 변수**로 추출해 이후 Step에서 사용:
  - `style`: style 이름 + 근거 한 줄
  - `color`: primary hex / surface hex
  - `font`: heading-font / body-font 페어링
  - `antipatterns`: anti-pattern 목록 배열 (필드 부재 시 빈 배열 `[]`)
  ```

  - **없으면** bullet 끝에 한 줄 추가: `rationale = null`

- [ ] **Step 2: Step 3.5 섹션 신설 (Step 3과 Step 4 사이에 삽입)**

  `### Step 3: HTML artifact 생성` 섹션 끝과 `### Step 4: 파일 저장` 헤더 사이에 삽입:
  ```markdown
  ### Step 3.5: Anti-pattern 게이트 (자동)

  **활성 조건**: `rationale`가 null이거나 `rationale.antipatterns`가 빈 배열(`[]`)이면 → skip, Step 4 직행.

  **활성 시**: Step 3에서 생성한 HTML과 `rationale.antipatterns` 목록을 대조:

  - **위반 없음** → `✅ Anti-pattern 체크 통과` 출력 후 Step 4 직행
  - **위반 발견** → 아래 프롬프트 출력 후 응답 대기:
    > `⚠️ Anti-pattern 위반: {위반 항목 목록}. 수정 후 저장 / 그냥 저장 [m/s, 기본=s]`
    - `m` → Step 3(HTML artifact 생성 + 수정 루프)으로 복귀
    - `s` 또는 Enter → Step 4 직행 (위반 인지, 사용자 주권 존중)
  ```

- [ ] **Step 3: Step 4에 rationale 동적 append 로직 추가**

  `### Step 4: 파일 저장` 섹션의 기존 bullet 목록 끝에 추가:
  ```markdown
  **[rationale 있으면]** screen.md 파일 끝에 다음 섹션을 append:
  ```markdown
  ## Design Rationale

  > ui-ux-pro-max 자문 기반 ({YYYY-MM-DD})

  - **Style**: {rationale.style}
  - **Color**: {rationale.color}
  - **Font pairing**: {rationale.font}
  - **Anti-patterns (금지)**: {rationale.antipatterns 쉼표 연결}
  ```
  rationale가 null이면 append 없이 저장 완료.
  ```

- [ ] **Step 4: 변경 내용 검토 + 커밋**

  ```bash
  grep -n "rationale\|Anti-pattern\|3\.5\|Design Rationale" commands/design-screen.md
  git add commands/design-screen.md
  git commit -m "feat(design-screen): rationale 보관 + Step 3.5 anti-pattern 게이트 + Step 4 동적 append"
  ```

---

### Task 2: commands/design-screens.md — Step 2 rationale 보관 + Step 3-3.5 신설 + Step 3-4 append

**파일**:
- 수정: `commands/design-screens.md`

- [ ] **Step 1: Step 2에 rationale 보관 명세 추가 (단수 Step 2.5와 동기화)**

  `## Step 2: design system 자문 (1회 공유)` 섹션에서:
  - 제목 변경: `## Step 2: design system 자문 + rationale 보관 (1회 공유)`
  - `없으면 skip` bullet 끝에 ` \`rationale = null\`` 추가
  - `있으면` 동작 설명 뒤에 다음 추가:

  ```markdown
  자문 완료 후 단수 Step 2.5와 동일한 4개 항목을 **rationale 변수**로 추출해 모든 화면에 공유 적용:
  - `style`: style 이름 + 근거 한 줄
  - `color`: primary hex / surface hex
  - `font`: heading-font / body-font 페어링
  - `antipatterns`: anti-pattern 목록 배열 (필드 부재 시 `[]`)
  ```

- [ ] **Step 2: Step 3-3.5 신설 (Step 3-3과 Step 3-4 사이에 삽입)**

  `**Step 3-3: HTML artifact 생성 + 수정 루프**` 단락과 `**Step 3-4: 저장**` 단락 사이에 삽입:
  ```markdown
  **Step 3-3.5: Anti-pattern 게이트**

  단수 Step 3.5와 동일. `rationale`가 null이거나 `antipatterns`가 빈 배열이면 → skip, Step 3-4 직행.

  활성 시 HTML ↔ `antipatterns` 대조:
  - **위반 없음** → `✅ Anti-pattern 체크 통과` 출력 후 Step 3-4 직행
  - **위반 발견** → `⚠️ Anti-pattern 위반: {위반 항목 목록}. 수정 후 저장 / 그냥 저장 [m/s, 기본=s]`
    - `m` → Step 3-3(HTML 수정 루프) 복귀
    - `s` 또는 Enter → Step 3-4 직행
  ```

- [ ] **Step 3: Step 3-4에 rationale append 로직 추가 (단수 Step 4와 동기화)**

  `**Step 3-4: 저장**` 단락 기존 내용 끝에 추가:
  ```markdown
  **[rationale 있으면]** 단수 Step 4와 동일하게 screen.md 끝에 `## Design Rationale` 섹션 append (공유 rationale 적용). rationale가 null이면 append 없이 저장.
  ```

- [ ] **Step 4: 변경 내용 검토 + 커밋**

  ```bash
  grep -n "rationale\|Anti-pattern\|3-3\.5\|Design Rationale" commands/design-screens.md
  git add commands/design-screens.md
  git commit -m "feat(design-screens): rationale 공유 보관 + Step 3-3.5 게이트 + Step 3-4 동적 append"
  ```

---

### Task 3: 회귀 검증 + AC 수동 확인

**파일**:
- 검증: `templates/screen.md`, `scripts/tests/test-design-screen.sh`

- [ ] **Step 1: templates/screen.md 변경 없음 확인 (AC-8-override)**

  ```bash
  grep "## Design Rationale" templates/screen.md
  # 예상: 매칭 없음 (exit 1 또는 빈 결과)
  ```

- [ ] **Step 2: 회귀 스크립트 실행 (AC-R-2)**

  ```bash
  bash scripts/tests/test-design-screen.sh
  # 예상: PASS=12 FAIL=0
  ```

- [ ] **Step 3: AC 수동 검토 체크리스트**

  design-screen.md 검토:
  ```bash
  grep -n "rationale" commands/design-screen.md
  # 예상: Step 2.5 (rationale 추출), Step 3.5 (게이트), Step 4 (append) 각 1회 이상
  grep -n "Step 3\.5" commands/design-screen.md
  # 예상: "### Step 3.5: Anti-pattern 게이트" 라인 존재
  grep -n "Design Rationale" commands/design-screen.md
  # 예상: Step 4 섹션에 존재
  ```

  design-screens.md 검토:
  ```bash
  grep -n "rationale" commands/design-screens.md
  # 예상: Step 2, Step 3-3.5, Step 3-4 각 위치
  grep -n "3-3\.5\|Anti-pattern" commands/design-screens.md
  # 예상: "Step 3-3.5: Anti-pattern 게이트" 존재
  ```

- [ ] **Step 4: session-progress append + 최종 커밋**

  ```bash
  bash scripts/session-progress-append.sh 20260610-design-screen-enrich /implement DONE "Task T1~T3 완료"
  git add -f .specops/20260610-design-screen-enrich/
  git commit -m "chore: plan.md + 회귀검증 결과 기록 (20260610-design-screen-enrich)"
  ```

---

## 7. 자체 검토 (5원칙 체크리스트)

- [x] **투명성**: 각 태스크에 "왜 이 순서인가" 명시 — T1·T2 독립(병렬 가능), T3은 T1·T2 의존
- [x] **문지기**: 파괴적 작업 없음 — 커맨드 md 편집만, 스크립트 미변경
- [x] **주권 존중**: anti-pattern 게이트에서 사용자가 [m/s] 선택 (강제 차단 아님)
- [x] **한계 고백**: §1 가정에 ui-ux-pro-max 반환 필드 가정, 자동화 테스트 없음 명시

## 8. Advisor 협의 기록

해당 없음 — 본 plan 작성 중 불확실 지점 없음. spec/clarifications가 이미 모든 설계 결정을 확정함.

## 9. 다음 단계

`/tasks 20260610-design-screen-enrich` — 본 플랜을 바이트-사이즈 TDD 태스크로 분해.

---

*작성: andyko · 2026-06-10 · FID: 20260610-design-screen-enrich · 생성 커맨드: /plan*
