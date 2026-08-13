# specops-ko

**Claude Code 전용 한국어 자율 Lifecycle 플러그인** (v1.74.0)

## 사용방법

### 1. 플러그인 설치 (1회)

```bash
# 의존성 선행 등록 (최초 1회)
claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill

# GitHub marketplace 등록 + 설치
claude plugin marketplace add andyko18/specops-ko
claude plugin install specops-ko@specops-ko
```

로컬 경로로 개발·dogfood 할 때는 `claude plugin marketplace add /절대경로/specops-ko` 도 가능합니다.

### 2. 작업 진입 (슬래시 1회 또는 자연어 1회)

| 의도 | 슬래시 진입 | 자연어 진입 |
|---|---|---|
| **프로젝트 초기화** (1회) | `/init-project [<프로젝트명>]` | (메타 skill 자동 안내) |
| **공통부 개발** (초기 1회) | `/start-foundation "라우팅·인증·공통 레이아웃"` | — |
| **전체 기능 일괄 구현** | `/start-all` | — |
| **전체 기능 일괄 구현 (무인)** | `/start-all-auto` | — |
| **신규 기능** | `/start "CSV 파일 줄 수 세기 CLI"` | "CSV 파일 줄 수 세기 CLI 만들어줘" |
| **신규 기능 (경량)** | `/start-lite "<기능>"` | — (NL 추론 금지) |
| **신규 기능 (무인)** | `/start-auto "<기능>"` | — |
| **유지보수** | `/maintain "auth.js 토큰 만료 처리"` | "auth.js 토큰 만료 처리 버그 고쳐줘" |
| **유지보수 (경량)** | `/maintain-lite "<대상>"` | — (NL 추론 금지) |
| **(선택) 아이디어 탐색** | `/brainstorming` | — |
| **화면·인터페이스 개별 설계** (lifecycle 밖) | `/design-screens` · `/design-interfaces` | — |

**어느 진입로를 고를까 — 결정 트리:**

```
신규 프로젝트인가?
├─ 예 → /init-project (문서 13종 부트스트랩, 1회)
│         ↓ 공통 인프라(라우팅·인증·DB) 필요?
│         ├─ 예 → /start-foundation (공통부 코드, 1회)
│         └─ 아니오 → 다음
│         ↓ requirements.md FR 표 확정 + 한번에 일괄?
│         ├─ 예 → /start-all (FR 전체 일괄, batch PR 1개)
│         └─ 아니오 → 기능마다 ↓
│
└─ 기존 프로젝트 작업 ↓
   작업이 기존 코드/화면을 수정·삭제하나?
   ├─ 아니오 (새 산출물) → /start "<기능>"
   │     · 매 게이트 확인(대화형)  |  무인 진행 원하면 → /start-auto (가역 게이트 자동 통과, PR만 확인)
   │     · 경량(clarify·plan skip, 화면/IF·B/C 유지) → /start-lite
   └─ 예 (기존 수정·제거·확장) → /maintain "<대상>"
         · analyzing 선행(영향 분석) + 회귀 AC 강제  |  경량(analyze-mini) → /maintain-lite

· 신규 프로젝트 순서: /init-project → /start-foundation → /start-all (또는 기능마다 /start)
· `/start-all` 전 UI/BE/풀스택은 `.specops/memory/foundation-manifest.md` 필수 (Phase 0 HARD — 없으면 재사용 게이트 침묵 SKIP)
· foundation `feat/<FID>` 는 main 머지 후 `/start-all` (Phase 0 `check-foundation-merged`)
· foundation IF는 `foundation-baseline` 마커 — `/start-all` Phase 2.5-B는 마커 밖만 append
· foundation UI 셸은 `app-shell` 등 + `foundation-shell` 마커 — Phase 2.5-A는 셸 재작성 금지
· `/start-all` queue.md 는 `init-batch-queue.sh`가 `--classify`로 기계 작성 (재개 시 REUSE)
· `[공통]` FR 은 `/start-all` 에서 SKIP — 구현은 `/start-foundation` (hybrid `§유형=foundation`+`§batch` 금지)
· 자연어로 진입해도 됨 — 메타 skill 이 신호 감지해 라우팅(혼재 시 1문항 확인).
```

> `/init-project` 는 한국 SI 표준 13종 산출물 (PRD/CLAUDE/DESIGN/architecture/api-spec/data-model/screens-overview 등) 을 자동 부트스트랩한다. (구 `/start-design` 은 본 슬래시로 통합·제거됨.)

진입 1회로 **spec → clarify → plan → TDD implement → verify → review → security → integration-test → performance-test → PR** 전 단계가 자동 체인됩니다. 각 단계를 수동으로 호출할 필요 없습니다.

> 자연어 진입은 SessionStart 시 자동 주입되는 메타 스킬 (`using-specops-ko`) 이 신호를 감지해 `specifying-ko` (신규) 또는 `analyzing-ko` (유지보수) 로 라우팅합니다.

---

## 의존성 (ui-ux-pro-max)

specops-ko 는 화면 설계 시 `ui-ux-pro-max`(MIT, marketplace `ui-ux-pro-max-skill`)를 **cross-marketplace hard dependency**로 사용한다.

**설치 전 marketplace 선행 등록 필수** — 미등록 시 설치가 `cross-marketplace` 에러로 **실패**한다:

```bash
claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
```

등록 후 specops-ko 설치 시 ui-ux-pro-max 가 자동 동반 설치된다. (미해결 환경에서도 화면 설계는 DESIGN.md fallback 으로 graceful 동작)

---

## 개요

슬래시 1회 진입 후 **메타 스킬이 단계·스킬을 자동 chain**하는 한국어 자율 Lifecycle 플러그인.

- **자율 체인**: Conductor 에이전트 없이 각 스킬 본문 `## 다음 skill`이 다음 단계를 강제
- **거버넌스**: R-1~R-5 규칙 엔진이 매 도구 호출 후 원칙 위반을 자동 감지 (R-6 은 manual-only 비활성)
- **AC 계약**: `acceptance-criteria.md`를 스프린트 계약서로 취급 — 평가자는 이것만 기준으로 판정
- **Generator/Evaluator 분리**: Phase B(스펙 준수)와 Phase C(코드 품질)를 별도 서브에이전트가 담당

---

## Lifecycle Chain

```
/start <기능>  또는  /maintain <대상>  또는  자연어
    ↓
specops-ko:using-specops-ko  (메타 · SessionStart · 신호 분류 → maintenance flag)
    ↓
   [신규]  ─── args 그대로 ───────────  [유지보수]
    │                                    ↓
    │                       args = "<!-- entry: maintain -->\n<원본>"
    │                                    ↓
    │                       specops-ko:analyzing-ko  ★ HARD GATE
    │                       (current-state.md + impact-analysis.md)
    │                                    ↓
    └─→ specops-ko:specifying-ko ←──┘     — spec.md (§유형 자동 라벨) + acceptance-criteria.md (회귀 AC 강제)
    ↓ HARD GATE (사용자 승인)
specops-ko:clarifying-ko     — clarifications.md
    ↓ HARD GATE
specops-ko:planning-ko       — plan.md
    ↓
specops-ko:decomposing-ko    — tasks.md + DAG
    ↓
specops-ko:implementing-ko   ←── (분기) systematic-debugging-ko
    │ · 태스크별 fresh 서브에이전트 dispatch
    │ · DAG-aware 병렬 실행 (독립 태스크 자동 식별)
    │ · Phase B: spec-reviewer-ko (스펙 준수)
    │ · Phase C: code-reviewer-ko (코드 품질)
    ↓
specops-ko:verifying-evidence-ko     — evidence.md
    ↓
specops-ko:requesting-code-review-ko
    ↓
specops-ko:receiving-code-review-ko
    ↓
specops-ko:security-review-ko    (SAST — 코드 표면·도구 없으면 graceful skip)
    ↓
specops-ko:integration-test-ko   (통합 표면 없으면 graceful skip)
    ↓
specops-ko:performance-test-ko   (성능 NFR 없으면 graceful skip)
    ↓
"PR 생성? [y/n]"
```

---

## 자산 구조

```
specops-ko/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── commands/                                 ← 슬래시 진입로 (24건)
│   ├── start.md                              ← 신규 진입 슬래시 /start
│   ├── start-lite.md                         ← 경량 신규 /start-lite (clarify·plan skip)
│   ├── start-foundation.md                   ← 공통부 우선 개발 /start-foundation
│   ├── maintain.md                           ← 유지보수 진입 슬래시 /maintain
│   ├── maintain-lite.md                      ← 경량 유지보수 /maintain-lite (analyze-mini)
│   ├── init-project.md                       ← 프로젝트 초기화 /init-project
│   ├── brainstorming.md                      ← 아이디어 탐색 /brainstorming (pre-start)
│   ├── design-screen.md                      ← 화면 설계 /design-screen
│   ├── design-screens.md                     ← 일괄 화면 설계 /design-screens
│   ├── design-interface.md                   ← 인터페이스 설계 /design-interface (화면 대칭)
│   ├── design-interfaces.md                  ← 일괄 인터페이스 설계 /design-interfaces
│   ├── e2e-test.md                           ← E2E lifecycle 자동 테스트 (9단계)
│   ├── gbrain.md                             ← 세션 인사이트 조회 /gbrain
│   ├── log.md                                ← 자유작업 인사이트 즉석 기록 /log
│   ├── improve-arch.md                       ← 아키텍처 정적 분석 /improve-arch
│   ├── release.md                            ← 릴리즈 자동화 /release
│   ├── start-auto.md                         ← 완전자동 모드 /start-auto
│   ├── start-all.md                          ← 배치 오케스트레이터 /start-all
│   ├── start-all-auto.md                     ← 무인 배치 오케스트레이터 /start-all-auto
│   ├── promote.md                            ← 자유작업 mini-FID lifecycle 승격 /promote
│   ├── status.md                             ← FID Lifecycle 단계·아티팩트 현황 /status
│   ├── doctor.md                             ← 설치·환경 건강 진단 /doctor
│   ├── security-scan.md                      ← 온디맨드 보안 점검 /security-scan
│   └── statusline-install.md                 ← HUD statusLine 등록 /statusline-install
├── hooks/                               ← SessionStart + PreToolUse + PostToolUse + Stop (거버넌스 4종) + Notification (보조)
│   ├── hooks.json                        ← 훅 매니페스트
│   ├── session-start.sh                  ← 메타 스킬 자동 주입 + session-progress rehydrate
│   ├── pretool-governance.sh             ← commit/PR 전 verify 누락 사전 차단 (R-1·R-2 Hard block)
│   ├── posttool-governance.sh            ← 도구 호출 후 감사 (R-1·R-2·R-3 Soft Warn)
│   ├── stop-governance.sh                ← 세션 종료 검사 (R-4·R-5, R-6 비활성)
│   ├── governance-lib.sh + rules.jsonl   ← 거버넌스 라이브러리 + 규칙 정의
│   ├── chain.yaml                        ← lifecycle chain primary edge 단일 Source of Truth
│   ├── ensure-session-progress.sh        ← session-progress.md 보장
│   └── (보조) inject-evaluator-timestamp · rotate-evaluator-artifact · notify · freecomment-capture
├── skills/                               ← flat: skills/<name>/SKILL.md × 30
│   │
│   │  Engine Skills (Lifecycle 체인)
│   ├── using-specops-ko/         ← 메타 스킬 (SessionStart 자동 주입)
│   ├── brainstorming-ko/                 ← 아이디어 탐색·수요 검증 (pre-design)
│   ├── analyzing-ko/                     ← 유지보수 baseline + impact 분석 (★ HARD GATE)
│   ├── specifying-ko/                    ← spec.md + AC 작성
│   ├── clarifying-ko/                    ← 모호성 해소
│   ├── planning-ko/                      ← 구현 플랜
│   ├── decomposing-ko/                   ← TDD 태스크 분해 + DAG
│   ├── implementing-ko/                  ← 서브에이전트 dispatch
│   ├── tdd-ko/                           ← TDD 5스텝 (서브에이전트용)
│   ├── verifying-evidence-ko/            ← 증거 기반 검증
│   ├── requesting-code-review-ko/        ← 코드 리뷰 요청
│   ├── receiving-code-review-ko/         ← 리뷰 피드백 수용
│   ├── security-review-ko/               ← SAST 보안 게이트 (semgrep+gitleaks, 표면·도구 없으면 graceful skip)
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
├── templates/                            ← 34건 (md 33 + html 1)
│   │  Lifecycle/공통 템플릿 (19건): spec, acceptance-criteria, plan, tasks, session-progress,
│   │      dispatch-context, dispatch-log, current-state, impact-analysis, test-conventions-{bash,python},
│   │      screen.{md,html}, DESIGN, SKILL, foundation-manifest, critic-prompt-{diff,plan}, freework
│   │  /init-project 산출 템플릿 (13건): constitution, PRD, requirements,
│   │      CLAUDE, README, architecture, frontend-architecture, backend-architecture,
│   │      api-spec, api-spec-consumer, data-model, screens-overview, test-strategy
├── agents/                               ← 8건 (implementer, spec-reviewer, code-reviewer, plan-reviewer, design-reviewer, red-team, blue-team, auditor)
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
│       └── init-project.sh              ← /init-project 오케스트레이터 (10 phase)
└── README.md
```

> `layer:` 필드 (각 SKILL.md frontmatter)로 Engine/Harness 구분 보존.

---

## 거버넌스 엔진

`hooks/rules.jsonl`에 정의된 6 규칙 중 R-1·R-2 는 PreToolUse 사전 차단(verify 누락 시 commit/PR deny, v1.14.0 신설), R-1~R-5 는 PostToolUse + Stop 훅으로 감사 검사됩니다 (R-6 은 `enabled: false` — gbrain-ko manual-only 설계).

| Rule | 원칙 | 감지 조건 |
|---|---|---|
| R-1 | 5 (검증) | git commit 전 verifying-evidence-ko 미호출 |
| R-2 | 5 (검증) | gh pr create 전 verifying-evidence-ko 미호출 |
| R-3 | 1 (투명성) | specops-ko 스킬 호출 전 "Using ..." 선언 부재 |
| R-4 | 5 (검증) | 성공 주장 있으나 테스트 러너 미실행 |
| R-5 | 1 (투명성) | plan.md 수정 시 Advisor 협의 기록 섹션 누락 |
| R-6 | 1 (투명성) | `/verify` + evidence.md 후 gbrain-append 호출 부재 — **비활성** (gbrain-ko manual-only 설계, `enabled: false`) |

위반 시 `.specops/<FID>/friction-log.jsonl`에 자동 기록 (Soft Warn).

---

## 검증 현황

- **Lifecycle dogfood**: 5회 완주 (csv-lines · slug-cli · cvt-cli · b64-cli · hex-cli)
- **거버넌스 테스트**: `bash scripts/tests/governance/test-rules.sh` → 전 항목 PASS (R-1~R-6)
- **DAG 파서 테스트**: `bash scripts/tests/dag/test-parse-dag.sh` → 전 항목 PASS
- **전체 테스트**: `bash scripts/tests/run-all.sh` → 전체 suite PASS (릴리즈 pre-flight 게이트)
- **거버넌스 성능**: p95 69ms / median 67ms (AC-8 < 200ms 충족)

---

*초기화: 2026-04-21 · PoC Gold PASS: 2026-04-22 · v1.0.0 릴리즈: 2026-04-26 · **최신: v1.74.0 (2026-08-13)** · Claude Code 전용*
