# Dispatch Context: T1 (FID 20260427-screen-design)

## 1. 담당 AC

- AC-2 (must): `ls templates/screen.md && grep -c "^## " templates/screen.md` → 파일 존재 + `^## ` 섹션 4개 이상. frontmatter에 `screen:` 포함.

## 2. 관련 spec.md 섹션

- `.specops/20260427-screen-design/spec.md` §4 FR-2 (templates/screen.md — 4개 이상 섹션 포함)
- `.specops/20260427-screen-design/acceptance-criteria.md` AC-2

## 3. 테스트 명령

```bash
ls templates/screen.md && grep -c "^## " templates/screen.md
# 기대: 5 이상

grep "screen:" templates/screen.md
# 기대: screen: {{name}} 라인 출력
```

기대: 파일 존재 + 섹션 5개 이상 + frontmatter `screen:` 포함

## 4. 수정 허용 파일 (whitelist)

- `templates/screen.md`

> ⚠️ 위 외 파일 수정 금지.

## 5. 작업 디렉터리

- `/Users/mac/code/specops-auto-ko/.worktrees/20260427-screen-design-T1/`

---

## 구현 지시

`templates/screen.md` 를 다음 내용으로 생성하라. **Write 도구 사용**:

```markdown
---
screen: {{name}}
title: {{화면 제목}}
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

<!-- reference: specops-auto-ko templates/screen.md -->
<!-- layer: Template -->

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

- [ComponentName] — DESIGN.md §4
- [ComponentName] — DESIGN.md §4

## States

- Default: [초기 상태 설명]
- Loading: [로딩 중 상태]
- Error: [에러 발생 상태]
- Success: [성공/완료 상태]

## Interactions

- [요소] 클릭/입력 → [결과 또는 이동할 화면]
- [요소] 클릭/입력 → [결과 또는 이동할 화면]
```

완료 후:
1. `ls templates/screen.md && grep -c "^## " templates/screen.md` 실행 → 5 이상 확인
2. `grep "screen:" templates/screen.md` 실행 → `screen: {{name}}` 확인
3. `git add templates/screen.md && git commit -m "feat(screen-design): templates/screen.md 화면 스펙 템플릿 추가"` 실행
