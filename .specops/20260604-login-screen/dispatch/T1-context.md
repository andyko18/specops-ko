<!-- specops-auto-ko Wave 2 U2 — emit-context.sh 자동 산출 -->
<!-- FID: 20260604-login-screen · task: T1 -->

# Dispatch Context: T1 (FID 20260604-login-screen)

## 1. 담당 AC

- AC-1: 로그인 폼 렌더링
- AC-2: 로딩 상태 전환
- AC-3: 에러 상태 표시
- AC-4: 반응형 레이아웃

## 2. 관련 spec.md 섹션

- `.specops/20260604-login-screen/spec.md`
- `screens/login.html`

## 3. 테스트 명령

```bash
bash scripts/tests/test-login-screen.sh
```

## 4. 수정 허용 파일 (whitelist)

- `screens/login.html`
- `scripts/tests/test-login-screen.sh`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `/Users/andyko/Project/0.Claude/specops-auto-ko`

> implementing-ko 가 worktree 생성 후 본 라인 sed 갱신.
