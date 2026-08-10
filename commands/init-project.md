---
name: init-project
description: specops-ko 한국어 자율 Lifecycle 진입 — 한국 SI 표준 13종 산출물 자동 부트스트랩
triggers:
  - "/init-project"
mode: ask
specops_version: 1.50.0
specops_layer: Lifecycle-Bootstrap
reference_upstream: specops-ko 독자 추가 (github/spec-kit 패턴 번안)
---

# /init-project [<프로젝트명>] [<기존 기획 문서 경로>]

## 목적

프로젝트 **최초 1회** 실행. PRD/CLAUDE/DESIGN/architecture 등 **한국 SI 표준 13종 산출물**을 자동 부트스트랩한다. `/start-design`은 본 슬래시로 통합됐다. (구 `/start-project` 에서 rename.)

**축소 계약 (v1.50)**: Intake 1 → Skeleton → Light enrich(게이트 1) → **Commit 1**. 화면 껍데기는 만들지 않음(본설계는 `/start-all` Phase 2.5).

## Process

0. **PRD 6필드 초안 합성** (bash 호출 전 — LLM 레이어). 근거 문서 탐색은 3단 우선순위:
   - **0-a. 명시 경로** — args 에 파일 경로가 포함되면(`/init-project 쇼핑몰 docs/기획서.md`) 그 문서가 최우선 근거.
   - **0-b. 브레인스토밍 메모** — `ls -t .specops/memory/brainstorming-*.md 2>/dev/null | head -1` 존재 시 사용.
   - **0-c. 기존 기획 문서 auto-discovery** (20260716 신설 — 온보딩 마찰 해소: 실무는 PRD 가 이미 파일로 존재하는 게 보통):
     ```bash
     ls PRD*.md prd*.md docs/PRD*.md docs/prd*.md 기획*.md 요구사항*.md REQUIREMENTS*.md requirements*.md docs/기획*.md docs/요구사항*.md docs/requirements*.md 2>/dev/null
     ```
     - 발견 시 **사용자 확인 필수**(주권 — 자동 소비 금지): "기존 문서 `<경로>` 를 PRD 초안 근거로 사용할까요? [y/n]". `n` 이면 무시.
     - 복수 발견 시 목록 제시 → 사용자 선택 (전체·일부·없음).
     - `requirements*.md` 가 이미 **FR 표를 포함**하면 Phase 8a 에서 해당 파일 보존(`_should_skip` 정책)되도록 안내 — 초안 근거와 산출물 보존은 별개.
   - 위 어느 경로든 문서 확보 시: 읽고 **6필드 초안**(한 줄/페르소나/가치제안 3개/M1/M2/M3)을 합성해 사용자에게 제시 → 확인/수정 → **확정값을 Phase 4에 강제 공급**:
     1. `.specops/.init-prd-fields` 에 줄당 1필드(6줄) 기록 **AND/OR**
     2. bash stdin numbered list 로 pipe
     - pipe 실패해도 `.init-prd-fields` 가 있으면 Phase 4는 **재입력하지 않는다**.
   - 문서에 없는 필드는 창작하지 말고 사용자에게 질문 (사실성 계약 — 근거 4원의 ① 이 "사전 문서"로 확장됨).
   - **셋 다 부재 시 현행 수동 입력** 그대로 (fallback — 초안 단계 skip).
1. `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/_internal/init-project.sh [--resume] "<프로젝트명>"` 호출 (인자 비우면 `basename $PWD` 디폴트)
   - `--resume`: 기존 파일 보존·누락 파일만 생성 (부분 부트스트랩 재개 시 사용)
2. **10 Phase 진행**:
   - Phase 1: 사전검사 (git/.specops/memory 검사 + 13종 파일별 표 + 충돌 정책). 브레인스토밍 메모 있으면 **BM_REF=y 자동**(Phase 0 확인 후 재질문 없음).
   - Phase 2: 종류 분류 (Web/UI · BE/API · CLI/lib · 풀스택 · 모바일 · 기타)
   - Phase 3: 헌법 5원칙 입력 ('skip' 가능)
   - Phase 4: PRD — Phase 0 `.init-prd-fields`/stdin 우선 · 부재 시에만 numbered list 수동
   - Phase 5: CLAUDE.md 자동 생성 (PRD §1 + constitution 원칙 5개 인용)
   - Phase 6: DESIGN.md (UI/풀스택/모바일만) — **자산 우선**: ui-ux-pro-max 의 제품유형별 팔레트(16토큰 + Success 미제공 사유행)·컨셉을 주입. 자산 부재·스키마 불일치 시 brand-pick(Stripe/Notion/Linear/Claude/직접)으로 graceful fallback + 사유 출력
     - **★ LLM 레이어 선행 (한국어 입력 경로)**: 자산의 제품 유형 목록은 **전량 영문**이다(한글 0건 실측). bash 호출 **전에** 사용자 한국어 입력·PRD 로 영문 제품 유형을 정해 `UIUX_PRODUCT_TYPE` 환경변수로 넘긴다(Phase 0 `.init-prd-fields` 패턴과 동형). 후보 조회는 `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/_internal/uiux-assets.sh` 를 source 해 `uiux::match <영문키워드>` 로 한다. 미지정이면 bash 가 brand-pick 으로 진행하므로 무해하다.
   - Phase 7: 화면 **이름 목록만** → `screens-overview.md` 표. **`screens/*.{md,html}` 껍데기 미생성**
   - Phase 8: 종류별 산출물 매트릭스 (8a~8h: requirements/architecture/frontend/backend/data-model/api-spec/test-strategy)
   - Phase 9: README.md 자동 생성 (PRD §1 인용)
   - Phase 10: `.specops/.gitignore` + session-progress + **원장 골격**(`project-context.md`·`decisions.md`) + **스테이징만**(커밋은 Phase 11 단일). `SPECOPS_INIT_COMMIT_NOW=1` 이면 bash에서 즉시 커밋.
3. **Phase 11 — Light enrich** (bash 종료 후, 아래 §Phase 11 섹션 준수)
4. 종료 후 안내: "이제 `/start \"<첫 기능>\"` 또는 `/start-foundation` → `/start-all` 으로 lifecycle 진입하세요"

## Phase 11 — Light enrich (bash 종료 후)

bash 10 Phase 가 생성한 산출물은 템플릿 골격이다. Phase 11 에서 LLM 이 **핵심 문서만** 프로젝트 특화 초안으로 보강한다.

**용도 선언**: 산출물은 **개발 기준 문서**다 — specifying·planning·implementing 이 재작성 없이 인용·소비한다. 보강은 정확·상세·정직해야 한다.

**문서별 보강 깊이 (Light enrich) — 최소 깊이 기준**:

**깊게** (생성분·해당 KIND만):
- `PRD.md` — **§1~2 는 Phase 4 확정분이라 건드리지 않는다**(사용자 응답 덮어쓰기 금지). 보강 대상은 `<TODO>` 가 남는 **§목적·성공 판정 · NFR · 리스크 · 기술 스택**뿐. e2e V21 이 `PRD.md` 를 스캔 대상으로 **지정**하므로 담당이 비면 게이트가 검사만 하고 채우는 주체가 없다(20260806 실측: 부트스트랩 직후 원시 `<TODO>` 10곳 잔존).
- `requirements.md` — M1 FR 세부 분해(must) + M2/M3 시점 명시(should)
- `api-spec.md` · `data-model.md` — PRD에서 도출된 실 엔드포인트·엔티티. **`<!-- specops:example:start -->`…`:end -->` 예시 블록은 마커째 삭제**한다(전자상거래 샘플 — 남기면 유령 스키마가 설계 계약이 되고 `scan-enrich-placeholders.sh` 가 미채움 판정).
- `frontend-architecture.md` · `backend-architecture.md` — 스택 표 실값
- `DESIGN.md` — **UI KIND일 때만**

**얕게/스킵** (골격·placeholder 유지 허용):
- `constitution.md` · `test-strategy.md` · `architecture.md` · `CLAUDE.md` · `README.md` · `screens-overview.md`

**Phase 11.5 — 단일 라운드 사전 인터뷰** (보강 전 — 대화형 전용):
- 보강 **직전**, 근거 부족으로 `가정:`·미확정 마커가 될 **결정급**만 질문으로 변환한다.
- **상한**: **총 최대 5문항** (단일 라운드 — 그룹별 5×3 폐지). 후보 초과 시 **결정급 우선** 선정(스택·인증·배포·데이터 경계·UI 유무).
- 객관식 우선. **모든 질문에 "모름/나중에" 선택지 필수** — 해당 답변은 미확정 마커로 남긴다.
- 답변은 근거 ④(인터뷰 응답)로 편입 — 마커/가정 대신 실값 기재.
- **질문 스킵 주권**: 사용자가 "질문 스킵" 응답 시 인터뷰 없이 아래 현행 흐름(가정:/마커)으로 진행.

**사실성 계약 (Karpathy 원칙 — karpathy-ko)**:
- 서술 근거는 **근거 4원**만: ① 사전 문서(브레인스토밍 메모 · Phase 0 에서 사용자가 확인한 기존 기획 문서) ② 사용자 응답(Phase 2~8 입력) ③ 검증 가능한 사실 ④ 인터뷰 응답(Phase 11.5). 이 외 창작 금지.
- **일반론 boilerplate 금지** — 어느 프로젝트에나 맞는 문장 대신 프로젝트 특화 구체값(이름·수치·결정)으로 작성.
- 불확실 항목은 `<미확정 — 근거 필요>` 마커로 남긴다 (원시 placeholder `<...>` 잔존 금지 — 미확정 마커만 허용).
- **규약 표기는 채움 대상 아님·잔존 허용** — `.specops/<FID>`·`screens/<name>` 류 문서 본문 서술은 placeholder 가 아니다 (allowlist SoT: `scripts/_internal/scan-enrich-placeholders.sh`). 스캔 통과 목적으로 규약 표기를 지우는 과보강 금지.
- 추론 항목은 `가정:` 접두 명시.
- 사용자가 이미 작성한 본문은 덮어쓰기 금지 (보강 대상 = placeholder·미확정 마커뿐).

must (구조 완결 — 위반 시 보강 미완):
- **빈 셀 금지** — 깊게 대상 문서의 표 셀·목록은 실값·`가정:`·`<미확정 — 근거 필요>` 셋 중 하나. `(미정)`·"며칠" 류 무정보 값 금지.
- 첫 마일스톤(M1) FR 분해 필수 — requirements.md 의 M1 시드를 세부 FR 로.

should (수치·상세 — 근거 없으면 마커 + 사유):
- NFR 정량화 (수치 임계값).
- M2/M3 사전 분해 — 불가 시 마커 + 분해 시점 명시.

**단일 승인 게이트 + 가정 다이제스트** (전문 재출력 금지 — 요약+변경 diff 1회):
1. 깊게 대상 전부 보강 → **1회** 요약 제시 → 게이트 `[y/번호 수정]`
   - `가정:` 전건 번호 목록 + 결정급 ★ 표시
   - `y` = 전체 승인, 번호 = 해당 가정만 수정 후 재제시 (루프 cap 없음 — 사용자 주권)
2. (구 그룹①②③ 3게이트 폐지)
3. DESIGN.md 보강 후 `screens/*.html` 이 **이미 존재**하면(구 부트스트랩·수동 생성): `bash` 로 각 html 에 `scripts/_internal/init-project/lib.sh` 의 `_inject_design_palette` 재실행 — DESIGN.md 확정 색을 화면 미리보기에 반영 (**스캐폴딩 원본·사용자 미편집 상태에서만** — 편집본 덮어쓰기 금지)

**가정 다이제스트 + 결정 원장** (대화형·무인 공통):
- 승인(또는 자동수락)된 `가정:` 전건을 **PRD.md 말미 `## §보강 가정 다이제스트`** 에 기록 (PRD 단일 출처 — requirements 등 중복 금지). 재실행(--enrich 포함) 시 기존 섹션 **전건 갱신**(replace) — 중복 섹션 append 금지.
- **동시**: `.specops/memory/project-context.md` §1~2 채움 + `.specops/memory/decisions.md` 표에 행 upsert (출처=`init Phase0`/`init Phase11.5`). specifying·clarifying이 이 원장을 소비한다.

**단일 커밋** (bash Phase 10 스테이징 + enrich 변경 통합):
```bash
git add <보강·골격 파일들> && git commit -m "chore(init): /init-project 부트스트랩+enrich (N종)"
```
(구: Phase 10 커밋 + Phase 11 재커밋 2회 → **1회**. bash만 단독 실행 시 `SPECOPS_INIT_COMMIT_NOW=1`.)

**무인 계약**: e2e-test-ko·§auto 무인 진입 시 승인 게이트를 **자동수락** 하고 Phase 11.5 인터뷰·가정 **건별 승인을 생략**한다 (HARD GATE 없이 완주 설계 정합). 단 가정 다이제스트·원장 기록은 **무인에서도 수행** — 사후 감사 경로.

## --enrich (소급 보강 단독 실행)

`/init-project --enrich`: Phase 1~10 부트스트랩 **skip** (Process 항목 0 PRD 초안 합성도 skip — Phase 4 stdin 공급처 없음), Phase 11 만 단독 실행.

- 대상 = 원시 placeholder(`<...>`) 또는 `<미확정 — 근거 필요>` 가 **잔존 문서만** (문서 자체가 상태 — 재실행 멱등 수렴). Light enrich 깊이 규칙 동일.
- 사용자 기작성 본문 무변경 보존.
- 기존 프로젝트(과거 부트스트랩)에 소급 적용하는 경로.
- Phase 11.5 인터뷰·가정 다이제스트 게이트를 **대화형 규칙 그대로** 적용한다 (멱등 계약 유지 — 대상 판정은 위 잔존 기준(원시 placeholder·미확정 마커)과 동일하며, `## §보강 가정 다이제스트` 섹션 내 `가정:` 은 잔존 판정에서 제외).

## 사용 예

```
/init-project mychat
# 기존 기획서가 있으면: /init-project mychat docs/기획서.md (0-a)
# 또는 repo 에 prd.md 만 두면 0-c 가 자동 발견 → 사용 확인 [y/n]
→ Phase 0 6필드 확정 → .init-prd-fields 기록
→ Phase 2 종류 선택 (4 = 풀스택)
→ Phase 3 헌법 skip
→ Phase 4 PRD (Phase 0 공급 — 재입력 없음)
→ Phase 6 디자인 브랜드 (1 = Stripe)
→ Phase 7 화면 이름 (home, login, dashboard) — overview만
→ Phase 8e DB? (y) · 8f API? (2 = OpenAPI)
→ 13종 골격 + 원장 골격 스테이징
→ Phase 11.5 인터뷰 ≤5 → Light enrich → 게이트 1회 [y]
→ git commit "chore(init): /init-project 부트스트랩+enrich (N종)"
→ "이제 /start-foundation 또는 /start-all 로 lifecycle 진입하세요"
```

## 안티패턴

- **lifecycle chain 자동 진입 금지** — 본 슬래시는 부트스트랩 **단독**. spec/clarify/plan 등은 `/start` 가 진입.
- **자동 chain 강제 시도 금지** — 5원칙 4 (사용자 주권) 위반.
- **재실행으로 덮어쓰기 금지** — `.specops/memory/` 존재 시 명시 안내 후 [y/N] 확인 (Phase 1).
- **Phase 7에서 screens 껍데기 생성 금지** — 본설계는 start-all 2.5.

## 참조

- `scripts/_internal/init-project.sh` — 본 슬래시의 오케스트레이터
- `templates/{constitution,PRD,CLAUDE,README,DESIGN,project-context,decisions,...}.md` — 13종+원장 템플릿
- `skills/using-specops-ko/SKILL.md` — 프로젝트 최초 진입 감지 분기
- `skills/specifying-ko/SKILL.md` — `.specops/memory/*` 자동 감지 (Step 1)

---

*specops-ko v1.50.0 · 2026-08-03 · Light enrich · 원장 · Phase7 목록만 · 커밋1*
