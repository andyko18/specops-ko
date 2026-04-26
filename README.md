# specops-auto-ko

**Claude Code 전용 한국어 자율 Lifecycle 플러그인** (v1.0.0)

## Quick Start

```bash
# 1. 플러그인 설치 (1회)
claude plugin marketplace add ~/path/to/specops-auto-ko

# 2. 새 프로젝트에서 시작
/start <기능 설명>
# 예: /start "CSV 파일 줄 수 세기 CLI"
```

`/start` 1회로 **spec → clarify → plan → TDD implement → verify → review** 전 단계가 자동 체인됩니다. 각 단계를 수동으로 호출할 필요 없습니다.

---

## 목적

슬래시 1회 진입 후 **메타 스킬이 단계·스킬을 자동 chain**하는 한국어 자율 Lifecycle 플러그인.

- **자율 체인**: Conductor 에이전트 없이 각 스킬 본문 `## 다음 skill`이 다음 단계를 강제
- **거버넌스**: R-1~R-5 규칙 엔진이 매 도구 호출 후 원칙 위반을 자동 감지
- **AC 계약**: `acceptance-criteria.md`를 스프린트 계약서로 취급 — 평가자는 이것만 기준으로 판정
- **Generator/Evaluator 분리**: Phase B(스펙 준수)와 Phase C(코드 품질)를 별도 서브에이전트가 담당

---

## Lifecycle Chain

```
/start <기능>
    ↓
specops-auto-ko:using-specops-auto-ko-ko  (메타 · SessionStart 자동 주입)
    ↓
specops-auto-ko:specifying-ko     — spec.md + acceptance-criteria.md
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
"PR 생성? [y/n]"
```

---

## 자산 구조

```
specops-auto-ko/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── commands/
│   └── start.md                          ← 단일 진입 슬래시 /start
├── hooks/
│   ├── hooks.json                        ← SessionStart + PostToolUse + Stop 매니페스트
│   ├── session-start.sh                  ← 메타 스킬 자동 주입 + session-progress rehydrate
│   ├── posttool-governance.sh            ← 도구 호출 후 R-1~R-5 검사
│   ├── governance-lib.sh + rules.jsonl   ← 거버넌스 라이브러리 + 규칙 정의
│   ├── ensure-session-progress.sh        ← session-progress.md 보장
│   └── stop-governance.sh               ← 세션 종료 정리
├── skills/                               ← flat: skills/<name>/SKILL.md × 18
│   │
│   │  Engine Skills (Lifecycle 체인)
│   ├── using-specops-auto-ko-ko/         ← 메타 스킬 (SessionStart 자동 주입)
│   ├── specifying-ko/                    ← spec.md + AC 작성
│   ├── clarifying-ko/                    ← 모호성 해소
│   ├── planning-ko/                      ← 구현 플랜
│   ├── decomposing-ko/                   ← TDD 태스크 분해 + DAG
│   ├── implementing-ko/                  ← 서브에이전트 dispatch
│   ├── tdd-ko/                           ← TDD 5스텝 (서브에이전트용)
│   ├── verifying-evidence-ko/            ← 증거 기반 검증
│   ├── requesting-code-review-ko/        ← 코드 리뷰 요청
│   ├── receiving-code-review-ko/         ← 리뷰 피드백 수용
│   ├── systematic-debugging-ko/          ← BLOCKED 상태 복구
│   ├── dispatching-parallel-agents-ko/   ← DAG-aware 병렬 dispatch
│   ├── using-git-worktrees-ko/           ← 병렬 격리 (git worktree)
│   │
│   │  Harness Skills (아키텍처 원칙)
│   ├── sprint-contracts-ko/              ← AC를 계약으로
│   ├── structured-artifacts-ko/          ← .specops/<FID>/ 규약
│   ├── generator-evaluator-ko/           ← Phase B/C 분리 원칙
│   ├── context-resets-ko/                ← 서브에이전트 컨텍스트 격리
│   └── file-based-communication-ko/      ← 파일 기반 dispatch 패턴
├── templates/                            ← 7건 (spec, AC, plan, tasks, session-progress,
│                                            dispatch-context, test-conventions-bash)
├── agents/                               ← 3건 (implementer, spec-reviewer, code-reviewer)
├── scripts/
│   ├── session-progress-append.sh
│   ├── dag/                              ← DAG 파서 + 컨텍스트 검증
│   ├── tests/                            ← governance + dag 단위 테스트
│   └── _internal/                        ← 유지보수 도구 (validate-structure 등)
├── examples/                             ← dogfood CLI 예시 (epoch/hex/b64/cvt/slug)
└── README.md
```

> `layer:` 필드 (각 SKILL.md frontmatter)로 Engine/Harness 구분 보존.

---

## 거버넌스 엔진

`hooks/rules.jsonl`에 정의된 5 규칙이 PostToolUse + Stop 훅으로 자동 검사됩니다.

| Rule | 원칙 | 감지 조건 |
|---|---|---|
| R-1 | 5 (검증) | git commit 전 verifying-evidence-ko 미호출 |
| R-2 | 5 (검증) | gh pr create 전 verifying-evidence-ko 미호출 |
| R-3 | 1 (투명성) | specops-auto-ko 스킬 호출 전 "Using ..." 선언 부재 |
| R-4 | 5 (검증) | 성공 주장 있으나 테스트 러너 미실행 |
| R-5 | 1 (투명성) | plan.md 수정 시 Advisor 협의 기록 섹션 누락 |

위반 시 `.specops/<FID>/friction-log.jsonl`에 자동 기록 (Soft Warn).

---

## upstream 출처

| 스킬 | upstream |
|---|---|
| specifying-ko | `obra/superpowers@v5.0.7 skills/brainstorming/` |
| planning-ko | `obra/superpowers@v5.0.7 skills/writing-plans/` |
| implementing-ko | `obra/superpowers@v5.0.7 skills/subagent-driven-development/` |
| tdd-ko | `obra/superpowers@v5.0.7` + `affaan-m/ECC skills/tdd-workflow/` |
| verifying-evidence-ko | `obra/superpowers@v5.0.7` + `affaan-m/ECC skills/verification-loop/` |
| requesting/receiving-code-review-ko | `obra/superpowers@v5.0.7` |
| systematic-debugging-ko | `obra/superpowers@v5.0.7 skills/systematic-debugging/` |
| clarifying-ko · decomposing-ko | 신규 (Spec-Kit 양식) |
| harness 5종 | revfactory/harness + Anthropic 2025 harness 설계 |

---

## 검증 현황

- **Lifecycle dogfood**: 5회 완주 (csv-lines · slug-cli · cvt-cli · b64-cli · hex-cli)
- **거버넌스 테스트**: `bash scripts/tests/governance/test-rules.sh` → PASS=38 FAIL=0
- **DAG 파서 테스트**: `bash scripts/tests/dag/test-parse-dag.sh` → PASS=13 FAIL=0
- **거버넌스 성능**: p95 69ms / median 67ms (AC-8 < 200ms 충족)

---

*초기화: 2026-04-21 · PoC Gold PASS: 2026-04-22 · **v1.0.0 릴리즈: 2026-04-26** · Claude Code 전용*
