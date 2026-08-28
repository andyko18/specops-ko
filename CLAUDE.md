# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

specops-ko는 **Claude Code 전용 한국어 자율 Lifecycle 플러그인**이다. 슬래시 1회(`/start`, `/start-lite`, `/maintain`, `/maintain-lite`) 또는 자연어 진입 후 메타 스킬이 spec → (clarify → plan) → TDD implement → verify → review → security → integration-test → performance-test → PR 전 단계를 자동 chain한다. `/start-lite`·`/maintain-lite`는 clarify·plan ceremony만 생략하고 화면/IF·Phase B/C·verify는 유지한다(NL로 lite 추론 금지). Conductor 에이전트 없이 각 SKILL.md 본문의 `## 다음 skill` 섹션이 다음 단계를 강제한다.

## 테스트 명령

> **clone 마다 1회**: `bash scripts/_internal/install-git-hooks.sh` — 2단 git hook 게이트를 설치한다 (`core.hooksPath` 는 `.git/config` 로컬 설정이라 버전관리되지 않는다). `pre-commit` = validate-structure + check-propagation(~5s) · `pre-push` = origin main **CI 상태 경고**(`gh` 있을 때만, ~1s, 비차단) + `run-all.sh` 전체(~330s — 147 스위트 실측, 스위트별 300s 상한). **Claude Code PreToolUse 훅(R-1)은 Cursor 등 다른 도구의 커밋에 발화하지 않으므로**, 도구 무관 게이트는 이 층뿐이다 (계기: 44cd095 가 run-all 없이 나가 main 이 하루 red). 탈출구는 `--no-verify`.

```bash
# 전체 테스트 (run-all.sh — 릴리즈 pre-flight 게이트와 동일)
bash scripts/tests/run-all.sh

# LLM 동작 smoke eval (수동 전용 — 토큰 비용 발생, run-all 비포함)
bash scripts/tests/llm-eval/run-evals.sh
# LLM eval N-run 신뢰성 (수동 — flakiness 측정): LLM_EVAL_RUNS=10 bash scripts/tests/llm-eval/run-evals.sh
#   fixture별 성공률·FLAKY(<80%) 리포트. 기본 N=1 은 기존 단발 동작.
# 주간 자동 smoke: .github/workflows/llm-smoke.yml (ANTHROPIC_API_KEY secret 등록 시 활성 — 미등록 시 graceful skip)

# lifecycle E2E 자동 검증 (수동 전용 — 토큰 비용 발생, run-all 비포함)
# e2e-test-ko skill 이 greet-cli fixture 로 9단계 chain 완주 + 산출물 구조 검증
/e2e-test

# Phase 2.5 dogfood (수동 전용 — 토큰 비용, run-all 비포함)
# scripts/tests/dogfood/phase25-checklist.md

# 거버넌스 규칙 테스트 (R-1~R-6, 전 항목 PASS 목표)
bash scripts/tests/governance/test-rules.sh

# DAG 파서 테스트 (전 항목 PASS 목표)
bash scripts/tests/dag/test-parse-dag.sh

# 플러그인 구조 무결성 검증 (전 항목 ✅ 목표)
bash scripts/_internal/validate-structure.sh
```

## 아키텍처

### Skill 계층 구조

```
skills/<name>/SKILL.md   ← 플랫 구조, layer 필드로 계층 구분
```

- **layer: 1** — 메타 스킬 (`using-specops-ko`): SessionStart 훅으로 자동 주입, 신호 감지 후 chain 진입
- **layer: 2** — Engine Skills: Lifecycle 체인의 각 단계 (specifying → clarifying → planning → decomposing → implementing → verifying → reviewing → security-review → integration-test → performance-test → PR)
- **layer: 2** — `karpathy-ko`: cross-cutting 행동 원칙 (Think·Simplicity·Surgical·Goal), 구현 단계 자동 활성
- **layer: 3** — Harness Skills: 아키텍처 원칙 강제 (sprint-contracts, structured-artifacts, generator-evaluator, context-resets, file-based-communication) + e2e-test-ko (lifecycle E2E 자동 검증)

chain 의 primary edge 는 `hooks/chain.yaml` 이 단일 Source of Truth 다 — 각 SKILL.md `## 다음 skill` 코드블록·메타 skill chain 목록과의 drift 는 `validate-structure.sh` `chain_consistency` 검사가 적발한다 (edge 변경 시 세 곳 동기 수정).

### 거버넌스 엔진

거버넌스 훅 이벤트 4종(+ `Notification` → `notify.sh` 보조 1종)이 자동 실행되며, `hooks/rules.jsonl`에 정의된 6개 규칙 중 R-1~R-5 를 검사한다 (R-6 은 `enabled: false` — gbrain-ko manual-only 설계):

- `SessionStart` → `session-start.sh`: 메타 스킬 주입 + session-progress rehydrate. **조립 순서 계약**: `specops-ko-anchor` → `freecomment-pending` → `session-progress-reconcile` → `batch-resume`(조건부 — ACTIVE 마커 있는 미완 batch 존재 시) → 메타 본문 → `session-progress-rehydrate` — harness 가 큰 additionalContext 를 선두 일부만 인라인하므로 행동 지시 블록을 앞에 둔다 (`scripts/tests/test-session-start-order.sh` 가 잠금)
- `PreToolUse` → `pretool-governance.sh` (v1.14.0 신설): R-1(commit 전 verify)·R-2(PR 전 verify) **사전 차단(Hard block)** — verify 누락 시 `git commit`·`gh pr create` 실행 전 deny. **관할 한정**: cwd 에 `.specops/` 부재 시(specops 미사용 repo) 면제 — 플러그인은 자기 관할 repo 만 통제(5원칙 4 주권). 면제 **4종**: `SPECOPS_GOVERNANCE_BYPASS=1`(인라인 사용 시 `SPECOPS_BYPASS_REASON='<사유>'` 병기 필수 — 무사유는 deny) · docs/design-only 변경(`*.md`·`*.txt`·`*.rst` + `screens/*.html`·`.specops/*`) · `.specops/` 부재 · fail-open(transcript 부재·tool_use 이벤트 0건(rc=2)·rules·jq 판정 불가)

> **플러그인 런타임 예외** (v1.82.0, `_files_all_docs`): `.claude-plugin/plugin.json` 이 있는 repo 에서는 `skills/*/SKILL.md`·`commands/*.md`·`agents/*.md`·`templates/*.md`·`hooks/*`·`.claude-plugin/*` 이 **확장자와 무관하게 코드**다. 이 플러그인의 실행 로직은 산문이라, `*.md` 를 무조건 문서로 보면 verify 강제가 제품 본체에서 통째로 면제됐다 (실측: 최근 60커밋 중 41건이 면제 클래스, 그중 22건이 실제 행동 변경 — 릴리즈 스탬프 19 제외). 제거된 `§auto` 자기발급 면제표보다 넓었다. **플러그인 repo 에서만** 적용한다 — 이 경로는 Claude Code 플러그인 규약이지 앱 규약이 아니라서, 무조건 걸면 하류 앱 repo 의 `templates/email.md` 가 문서 커밋에서 막히고 false-deny 가 BYPASS 관성을 만든다. 같은 트리라도 `skills/*/README.md`·루트 `README`·`CHANGELOG`·`CLAUDE.md` 는 면제 유지(배포 런타임 아님).
- `PostToolUse` → `posttool-governance.sh`: R-1(commit 전 verify), R-2(PR 전 verify) **감사 기록(Soft Warn)**, R-3(스킬 선언 투명성). 기록 시 `_audit_scope_class` 로 **방금 액션의 커밋 범위**(R-1 `HEAD~1..HEAD` · R-2 `base...HEAD`)를 분류해 `scope_class` 필드를 남긴다 — 면제 시엔 기록 자체가 없으므로 posttool 기여분에 `docs-only` 는 구조적으로 나타나지 않고 `code`·`empty`·판정불가(필드 부재)만 쌓인다.
- `Stop` → 3 훅 발화: `ensure-session-progress.sh`(session-progress.md 보장) + `stop-governance.sh`(거버넌스: R-4 성공 주장 + 테스트 미실행, R-5 plan 수정 + Advisor 협의 누락(협의를 **주장**하면 transcript 실호출 증거 요구 — `server_tool_use`(advisor)↔`advisor_tool_result` 또는 `critic-ask.sh`. `해당 없음` 정직 선언은 증거 불요), R-6 `/verify` + evidence.md 후 gbrain-append 호출 부재 — 비활성) + `freecomment-capture.sh`(자유 코멘트 자동 캡처 — pending 적재, SessionStart 에서 LLM 요약→freelog.md)

R-1/R-2 는 **pretool=강제 차단 / posttool=감사** 로 역할이 분리된다(면제·fail-open 시 posttool audit trail 보존). 그 외 위반은 `.specops/<FID>/friction-log.jsonl`에 Soft Warn으로 기록된다.

**실행-근거 gate** (v1.45.0, `governance-lib.sh:_verify_exec_evidence`): R-1/R-2 의 verify 면제는 **자기보고만으로 열리지 않는다**. transcript 가용 시, 자기보고 면제 3경로 — session-progress 의 `/verify PASS` 줄 · evidence.md 의 `RUN-VERIFICATION-RESULT` 스탬프 · `verifying-evidence-ko` Skill 호출 — 는 **무엇이 있든** transcript 의 `tool_use` ↔ `tool_result` 를 `tool_use_id` 로 join 해 검증 러너가 **실제로 실행되어 `VERIFY: PASS` 를 출력했는지** 확인한 뒤에만 면제된다 (`VERIFY: PARTIAL`·`FAIL`·`is_error` 는 불인정). 모델이 spec.md 에 스스로 쓰는 `§auto: true` 라벨의 **무조건 면제는 제거됐다** — 자기발급 면제표였기 때문이다. 무인 모드(`/start-auto`)도 chain 에 verify 가 있어 실제 실행하므로 정직한 흐름은 그대로 통과한다. 판정 불가(transcript 부재·tool_use 이벤트 0건(rc=2)·jq 실패)는 fail-open.

### 서브에이전트 리뷰 패턴 (Generator ↔ Evaluator 분리)

Generator와 Evaluator를 엄격히 분리해 자기평가 편향을 차단한다. `agents/` 의 서브에이전트는 용도가 나뉜다:

- **구현 2단계** (`implementing-ko` 가 태스크별 fresh dispatch): **Phase B** `spec-reviewer-ko`(스펙 준수만) → PASS 후 **Phase C** `code-reviewer-ko`(코드 품질·보안·커버리지·DB 관점).
- **설계 리뷰** (`planning-ko` 가 dispatch): `plan-reviewer-ko` — TDD 커버리지·플레이스홀더·파일 경계·타입 일관성 + 실측 의무.
- **batch 화면·IF 리뷰** (`/start-all` Phase 2.5-D): `design-reviewer-ko` — Interactions↔api-spec·data-model 정합·껍데기·cross-FR + 실측 의무.
- **self-config 적대감사** (`/security-scan --self-config`): `red-team-ko`(공격 표면 탐색) → `blue-team-ko`(기존 방어 유효성 평가) → `auditor-ko`(종합 risk 등급 A~F 리포트). 플러그인 자기 hooks·rules·settings 번들을 read-only 감사.

Evaluator 에이전트는 frontmatter `role: evaluator` 로 Write/Edit 를 하드 박탈한다 (validate-structure `agent_tools` 스캔 강제).

### 아티팩트 규약

모든 작업 산출물은 `.specops/<FID>/`에 보관된다. FID 포맷: `YYYYMMDD-kebab-slug`.

```
.specops/<FID>/
├── spec.md + acceptance-criteria.md   ← /specify 산출
├── clarifications.md                  ← /clarify 산출
├── plan.md                            ← /plan 산출
├── tasks.md                           ← /decompose 산출 (YAML DAG 포함)
├── dispatch/<task-id>-context.md      ← 서브에이전트 입력
├── evidence.md                        ← /verify 산출
└── friction-log.jsonl                 ← 거버넌스 위반 기록
```

### design-first 대칭 (화면 Step 5.5 ↔ 인터페이스 Step 5.6)

`specifying-ko` 설계 승인 직후, 구현 전에 두 design-first 루프가 대칭으로 돈다:

- **Step 5.5 화면** — UI 기능이면 화면별로 `screens/<name>.md`(스펙) + `screens/<name>.html`(미리보기) 쌍 생성. lifecycle 밖 개별/일괄 수정은 `/design-screen(s)`.
- **Step 5.6 인터페이스** — API/스키마 기능이면 마스터 문서 `.specops/memory/api-spec.md`(IF 설계) · `.specops/memory/data-model.md`(테이블 설계) 의 해당 섹션을 **먼저** 갱신. lifecycle 밖은 `/design-interface(s)`.

`foundation` 분기는 Step 5.5 를 **전면 skip 하지 않는다** — **셸 전용**(allowlist `app-shell`·`layout`·`login` + `<!-- foundation-shell -->`, 기능 화면 금지). **Step 5.6 은 적용**(공통부 DB 스키마·공통 API 의 본진). `/start-all` **batch** 는 Step 5.5·5.6을 모두 skip 하고 Phase 2.5에서 **화면→인터페이스→`design-reviewer-ko` 무거운 리뷰** 순으로 1회 통합한다(화면 또는 IF 산출 시 리뷰 필수). 파괴적 스키마 변경은 `impact-analysis.md §2`(expand-contract) + 회귀 AC-R-2(데이터 보존)로 연계. verify 가 역방향 안전망으로 설계-구현 대칭을 검사한다.

### 학습 루프 (gbrain / freelog)

세션 인사이트는 `.specops/memory/learnings.jsonl` 에 축적된다 — `scripts/gbrain-append.sh` append, `/gbrain` 조회. 자유작업(lifecycle 밖 편집)은 Stop 훅 `freecomment-capture.sh` 가 pending 적재 → SessionStart 가 LLM 요약해 `.specops/freelog.md` 기록 + mini-FID 또는 진행 중 FID 귀속. `/log` 로 수동 즉석 기록.

## 주요 규약

### SKILL.md frontmatter 필수 필드

```yaml
---
name: <스킬명>
description: <한 줄 설명>
layer: <1|2|3>
reference_upstream: <owner/repo@version path>  # 포맷 필수 (독자 추가 시 "specops-ko 독자 추가" 허용)
specops_version: <semver>  # 본 skill 본문이 마지막으로 substantive 변경된 플러그인 버전 (자동 갱신 아님)
used_by: <호출자 목록>  # 표기 규약 — command 는 /<name>, skill 은 short name (<skill>-ko)
---
```

선택 marker 필드: skills `discipline: true` (합리화 차단표 의무 — test-skill-conventions T9 스캔), agents `role: evaluator` (Write/Edit 박탈 하드강제 — validate-structure agent_tools 스캔). 신규 discipline/evaluator 항목은 marker 만 달면 자동 검사 편입.

### tasks.md DAG 포맷

`decomposing-ko`가 생성하는 `tasks.md`에는 YAML DAG가 포함된다. `scripts/dag/parse-dag.sh`가 파싱하여 독립 batch를 추출하고, `implementing-ko`가 병렬 dispatch에 활용한다.

### maintenance flag

진입 분기 약속어 — args 첫 줄에 HTML 주석을 prepend하여 분기를 구분한다.
매칭 순서(specifying-ko): maintain-lite → maintain → lite → foundation → batch → auto → (신규 기본).

- `<!-- entry: maintain-lite -->` — 경량 유지보수. `analyzing-ko` `[lite-mini 분기]` → `specifying-ko` `[maintain-lite 분기]`. `maintain`보다 **먼저** 매칭.
- `<!-- entry: maintain -->` — 유지보수 진입. `specifying-ko`의 `[유지보수 분기]`가 감지.
- `<!-- entry: lite -->` — 경량 신규. `specifying-ko` `[lite 분기]` — clarify/plan skip, §lite+trivial, 화면/IF·B/C 유지.
- `<!-- entry: foundation -->` — 공통부 먼저 개발 진입. `specifying-ko`의 `[foundation 분기]`가 감지. Step 5.5 **셸 전용**(allowlist `app-shell`·`layout`·`login` + `<!-- foundation-shell -->`, 기능 화면 금지), Step 5.6 적용, §유형=`foundation` 자동 라벨.
- `<!-- entry: batch -->` — `/start-all` FR 루프. Step 0 git-branch skip, Step 5.5·5.6 skip(Phase 2.5로 이관). 셋째 줄 `<!-- auto: true -->`면 `§auto` 동시 기재.
- `<!-- entry: auto -->` — 무인 단독(`§auto: true`). git-branch 유지, clarify/plan 수행.

## 구조 검증이 FAIL나면

```bash
bash scripts/_internal/validate-structure.sh
```

- `file_counts FAIL` → 파일 추가/삭제 시 스크립트 내 기대값(commands, skills, templates 개수) 업데이트
- `frontmatter FAIL` → YAML `{{placeholder}}`는 따옴표로 감싸야 함
- `ref_upstream_fmt` → `owner/repo@version path` 포맷 또는 `specops-ko 독자 추가` 명시 필요
