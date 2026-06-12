# specops-auto-ko

**Claude Code 전용 한국어 자율 Lifecycle 플러그인** (v1.12.0)

## 사용방법

### 1. 플러그인 설치 (1회)

```bash
claude plugin marketplace add ~/path/to/specops-auto-ko
```

### 2. 작업 진입 (슬래시 1회 또는 자연어 1회)

| 의도 | 슬래시 진입 | 자연어 진입 |
|---|---|---|
| **프로젝트 초기화** (1회) | `/start-project [<프로젝트명>]` | (메타 skill 자동 안내) |
| **공통부 개발** (초기 1회) | `/start-foundation "라우팅·인증·공통 레이아웃"` | — |
| **전체 기능 일괄 구현** | `/start-batch` | — |
| **신규 기능** | `/start "CSV 파일 줄 수 세기 CLI"` | "CSV 파일 줄 수 세기 CLI 만들어줘" |
| **유지보수** | `/maintain "auth.js 토큰 만료 처리"` | "auth.js 토큰 만료 처리 버그 고쳐줘" |

> `/start-project` 는 한국 SI 표준 13종 산출물 (PRD/CLAUDE/DESIGN/architecture/api-spec/data-model/screens-overview 등) 을 자동 부트스트랩한다. (구 `/start-design` 은 본 슬래시로 통합·제거됨.)

진입 1회로 **spec → clarify → plan → TDD implement → verify → review → integration-test → performance-test → PR** 전 단계가 자동 체인됩니다. 각 단계를 수동으로 호출할 필요 없습니다.

> 자연어 진입은 SessionStart 시 자동 주입되는 메타 스킬 (`using-specops-auto-ko-ko`) 이 신호를 감지해 `specifying-ko` (신규) 또는 `analyzing-ko` (유지보수) 로 라우팅합니다.

---

## 개요

슬래시 1회 진입 후 **메타 스킬이 단계·스킬을 자동 chain**하는 한국어 자율 Lifecycle 플러그인.

- **자율 체인**: Conductor 에이전트 없이 각 스킬 본문 `## 다음 skill`이 다음 단계를 강제
- **거버넌스**: R-1~R-6 규칙 엔진이 매 도구 호출 후 원칙 위반을 자동 감지
- **AC 계약**: `acceptance-criteria.md`를 스프린트 계약서로 취급 — 평가자는 이것만 기준으로 판정
- **Generator/Evaluator 분리**: Phase B(스펙 준수)와 Phase C(코드 품질)를 별도 서브에이전트가 담당

---

## Lifecycle Chain

```
/start <기능>  또는  /maintain <대상>  또는  자연어
    ↓
specops-auto-ko:using-specops-auto-ko-ko  (메타 · SessionStart · 신호 분류 → maintenance flag)
    ↓
   [신규]  ─── args 그대로 ───────────  [유지보수]
    │                                    ↓
    │                       args = "<!-- entry: maintain -->\n<원본>"
    │                                    ↓
    │                       specops-auto-ko:analyzing-ko  ★ HARD GATE
    │                       (current-state.md + impact-analysis.md)
    │                                    ↓
    └─→ specops-auto-ko:specifying-ko ←──┘     — spec.md (§유형 자동 라벨) + acceptance-criteria.md (회귀 AC 강제)
    ↓ HARD GATE (사용자 승인)
specops-auto-ko:clarifying-ko     — clarifications.md
    ↓ HARD GATE
specops-auto-ko:planning-ko       — plan.md
    ↓
specops-auto-ko:decomposing-ko    — tasks.md + DAG
    ↓
specops-auto-ko:implementing-ko   ←── (분기) systematic-debugging-ko
    │ · 태스크별 fresh 서브에이전트 dispatch
    │ · DAG-aware 병렬 실행 (독립 태스크 자동 식별)
    │ · Phase B: spec-reviewer-ko (스펙 준수)
    │ · Phase C: code-reviewer-ko (코드 품질)
    ↓
specops-auto-ko:verifying-evidence-ko     — evidence.md
    ↓
specops-auto-ko:requesting-code-review-ko
    ↓
specops-auto-ko:receiving-code-review-ko
    ↓
specops-auto-ko:integration-test-ko   (통합 표면 없으면 graceful skip)
    ↓
specops-auto-ko:performance-test-ko   (성능 NFR 없으면 graceful skip)
    ↓
"PR 생성? [y/n]"
```

---

## 자산 구조

```
specops-auto-ko/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── commands/                                 ← 슬래시 진입로 (13건)
│   ├── start.md                              ← 신규 진입 슬래시 /start
│   ├── start-foundation.md                   ← 공통부 우선 개발 /start-foundation
│   ├── maintain.md                           ← 유지보수 진입 슬래시 /maintain
│   ├── start-project.md                      ← 프로젝트 초기화 /start-project
│   ├── brainstorming.md                      ← 아이디어 탐색 /brainstorming (pre-start)
│   ├── design-screen.md                      ← 화면 설계 /design-screen
│   ├── design-screens.md                     ← 일괄 화면 설계 /design-screens
│   ├── e2e-test.md                           ← E2E lifecycle 자동 테스트 (9단계)
│   ├── gbrain.md                             ← 세션 인사이트 조회 /gbrain
│   ├── improve-arch.md                       ← 아키텍처 정적 분석 /improve-arch
│   ├── release.md                            ← 릴리즈 자동화 /release
│   ├── start-auto.md                         ← 완전자동 모드 /start-auto
│   └── start-batch.md                        ← 배치 오케스트레이터 /start-batch
├── hooks/
│   ├── hooks.json                        ← SessionStart + PostToolUse + Stop 매니페스트
│   ├── session-start.sh                  ← 메타 스킬 자동 주입 + session-progress rehydrate
│   ├── posttool-governance.sh            ← 도구 호출 후 R-1~R-3 검사 (R-4~R-6 은 Stop 훅)
│   ├── governance-lib.sh + rules.jsonl   ← 거버넌스 라이브러리 + 규칙 정의
│   ├── ensure-session-progress.sh        ← session-progress.md 보장
│   └── stop-governance.sh               ← 세션 종료 정리
├── skills/                               ← flat: skills/<name>/SKILL.md × 30
│   │
│   │  Engine Skills (Lifecycle 체인)
│   ├── using-specops-auto-ko-ko/         ← 메타 스킬 (SessionStart 자동 주입)
│   ├── brainstorming-ko/                 ← 아이디어 탐색·수요 검증 (pre-design)
│   ├── analyzing-ko/                     ← 유지보수 baseline + impact 분석 (★ HARD GATE)
│   ├── specifying-ko/                    ← spec.md + AC 작성
│   ├── clarifying-ko/                    ← 모호성 해소
│   ├── planning-ko/                      ← 구현 플랜
│   ├── plan-reviewer-ko/                 ← plan.md Eng 리뷰 서브에이전트
│   ├── decomposing-ko/                   ← TDD 태스크 분해 + DAG
│   ├── implementing-ko/                  ← 서브에이전트 dispatch
│   ├── tdd-ko/                           ← TDD 5스텝 (서브에이전트용)
│   ├── verifying-evidence-ko/            ← 증거 기반 검증
│   ├── requesting-code-review-ko/        ← 코드 리뷰 요청
│   ├── receiving-code-review-ko/         ← 리뷰 피드백 수용
│   ├── integration-test-ko/              ← 통합 테스트 (PR 직전, 표면 없으면 graceful skip)
│   ├── performance-test-ko/              ← 성능 테스트 + PR 게이트 (임계값 없으면 graceful skip)
│   ├── finishing-a-development-branch-ko/ ← worktree 정리·branch 삭제·main 동기화
│   ├── systematic-debugging-ko/          ← BLOCKED 상태 복구
│   ├── dispatching-parallel-agents-ko/   ← DAG-aware 병렬 dispatch
│   ├── using-git-worktrees-ko/           ← 병렬 격리 (git worktree)
│   ├── gbrain-ko/                        ← 세션 인사이트 조회 (learnings.jsonl)
│   ├── improve-codebase-architecture-ko/ ← deep module 정적 분석 (split/merge 권고)
│   ├── karpathy-ko/                      ← Karpathy 4원칙 (Think·Simplicity·Surgical·Goal)
│   ├── advisor-ko/                       ← advisor 활용 (애매성 발생 시 외부 자문 의무)
│   │
│   │  Harness Skills (아키텍처 원칙)
│   ├── sprint-contracts-ko/              ← AC를 계약으로
│   ├── structured-artifacts-ko/          ← .specops/<FID>/ 규약
│   ├── generator-evaluator-ko/           ← Phase B/C 분리 원칙
│   ├── context-resets-ko/                ← 서브에이전트 컨텍스트 격리
│   ├── file-based-communication-ko/      ← 파일 기반 dispatch 패턴
│   └── e2e-test-ko/                      ← lifecycle chain fixture 자동 실행 (9단계)
├── templates/                            ← 30건
│   │  Lifecycle/공통 템플릿 (15건): spec, acceptance-criteria, plan, tasks, session-progress,
│   │      dispatch-context, dispatch-log, current-state, impact-analysis, test-conventions-{bash,python},
│   │      screen.{md,html}, DESIGN, SKILL, foundation-manifest
│   │  /start-project 산출 템플릿 (12건): constitution, PRD, requirements,
│   │      CLAUDE, README, architecture, frontend-architecture, backend-architecture,
│   │      api-spec, data-model, screens-overview, test-strategy
├── agents/                               ← 3건 (implementer, spec-reviewer, code-reviewer)
├── scripts/
│   ├── session-progress-append.sh
│   ├── dag/                              ← DAG 파서 + 컨텍스트 검증
│   ├── tests/                            ← governance + dag 단위 테스트
│   └── _internal/                        ← 유지보수 도구
│       ├── validate-structure.sh        ← 구조 무결성 검증 (`--update-baseline` 플래그)
│       ├── .structure-baseline          ← jsonl baseline (commands/skills/templates/agents 카운트)
│       ├── count-artifacts.sh
│       ├── diff-upstream.sh
│       ├── is-hook-enabled.sh
│       ├── validate-task-dependencies.sh
│       └── start-project.sh             ← /start-project 오케스트레이터 (10 phase)
├── examples/                             ← dogfood CLI 예시 (epoch/hex/b64/cvt/slug)
└── README.md
```

> `layer:` 필드 (각 SKILL.md frontmatter)로 Engine/Harness 구분 보존.

---

## 거버넌스 엔진

`hooks/rules.jsonl`에 정의된 6 규칙 중 R-1~R-5 가 PostToolUse + Stop 훅으로 자동 검사됩니다 (R-6 은 `enabled: false` — gbrain-ko manual-only 설계).

| Rule | 원칙 | 감지 조건 |
|---|---|---|
| R-1 | 5 (검증) | git commit 전 verifying-evidence-ko 미호출 |
| R-2 | 5 (검증) | gh pr create 전 verifying-evidence-ko 미호출 |
| R-3 | 1 (투명성) | specops-auto-ko 스킬 호출 전 "Using ..." 선언 부재 |
| R-4 | 5 (검증) | 성공 주장 있으나 테스트 러너 미실행 |
| R-5 | 1 (투명성) | plan.md 수정 시 Advisor 협의 기록 섹션 누락 |
| R-6 | 1 (투명성) | `/verify` + evidence.md 후 gbrain-append 호출 부재 — **비활성** (gbrain-ko manual-only 설계, `enabled: false`) |

위반 시 `.specops/<FID>/friction-log.jsonl`에 자동 기록 (Soft Warn).

---

## 검증 현황

- **Lifecycle dogfood**: 5회 완주 (csv-lines · slug-cli · cvt-cli · b64-cli · hex-cli)
- **거버넌스 테스트**: `bash scripts/tests/governance/test-rules.sh` → 전 항목 PASS (R-1~R-6)
- **DAG 파서 테스트**: `bash scripts/tests/dag/test-parse-dag.sh` → 전 항목 PASS
- **전체 테스트**: `bash scripts/tests/run-all.sh` → 41 suites PASS (릴리즈 pre-flight 게이트)
- **거버넌스 성능**: p95 69ms / median 67ms (AC-8 < 200ms 충족)

---

*초기화: 2026-04-21 · PoC Gold PASS: 2026-04-22 · v1.0.0 릴리즈: 2026-04-26 · **최신: v1.12.0 (2026-06-11)** · Claude Code 전용*
