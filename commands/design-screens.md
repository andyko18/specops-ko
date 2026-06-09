---
name: design-screens
description: 기능 설명으로 복수 화면을 일괄 디자인 — 목록 자동 판단·승인 게이트·화면별 순차 대화 루프
triggers:
  - "/design-screens"
mode: ask
specops_version: 1.0.0
specops_layer: Lifecycle-Tool
reference_upstream: specops-auto-ko 독자 추가
---

# /design-screens [기능 설명]

여러 화면을 한 번에 standalone 으로 디자인하는 오케스트레이터. 기능 설명을 입력받아 ① 필요한 화면 목록을 자동 판단하고 ② 사용자 승인 게이트를 거친 뒤 ③ 각 화면을 기존 `/design-screen` 대화 루프로 순차 디자인한다.

## Step 1: 화면 목록 자동 판단 + 승인 게이트

args = 기능 설명. 비어 있거나 너무 짧으면(10자 미만) 최소 예시 목록을 제안하고 편집 게이트를 연다:

> "기능 설명이 없거나 짧습니다. 아래 예시 화면 목록으로 시작하고 수정해 주세요:
> 1. Login — 로그인 화면
> 2. Dashboard — 메인 대시보드
> [추가/삭제/이름변경 후 완성된 목록을 알려주세요]"

기능 설명이 충분하면 LLM이 필요한 화면 목록을 자동 도출한다. 각 항목은 `{name}` + 한 줄 설명으로 구성한다.

- `{name}` 은 반드시 `^[A-Za-z0-9_-]{1,64}$` 충족 (design-screen.sh CLI 계약). 위반 후보는 자동 정규화 후 표기.
- 충돌하는 기존 화면(`screens/{name}.html` 이미 존재)은 목록에 `⚠️ 기존 파일 존재` 표시.

사용자에게 목록 제시 후 **승인/편집 루프**:
> "이 목록으로 진행할까요? 추가/삭제/이름변경이 있으면 말씀해 주세요. [y/수정]"

`y` 응답 시 Step 2로 진행. 수정 시 수정된 목록 재확인 후 진행.

## Step 2: design system 자문 (1회 공유)

available-skills 에 `ui-ux-pro-max:ui-ux-pro-max` 가 있으면 **첫 화면 전 단 1회** 호출한다. 산출된 design system을 모든 화면에 공유 적용한다. (단수 `/design-screen`은 화면마다 호출하지만 복수는 1회로 집약 — 일관성 + 토큰 절감)

없으면 skip → DESIGN.md 토큰 fallback(DESIGN.md 존재 시 읽어 공유).

## Step 3: 화면별 순차 대화 루프

승인된 화면 목록을 순서대로 처리한다. 각 화면에 대해:

**Step 3-1: 스캐폴딩**

`screens/{name}.html` 이 이미 존재하는지 먼저 확인한다:
> "화면 `{name}`이 이미 존재합니다(`screens/{name}.html`). 덮어쓸까요? [y/n(건너뜀)]"
> - `y` → `bash scripts/_internal/design-screen.sh {name} --force` 실행
> - `n` → 해당 화면 건너뜀, 다음 화면 진행

존재하지 않으면:

```bash
bash scripts/_internal/design-screen.sh {name}
```

**Step 3-2: 목적·컴포넌트·다음화면 질문**

단수 `/design-screen` Step 2와 동일한 3개 질문을 순서대로 한다:
1. 이 화면의 목적은 무엇인가요?
2. 주요 컴포넌트는 무엇인가요?
3. 이 화면에서 이동 가능한 다음 화면은 무엇인가요?

**Step 3-3: HTML artifact 생성 + 수정 루프**

Step 3-1에서 스크립트가 이미 `screens/{name}.html`을 생성했으므로, Step 2의 공유 design system(또는 DESIGN.md)을 반영하여 그 내용을 채워 완성한다. 수정 요청 수렴 → 재생성 루프. 단수 Step 3와 동일 흐름.

**Step 3-4: 저장**

승인 시 단수 Step 4와 동일하게 `screens/{name}.md` + `screens/{name}.html` 저장.

**Step 3-5: 커밋**

단수 Step 5와 동일하게 화면별 commit:

```bash
git add screens/{name}.md screens/{name}.html
git add .specops/memory/screens-overview.md 2>/dev/null || true
git commit -m "feat(screens): {name} 화면 설계 추가"
```

진행 표시:
> "화면 N/M: `{name}` 완료. 다음 화면으로 진행합니다."

모든 화면 완료 후:
> "총 M개 화면 설계 완료: {name1}, {name2}, ..."

## 참조

- `commands/design-screen.md` — 단수 커맨드 (화면 1개씩 `/design-screen`)
- `scripts/_internal/design-screen.sh` — 스캐폴딩 백엔드 (CLI: `<name> [--force]`, name regex `^[A-Za-z0-9_-]{1,64}$`)
- `templates/screen.html` — HTML 기반 템플릿
- `screens/` — 화면 산출물 저장 디렉터리
