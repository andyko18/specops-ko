---
name: start-all
description: "[전체·대화형] specops-ko 한국어 자율 Lifecycle — requirements.md FR 표 전체 기능 일괄 구현. 3-Phase 오케스트레이터"
triggers:
  - "/start-all"
mode: ask
specops_version: 1.51.0
specops_layer: Lifecycle
reference_upstream: specops-ko 독자 추가
---

# /start-all

## 목적

`requirements.md` FR 표의 **전체 기능**을 단일 세션에서 일괄 구현하는 오케스트레이터.

`/init-project`(doc-only) → `/start-foundation`(공통 코드) → **`/start-all`(전체 기능 일괄 구현)** 순서로 진행. `/start`의 단일 기능 루프를 FR 단위로 자동 반복한다.

## Process

### Phase 0 — 준비

1. **batch-id 결정** (실행 날짜 기준):
   ```
   BATCH_ID = "batch-<YYYYMMDD>"   예: batch-20260605
   ```
2. **requirements.md 탐색** (`.specops/memory/requirements.md` 우선, 없으면 루트):
   - 탐색 순서: `.specops/memory/requirements.md` → `requirements.md`
   - 두 곳 모두 없으면: "`requirements.md`가 없습니다. `/init-project`를 먼저 실행하세요." 출력 후 **중단**
3. **FR 목록 파싱**:
   ```bash
   grep -E '^\| FR-[0-9]+ \|' <requirements.md 경로>
   ```
   FR 행 0건이면: "FR 표가 비어 있습니다. `requirements.md`에 FR 표를 작성 후 재실행하세요." 출력 후 **중단**
4. **batch 브랜치 생성** (1회, 재진입 시 skip):
   ```bash
   # 이미 존재하면 switch, 없으면 create
   git show-ref --verify --quiet "refs/heads/feat/$BATCH_ID" \
     && git checkout "feat/$BATCH_ID" \
     || git checkout -b "feat/$BATCH_ID"
   ```
5. **queue.md 초기화 + ACTIVE 마커** — `.specops/$BATCH_ID/queue.md` 생성 (재진입 시 기존 파일 재사용).
   queue.md 를 만들거나 재사용할 때 **반드시 함께** 진행 표시를 남긴다:
   ```bash
   : > ".specops/$BATCH_ID/ACTIVE"
   ```
   이 마커가 batch PR 게이트(`hooks/pretool-governance.sh`)의 판정 범위다 — **마커가 있는 batch 만** 검사한다.
   `.specops/*` 는 gitignore 라 끝난 batch 디렉토리가 디스크에 계속 남는데, 마커 없이 아무 batch 나 집으면
   그것과 무관한 후속 작업의 PR 이 과거 상태로 차단된다(false-block). 마커를 안 남기면 게이트도 발화하지 않는다.

   `.specops/$BATCH_ID/queue.md` 이미 존재하면 → **기존 파일 재사용** (초기화 스킵, PENDING/PLAN_DONE 상태 보존).
   없으면 신규 생성:
   ```
   | FR-ID | FID | FR 설명(1줄) | Status |
   |---|---|---|---|
   | FR-1 | TBD | <FR 설명> | PENDING |
   | FR-2 | TBD | <FR 설명> | PENDING |
   ...
   ```
   FID 컬럼은 Phase 1에서 `BATCH-PHASE1-DONE: <FID>` 수신 후 실제 FID로 갱신됨.

### Phase 1 — 전 FR spec→decompose (대화형)

각 FR에 대해 **순서대로** 반복 (queue.md PENDING 항목):

1. `specops-ko:specifying-ko` 호출 — args 정확히 아래 형식:
   ```
   <!-- entry: batch -->
   <!-- batch-id: <BATCH_ID> -->
   <FR 원문 — FR-N 행의 설명 부분>
   ```
2. specifying-ko → clarifying-ko → planning-ko → decomposing-ko 체인 자동 진행 (FID는 specifying-ko Step 0이 결정)
   - **HARD**: batch 분기에서 specifying **Step 5.5·5.6 SKIP** — 화면·인터페이스 상세는 Phase 2.5 전담(통상 순서: 화면 → 인터페이스). Phase 1은 예정 화면/엔드포인트·테이블 **이름만** §참조에 남긴다.
   - clarifying은 `.specops/memory/decisions.md` 확정 주제를 재묻지 않음 (init 원장 우선).
3. decomposing-ko 출력에서 `BATCH-PHASE1-DONE: <FID>` 감지 → queue.md 해당 FR의 FID 컬럼을 `TBD`에서 실제 `<FID>`로 갱신 + Status를 `PLAN_DONE`으로 갱신
4. 다음 PENDING FR 반복

> **HARD GATE**: clarifying-ko의 BLOCKING 질문은 사용자 응답 필수. Phase 1은 대화형이다. (원장에 이미 확정된 주제는 BLOCKING에서 제외)

### Phase 2 — 일괄 리뷰 (단일 게이트)

1. 전 FID의 `.specops/<FID>/spec.md`, `plan.md`, `tasks.md` 핵심 내용 요약 제시
   - 이 시점의 `api-spec`·`data-model` cross-FR 검수는 **하지 않는다**(인터페이스 본설계는 Phase 2.5-B). architecture 드리프트가 보이면 한 줄 경고만.
1.5. **[§auto 모드]** (`/start-all-auto` 진입 — 전 FID spec.md에 `**§auto**: true`): 본 일괄 리뷰 게이트를 **자동 통과** → Phase 2.5 직행. 사용자 응답 대기 없음. (가역 게이트 — 가정은 batch PR 게이트 다이제스트로 집계)
2. 단일 게이트: **"화면·인터페이스 설계 후 구현 진행? [y/n]"**
   - `n` → **중단**. 아티팩트 보존, `feat/<BATCH_ID>` 브랜치 보존. `/start-all` 재진입 시 Phase 2.5부터 재개 가능
   - `y` → Phase 2.5 진입

### Phase 2.5 — batch 통합 design-first (화면 → 인터페이스)

> **왜 여기 통합 단계인가**: specifying Step 5.5·5.6은 batch에서 **SKIP**한다. FR마다 화면·IF를 돌리면 batch 이점을 깨뜨리므로, 구현 직전 **1회 통합**한다. 통상 순서: **A 화면 → B 인터페이스 → C cross-FR → D 무거운 설계 리뷰 → E 승인 → F 커밋**.

#### A. 통합 화면 설계 (UI 기능 시)

1. **UI 표면 검출** — 전 FID `.specops/<FID>/spec.md` §참조·§범위에서 화면 신호(`screens/<name>` 목록·화면 렌더·사용자 흐름)를 취합한다.
   - **신호 없음(순수 API·CLI·데이터 batch)** → `SCREEN-DESIGN: SKIP — <근거>` 를 `queue.md`에 기록 후 **B(인터페이스)로 진행** (Phase 3 직행 금지 — API batch도 B가 본설계).
2. **ui-ux-pro-max 1회 통합 호출** — 취합된 **전체 화면셋**에 대해 `ui-ux-pro-max:ui-ux-pro-max` Skill 을 **1회만** 호출 → batch 공통 design system 산출. **graceful 안전망**: ui-ux-pro-max 미감지 시 `DESIGN.md` 토큰 fallback + marketplace 안내. 우선순위: ui-ux-pro-max 결과 우선, DESIGN.md 후순위.
3. **화면 산출물 생성** — 각 화면별 `screens/<name>.md` + `screens/<name>.html` 쌍을 통합 design system 스타일로 생성한다.
   - **파일이 없으면 생성**한다.
   - **이미 있고** `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/_internal/design-screen.sh --check screens/<name>.md screens/<name>.html` → exit 1(정상) → **재사용**.
   - **이미 있고** exit 0(껍데기) → **재사용 금지**. 통합 design system으로 덮어쓰고 **껍데기 마커 줄을 삭제**한다.
   - 해당 FID spec.md §참조에 경로가 없으면 추가한다.
4. **[§auto 모드]**: 화면별 대화형 승인 **없이** 자동 반영. 생성 화면 목록은 batch PR 다이제스트에 집계.

#### B. 통합 인터페이스 설계 (API/스키마 기능 시 · 화면 직후)

> design-first: **A에서 만든 `screens/*.md`의 Interactions를 우선**해 엔드포인트·테이블을 도출한다 (`/design-interface` Step 1과 동일). 화면이 없으면(B만 해당) 각 FID spec §범위·예정 IF 이름에서 도출한다.

1. **IF 표면 검출** — 전 FID spec §범위·§참조 + (존재 시) `screens/*.md` Interactions에서 API/DB/클라이언트 스토리지 신호를 취합한다.
   - **신호 없음(순수 UI·문서 batch)** → `INTERFACE-DESIGN: SKIP — <근거>` 를 `queue.md`에 기록 후 **C로 진행**.
2. **마스터 갱신** — `.specops/memory/api-spec.md`·`data-model.md`에 전 FR 변경분을 **append**(섹션 덮어쓰기 금지 · 동일 메서드+경로/테이블은 **해당 행 갱신**).
   - memory 부재 시: 대화형은 생성 확인, §auto는 신규 생성 금지·각 FID spec에 "인터페이스 미반영: memory 부재" 기록.
3. 각 FID spec.md §1에 반영 요약 1줄(`**자동 결정 인터페이스**` 또는 대화형 동등 요약) + §참조에 api-spec/data-model 경로.
4. **[§auto 모드]**: 인터페이스 대화형 승인 없이 자동 append(가역 — PR 다이제스트 집계).

#### C. cross-FR 계약 리뷰 (오케스트레이터 quick)

1. 갱신된 `api-spec.md`·`data-model.md`에서 **충돌·중복 엔드포인트/테이블**을 한 표로 요약 (서브에이전트 추가 금지 — 산문 1회).
2. 충돌이 있으면 해소 후 D로 — §auto여도 Critical 충돌은 자동 무시 금지(목록 기록 + 최소 수정 또는 사용자 확인).

#### D. 무거운 설계 리뷰 (`design-reviewer-ko`)

> A(화면) 또는 B(IF) 중 **하나라도 산출**되면 **항상** Evaluator를 돌린다. 둘 다 SKIP이면 D·E 생략 → F(커밋 없이 Phase 3) 또는 빈 design 커밋 생략 후 Phase 3.

1. **dispatch** — `Agent` 도구, `subagent_type: "specops-ko:design-reviewer-ko"`. 컨텍스트: `BATCH_ID` · PLAN_DONE FID 목록 · `screens/` · `api-spec.md` · `data-model.md` · 각 FID `spec.md` 경로.
2. 부모는 리뷰어 stdout을 `.specops/<BATCH_ID>/design-review.md`에 저장한다 (리뷰어는 Write 없음).
3. 시그널 처리:
   | 결과 | 동작 |
   |---|---|
   | `DESIGN-REVIEW-RESULT: PASS` | E로 진행 |
   | `DESIGN-REVIEW-RESULT: FAIL` (1회차) | 이슈 목록으로 A/B 수정 → **재dispatch 1회** |
   | `DESIGN-REVIEW-RESULT: FAIL` (재시도 후) | 부모가 `design-review.md`에서 `^Critical:[[:space:]]*[1-9]` 를 본다. **Critical≥1**: 대화형·**§auto 모두** `HARD-GATE: design-reviewer Critical cap — 사용자 결정` 후 **정지**(§auto 자동통과 금지, queue에 사유 기록). **Critical=0 이고 Important≥1**: 대화형은 HARD GATE. **§auto**만 `Important-only cap → §auto 자동통과` 를 queue/다이제스트에 기록 후 E(가역) |
   | `DESIGN-REVIEW-RESULT: SKIP` | D 대상 아님 — E 생략 후 F/Phase 3 |
4. **Evaluator 모델 불가 fallback**: `model: fable` 실패 시 부모 self-review 금지 — 같은 `design-reviewer-ko`를 가용 모델 override로 재dispatch. queue 또는 design-review.md 헤더에 `모델 fallback: fable 불가 → <모델>` 기록 (`implementing-ko` 동일 원칙). 직후 `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/_internal/record-metric.sh --fid <대표-FID-또는-BATCH_ID가-FID형식이면그값> --phase evaluator-degradation --fallback true --model <override-model>` 실행(식별자만; BATCH_ID가 FID 형식이 아니면 PLAN_DONE 중 대표 FID 1개 사용).

#### E. 설계 승인 게이트

1. `design-review.md` 요약(Critical/Important/Minor 건수 + 상위 이슈) + 화면 목록 + IF 변경 요약을 제시.
2. 대화형: **"이 설계로 구현 진행? [y/n]"**
   - `n` → A/B 수정 후 D부터 재개 (리뷰 재실행)
   - `y` → F
3. **[§auto 모드]**: D가 PASS(또는 Important-only cap 자동통과)면 본 게이트 **자동 통과**. Critical cap 정지 시 E에 도달하지 않는다. 화면·IF·design-review 결과는 batch PR 다이제스트에 집계.

#### F. design 산출물 커밋 → Phase 3

1. `screens/*.md`·`screens/*.html`·`DESIGN.md`·`.specops/memory/api-spec.md`·`.specops/memory/data-model.md`·`.specops/<BATCH_ID>/design-review.md`·`.specops/` **만** 담아 커밋(코드 혼입 금지). R-1 docs/design-only 면제 — **BYPASS 불요**.
2. 완료 → Phase 3. `implementing-ko`는 `screens/`·api-spec·data-model을 **§6 설계 계약**으로 소비하고, `verifying-evidence-ko` memory 동기화 점검이 역방향 안전망이다.

### Phase 3 — per FR 순차 구현 (무중단)

> **[per-FR ≠ batch-level — 뭉개짐 방지 경계]** 아래 스텝 1~6 은 **FR 마다 개별** 실행이다 — verify·code-review 는 FID 당 **각각 1개**의 산출물(`evidence.md` · `review-request.md`)을 남긴다. **한 번에 뭉쳐 돌리지 않는다.** (대조: 아래 "Phase 3 완료" 의 Step A/B/C security·integration·performance 는 batch 전체를 대표 FID 로 **1회** 통합 실행 — 성격이 반대다. 이 문서 후반부의 batch-level 패턴을 verify·review 에 일반화하지 말 것.) verify 는 `run-verification.sh <FID>` 로 그 FR 의 tasks.md 명령만 뽑아 자연히 격리되지만, review.diff 는 공유 batch 브랜치에서 **base 를 명시 기록**하지 않으면 직전 FR 변경까지 끌어들여 내용이 뭉개진다(스텝 1a).

queue.md의 PLAN_DONE 항목을 **순서대로** 처리 (IMPL_DONE은 skip). 각 FR(=FID)에 대해:

1a. **per-FR review base 기록** — implementing-ko 호출 **직전** 현재 HEAD 를 그 FID 의 review base 로 고정 (이 파일이 없으면 requesting-code-review-ko 가 `HEAD~1` 로 falling back → batch 에서 FR 격리 실패):
   ```bash
   git rev-parse HEAD > ".specops/<FID>/review-base.sha"   # 이 FR 구현 시작점 — review.diff 격리 base
   ```
   (재진입 시 해당 FID 가 이미 IMPL_DONE 이면 이 FR 전체를 skip — 파일 재기록 금지)
1. `specops-ko:implementing-ko` 호출 (**FID 기준**)
2. 완료 → `specops-ko:verifying-evidence-ko` 호출 (**FID 기준** — `run-verification.sh <FID>` → `.specops/<FID>/evidence.md` 개별 생성 + session-progress 에 `/verify PASS` 줄 append 까지가 이 스텝이다. 이 줄이 R-1/R-2 면제 신호이자 batch-state 하드 재검 대상 — `pnpm test` 류 직접 실행으로 대체하면 실행 증거·진행 줄이 없어 커밋/PR 게이트가 닫힌 채 남는다)
3. **request/receive 리뷰** — 기본: `specops-ko:requesting-code-review-ko` → `receiving-code-review-ko` (**FID 기준**, review.diff base = `.specops/<FID>/review-base.sha`).
   - **축소(오케스트레이터 산문 + batch-state 메타 검증)**: 해당 FID가 **단일 태스크**이고 `.specops/<FID>/risk-profile.json`의 **`effective`가 `lite`** 이며 **`reductions_allowed`에 `batch-review-skip` 포함**이고 implementing Phase C PASS면, requesting/receiving-code-review를 **skip 가능**. skip 시 `BATCH-REVIEW-DONE: <FID>` 를 오케스트레이터가 기록하고, IMPL_DONE 전에 `review-request.md` 대신 `review-skip.md`(사유 1줄: lite+단일태스크+Phase C PASS)를 둔다. 멀티태스크·standard/strict·auth/DB/migration·`risk-profile.json` 부재·allowlist 부재는 **skip 금지**. `batch-state.sh`는 skip-only 경로에서 `effective=lite`·`batch-review-skip` allowlist·태스크 1개·사유 비어있지 않음을 재검한다(남용 차단 — Phase C PASS 자체는 산문).
4. receiving(또는 skip) 후 per-FR security/integration/performance/PR 차단. chain 자동 진행
5. `.specops/<FID>/review-base.sha` · `evidence.md` · (`review-request.md` **또는** `review-skip.md`) **3종 존재** + session-progress FID 섹션의 **`/verify PASS` 줄 존재** 확인 후 queue.md 해당 FR → `IMPL_DONE` 갱신 (하나라도 없으면 뭉개짐 — IMPL_DONE 금지, 해당 스텝 재실행. batch PR 직전 `batch-state.sh` 가 IMPL_DONE FID 마다 재검 — skip 경로는 메타 조건까지 통과해야 인정)
6. 다음 PLAN_DONE FR 반복

> **HARD GATE**: implementing-ko HARD GATE cap 초과 시에만 사용자 개입 요청. 그 외 실패는 `specops-ko:systematic-debugging-ko`로 처리 후 재개.

### Phase 3 완료 — batch 레벨 통합·E2E·성능 테스트 + batch PR 생성

전 FID IMPL_DONE 확인 후 — **batch-state 하드 스캔** (prose 확인이 아닌 스크립트 판정):

```bash
bash "${CLAUDE_PLUGIN_ROOT}"/scripts/batch-state.sh ".specops/$BATCH_ID"
```
- exit 0 → Step A 진행
- exit 1 (미완·드리프트·중복 목록 출력) → 사용자 확인 게이트: **"미완/드리프트 N건 — 그래도 batch PR 진행? [y/n]"**. `y`=의도적 부분 진행 허용(주권 — queue 헤더에 사유 기록 권장), `n`=중단. **§auto 무인은 여기서 정지**(목록 출력 + 사용자 입력 대기 — silent 부분 PR 금지)

> **이 스캔은 산문 지시일 뿐 아니라 훅으로도 강제된다** (20260721-batch-pr-teeth). `gh pr create` 시
> `hooks/pretool-governance.sh` 가 최신 `.specops/batch-*/queue.md` 에 `batch-state.sh --gate` 를 자동 실행한다.
> `--gate` 는 기본 모드와 판정 기준이 다르다 — **뭉개짐 신호만** 차단한다(per-FR 산출물 부재·진행기록 부재·라벨 오염).
> 드리프트·미완·중복은 부분 batch 에서 정당하므로 훅은 차단하지 않는다(위 [y/n] 게이트 소관).
> 훅 차단은 **인라인 `SPECOPS_GOVERNANCE_BYPASS` 로 열리지 않는다** — batch PR 은 비가역이라
> security Critical/High 와 동급으로 다룬다. 사용자 주권 탈출구는 세션 env(`export SPECOPS_GOVERNANCE_BYPASS=1`)다.
> 계기: dogfood 20260721 test1 — 이 스캔이 산문에만 있어 호출되지 않았고, 7 FR 이 BATCH_ID 하나로 뭉개진 채 PR 이 나갔다.

> **batch-level 호출 규약**: Step A/B/C 의 skill 은 §batch 감지를 `grep .specops/<FID>/spec.md` 로 **FID-scoped** 수행한다. 오케스트레이터는 batch 의 **대표 FID**(queue.md 의 임의 IMPL_DONE FID — 전 FR spec 이 `**§batch**` 라벨 보유)의 spec.md 를 참조해 호출해야 batch 모드가 발동한다(§batch 부재 스코프로 호출 시 SINGLE 모드 falling back → 단일-batch-PR 불변식 위협). 따라서 아래 `-DONE` signal 의 suffix 는 그 대표 `<FID>` 다(스캔 범위는 batch 전체지만 라벨 판정 기준은 대표 FID).

**Step A: batch 레벨 보안 리뷰 (SAST)**

1. `specops-ko:security-review-ko` 호출 — batch 전체 코드 변경 표면 대상
   - 각 FR의 `.specops/<FID>/spec.md` `§범위` 스캔 → 코드 변경 표면 신호 부재 시 graceful skip
   - 또는 `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/security-scan.sh .`로 batch 전체 직접 스캔 (semgrep·gitleaks 미설치 시 graceful skip)
   - `BATCH-SECURITY-DONE: <FID>` 출력 후 오케스트레이터로 제어 반환 (`**§batch**` halt)
   - Critical/High 검출 시 → `specops-ko:systematic-debugging-ko` → 수정 후 재실행 (§auto여도 자동 통과 금지)

**Step B: batch 레벨 통합·E2E 테스트**

2. `specops-ko:integration-test-ko` 호출 — batch 전체 통합 표면 대상
   - 각 FR의 `.specops/<FID>/spec.md` `§범위` 스캔 → **두 표면을 함께** 검출(integration-test-ko Q5 풀스택 — 신호 OR, 둘 다 커버):
     - **통합 표면**(API·DB·서비스 간 호출) → downstream 스택 통합 테스트(supertest/httpx/pg 등)
     - **UI 표면**(화면 렌더·사용자 흐름·클릭/폼/라우팅) → **E2E 위임**: 브라우저 E2E 를 downstream 프로젝트 스택(**Playwright/Cypress 등**)으로 작성·실행(플러그인은 브라우저 인프라 미보유 — execution 은 downstream). `e2e-runner` 에이전트 있으면 선택 활용(없어도 downstream 스택 직접 지시로 graceful — 하드 의존 금지).
   - **두 표면 모두 부재**(순수 데이터 batch·CLI) 시에만 graceful skip. **UI batch 인데 E2E 를 건너뛰면 안 된다** — 화면 있는 batch 는 E2E 가 통합 검증의 본체다(dogfood 20260716: batch 가 API 통합만 보고 UI E2E 를 흐름 밖으로 흘려 사후 수동 보충됨).
   - `BATCH-INTEGRATION-DONE: <FID>` 출력 후 오케스트레이터로 제어 반환 (`**§batch**` halt — performance 자동 chain 차단)
   - FAIL 시 → `specops-ko:systematic-debugging-ko` → 수정 후 재실행

**Step C: batch 레벨 성능 테스트**

3. `specops-ko:performance-test-ko` 호출 — batch 전체 성능 임계값 대상
   - `.specops/memory/requirements.md` `## 3. 비기능 요구사항 (NFR)` + 각 FR spec.md `§NFR` 스캔
   - 성능 임계값 신호 부재 시 graceful skip
   - FAIL 시 → `specops-ko:systematic-debugging-ko` → 수정 후 재실행
   - **본 skill의 PR 게이트 skip** (`**§batch**` 라벨 감지 → `BATCH-PERF-DONE: <FID>` 출력 후 오케스트레이터로 제어 반환)

**Step D: batch PR 생성**

```bash
git push -u origin "feat/$BATCH_ID"
```
```bash
gh pr create \
  --base main \
  --head "feat/$BATCH_ID" \
  --title "feat: $BATCH_ID 전체 기능 일괄 구현" \
  --body "$(cat <<'EOF'
## Summary
- /start-all로 requirements.md FR 전체 기능 일괄 구현
- batch 레벨 통합·성능 테스트 완료 (또는 graceful skip)

## FR 목록
queue.md 상태 전이 요약 (PENDING→PLAN_DONE→IMPL_DONE) 직접 기재

## Test plan
- [ ] 전 FR verifying-evidence-ko PASS 확인
- [ ] batch 레벨 security-review PASS 또는 SKIP 확인
- [ ] batch 레벨 integration-test (통합 + UI 표면 시 E2E) PASS 또는 SKIP 확인
- [ ] batch 레벨 performance-test PASS 또는 SKIP 확인
- [ ] validate-structure.sh 전 항목 ✅

🤖 Generated with specops-ko /start-all
EOF
)"
```

PR 생성이 **성공하면** 진행 표시를 지운다 — 이 batch 는 끝났고, 남겨두면 이후의 무관한 작업이
끝난 batch 상태로 차단된다(false-block):
```bash
rm -f ".specops/$BATCH_ID/ACTIVE"
```

## 안티패턴

- **requirements.md FR 표 없이 실행** — `/init-project` 먼저 실행해 `requirements.md`에 FR 표 작성 후 `/start-all` 진입
- **spec 생략 요구** — 각 FR에 대해 specifying-ko → clarifying-ko → planning-ko → decomposing-ko 체인 필수. Phase 1 생략 금지
- **per-FR PR 생성** — Phase 3에서 per-FR PR 생성 금지. `receiving-code-review-ko`가 `BATCH-REVIEW-DONE: <FID>` 를 출력하고 halt함으로써 자동 차단된다. 최종 batch PR 1개 (Phase 3 완료 Step D)만 생성
- **Phase 2·2.5 건너뜀** — 일괄 리뷰 게이트와 화면→인터페이스 통합 design-first는 필수. 사용자 확인 없이 Phase 3 진입 금지
- **Phase 1에서 batch Step 5.6 실행** — FR별 api-spec 선갱신 금지. 인터페이스는 Phase 2.5-B(화면 직후)
- **Phase 2.5-D 생략** — 화면 또는 IF 산출이 있으면 `design-reviewer-ko` 필수. 부모 self-review로 대체 금지
- **design-review FAIL을 무시하고 구현** — PASS(또는 §auto Important-only cap 기록) 없이 Phase 3 진입 금지. **Critical cap은 §auto여도 정지**
- **skill 미호출 인라인 뭉개기** — 오케스트레이터가 spec~verify 산출물을 heredoc 으로 직접 쓰는 것 금지 (R-3 스킬 선언 투명성 위반 + session-progress 줄 0 → `batch-state.sh` `[진행기록 누락]` 이 batch PR 직전 차단). 각 단계는 Skill 도구로 **실호출**한다 — dogfood 20260716: 4 FID spec→tasks 가 3분 만에 인라인 생성되어 진행 흔적이 전무했다
- **deny 를 무사유 BYPASS 로 정면 돌파** — pretool deny 를 만나면 우선 `run-verification.sh <FID>` 를 실행해 정직하게 연다. 우회가 정당한 경우(verify 선행 단계의 중간 커밋 등)에도 인라인 BYPASS 는 `SPECOPS_BYPASS_REASON='<사유>'` 병기 필수 — 무사유는 pretool 이 deny 한다

## 참조

- `skills/specifying-ko/SKILL.md` — batch 분기 (Step 0 git-branch-create skip, §batch 라벨)
- `skills/decomposing-ko/SKILL.md` — Phase 1 정지점 (BATCH-PHASE1-DONE)
- `commands/start-foundation.md` — 미러링 패턴
- `commands/start.md` — 단일 기능 진입 슬래시
- `templates/requirements.md` — FR 표 포맷 참조

---

*specops-ko v1.51.0 · 2026-08-04 · Phase 2.5 design-reviewer 무거운 설계 리뷰*
