---
fid: 20260427-screen-design
title: Screen Design 통합
owner: specops-auto-ko
status: specifying-done
---

# Screen Design 통합 스펙

## 1. 목표

프로젝트당 10개 이상의 화면을 체계적으로 설계·관리하는 구조를 specops-auto-ko에 추가한다.  
specifying-ko UI 기능 설계 시 HTML artifact로 시각 확인 → 승인 → `screens/` 디렉터리에 `.md` + `.html` 쌍으로 영구 저장한다.

## 2. 범위

### 포함

- `commands/design-screen.md` — `/design-screen [screen-name]` 슬래시 커맨드 (독립 실행)
- `templates/screen.md` — 화면 스펙 마크다운 템플릿
- `templates/screen.html` — DESIGN.md CSS 변수 기반 HTML 미리보기 템플릿
- `skills/specifying-ko/SKILL.md` 수정 — 체크리스트 §1에 `screens/` 감지 + HTML artifact 생성 스텝 추가
- dogfood: `screens/login.md` + `screens/login.html` 생성

### 제외

- 화면 간 네비게이션 자동 생성
- Figma/Stitch export 연동
- 화면별 테스트 자동화

## 3. 결과물 구조

```
프로젝트 루트/
  DESIGN.md              ← 디자인 시스템 (기존)
  screens/
    {name}.md            ← 화면 스펙 (레이아웃·컴포넌트·상태·인터랙션)
    {name}.html          ← HTML 미리보기 (DESIGN.md 색상·폰트 적용)
```

## 4. 기능 요구사항 (FR)

**FR-1**: `/design-screen [name]` 커맨드 실행 시:
- `screens/{name}.md` 존재하면 "기존 화면입니다. 수정할까요? [y/n]" 확인
- 없으면 화면 목적·레이아웃 질문 → HTML artifact 생성 → 승인 → 파일 저장

**FR-2**: `templates/screen.md` — 4개 이상 섹션 포함:
- frontmatter (screen/title/created/updated)
- Layout, Components, States, Interactions

**FR-3**: `templates/screen.html` — DESIGN.md §1 색상을 CSS 변수로 참조:
- `--color-primary`, `--color-bg`, `--color-surface`, `--color-text` 등

**FR-4**: `skills/specifying-ko/SKILL.md` 체크리스트 §1 수정:
- `screens/` 존재 확인 스텝 추가
- 있으면 기존 화면 목록 표시
- UI 기능이면 관련 화면 HTML artifact 생성 안내

**FR-5 (should)**: 기존 화면 덮어쓰기 방지 확인 질문

**FR-6 (should)**: dogfood — `screens/login.md` + `screens/login.html` 생성

## 5. 비기능 요구사항 (NFR)

- HTML 미리보기는 외부 라이브러리 없이 순수 CSS+HTML만 사용 (CDN 의존 없음)
- CSS 변수는 DESIGN.md §1 컬러 테이블과 1:1 대응

## 6. 제약사항

- `skills/specifying-ko/SKILL.md` 수정은 기존 DESIGN.md 감지 로직과 충돌 없어야 함
- 화면 파일은 프로젝트 루트 `screens/` 고정 (FID별 분산 없음)

## 7. 참조

- `DESIGN.md` — 디자인 시스템 (색상·폰트·컴포넌트)
- `commands/start-design.md` — 패턴 참조
- `templates/DESIGN.md` — 템플릿 패턴 참조
- `skills/specifying-ko/SKILL.md` — 수정 대상
