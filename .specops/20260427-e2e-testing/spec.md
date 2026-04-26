<!-- FID: 20260427-e2e-testing -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md -->
<!-- layer: Lifecycle-Artifact -->

# E2E 자동 테스트 스킬 명세 — 20260427-e2e-testing

## 1. 개요

**목적**: AI가 Chrome 브라우저(웹)와 모바일 에뮬레이터(Appium)를 직접 조작해 E2E 테스트를 자동으로 생성·실행한다.

**배경**: TDD(tdd-ko)는 코드 단위 검증을 담당하지만, 실제 브라우저·모바일 환경에서의 사용자 흐름 검증은 별도 레이어가 필요하다. screens/{name}.md의 Interactions 섹션과 acceptance-criteria.md의 Given/When/Then을 합쳐 시나리오를 자동 생성하면 화면 설계서와 테스트가 항상 동기화된다.

**성공 판정**: `e2e-testing-ko` 스킬 호출 시 Chrome 브라우저와 모바일 에뮬레이터에서 E2E 테스트가 자동 실행되고 결과가 `e2e-results.md`에 기록된다.

## 2. 범위

### 포함
- `skills/e2e-testing-ko/SKILL.md` — E2E 테스트 스킬 (독립 — 병렬 구현 가능)
- `commands/e2e-test.md` — `/e2e-test` 독립 커맨드 (독립 — 병렬 구현 가능)
- 시나리오 생성기 — screens/ Interactions + AC Given/When/Then → 테스트 코드 변환 (의존: screens/, acceptance-criteria.md)
- 결과 리포터 — 실행 결과 + 스크린샷 → e2e-results.md (의존: 시나리오 생성기)

### 제외 (YAGNI)
- CI/CD 파이프라인 자동 연동
- 시각적 회귀 테스트 (Visual Regression Testing)
- 성능/부하 테스트
- Puppeteer·Appium 자동 설치 (사용자가 사전 설치)

## 3. 사용자 시나리오

### 주요 시나리오 — 웹 E2E
**사용자**: specops-auto-ko로 웹 앱을 개발 중인 개발자
**상황**: implementing-ko로 로그인 기능 구현 완료 후
**행동**: `e2e-testing-ko` 스킬 호출 (또는 `/e2e-test web`)
**기대 결과**: AI가 screens/login.md Interactions + AC를 읽고 Puppeteer 테스트를 생성·실행. Chrome 브라우저에서 로그인 흐름이 자동으로 검증되고 스크린샷이 저장됨

### 주요 시나리오 — 모바일 E2E
**사용자**: 동일
**상황**: 동일
**행동**: `/e2e-test mobile` 또는 `/e2e-test all`
**기대 결과**: 모바일 웹은 Puppeteer 디바이스 에뮬레이션으로, 네이티브 앱은 Android AVD / iOS Simulator에서 Appium으로 테스트 실행

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | `screens/{name}.md`의 `## Interactions` 섹션을 파싱해 테스트 시나리오 자동 생성 | must |
| FR-2 | `acceptance-criteria.md`의 `Given/When/Then`을 파싱해 테스트 시나리오 자동 생성 | must |
| FR-3 | FR-1·FR-2 중복 시나리오 자동 병합 (같은 동작 두 번 실행 방지) | must |
| FR-4 | Puppeteer로 Chrome 브라우저를 직접 제어해 웹 테스트 실행 | must |
| FR-5 | Puppeteer 디바이스 에뮬레이션(Mobile Chrome)으로 모바일 웹 테스트 실행 | must |
| FR-6 | Appium으로 Android AVD / iOS Simulator 연결해 네이티브 앱 테스트 실행 | must |
| FR-7 | 테스트 결과 (PASS/FAIL) + 스크린샷 경로를 `.specops/<FID>/e2e-results.md`에 저장 | must |
| FR-8 | `/e2e-test [web\|mobile\|native\|all]` 독립 커맨드 지원 | must |
| FR-9 | Lifecycle 내 `verifying-evidence-ko` 이후 선택적 자동 호출 | should |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 런타임 | Node.js 18+ (실측 미확인) |
| NFR-2 | Puppeteer | 20.0+ (실측 미확인) |
| NFR-3 | Appium | 2.0+ (실측 미확인) |
| NFR-4 | 테스트 타임아웃 | 기본 30초/테스트 (설정 가능) |
| NFR-5 | 스크린샷 저장 경로 | `e2e/screenshots/{name}-{timestamp}.png` |

## 6. 제약사항

- **기술 스택**: Node.js, Puppeteer (Chrome DevTools Protocol), Appium 2.0
- **의존성**:
  - 웹 테스트: Chrome 108+ 설치 필요, 앱이 localhost에서 실행 중이어야 함
  - 네이티브 테스트: Android AVD 또는 iOS Simulator가 이미 실행 중이어야 함
  - Appium: `appium` + 플랫폼 드라이버 (`uiautomator2`, `xcuitest`) 사전 설치 필요
- **호환성**: specops-auto-ko 기존 Lifecycle 스킬 체인과 호환 (verifying-evidence-ko 이후)

## 7. 가정

- Puppeteer, Appium, Chrome은 사용자가 별도 설치한 상태 (specops-auto-ko가 설치 책임 없음)
- Android AVD 또는 iOS Simulator가 테스트 실행 전 이미 구동 중인 상태
- 웹 앱은 `localhost:{port}`에서 실행 중인 상태 (포트는 `/e2e-test` 호출 시 파라미터로 지정)
- `screens/{name}.md`의 `## Interactions` 섹션이 존재해야 웹 시나리오 생성 가능
- 네이티브 앱 테스트는 앱 패키지명(`bundleId` / `appPackage`) 파라미터 필요

## 8. 열린 질문

- Q1: 네이티브 앱 테스트 시 앱 패키지명을 어디서 가져올지 (screens/ frontmatter? 별도 설정 파일?)
- Q2: Appium 서버 실행을 AI가 자동으로 할지, 사용자가 수동 실행하는지

## 9. Advisor 협의 기록

해당 없음 — 본 spec 작성 중 불확실 지점 없음.

## 10. 참조

- `skills/e2e-testing-ko/SKILL.md` — 구현 대상 스킬
- `commands/e2e-test.md` — 구현 대상 커맨드
- `skills/verifying-evidence-ko/SKILL.md` — Lifecycle 선행 스킬
- `screens/login.md` — dogfood 테스트 대상 예시
- `DESIGN.md` — 디자인 시스템 준수

---

*작성: kohaedong · 2026-04-27 · FID: 20260427-e2e-testing · 생성 커맨드: /specify*
