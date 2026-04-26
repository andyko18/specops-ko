<!-- FID: 20260427-design-md -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md -->
<!-- layer: Lifecycle-Artifact -->

# awesome-design-md 통합 명세 — 20260427-design-md

## 1. 개요

**목적**: specops-auto-ko에 프로젝트 수준 디자인 시스템 문서(DESIGN.md) 생성·관리 흐름을 추가해, UI 프로젝트에서 AI가 일관된 디자인으로 컴포넌트를 생성할 수 있게 한다.

**배경**: awesome-design-md(Google Stitch 제안, 65K+ stars)는 AI 에이전트가 읽고 UI를 생성하기 위한 플레인텍스트 디자인 시스템 문서 포맷이다. specops-auto-ko는 현재 CLI/API 도구 중심으로 검증됐으나, UI 프로젝트 확장을 위해 DESIGN.md 생성·참조 흐름이 필요하다.

**성공 판정**: `/start-design` 커맨드로 DESIGN.md가 프로젝트 루트에 생성되고, 이후 specifying-ko가 이를 자동 감지해 spec.md §참조에 포함하면 완성이다.

## 2. 범위

### 포함
- `commands/start-design.md` 슬래시 커맨드 신규 작성 (독립 — 병렬 구현 가능)
- `templates/DESIGN.md` awesome-design-md 포맷 템플릿 신규 작성 (독립 — 병렬 구현 가능)
- `skills/specifying-ko/SKILL.md` DESIGN.md 감지·참조 주입 스텝 추가 (의존: templates/DESIGN.md)
- dogfood: specops-auto-ko 프로젝트 루트에 실제 DESIGN.md 생성 (의존: commands/start-design.md)

### 제외 (YAGNI)
- awesome-design-md 브랜드 DB 자동 크롤링 (웹 요청 없음)
- preview.html 시각 미리보기 생성
- implementing-ko dispatch-context DESIGN.md 필드 주입
- React/CSS-in-JS 컴포넌트 자동 생성

## 3. 사용자 시나리오

### 주요 시나리오 — 신규 UI 프로젝트 시작
**사용자**: specops-auto-ko로 Next.js 대시보드 프로젝트를 시작하는 개발자
**상황**: 새 프로젝트 폴더를 만들고 첫 기능 specifying 전 디자인 시스템을 설정하고 싶다
**행동**: `/start-design` 입력 → 브랜드 선택(예: Stripe) → DESIGN.md 자동 생성
**기대 결과**: 프로젝트 루트에 색상·타이포·컴포넌트 규칙이 담긴 DESIGN.md 생성. 이후 specifying-ko가 UI 기능 스펙 작성 시 DESIGN.md를 자동 참조에 포함.

### 보조 시나리오 — 기존 프로젝트에 추가
**상황**: 이미 진행 중인 프로젝트에 뒤늦게 디자인 시스템 도입
**행동**: `/start-design` 입력 → "이미 존재합니다. 덮어쓸까요?" 확인 → y
**기대 결과**: 기존 DESIGN.md 덮어쓰기 후 재생성.

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | `/start-design` 커맨드 실행 시 브랜드 선택 질문을 제시하고 선택에 따라 DESIGN.md를 생성한다 | must |
| FR-2 | DESIGN.md 템플릿은 6개 섹션(Color/Typography/Spacing/Components/Principles/AI Usage)을 포함한다 | must |
| FR-3 | specifying-ko 탐색 단계에서 프로젝트 루트의 DESIGN.md 존재를 확인한다 | must |
| FR-4 | DESIGN.md가 존재하면 spec.md §참조에 "DESIGN.md 디자인 시스템 준수" 지시를 포함한다 | must |
| FR-5 | `/start-design` 실행 시 기존 DESIGN.md가 있으면 덮어쓰기 전 사용자 확인을 요청한다 | should |
| FR-6 | `/start-design`이 DESIGN.md 생성 후 git commit을 수행한다 | should |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 형식 | awesome-design-md 포맷 호환 (6섹션 구조, AI Usage Guidelines 포함) |
| NFR-2 | 언어 | 커맨드·스킬 문서는 한국어. DESIGN.md 템플릿 내 실제 설계값은 영어 허용 |
| NFR-3 | 의존성 | 외부 네트워크 요청 없음. stdlib·git만 사용 |

## 6. 제약사항

- 기술 스택: 마크다운 파일만 (bash/Python 코드 없음)
- 의존성: git CLI (commit용)
- 호환성: 기존 specops-auto-ko Lifecycle(specifying-ko 체크리스트) 파괴 금지 — append-only 수정

## 7. 가정 (5원칙 5번 — 한계 고백)

- DESIGN.md는 프로젝트 루트 (`./DESIGN.md`)에 위치한다고 가정. 서브디렉토리 지원 불필요.
- 브랜드 레퍼런스 콘텐츠는 AI 지식 기반으로 생성. awesome-design-md 레포 크롤링 미포함.
- specifying-ko 수정은 체크리스트 1번 항목 append만 수행. 기존 로직 변경 없음.

## 8. 열린 질문

`/clarify` 단계에서 해소할 사항.

- Q1: dogfood DESIGN.md 생성 시 어떤 브랜드를 사용할까? (사용자 선호)
- Q2: specifying-ko에서 UI 컴포넌트 포함 여부를 어떻게 판단할까? (자동 감지 vs 명시적 질문)

## 9. Advisor 협의 기록

해당 없음 — 본 spec 작성 중 불확실 지점 없음.

## 10. 참조

- awesome-design-md: https://github.com/VoltAgent/awesome-design-md
- getdesign.md: https://getdesign.md/
- 관련 선행 FID: 20260427-csvstat-cli (Python 지원 인프라)

---

*작성: specops-auto-ko · 2026-04-26 · FID: 20260427-design-md · 생성 커맨드: /specify*
