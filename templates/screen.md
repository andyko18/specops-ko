---
screen: "{{name}}"
title: "{{화면 제목}}"
created: "{{created}}"
updated: "{{updated}}"
---

<!-- reference: specops-auto-ko templates/screen.md -->
<!-- layer: Project-Document -->

# {{화면 제목}} 화면 스펙

> AI 에이전트용 화면 설계 문서. `/design-screen` 커맨드로 생성.
> HTML 미리보기: `screens/{{name}}.html`

## 목적

[이 화면이 사용자에게 하는 일 — 1~2 문장]

## Layout

[헤더]  로고 / 네비게이션
[본문]  메인 컨텐츠 영역
[하단]  액션 버튼 / 링크

## Components

- [ComponentName, 예: Button(primary)] — DESIGN.md §4
- [ComponentName, 예: Input(email)] — DESIGN.md §4
- [ComponentName, 예: Card] — DESIGN.md §4

## States

- Default: [초기 상태 설명]
- Loading: [로딩 중 상태]
- Error: [에러 발생 상태]
- Success: [성공/완료 상태]

## Interactions

- [요소] 클릭/입력 → [결과 또는 이동할 화면]
- [요소] 클릭/입력 → [결과 또는 이동할 화면]
