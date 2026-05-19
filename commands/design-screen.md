---
name: design-screen
description: 화면 스펙(.md) + HTML 미리보기(.html) 쌍을 screens/ 에 생성/수정 — 프로젝트 UI 화면 설계
triggers:
  - "/design-screen"
mode: ask
specops_version: 0.0.0
specops_layer: Lifecycle-Tool
---

# /design-screen

## 목적

`screens/{name}.md` (화면 스펙) + `screens/{name}.html` (HTML 미리보기)을 생성하거나 수정한다.
DESIGN.md §1 색상·§2 폰트를 CSS 변수로 참조한 정적 HTML을 함께 생성한다.

## Process

### Step 1: 기존 화면 확인

```bash
ls screens/{name}.md 2>/dev/null
```

- **존재하면**: 사용자에게 확인:
  > "이미 `screens/{name}.md`가 존재합니다. 덮어쓸까요? [y/n]"
  - `n` → 중단. "기존 화면을 유지합니다."
  - `y` → Step 2 진행 (덮어쓰기)

- **없으면**: Step 2 바로 진행

### Step 2: 화면 목적·레이아웃 질문

다음 질문을 제시:

> "화면 설계를 시작합니다. 다음 정보를 알려주세요:
>
> 1. 이 화면의 **목적**은 무엇인가요? (1~2 문장)
> 2. 주요 **컴포넌트**는 무엇인가요? (예: 로그인 버튼, 이메일 입력)
> 3. 이 화면에서 다음으로 이동하는 **화면**이 있나요?"

### Step 3: HTML artifact 생성

`templates/screen.html` 기반으로 다음을 채워 HTML artifact를 생성:
- CSS `:root` 의 `--color-*` 변수는 `DESIGN.md §1`에서 그대로 가져옴
- 화면 레이아웃을 사용자 답변 기반으로 구성
- 컴포넌트는 `templates/screen.html` 의 `.btn`, `.input`, `.card` 클래스 사용

사용자에게 artifact를 보여주고 수정 요청을 받는다:
> "위 HTML 미리보기를 확인해 주세요. 수정이 필요하시면 말씀해 주세요. 진행할까요? [y/n]"

수정 요청 시 → HTML artifact 재생성 후 재확인 루프.

### Step 4: 파일 저장

승인 후:

1. `screens/` 디렉토리가 없으면 생성:
   ```bash
   mkdir -p screens
   ```

2. `screens/{name}.md` 생성 (`templates/screen.md` 기반으로 채움):
   - frontmatter: `screen: {name}`, `title: {화면 제목}`, `created: {오늘 날짜}`, `updated: {오늘 날짜}`
   - 섹션: 목적, Layout, Components, States, Interactions

3. `screens/{name}.html` 저장 (Step 3에서 승인한 HTML)

### Step 5: git commit

```bash
git add screens/{name}.md screens/{name}.html
git commit -m "feat(screens): {name} 화면 설계 추가"
```

## 사용 예

```
/design-screen login
→ "이미 screens/login.md 가 존재합니다. 덮어쓸까요? [y/n]"
→ 사용자: "n" → "기존 화면을 유지합니다." 종료

/design-screen dashboard
→ "화면 설계를 시작합니다..."
→ 사용자 답변
→ HTML artifact 생성 및 확인
→ 승인 → screens/dashboard.md + screens/dashboard.html 저장
→ git commit
```

## 참조

- `templates/screen.md` — 화면 스펙 마크다운 템플릿
- `templates/screen.html` — HTML 미리보기 템플릿
- `DESIGN.md` — 디자인 시스템 (색상·폰트·컴포넌트)
- `commands/start-project.md` — DESIGN.md 부트스트랩 (start-design 통합됨)

---

*specops-auto-ko · 2026-04-27 · FID: 20260427-screen-design*
