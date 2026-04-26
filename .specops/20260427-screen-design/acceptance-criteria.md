---
fid: 20260427-screen-design
title: Screen Design 통합 — Acceptance Criteria
---

# Acceptance Criteria — 20260427-screen-design

## AC-1 (must): /design-screen 커맨드 존재

- **Given** specops-auto-ko 레포 클론 상태
- **When** `ls commands/design-screen.md` 실행
- **Then** 파일 존재 (exit 0) + `/design-screen` 트리거 포함

```bash
ls commands/design-screen.md
grep "design-screen" commands/design-screen.md
```

---

## AC-2 (must): templates/screen.md — 4섹션 이상

- **Given** specops-auto-ko 레포 클론 상태
- **When** `ls templates/screen.md && grep -c "^## " templates/screen.md` 실행
- **Then** 파일 존재 + `^## ` 섹션 4개 이상

필수 섹션: Layout, Components, States, Interactions  
필수 frontmatter: `screen`, `title`, `created`

```bash
ls templates/screen.md && grep -c "^## " templates/screen.md
grep "screen:" templates/screen.md
```

---

## AC-3 (must): templates/screen.html — CSS 변수 DESIGN.md 참조

- **Given** specops-auto-ko 레포 클론 상태
- **When** `ls templates/screen.html && grep -c "var(--color" templates/screen.html` 실행
- **Then** 파일 존재 + `var(--color` CSS 변수 1개 이상

```bash
ls templates/screen.html && grep -c "var(--color" templates/screen.html
```

---

## AC-4 (must): specifying-ko screens/ 감지 스텝 추가

- **Given** `skills/specifying-ko/SKILL.md`
- **When** `grep -c "screens/" skills/specifying-ko/SKILL.md` 실행
- **Then** 2회 이상 등장

```bash
grep -c "screens/" skills/specifying-ko/SKILL.md
```

---

## AC-5 (should): /design-screen 덮어쓰기 방지

- **Given** `commands/design-screen.md`
- **When** 내용 확인
- **Then** 기존 화면 존재 시 덮어쓰기 방지 확인 질문 로직 포함 ("덮어" 키워드)

```bash
grep -c "덮어" commands/design-screen.md
```

---

## AC-6 (should): dogfood screens/login.md + login.html

- **Given** specops-auto-ko 레포
- **When** `ls screens/login.md && ls screens/login.html` 실행
- **Then** 두 파일 모두 존재

```bash
ls screens/login.md && ls screens/login.html
grep -c "^## " screens/login.md  # 기대: 4 이상
grep -c "var(--color" screens/login.html  # 기대: 1 이상
```
