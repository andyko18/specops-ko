<!-- FID: 20260604-login-screen -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md -->
<!-- layer: Lifecycle-Artifact -->

# 로그인 화면 명세 — 20260604-login-screen

## 1. 개요

**§유형**: 신규

**목적**: 사용자가 이메일·비밀번호로 서비스에 인증하는 정적 HTML/CSS 로그인 화면을 제공한다.

**배경**: UI 기능 테스트 목적으로 specops-auto-ko의 화면 설계 Lifecycle(ui-ux-pro-max 연동 포함)을 검증한다.

**성공 판정**: `screens/login.html`을 브라우저에서 열었을 때 이메일·비밀번호 입력 + 로그인 버튼이 정상 렌더링되고 상태 전환(Loading/Error)이 동작한다.

## 2. 범위

### 포함
- 로그인 폼 레이아웃 (독립 — 병렬 구현 가능)
- 입력 필드 스타일 + focus/error 상태 (독립 — 병렬 구현 가능)
- 버튼 Loading 상태 시뮬레이션 (의존: 로그인 폼 레이아웃)

### 제외 (YAGNI)
- 실제 인증 API 연동
- 소셜 로그인
- 비밀번호 재설정 기능 (링크 표시만)
- 회원가입 기능

## 3. 사용자 시나리오

### 주요 시나리오
**사용자**: 서비스 기존 회원
**상황**: 브라우저에서 로그인 화면 접근
**행동**: 이메일·비밀번호 입력 후 로그인 버튼 클릭
**기대 결과**: 버튼이 "로그인 중..."으로 바뀌며 비활성화됨 → 에러 상태로 전환(시뮬레이션)

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | 이메일 input(type=email)과 비밀번호 input(type=password)을 렌더링한다 | must |
| FR-2 | 로그인 버튼 클릭 시 버튼을 비활성화하고 "로그인 중..." 텍스트를 표시한다 | must |
| FR-3 | 인증 실패 시 입력 필드에 error 스타일과 에러 메시지를 표시한다 | must |
| FR-4 | 320px 이상 뷰포트에서 레이아웃이 깨지지 않는다 | must |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 기술 스택 | 순수 HTML5 + CSS3, JS 최소화 (상태 전환 시뮬레이션만) |
| NFR-2 | 접근성 | label-for 연결, 키보드 tab 순서 준수 |
| NFR-3 | 반응형 | 320px 이상 정상 렌더링 |

## 6. 제약사항

- 기술 스택: HTML5, CSS3 (CSS 변수), 인라인 JS (상태 전환만)
- 의존성: 없음 (외부 라이브러리 없음)
- 호환성: 최신 브라우저 (Chrome/Firefox/Safari)

## 7. 가정

- 실제 인증 백엔드 없음 — 시뮬레이션으로 대체
- DESIGN.md 부재 → 템플릿 기본 CSS 변수 사용

## 8. 열린 질문

- Q1: 비밀번호 표시/숨김 토글 추가 필요 여부

## 9. Advisor 협의 기록

해당 없음 — 본 spec 작성 중 불확실 지점 없음.

## 10. 참조

- `screens/login.md` — 화면 스펙
- `screens/login.html` — HTML 미리보기

---

*작성: specops-auto-ko · 2026-06-04 · FID: 20260604-login-screen · 생성 커맨드: /specify*
