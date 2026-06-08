---
name: start-project
description: specops-auto-ko 한국어 자율 Lifecycle 진입 — 한국 SI 표준 13종 산출물 자동 부트스트랩
triggers:
  - "/start-project"
mode: ask
specops_version: 2.0.0
specops_layer: Lifecycle-Bootstrap
reference_upstream: specops-auto-ko 독자 추가 (github/spec-kit 패턴 번안)
---

# /start-project [<프로젝트명>]

## 목적

프로젝트 **최초 1회** 실행. PRD/CLAUDE/DESIGN/architecture 등 **한국 SI 표준 13종 산출물**을 자동 부트스트랩한다. `/start-design`은 본 슬래시로 통합됐다.

## Process

1. `bash scripts/_internal/start-project.sh [--resume] "<프로젝트명>"` 호출 (인자 비우면 `basename $PWD` 디폴트)
   - `--resume`: 기존 파일 보존·누락 파일만 생성 (부분 부트스트랩 재개 시 사용)
2. **10 Phase 진행**:
   - Phase 1: 사전검사 (git/.specops/memory 검사 + 13종 파일별 표 + 충돌 정책)
   - Phase 2: 종류 분류 (Web/UI · BE/API · CLI/lib · 풀스택 · 모바일 · 기타)
   - Phase 3: 헌법 5원칙 입력 ('skip' 가능)
   - Phase 4: PRD numbered list 6필드 (한 줄/페르소나/가치제안 3개/M1/M2/M3, 빈 줄 sentinel; parse-fail 시 단답 fallback)
   - Phase 5: CLAUDE.md 자동 생성 (PRD §1 + constitution 원칙 5개 인용)
   - Phase 6: DESIGN.md (UI/풀스택/모바일만, brand-pick: Stripe/Notion/Linear/Claude/직접)
   - Phase 7: 화면 목록 입력 → screens/<name>.{md,html} + screens-overview.md 동적 표
   - Phase 8: 종류별 산출물 매트릭스 (8a~8h: requirements/architecture/frontend/backend/data-model/api-spec/test-strategy)
   - Phase 9: README.md 자동 생성 (PRD §1 인용)
   - Phase 10: `.specops/.gitignore` + `.specops/session-progress.md` + `git commit "chore(init): /start-project 부트스트랩 (<라벨> · 13종 중 N종)"`
3. 종료 후 안내: "이제 `/start \"<첫 기능>\"` 으로 lifecycle 진입하세요"

## 사용 예

```
/start-project mychat
→ Phase 2 종류 선택 (4 = 풀스택)
→ Phase 3 헌법 5원칙
→ Phase 4 PRD 6필드 (numbered list)
→ Phase 6 디자인 브랜드 (1 = Stripe)
→ Phase 7 화면 (home, login, dashboard)
→ Phase 8e DB? (y)
→ Phase 8f API 방식? (2 = OpenAPI)
→ 13종 자동 생성 + git commit "(풀스택 · 13종 중 13종)"
→ "이제 /start \"채팅 기본 기능\" 으로 lifecycle 진입하세요"
```

## 안티패턴

- **lifecycle chain 자동 진입 금지** — 본 슬래시는 부트스트랩 **단독**. spec/clarify/plan 등은 `/start` 가 진입.
- **자동 chain 강제 시도 금지** — 5원칙 4 (사용자 주권) 위반.
- **재실행으로 덮어쓰기 금지** — `.specops/memory/` 존재 시 명시 안내 후 [y/N] 확인 (Phase 1).

## 참조

- `scripts/_internal/start-project.sh` — 본 슬래시의 오케스트레이터
- `templates/{constitution,PRD,CLAUDE,README,DESIGN,...}.md` — 13종 템플릿
- `skills/using-specops-auto-ko-ko/SKILL.md` — 프로젝트 최초 진입 감지 분기
- `skills/specifying-ko/SKILL.md` — `.specops/memory/*` 자동 감지 (Step 1)

---

*specops-auto-ko v2.0.0 · 2026-05-14 · 한국 SI 13종 부트스트랩*
