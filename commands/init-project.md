---
name: init-project
description: specops-auto-ko 한국어 자율 Lifecycle 진입 — 한국 SI 표준 13종 산출물 자동 부트스트랩
triggers:
  - "/init-project"
mode: ask
specops_version: 1.36.0
specops_layer: Lifecycle-Bootstrap
reference_upstream: specops-auto-ko 독자 추가 (github/spec-kit 패턴 번안)
---

# /init-project [<프로젝트명>]

## 목적

프로젝트 **최초 1회** 실행. PRD/CLAUDE/DESIGN/architecture 등 **한국 SI 표준 13종 산출물**을 자동 부트스트랩한다. `/start-design`은 본 슬래시로 통합됐다. (구 `/start-project` 에서 rename.)

## Process

0. **PRD 6필드 초안 합성** (bash 호출 전 — LLM 레이어):
   - `ls -t .specops/memory/brainstorming-*.md 2>/dev/null | head -1` 존재 시: 메모를 읽고 **6필드 초안**(한 줄/페르소나/가치제안 3개/M1/M2/M3)을 합성해 사용자에게 제시 → 확인/수정 → 확정값을 Phase 4 stdin numbered list 로 공급.
   - **메모 부재 시 현행 수동 입력** 그대로 (fallback — 초안 단계 skip).
1. `bash scripts/_internal/init-project.sh [--resume] "<프로젝트명>"` 호출 (인자 비우면 `basename $PWD` 디폴트)
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
   - Phase 10: `.specops/.gitignore` + `.specops/session-progress.md` + `git commit "chore(init): /init-project 부트스트랩 (<라벨> · 13종 중 N종)"`
3. **Phase 11 — LLM 보강 패스** (bash 10 Phase 종료 후, 아래 §Phase 11 섹션 준수)
4. 종료 후 안내: "이제 `/start \"<첫 기능>\"` 으로 lifecycle 진입하세요"

## Phase 11 — LLM 보강 패스 (bash 종료 후)

bash 10 Phase 가 생성한 산출물은 템플릿 골격이다. Phase 11 에서 LLM 이 본문을 프로젝트 특화 초안으로 보강한다.

**용도 선언**: 13종 산출물은 **개발 기준 문서**다 — specifying·planning·implementing 이 재작성 없이 인용·소비한다. 보강은 정확·상세·정직해야 한다.

**사실성 계약 (Karpathy 원칙 — karpathy-ko)**:
- 서술 근거는 **근거 3원**만: ① 브레인스토밍 메모 ② 사용자 응답(Phase 2~8 입력) ③ 검증 가능한 사실. 이 외 창작 금지.
- **일반론 boilerplate 금지** — 어느 프로젝트에나 맞는 문장 대신 프로젝트 특화 구체값(이름·수치·결정)으로 작성.
- 불확실 항목은 `<미확정 — 근거 필요>` 마커로 남긴다 (원시 placeholder `<...>` 잔존 금지 — 미확정 마커만 허용).
- **규약 표기는 채움 대상 아님·잔존 허용** — `.specops/<FID>`·`screens/<name>` 류 문서 본문 서술은 placeholder 가 아니다 (allowlist SoT: `scripts/_internal/scan-enrich-placeholders.sh`). 스캔 통과 목적으로 규약 표기를 지우는 과보강 금지.
- 추론 항목은 `가정:` 접두 명시.
- 사용자가 이미 작성한 본문은 덮어쓰기 금지 (보강 대상 = placeholder·미확정 마커뿐).

**문서별 최소 채움 기준**:
| 문서 | 기준 |
|---|---|
| PRD.md | 메모의 수요 증거·고객 인물·최소 버전 Spec 반영 |
| requirements.md | M1~M3 시드 FR-1~3 을 세부 FR 로 분해 |
| architecture.md 계열 | 기술 스택 표 각 행 = 결정값 또는 미확정 마커 |
| api-spec.md | PRD 기능에서 도출된 실제 엔드포인트 |
| data-model.md | PRD 기능에서 도출된 실명 엔티티·필드 |
| test-strategy.md | 실제 실행 가능한 테스트 명령 |

**그룹 3묶음 승인 게이트** (그룹별 요약+변경 diff 만 제시 — 13종 전문 재출력 금지):
1. ① **제품**(PRD.md·requirements.md) 보강 → 요약 제시 → `[y/수정]`
2. ② **아키텍처**(architecture.md·frontend/backend-architecture.md·api-spec.md·data-model.md — 생성분만) → `[y/수정]`
3. ③ **운영**(constitution.md·test-strategy.md·DESIGN.md·screens-overview.md·CLAUDE.md·README.md — 생성분만) → `[y/수정]`

수정 요청 시 해당 그룹만 재보강 (루프 cap 없음 — 사용자 주권).

**재커밋**: 3그룹 완료 후 1회:
```bash
git add <보강된 파일들> && git commit -m "chore(init): Phase 11 LLM 보강 (N종)"
```

**무인 계약**: e2e-test-ko·§auto 무인 진입 시 그룹 승인 게이트를 **자동수락** 한다 (HARD GATE 없이 완주 설계 정합).

## --enrich (소급 보강 단독 실행)

`/init-project --enrich`: Phase 1~10 부트스트랩 **skip** (Process 항목 0 PRD 초안 합성도 skip — Phase 4 stdin 공급처 없음), Phase 11 만 단독 실행.

- 대상 = 원시 placeholder(`<...>`) 또는 `<미확정 — 근거 필요>` 가 **잔존 문서만** (문서 자체가 상태 — 재실행 멱등 수렴).
- 사용자 기작성 본문 무변경 보존.
- 기존 프로젝트(과거 부트스트랩)에 소급 적용하는 경로.

## 사용 예

```
/init-project mychat
→ Phase 2 종류 선택 (4 = 풀스택)
→ Phase 3 헌법 5원칙
→ Phase 4 PRD 6필드 (numbered list)
→ Phase 6 디자인 브랜드 (1 = Stripe)
→ Phase 7 화면 (home, login, dashboard)
→ Phase 8e DB? (y)
→ Phase 8f API 방식? (2 = OpenAPI)
→ 13종 자동 생성 + git commit "(풀스택 · 13종 중 13종)"
→ Phase 11 LLM 보강: ① 제품 [y] → ② 아키텍처 [y] → ③ 운영 [y]
→ git commit "chore(init): Phase 11 LLM 보강 (13종)"
→ "이제 /start \"채팅 기본 기능\" 으로 lifecycle 진입하세요"
```

## 안티패턴

- **lifecycle chain 자동 진입 금지** — 본 슬래시는 부트스트랩 **단독**. spec/clarify/plan 등은 `/start` 가 진입.
- **자동 chain 강제 시도 금지** — 5원칙 4 (사용자 주권) 위반.
- **재실행으로 덮어쓰기 금지** — `.specops/memory/` 존재 시 명시 안내 후 [y/N] 확인 (Phase 1).

## 참조

- `scripts/_internal/init-project.sh` — 본 슬래시의 오케스트레이터
- `templates/{constitution,PRD,CLAUDE,README,DESIGN,...}.md` — 13종 템플릿
- `skills/using-specops-auto-ko-ko/SKILL.md` — 프로젝트 최초 진입 감지 분기
- `skills/specifying-ko/SKILL.md` — `.specops/memory/*` 자동 감지 (Step 1)

---

*specops-auto-ko v1.36.0 · 2026-07-09 · 한국 SI 13종 부트스트랩 + Phase 11 LLM 보강*
