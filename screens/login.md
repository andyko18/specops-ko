---
screen: login
title: 로그인
created: 2026-04-27
updated: 2026-04-27
---

<!-- specops-auto-ko 웹 대시보드 — 가상 로그인 화면 (dogfood) -->

# 로그인 화면 스펙

> HTML 미리보기: screens/login.html

## 목적

specops-auto-ko 웹 대시보드 진입 전 사용자 인증을 처리한다.
이메일과 비밀번호를 입력받아 로그인하고, 성공 시 대시보드로 이동한다.

## Layout

```
[로고]   specops-auto-ko  (중앙 정렬)
[카드]
  [제목]  로그인
  [폼]
    이메일 Input
    비밀번호 Input
    로그인 Button (Primary, full-width)
  [링크]  "비밀번호를 잊으셨나요?"
```

## Components

- Input (Email, type="email") — DESIGN.md §4
- Input (Password, type="password") — DESIGN.md §4
- Button (Primary, "로그인", full-width) — DESIGN.md §4
- 텍스트 링크 ("비밀번호를 잊으셨나요?") — color: var(--color-secondary)

## States

- Default: 빈 폼, 로그인 버튼 활성
- Loading: 버튼 비활성 + 텍스트 "로그인 중..."
- Error: Input 테두리 --color-error + 에러 메시지 "이메일 또는 비밀번호가 올바르지 않습니다"
- Success: 대시보드(/dashboard) 화면으로 이동

## Interactions

- 로그인 버튼 클릭 → 인증 요청 → (success) dashboard 화면 / (error) Error 상태
- 비밀번호를 잊으셨나요? 링크 → forgot-password 화면
- Enter 키 (폼 내부) → 로그인 버튼과 동일 동작
