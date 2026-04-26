# Clarifications — 20260427-screen-design

**status**: RESOLVED
**timestamp**: 2026-04-27T00:10:00+09:00

## Q1 · dogfood 화면 내용 · DESIRABLE

**질문**: specops-auto-ko 자체는 CLI 도구라 실제 로그인 UI가 없음. `screens/login.md` + `screens/login.html` dogfood 예시로 어떤 시나리오를 사용할지?

**답변**: (a) — specops-auto-ko가 미래에 웹 대시보드를 가진다고 가정한 가상 로그인 화면 (이메일 + 비밀번호 입력, 로그인 버튼)

**영향**: `screens/login.md` 및 `screens/login.html`을 실제 사용 가능한 구체 화면으로 작성 (frontmatter에 specops-auto-ko 대시보드 맥락 명시)

---

## Q2 · 화면 파일명 규칙 · DESIRABLE

**질문**: `screens/` 안 파일이 쌓일 때 순서 번호 포함 여부?

**답변**: (a) — 단순명 `login.md` / `dashboard.md` (알파벳 정렬, 가독성 우선)

**영향**: `commands/design-screen.md` 및 템플릿에서 파일명 규칙을 단순명으로 안내
