<!-- FID: 20260604-login-screen -->
<!-- OWNER_COMMAND: /plan -->
<!-- reference_upstream: github/spec-kit plan-template.md + obra/superpowers writing-plans -->
<!-- layer: Lifecycle-Artifact -->

# 로그인 화면 구현 플랜 — 20260604-login-screen

> **에이전트 워커용**: 필수 하위 스킬 — `specops-auto-ko:implementing-ko`. 스텝은 체크박스 `- [ ]` 문법으로 추적.

**목표**: `screens/login.html`에 AC-1~AC-4 충족 검증 + AC-5 비밀번호 표시/숨김 토글을 추가한다. (AC-5 scope는 `.specops/20260604-login-screen/clarifications.md` Q1 RESOLVED에서 확정됨)

**아키텍처**: 기존 `screens/login.html`은 이미 FR-1~FR-4(폼 렌더링, 로딩/에러 상태, 반응형)를 구현하고 있다. bash grep 기반 검증 스크립트로 AC-1~AC-4를 TDD 방식으로 확정하고, 이후 AC-5(토글) 구현을 추가한다. 외부 의존성 없이 순수 HTML5/CSS3/인라인 JS로만 구현.

**기술 스택**: HTML5, CSS3 (CSS 변수), 인라인 JS, bash (검증 스크립트)

**관련 AC**: AC-1, AC-2, AC-3, AC-4, AC-5

---

## 1. 가정 (5원칙 5번)

- 브라우저 자동화 테스트(Playwright) 없음 → bash grep으로 HTML 구조 검증, 동적 상태(Loading/Error)는 수동 브라우저 검증으로 대체
- 기존 `screens/login.html`이 AC-1~AC-4를 이미 충족한다고 판단 (코드 리뷰 확인)
- 토글 버튼에 별도 아이콘 라이브러리 없음 → SVG 인라인 또는 텍스트("보기"/"숨기기")로 대체

## 2. 파일 구조

### 수정
- `screens/login.html` — AC-5 비밀번호 토글 버튼 + CSS + JS 추가

### 생성
- `scripts/tests/test-login-screen.sh` — HTML 구조 grep 검증 (AC-1 input 존재, AC-4 viewport meta, AC-5 토글 버튼)

## 3. 태스크 개요

1. **검증 스크립트 작성** — bash grep으로 AC-1/AC-4/AC-5 구조 검증 (TDD 선행 작성)
2. **기존 파일 검증 실행** — AC-1~AC-4 PASS, AC-5 FAIL 확인
3. **AC-5 토글 구현** — login.html에 토글 버튼·CSS·JS 추가
4. **검증 재실행** — 전체 PASS 확인 후 커밋

## 4. 위험과 완화

| 위험 | 영향 | 완화 |
|---|---|---|
| 토글 버튼이 기존 input 레이아웃을 깨뜨림 | M | `.input-wrapper` position:relative로 감싸고 버튼은 absolute 우측 배치 |
| 320px에서 토글 버튼이 input 텍스트와 겹침 | M | padding-right 충분히 확보 (40px+) |

---

## Task 1: 검증 스크립트 작성 (TDD 선행)

**목적**: AC-1(input 존재), AC-4(viewport meta), AC-5(토글 버튼) 구조를 grep으로 검증하는 bash 스크립트를 먼저 작성해 TDD 기준을 확정.

**파일**:
- 생성: `scripts/tests/test-login-screen.sh`

- [ ] **Step 1: 검증 스크립트 작성**

```bash
#!/usr/bin/env bash
set -euo pipefail
FILE="screens/login.html"
PASS=0; FAIL=0

check() {
  local label="$1" pattern="$2"
  if grep -q "$pattern" "$FILE"; then
    echo "PASS: $label"; ((PASS++))
  else
    echo "FAIL: $label"; ((FAIL++))
  fi
}

check "AC-1 이메일 input(type=email)" 'type="email"'
check "AC-1 비밀번호 input(type=password)" 'type="password"'
check "AC-1 label[for=email]" 'for="email"'
check "AC-1 label[for=password]" 'for="password"'
check "AC-2/AC-3 error-msg 요소" 'error-msg'
check "AC-2/AC-3 error-input 클래스" 'error-input'
check "AC-2 btn.disabled 처리" 'btn.disabled'
check "AC-2 로그인 중 텍스트" '로그인 중'
check "AC-4 viewport meta" 'width=device-width'
check "AC-5 비밀번호 토글 버튼" 'toggle-password'
check "AC-5 토글 aria-label" 'aria-label="비밀번호 표시/숨김"'

echo ""
echo "결과: PASS=${PASS}, FAIL=${FAIL}"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

- [ ] **Step 2: 실행 권한 부여**

```bash
chmod +x scripts/tests/test-login-screen.sh
```

- [ ] **Step 3: 초기 실행 (AC-5 FAIL 예상)**

```bash
bash scripts/tests/test-login-screen.sh
```

예상 출력:
```
PASS: AC-1 이메일 input(type=email)
PASS: AC-1 비밀번호 input(type=password)
PASS: AC-1 label[for=email]
PASS: AC-1 label[for=password]
PASS: AC-2/AC-3 error-msg 요소
PASS: AC-2/AC-3 error-input 클래스
PASS: AC-2 btn.disabled 처리
PASS: AC-2 로그인 중 텍스트
PASS: AC-4 viewport meta
FAIL: AC-5 비밀번호 토글 버튼
FAIL: AC-5 토글 aria-label
결과: PASS=9, FAIL=2
```

- [ ] **Step 4: 커밋**

```bash
git add scripts/tests/test-login-screen.sh
git commit -m "test(login-screen): AC-1~AC-5 HTML 구조 검증 스크립트 추가"
```

---

## Task 2: AC-5 비밀번호 토글 구현

**목적**: 비밀번호 input 오른쪽에 토글 버튼을 추가해 type=password ↔ type=text 전환.

**파일**:
- 수정: `screens/login.html`

- [ ] **Step 1: CSS 추가 — input-wrapper와 토글 버튼 스타일**

`screens/login.html` `<style>` 블록 내 `input` 스타일 이후에 추가:

```css
.input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}
.input-wrapper input {
  padding-right: 40px;
}
.toggle-password {
  position: absolute;
  right: 10px;
  background: none;
  border: none;
  cursor: pointer;
  color: var(--color-text-secondary);
  font-size: 0.8rem;
  padding: 2px 4px;
  line-height: 1;
}
.toggle-password:hover { color: var(--color-text); }
```

- [ ] **Step 2: HTML 수정 — 비밀번호 input을 .input-wrapper로 감싸고 토글 버튼 추가**

기존:
```html
<input id="password" type="password" placeholder="••••••••" autocomplete="current-password" required />
```

변경:
```html
<div class="input-wrapper">
  <input id="password" type="password" placeholder="••••••••" autocomplete="current-password" required />
  <button type="button" class="toggle-password" id="toggle-password" aria-label="비밀번호 표시/숨김">보기</button>
</div>
```

- [ ] **Step 3: JS 추가 — 토글 함수**

`<script>` 블록 내 `handleLogin` 함수 이후에 추가:

```javascript
document.getElementById('toggle-password').addEventListener('click', function() {
  const input = document.getElementById('password');
  if (input.type === 'password') {
    input.type = 'text';
    this.textContent = '숨기기';
  } else {
    input.type = 'password';
    this.textContent = '보기';
  }
});
```

- [ ] **Step 4: 검증 스크립트 재실행 (전체 PASS 예상)**

```bash
bash scripts/tests/test-login-screen.sh
```

예상 출력:
```
PASS: AC-1 이메일 input(type=email)
PASS: AC-1 비밀번호 input(type=password)
PASS: AC-1 label[for=email]
PASS: AC-1 label[for=password]
PASS: AC-2/AC-3 error-msg 요소
PASS: AC-2/AC-3 error-input 클래스
PASS: AC-2 btn.disabled 처리
PASS: AC-2 로그인 중 텍스트
PASS: AC-4 viewport meta
PASS: AC-5 비밀번호 토글 버튼
PASS: AC-5 토글 aria-label
결과: PASS=11, FAIL=0
```

- [ ] **Step 5: 수동 브라우저 검증 (AC-2, AC-3)**

```bash
open screens/login.html
```

확인 체크리스트:
- [ ] 이메일+비밀번호 input + 로그인 버튼 정상 렌더링
- [ ] 로그인 버튼 클릭 → "로그인 중..." + disabled
- [ ] ~1초 후 에러 상태 (빨간 테두리 + 에러 메시지)
- [ ] "보기" 버튼 클릭 → 비밀번호 텍스트 표시 + "숨기기"로 변경
- [ ] DevTools 320px → 가로 스크롤 없음

- [ ] **Step 6: 커밋**

```bash
git add screens/login.html
git commit -m "feat(login-screen): AC-5 비밀번호 표시/숨김 토글 추가"
```

---

## 7. 자체 검토 (5원칙 체크리스트)

- [x] **투명성**: 각 태스크에 "목적" 한 줄 포함
- [x] **문지기**: 파괴적 작업 없음 (기존 파일 수정만)
- [x] **주권 존중**: 수동 브라우저 검증 단계(Step 5)에서 사용자 확인
- [x] **한계 고백**: §1 가정에 "bash grep 한계 — 동적 상태는 수동 검증" 명시

## 8. Advisor 협의 기록

해당 없음 — 본 plan 작성 중 불확실 지점 없음. 기존 login.html이 주요 FR을 충족하는 것이 명확하고, AC-5 토글 구현 범위도 단순해 advisor 호출 불필요.

## 9. 다음 단계

`/decompose 20260604-login-screen` — 본 플랜을 바이트-사이즈 TDD 태스크로 분해.

---

*작성: specops-auto-ko · 2026-06-04 · FID: 20260604-login-screen · 생성 커맨드: /plan*
