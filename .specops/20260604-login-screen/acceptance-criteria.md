<!-- FID: 20260604-login-screen -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260604-login-screen

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다.

## 계약 항목

### AC-1: 로그인 폼 렌더링

**Given** `screens/login.html`을 최신 브라우저(Chrome/Firefox/Safari)로 열었을 때

**When** 페이지가 로드된다

**Then** 이메일 input(type=email)과 비밀번호 input(type=password)이 각각 label과 연결되어 렌더링되고, 로그인 버튼이 표시된다

**검증 방법**: 브라우저에서 `screens/login.html` 직접 열기 → 두 input + 버튼 시각 확인, DevTools에서 `input[type=email]`, `input[type=password]` 존재 확인
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: 로딩 상태 전환

**Given** 이메일·비밀번호 입력 필드에 임의 값이 입력된 상태에서

**When** 로그인 버튼을 클릭한다

**Then** 버튼이 즉시 비활성화(disabled)되고 텍스트가 "로그인 중..."으로 변경된다

**검증 방법**: 브라우저에서 버튼 클릭 → 버튼 disabled 속성 + 텍스트 변경 시각 확인
**관련 FR**: FR-2
**우선순위**: must

---

### AC-3: 에러 상태 표시

**Given** 로딩 상태 시뮬레이션이 완료된 후

**When** 인증 실패 상태로 전환된다

**Then** 입력 필드에 error 스타일(빨간 테두리 등)이 적용되고, 에러 메시지 텍스트가 폼 영역에 표시된다

**검증 방법**: 버튼 클릭 후 약 2초 대기 → 에러 스타일 + 메시지 시각 확인
**관련 FR**: FR-3
**우선순위**: must

---

### AC-4: 반응형 레이아웃

**Given** `screens/login.html`이 열린 상태에서

**When** 뷰포트 너비를 320px로 축소한다

**Then** 가로 스크롤 없이 로그인 폼의 모든 요소가 정상 렌더링된다

**검증 방법**: DevTools 반응형 모드에서 320px 설정 → 가로 스크롤 없음, 폼 요소 잘림 없음 확인
**관련 FR**: FR-4
**우선순위**: must

---

### AC-5: 비밀번호 표시/숨김 토글

**Given** 비밀번호 input 필드가 렌더링된 상태에서

**When** 입력 필드 오른쪽의 토글 버튼을 클릭한다

**Then** input의 type이 `password` ↔ `text`로 전환되어 입력값이 표시/숨김 처리된다

**검증 방법**: 브라우저에서 토글 클릭 → input type 변화 시각 확인, DevTools에서 `input.type` 속성 확인
**관련 FR**: FR-1 (확장)
**우선순위**: should

---

## 회귀 방지 AC

> **§유형 = 신규** — 회귀 AC 강제 면제.

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md`에 사유 기록
- **nice-to-have**: 여유가 있으면 반영. 미충족 시 BLOCK 없음

---

*작성: specops-auto-ko · 2026-06-04 · FID: 20260604-login-screen · 생성 커맨드: /specify*
