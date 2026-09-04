---
name: design-screen
description: "[lifecycle 밖] 화면 1개 설계 — screens/ 에 .md+.html 쌍 생성/수정. lifecycle 안은 Step 5.5(단일)·Phase 2.5-A(batch) 가 자동 처리"
triggers:
  - "/design-screen"
mode: ask
specops_version: 1.80.0
specops_layer: Lifecycle-Tool
reference_upstream: specops-ko 독자 추가
---

# /design-screen [name]

## 목적

`screens/{name}.md` (화면 스펙) + `screens/{name}.html` (HTML 미리보기)을 생성하거나 수정한다.
`scripts/_internal/design-screen.sh`가 보일러플레이트(파일 스캐폴딩·DESIGN.md 색상 추출·screens-overview.md 갱신)를 자동 처리하고, Claude는 레이아웃·컴포넌트 콘텐츠 생성에 집중한다.

## 화면 설계 경로 분업

| 경로 | 진입 | 언제 쓰나 |
|---|---|---|
| **specifying Step 5.5** (인라인) | lifecycle 자동 (UI 기능 spec 승인 직후) | `/start` 흐름 중 — **별도 호출 불필요**. **`/start-all` batch는 SKIP** → Phase 2.5-A. **`/start-foundation`은 셸만**(`app-shell`·`layout`·`login` + `<!-- foundation-shell -->`) |
| **`/start-all` Phase 2.5-A** | batch 오케스트레이터 | 전 FR 화면 1회 통합. 이어서 IF(2.5-B) → **`design-reviewer-ko`(2.5-D)** |
| **`/design-screen [name]`** | 독립 슬래시 | lifecycle 밖에서 **화면 1개** 신규/수정 |
| **`/design-screens`** | 독립 슬래시 | lifecycle 밖에서 **여러 화면 일괄** (목록 자동판단 + 승인게이트 + 순차루프) |

> `/init-project` Phase 7 은 화면 **목록만** 기록(껍데기 파일 미생성) — 위 경로가 채운다.
> 즉 `/start` 로 UI 기능 개발 중이면 Step 5.5 가 자동 처리하므로 `/design-screen` 을 따로 부를 필요 없다. 독립 화면 작업 시에만 단수/복수 슬래시 사용.

## Process

### Step 1: 스크립트로 스캐폴딩

```bash
bash "${CLAUDE_PLUGIN_ROOT}"/scripts/_internal/design-screen.sh {name}
```

- **파일이 이미 존재하면**: exit 1 + 안내 출력. 덮어쓰려면:
  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}"/scripts/_internal/design-screen.sh {name} --force
  ```
- **성공 시**: `screens/{name}.md` + `screens/{name}.html` 생성, `.specops/memory/screens-overview.md` 표 자동 갱신

### Step 2: 화면 목적·레이아웃 질문

사용자에게:

> "화면 설계를 시작합니다. 다음 정보를 알려주세요:
>
> 1. 이 화면의 **목적**은 무엇인가요? (1~2 문장)
> 2. 주요 **컴포넌트**는 무엇인가요? (예: 로그인 버튼, 이메일 입력)
> 3. 이 화면에서 다음으로 이동하는 **화면**이 있나요?"

### Step 2.5: design system 자문 (ui-ux-pro-max hard dependency) + rationale 보관 (자동)

**탐지**: ui-ux-pro-max 는 plugin.json hard dependency(보장)다. available-skills 에 `ui-ux-pro-max:ui-ux-pro-max` 감지 시 호출, 미감지(의존성 미해결) 시 graceful fallback.
- **없으면 (의존성 미해결)**: 이 단계 전체 skip → Step 3 직행. `rationale = null`. ⚠️ `claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill` 로 marketplace 선행 등록 권고.
- **있으면**: `ui-ux-pro-max:ui-ux-pro-max` Skill 자동 호출 (제품유형·산업·톤·밀도 멀티키워드 입력). 산출된 design system(style/colors/typography/effects + anti-patterns)을 Step 3 HTML artifact 의 레이아웃·컴포넌트·스타일 선택에 반영. **우선순위**: **DESIGN.md 우선** — `/init-project` Phase 6 이 ui-ux-pro-max 자산으로 확정한 **프로젝트 상수**다. ui-ux-pro-max Skill 은 DESIGN.md 가 **비워 둔 항목만** 보조한다(per-FID 생성물이 프로젝트 상수를 이기지 않는다).

  자문 완료 후 아래 4개 항목을 **rationale 변수**로 추출해 이후 Step에서 사용:
  - `style`: style 이름 + 근거 한 줄
  - `color`: primary hex / surface hex
  - `font`: heading-font / body-font 페어링
  - `antipatterns`: anti-pattern 목록 배열 (필드 부재 시 빈 배열 `[]`)

### Step 3: HTML artifact 생성

스크립트가 이미 기본 HTML 구조를 생성했으므로, 사용자 답변 기반으로 **레이아웃·컴포넌트 내용만** 채운 HTML artifact를 생성:
- `screens/{name}.html`에 이미 `--color-primary` CSS 변수가 DESIGN.md 색상으로 설정됨
- 컴포넌트는 `.btn`, `.input`, `.card` 클래스 사용 (DESIGN.md §4 준수)
- `<main>` 영역에 실제 화면 마크업 작성
- **DESIGN.md 준수**: 화면 작성 시 `DESIGN.md` **§2 타이포·§3 간격** · §6 레이아웃 패턴 · §6.1 화면 원형 · §7 상태 표현 · §8 원칙/안티패턴 · §9 AI 지침을 읽고 따른다 (DESIGN.md 부재 시 skip).

사용자에게 artifact를 보여주고 수정 요청을 받는다:
> "위 HTML 미리보기를 확인해 주세요. 수정이 필요하시면 말씀해 주세요. 진행할까요? [y/n]"

- `y` 또는 수정 없음 → Step 3.5 진행
- `n` 또는 수정 요청 → HTML artifact 재생성 후 재확인 루프

### Step 3.5: Anti-pattern 게이트 (자동)

**활성 조건**: `rationale`가 null이면 → skip, Step 4 직행. null이 아닌 경우 `rationale.antipatterns`가 빈 배열(`[]`)이면 → skip, Step 4 직행.

**활성 시**: Step 3에서 생성한 HTML과 `rationale.antipatterns` 목록을 대조:

- **위반 없음** → `✅ Anti-pattern 체크 통과` 출력 후 Step 4 직행
- **위반 발견** → 아래 프롬프트 출력 후 응답 대기:
  > `⚠️ Anti-pattern 위반: {위반 항목 목록}. 수정 후 저장 / 그냥 저장 [m/s, 기본=s]`
  - `m` → Step 3(HTML artifact 생성 + 수정 루프)으로 복귀
  - `s` 또는 Enter → Step 4 직행 (위반 인지, 사용자 주권 존중)

### Step 4: 파일 저장

승인 후 `screens/{name}.md` + `screens/{name}.html`에 실제 콘텐츠를 채워 저장:
- screen.md: **필수 8섹션**(목적 · Layout · Components · States · Interactions · 필드 정의표 · 데이터 소스 · 에러 메시지) 완성. 조건부 4섹션(RBAC 권한별 표시 · 반응형 브레이크포인트 · 접근성 · 진입/이탈 경로)은 해당할 때만 남기고, 미해당이면 **섹션 자체를 넣지 않는다**(`—` 채우기 금지). 채운 뒤 껍데기 **마커 줄을 삭제**한다.
- screen.html: Step 3에서 승인한 HTML로 교체
- `screens-overview.md` 갱신은 Step 1 스크립트가 이미 완료

**[rationale 있으면]** screen.md 파일 끝에 다음 섹션을 append:
```markdown
## Design Rationale

> ui-ux-pro-max 자문 기반 ({YYYY-MM-DD})

- **Style**: {rationale.style}
- **Color**: {rationale.color}
- **Font pairing**: {rationale.font}
- **Anti-patterns (금지)**: {rationale.antipatterns 쉼표 연결}
```
rationale가 null이면 append 없이 저장 완료.

### Step 5: git commit

```bash
git add screens/{name}.md screens/{name}.html
git add .specops/memory/screens-overview.md 2>/dev/null || true
git commit -m "feat(screens): {name} 화면 설계 추가"
```

## 사용 예

```
/design-screen dashboard
→ bash "${CLAUDE_PLUGIN_ROOT}"/scripts/_internal/design-screen.sh dashboard
  → screens/dashboard.md + screens/dashboard.html 생성
  → DESIGN.md Primary 색상 추출 → --color-primary 주입
  → screens-overview.md 표 갱신
→ "이 화면의 목적은..." 질문
→ 사용자 답변
→ HTML artifact 생성 (레이아웃 + 컴포넌트)
→ 승인 → 파일 저장
→ git commit

/design-screen login  (기존 존재)
→ bash "${CLAUDE_PLUGIN_ROOT}"/scripts/_internal/design-screen.sh login
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
- `commands/design-screens.md` — 복수 커맨드 (여러 화면 일괄 설계 `/design-screens`)

---

*specops-ko v1.80.0 · 2026-05-20 · 화면별 목업 생성 슬래시*
