<!-- FID: 20260610-design-screen-enrich -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md -->
<!-- layer: Lifecycle-Artifact -->

# design-screen(s) ui-ux-pro-max 심층 연동 강화 명세 — 20260610-design-screen-enrich

## 1. 개요

**목적**: `/design-screen`, `/design-screens` 커맨드에서 ui-ux-pro-max 자문 결과를 `screens/{name}.md`의 `## Design Rationale` 섹션으로 박제하고, 저장 전 anti-pattern 체크 게이트를 추가하여 설계 근거를 추적 가능하게 만든다.

**배경**: 현재 ui-ux-pro-max 자문 결과는 HTML 스타일 생성에만 일회성으로 사용되고 screen.md에 기록되지 않는다. 이후 화면을 수정하거나 리뷰할 때 왜 이 스타일·컬러·폰트를 선택했는지 근거가 사라지는 문제가 있다. 또한 anti-pattern 위반이 저장까지 무검사로 통과된다.

**성공 판정**: `/design-screen foo` 실행 후 `screens/foo.md`에 `## Design Rationale` 섹션이 포함되고, 저장 전 anti-pattern 체크가 수행되면 완성.

**§유형**: 유지보수

## 2. 범위

### 포함

- `commands/design-screen.md` Step 2.5 — rationale 변수 보관 명세 추가 (독립 — 병렬 구현 가능)
- `commands/design-screen.md` Step 3.5(新) — anti-pattern 게이트 (의존: Step 2.5 rationale 보관)
- `commands/design-screen.md` Step 4 — screen.md 저장 시 `## Design Rationale` 섹션 포함 (의존: Step 2.5 rationale 보관)
- `commands/design-screens.md` Step 2 — rationale 1회 공유 보관 명세 동기화 (독립 — 병렬 구현 가능)
- `commands/design-screens.md` Step 3-3.5(新) — 화면별 anti-pattern 게이트 (의존: Step 2 rationale)
- `commands/design-screens.md` Step 3-4 — 저장 시 design-rationale 섹션 포함 동기화 (의존: Step 2 rationale)
- `templates/screen.md` — `## Design Rationale` 섹션 추가 (독립 — 병렬 구현 가능)

### 제외 (YAGNI)

- ui-ux-pro-max 반환 구조 변경 (외부 플러그인 — 불가)
- 기존 `screens/*.md` 파일 소급 갱신 (신규 스캐폴딩에만 적용)
- anti-pattern 자동 수정 (사용자 주권 존중 — 확인 후 진행)
- DESIGN.md 내용과 Design Rationale 섹션 자동 동기화

## 3. 사용자 시나리오

### 주요 시나리오 (신규 화면 설계)
**사용자**: specops-auto-ko 플러그인 사용 개발자
**상황**: `/design-screen dashboard` 실행. ui-ux-pro-max 설치됨
**행동**: Step 2.5에서 자동 자문 → 핵심 결정 요약 → Step 3 HTML 생성 → Step 3.5 anti-pattern 체크 → Step 4 저장
**기대 결과**: `screens/dashboard.md`에 `## Design Rationale` 섹션(style/color/font/anti-patterns) 포함. 위반 없으면 ✅ 출력 후 저장. 위반 있으면 목록 표시 + [m/s] 확인.

### 보조 시나리오 (ui-ux-pro-max 없음)
**상황**: ui-ux-pro-max 미설치
**기대 결과**: Step 2.5 skip → Step 3.5 skip(게이트 미활성) → `## Design Rationale` 섹션 없이 저장. 기존 동작과 동일.

### 보조 시나리오 (복수 화면)
**상황**: `/design-screens "관리자 앱"` 실행
**기대 결과**: Step 2에서 rationale 1회 도출 → 모든 화면에 공유. 화면마다 Step 3-3.5 게이트 → Step 3-4 저장 시 섹션 포함.

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | ui-ux-pro-max 자문 결과에서 style 이름, primary color, 폰트 페어링, anti-pattern 2-3개를 rationale로 추출·보관한다 | must |
| FR-2 | screen.md 저장 시 rationale가 있으면 `## Design Rationale` 섹션을 포함한다 | must |
| FR-3 | rationale가 없으면(ui-ux-pro-max 미사용) Design Rationale 섹션을 생략한다 | must |
| FR-4 | Step 3.5에서 HTML과 anti-pattern 목록을 대조해 위반 발견 시 목록 표시 + [m/s] 확인을 받는다 | must |
| FR-5 | anti-pattern 위반 없으면 `✅ Anti-pattern 체크 통과` 출력 후 바로 저장 진행 | must |
| FR-6 | `templates/screen.md`에 `## Design Rationale` placeholder 섹션을 추가한다 | must |
| FR-7 | `/design-screens`의 rationale는 첫 화면 전 1회만 도출해 모든 화면에 공유한다 | must |
| FR-8 | [m] 선택 시 HTML 수정 루프(Step 3)로 복귀, [s] 선택 시 위반 상태로 저장한다 | should |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 기존 동작 보존 | ui-ux-pro-max 없는 경로에서 기존 flow와 100% 동일 |
| NFR-2 | 단수·복수 일관성 | design-screen.md와 design-screens.md의 rationale/게이트 동작이 동일 |
| NFR-3 | 산출물 규약 | FR-3 미충족(섹션 생략) 시에도 screen.md의 다른 섹션은 정상 저장 |

## 6. 제약사항

- 변경 대상: 커맨드 문서(md) + 템플릿(md) 파일만 — 스크립트·테스트 변경 없음
- ui-ux-pro-max 반환 필드: SKILL.md description 기준 "anti-patterns" 필드 존재 가정. 실제 없을 시 "항목 없음" 처리 분기 필요 (게이트 skip)
- `design-screen.sh`는 `templates/screen.md`를 cp로 스캐폴딩 — 템플릿 변경이 신규 스캐폴딩에 자동 반영됨

## 7. 가정

- ui-ux-pro-max SKILL이 반환하는 결과에 anti-patterns 열거 필드가 존재한다고 가정 (SKILL.md description 기반)
- [s] 선택 시 위반 상태 저장은 screen.md에 별도 경고 표시 없이 저장 (사용자가 이미 인지)

## 8. 열린 질문

없음.

## 9. Advisor 협의 기록

해당 없음 — 본 spec 작성 중 불확실 지점 없음.

## 10. 참조

- `.specops/20260610-design-screen-enrich/current-state.md`
- `.specops/20260610-design-screen-enrich/impact-analysis.md`
- `commands/design-screen.md` — 단수 커맨드 (변경 대상)
- `commands/design-screens.md` — 복수 커맨드 (변경 대상)
- `templates/screen.md` — 화면 스펙 템플릿 (변경 대상)
- `skills/ui-ux-pro-max/SKILL.md` — design system 자문 (외부 플러그인)

---

*작성: andyko · 2026-06-10 · FID: 20260610-design-screen-enrich · 생성 커맨드: /specify*
