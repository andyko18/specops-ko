# Review Request — 20260427-screen-design

**FID**: 20260427-screen-design
**날짜**: 2026-04-27
**브랜치**: feat/20260427-screen-design
**BASE_SHA**: af822f513fcd4985b620b84dbdb0b63434b37735 (main)
**HEAD_SHA**: 83fe214610f66fe52a15262c94913f1cf55b91ec

---

## WHAT_WAS_IMPLEMENTED

specops-auto-ko 에 화면 설계 통합 기능을 추가했다:

1. **`templates/screen.md`** — AI 에이전트용 화면 스펙 마크다운 템플릿 (frontmatter + 5개 섹션)
2. **`templates/screen.html`** — DESIGN.md §1 CSS 변수 기반 HTML 미리보기 템플릿 (순수 CSS, CDN 없음)
3. **`commands/design-screen.md`** — `/design-screen [name]` 슬래시 커맨드 (덮어쓰기 방지, HTML artifact 생성 플로우)
4. **`skills/specifying-ko/SKILL.md`** — 체크리스트 §1 + 흐름 다이어그램에 `screens/` 감지 로직 추가
5. **`screens/login.md` + `screens/login.html`** — dogfood: 가상 로그인 화면 스펙 + HTML 미리보기

## PLAN_OR_REQUIREMENTS

`.specops/20260427-screen-design/spec.md` FR-1~FR-6:
- FR-1: `/design-screen` 커맨드 — 덮어쓰기 방지 + HTML artifact 승인 플로우
- FR-2: `templates/screen.md` — frontmatter(screen/title/created/updated) + 4개 이상 섹션
- FR-3: `templates/screen.html` — `--color-primary`, `--color-bg` 등 DESIGN.md CSS 변수 참조
- FR-4: `specifying-ko/SKILL.md` — screens/ 감지 스텝 추가
- FR-5: 덮어쓰기 방지
- FR-6: dogfood screens/login.md + screens/login.html

AC 6/6 PASS (evidence.md 확인).

## DESCRIPTION

프로젝트당 10개 이상 화면을 `.md`(스펙) + `.html`(미리보기) 쌍으로 관리하는 구조 추가. specifying-ko가 UI 기능 설계 시 `screens/` 디렉토리를 자동 감지해 기존 화면 목록 표시 및 HTML artifact 생성을 안내한다. `/design-screen` 커맨드로 독립 실행도 가능.

## 변경 파일 목록

- `commands/design-screen.md` — CREATE
- `templates/screen.md` — CREATE
- `templates/screen.html` — CREATE
- `skills/specifying-ko/SKILL.md` — MODIFY (+9줄)
- `screens/login.md` — CREATE (dogfood)
- `screens/login.html` — CREATE (dogfood)
