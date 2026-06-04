---
name: design-screen
description: 화면 스펙(.md) + HTML 미리보기(.html) 쌍을 screens/ 에 생성/수정 — 프로젝트 UI 화면 설계
triggers:
  - "/design-screen"
mode: ask
specops_version: 1.0.0
specops_layer: Lifecycle-Tool
reference_upstream: specops-auto-ko 독자 추가
---

# /design-screen [name]

## 목적

`screens/{name}.md` (화면 스펙) + `screens/{name}.html` (HTML 미리보기)을 생성하거나 수정한다.
`scripts/_internal/design-screen.sh`가 보일러플레이트(파일 스캐폴딩·DESIGN.md 색상 추출·screens-overview.md 갱신)를 자동 처리하고, Claude는 레이아웃·컴포넌트 콘텐츠 생성에 집중한다.

## Process

### Step 1: 스크립트로 스캐폴딩

```bash
bash scripts/_internal/design-screen.sh {name}
```

- **파일이 이미 존재하면**: exit 1 + 안내 출력. 덮어쓰려면:
  ```bash
  bash scripts/_internal/design-screen.sh {name} --force
  ```
- **성공 시**: `screens/{name}.md` + `screens/{name}.html` 생성, `.specops/memory/screens-overview.md` 표 자동 갱신

### Step 2: 화면 목적·레이아웃 질문

사용자에게:

> "화면 설계를 시작합니다. 다음 정보를 알려주세요:
>
> 1. 이 화면의 **목적**은 무엇인가요? (1~2 문장)
> 2. 주요 **컴포넌트**는 무엇인가요? (예: 로그인 버튼, 이메일 입력)
> 3. 이 화면에서 다음으로 이동하는 **화면**이 있나요?"

### Step 2.5: [ui-ux-pro-max 있으면] design system 자문 (자동)

**탐지**: 현재 세션 available-skills 에 `ui-ux-pro-max:ui-ux-pro-max` 가 있는가?
- **없으면**: 이 단계 전체 skip → Step 3 직행
- **있으면**: `ui-ux-pro-max:ui-ux-pro-max` Skill 자동 호출 (제품유형·산업·톤·밀도 멀티키워드 입력). 산출된 design system(style/colors/typography/effects + anti-patterns)을 Step 3 HTML artifact 의 레이아웃·컴포넌트·스타일 선택에 반영. **우선순위**: ui-ux-pro-max 결과 우선 채택 — DESIGN.md 토큰은 후순위 fallback.

### Step 3: HTML artifact 생성

스크립트가 이미 기본 HTML 구조를 생성했으므로, 사용자 답변 기반으로 **레이아웃·컴포넌트 내용만** 채운 HTML artifact를 생성:
- `screens/{name}.html`에 이미 `--color-primary` CSS 변수가 DESIGN.md 색상으로 설정됨
- 컴포넌트는 `.btn`, `.input`, `.card` 클래스 사용 (DESIGN.md §4 준수)
- `<main>` 영역에 실제 화면 마크업 작성

사용자에게 artifact를 보여주고 수정 요청을 받는다:
> "위 HTML 미리보기를 확인해 주세요. 수정이 필요하시면 말씀해 주세요. 진행할까요? [y/n]"

수정 요청 시 → HTML artifact 재생성 후 재확인 루프.

### Step 4: 파일 저장

승인 후 `screens/{name}.md` + `screens/{name}.html`에 실제 콘텐츠를 채워 저장:
- screen.md: 목적, Layout, Components, States, Interactions 섹션 완성
- screen.html: Step 3에서 승인한 HTML로 교체
- `screens-overview.md` 갱신은 Step 1 스크립트가 이미 완료

### Step 5: git commit

```bash
git add screens/{name}.md screens/{name}.html
git add .specops/memory/screens-overview.md 2>/dev/null || true
git commit -m "feat(screens): {name} 화면 설계 추가"
```

## 사용 예

```
/design-screen dashboard
→ bash scripts/_internal/design-screen.sh dashboard
  → screens/dashboard.md + screens/dashboard.html 생성
  → DESIGN.md Primary 색상 추출 → --color-primary 주입
  → screens-overview.md 표 갱신
→ "이 화면의 목적은..." 질문
→ 사용자 답변
→ HTML artifact 생성 (레이아웃 + 컴포넌트)
→ 승인 → 파일 저장
→ git commit

/design-screen login  (기존 존재)
→ bash scripts/_internal/design-screen.sh login
  → Error: screens/login.md 이미 존재합니다. --force 사용.
→ 사용자에게 안내 후 중단 또는 --force 재시도
```

## 참조

- `scripts/_internal/design-screen.sh` — 보일러플레이트 자동화 스크립트
- `scripts/tests/test-design-screen.sh` — 스크립트 검증 테스트
- `templates/screen.md` — 화면 스펙 마크다운 템플릿
- `templates/screen.html` — HTML 미리보기 템플릿 (CSS 변수 기반)
- `DESIGN.md` — 디자인 시스템 (색상·폰트·컴포넌트)
- `.specops/memory/screens-overview.md` — 화면 목록 마스터
- `ui-ux-pro-max:ui-ux-pro-max` — design system 자문 (Step 2.5, available-skills 에 있으면 선택 호출)

---

*specops-auto-ko · 2026-05-20 · FID: 20260520-design-screen-command*
