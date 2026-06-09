<!-- FID: 20260609-design-screens -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: specops-auto-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# /design-screens (복수) 신규 커맨드 명세 — 20260609-design-screens

## 1. 개요

**§유형**: 신규

**목적**: 기능 설명 하나로 여러 화면을 한 번에 일괄 디자인하는 standalone 진입로를 제공한다.

**배경**: 현재 화면 설계 진입로는 `/start` Step 5.5 (Lifecycle 인라인) 또는 `/design-screen` (단수 1개)뿐이다. 여러 화면을 한 번에 standalone 으로 디자인하는 진입로가 없어, 사용자가 단수 커맨드를 N번 반복 호출해야 하는 불편이 있다. `/design-screens` (복수) 는 기능 설명 → 화면 목록 자동 판단 → 승인 게이트 → 각 화면 순차 대화 루프로 이 불편을 해소하는 오케스트레이터다.

**성공 판정**: `/design-screens "X 기능"` 실행 시 화면 목록을 자동 제안하고, 사용자 승인 후 각 화면에 대한 `screens/*.md + *.html` 쌍이 생성된다.

## 2. 범위

### 포함

- `commands/design-screens.md` 신설 — 복수 오케스트레이터 커맨드 (독립 — 병렬 구현 가능)
- `README.md` 12건→13건 갱신 + file tree design-screens.md 항목 추가 (의존: design-screens.md)
- `scripts/_internal/.structure-baseline` commands count:12→13 갱신 (의존: design-screens.md)
- `commands/design-screen.md` 참조 섹션에 복수 커맨드 cross-reference 1줄 추가 (독립)

### 제외 (YAGNI)

- `scripts/_internal/design-screen.sh` 백엔드 수정 — 무수정 재사용
- 화면 병렬/비동기 동시 설계
- YAML/JSON 파일 입력으로 화면 목록 제공
- `/start` specifying-ko Step 5.5 수정

## 3. 사용자 시나리오

### 주요 시나리오

**사용자**: 프론트엔드 개발자 (specops-auto-ko 사용 중)
**상황**: 새 기능에 필요한 화면 3개를 한 번에 설계하고 싶음
**행동**: `/design-screens "로그인, 대시보드, 설정 기능"` 호출 → 화면 목록 제안 검토 → 승인 → 각 화면 목적·컴포넌트 입력 → HTML 편집 루프
**기대 결과**: screens/login.md, screens/dashboard.md, screens/settings.md + 각 .html 생성, git commit 완료

### 보조 시나리오

**충돌 케이스**: 이미 screens/login.md 존재 → 사용자에게 --force 여부 확인 → y 시 덮어쓰기, n 시 해당 화면 skip

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | `/design-screens {기능 설명}` 진입 시 필요 화면 목록(이름+한 줄 설명)을 자동 도출한다 | must |
| FR-2 | 도출된 목록을 사용자에게 제시하고 승인/편집 게이트 루프를 실행한다 | must |
| FR-3 | 승인 후 화면 이름이 `^[A-Za-z0-9_-]{1,64}$` 를 충족하는지 검증한다 | must |
| FR-4 | `ui-ux-pro-max:ui-ux-pro-max` 가 available-skills 에 있으면 첫 화면 전 1회만 호출해 design system 을 모든 화면에 공유한다 | should |
| FR-5 | 각 화면에 대해 순차적으로 design-screen.sh 스캐폴딩 → 목적·컴포넌트 질문 → HTML artifact + 편집 루프 → 파일 저장 → git commit 을 실행한다 | must |
| FR-6 | 화면 파일이 이미 존재하면 --force 사용 여부를 사용자에게 확인한다 | must |
| FR-7 | 진행 상황을 "화면 N/총M: {name} 완료" 형태로 표시한다 | should |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 런타임 호환성 | Claude Code CLI + bash 3.2+ (macOS 실측 · Linux 미검증) |
| NFR-2 | 백엔드 계약 준수 | design-screen.sh CLI 계약 (name regex, --force, exit code) 변경 없이 재사용 |
| NFR-3 | 구조 검증 | validate-structure.sh 전 항목 ✅ 유지 (commands=13) |

## 6. 제약사항

- 기술 스택: Claude Code commands (Markdown), bash, git
- 의존성: `scripts/_internal/design-screen.sh` (무수정 재사용), `scripts/_internal/.structure-baseline`
- 호환성: 기존 `/design-screen` (단수) 와 공존 — 단수 동작 영향 없음

## 7. 가정 (5원칙 5번 — 한계 고백)

- design-screen.sh 의 CLI 계약(name regex, --force, exit 1 on conflict)은 불변으로 가정
- ui-ux-pro-max skill 부재 시 DESIGN.md fallback 으로 충분하다고 가정
- 화면별 commit 은 단수 Step 5 흐름을 그대로 위임한다고 가정 (전체 batch 단일 commit 은 clarify DESIRABLE)

## 8. 열린 질문

`/clarify` 단계에서 해소할 사항.

- Q1: 전체 batch 완료 후 단일 commit 으로 묶는 옵션을 지원할 것인가? (DESIRABLE)
- Q2: 화면 목록 자동 판단 실패(기능 설명 부족) 시 fallback 질문 방식은? (DESIRABLE)

## 9. Advisor 협의 기록

해당 없음 — 본 spec 작성 중 불확실 지점 없음 (설계는 AskUserQuestion 으로 사용자 확정, 기술 제약은 design-screen.sh 코드 직접 확인).

## 10. 참조

- `commands/design-screen.md` — 단수 커맨드 (위임 대상)
- `scripts/_internal/design-screen.sh` — 백엔드 스크립트 (무수정 재사용)
- `scripts/tests/test-design-screen.sh` — 기존 백엔드 테스트 (회귀 보호)
- `scripts/_internal/.structure-baseline` — 구조 검증 baseline

---

*작성: specifying-ko · 2026-06-09 · FID: 20260609-design-screens · 생성 커맨드: /start*
