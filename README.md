# specops-auto-ko

**한국어 자율 Lifecycle Claude Code 플러그인** (v0.1.0 · v0.0 PoC **Gold PASS** · dogfood FRICTION-LOG F-11~F-15 흡수).

## 목적

Superpowers 메인 + ECC/Spec-Kit/Harness 보조. 슬래시 1회(`/start`) 또는 자연어 진입 후 **메타 skill이 단계·skill을 자동 chain**. specops-ko v0.2 자산 fork 베이스.

자세한 설계: `~/Project/0.Claude/specops-ko/docs/case-studies/2026-04-21-specops-auto-ko-design.md §15` (채택본).

## 현재 상태 — v0.1.0 release (v0.0 PoC Gold PASS 계승)

dogfood (`~/Project/0.Claude/dogfood-demo` FID `20260422-csv-lines`) 에서 자연어 `CSV 줄 수 세기 CLI 만들어줘` 진입으로 **9 단계 엔드투엔드 완주**. Lifecycle skill 전부 Skill 도구로 자동 chain 호출 (Conductor 에이전트 없이), `implementing-ko` 는 Task 도구로 서브에이전트 dispatch. 최종 외부 리뷰 `READY_TO_MERGE` 판정. 상세 증거: `docs/case-studies/2026-04-22-specops-auto-ko-v0.0-poc-pass.md`.

| 구성요소 | 증거 |
|---|---|
| 메타 skill 자동 주입 | SessionStart `<EXTREMELY_IMPORTANT>` 블록 + 5원칙 인용 |
| skill chain (7 회) | clarifying · planning · decomposing · implementing · verifying-evidence · requesting-code-review · receiving-code-review |
| subagent dispatch (5 회) | backend-dev × 1 + code-reviewer Phase B/C + external = 5 Task 박스 |
| TDD 5스텝 | 5 feat 커밋 + 테스트 9/9 PASS |
| 2단계 리뷰 | 스펙 COMPLIANT · 코드 APPROVED |
| 외부 리뷰 | READY_TO_MERGE (Critical/Important 0) |
| commit trailer | 12 커밋 전부 Constraint · Rejected · Directive 포함 |

**도출된 Phase 3 v0.1 백로그** (FRICTION-LOG F-11~F-14 근거):
- **P0** clarify 기본 필수 고정 · implementing-ko "TDD 체인 집약 dispatch" ESCAPE HATCH 명시
- **P1** specifying-ko NFR 실측 우선 가이드
- **P2** 짝 아티팩트 교차 리뷰 패턴 문서화

### 진화 경로 (커밋 히스토리)

- `de3cdd7` Phase 1 — Lifecycle skill 골격 (flat `.md` 배치)
- `e8816e4` validator v0.0 baseline 정렬
- `433a624` **P1 구조 표준화** + SessionStart 자동 주입 (16 skill 을 `skills/<name>/SKILL.md` 로 평탄화, Superpowers 동일 경로 이식)
- `b664592` **B-1** — `/start` 인자 내용 2차 판단 금지 (command Source of Truth 단일화)
- `1146fc1` PoC PASS case study
- `fb8c2b1` **v0.1** F-11 clarify 기본 필수 고정
- `4602fb2` **v0.1** F-12 implementing-ko TDD 체인 집약 dispatch ESCAPE HATCH
- `f9138ff` **v0.1** F-13·F-15 specifying-ko NFR 실측 가이드 + 질문 상한
- `ed87089` **v0.1** F-14 pair-artifact cross-review pattern 문서화

### 자동 활성 메커니즘

`hooks/session-start.sh` 가 SessionStart 시점에 `skills/using-specops-auto-ko-ko/SKILL.md` 본문 전체를 JSON `additionalContext` 로 주입 → Claude Code 가 `<EXTREMELY_IMPORTANT>` 블록으로 세션 컨텍스트에 첨부. 이는 `obra/superpowers@v5.0.7 hooks/session-start` 의 이식이며 Superpowers 와 동일한 자동 활성 경로를 공유한다.

### 자산

```
specops-auto-ko/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── commands/
│   └── start.md                          ← 단일 진입 슬래시
├── hooks/
│   ├── hooks.json                        ← SessionStart + Stop 매니페스트
│   ├── session-start.sh                  ← 메타 skill 자동 주입 + session-progress rehydrate
│   ├── ensure-session-progress.sh        ← session-progress.md 보장
│   ├── rotate-evaluator-artifact.sh      ← 산출물 회전
│   ├── log-subagent-calls.sh             ← 서브에이전트 감사 로그
│   └── inject-evaluator-timestamp.sh     ← timestamp 자동 주입
├── skills/                               ← flat: skills/<name>/SKILL.md × 16
│   ├── using-specops-auto-ko-ko/         ← 메타 skill (session-start.sh 로 자동 주입)
│   ├── structured-artifacts-ko/
│   ├── sprint-contracts-ko/
│   ├── generator-evaluator-ko/
│   ├── context-resets-ko/
│   ├── file-based-communication-ko/
│   ├── specifying-ko/                    ← Superpowers brainstorming fork
│   ├── clarifying-ko/                    ← 신규 (Spec-Kit clarify 양식)
│   ├── planning-ko/                      ← Superpowers writing-plans fork
│   ├── decomposing-ko/                   ← 신규 (Spec-Kit tasks 양식)
│   ├── implementing-ko/                  ← Superpowers subagent-driven-development fork
│   ├── tdd-ko/                           ← Superpowers test-driven-development fork
│   ├── verifying-evidence-ko/            ← Superpowers verification-before-completion fork
│   ├── requesting-code-review-ko/        ← Superpowers requesting-code-review fork
│   ├── receiving-code-review-ko/         ← Superpowers receiving-code-review fork
│   └── systematic-debugging-ko/          ← Superpowers systematic-debugging fork (분기 호출)
├── templates/  (6건 — specops-ko 경유 Spec-Kit 양식)
├── scripts/  (5건 + tests/)
├── docs/
└── README.md
```

harness / engine 의 논리적 구분은 각 SKILL.md frontmatter 의 `layer:` 필드로 보존한다 (디렉토리로는 평평화).

### Lifecycle chain

```
/start <기능>  (또는 자연어 "X 만들어줘")
    ↓
specops-auto-ko:using-specops-auto-ko-ko (메타 · SessionStart 자동 주입)
    ↓
specops-auto-ko:specifying-ko   — spec.md + acceptance-criteria.md
    ↓ HARD GATE
specops-auto-ko:clarifying-ko   — clarifications.md
    ↓ HARD GATE
specops-auto-ko:planning-ko     — plan.md
    ↓
specops-auto-ko:decomposing-ko  — tasks.md
    ↓
specops-auto-ko:implementing-ko ←─── (분기) specops-auto-ko:systematic-debugging-ko
    │ · 태스크별 fresh 서브에이전트
    │ · 2단계 리뷰 (스펙 준수 → 코드 품질)
    │ · 각 서브에이전트는 specops-auto-ko:tdd-ko 준수
    ↓
specops-auto-ko:verifying-evidence-ko   — evidence.md
    ↓
specops-auto-ko:requesting-code-review-ko
    ↓
specops-auto-ko:receiving-code-review-ko
    ↓
"PR 생성? [y/n]"
```

각 skill 본문 말미 `## 다음 skill` 섹션이 chain 을 강제. Conductor 에이전트 없음.

### upstream 직접 차용 방침

| 자산 | 1차 · upstream | 2차 · specops-ko 한국어 선례 |
|---|---|---|
| using-specops-auto-ko-ko | `obra/superpowers@v5.0.7 skills/using-superpowers/` | — |
| hooks/session-start.sh   | `obra/superpowers@v5.0.7 hooks/session-start`      | — |
| specifying-ko            | `obra/superpowers@v5.0.7 skills/brainstorming/`    | `brainstorming-ko.md` |
| planning-ko              | `obra/superpowers@v5.0.7 skills/writing-plans/`    | `writing-plans-ko.md` |
| implementing-ko          | `obra/superpowers@v5.0.7 skills/subagent-driven-development/` (+ 3 prompts) | `subagent-driven-development-ko.md` |
| tdd-ko                   | `obra/superpowers@v5.0.7 skills/test-driven-development/` + `affaan-m/ECC skills/tdd-workflow/` | `tdd-ko.md` |
| verifying-evidence-ko    | `obra/superpowers@v5.0.7 skills/verification-before-completion/` + `affaan-m/ECC skills/verification-loop/` | `verifying-evidence-ko.md` |
| receiving/requesting-code-review-ko | `obra/superpowers@v5.0.7 skills/{receiving,requesting}-code-review/` | 동명 한국어본 |
| systematic-debugging-ko  | `obra/superpowers@v5.0.7 skills/systematic-debugging/` | `systematic-debugging-ko.md` |
| clarifying-ko · decomposing-ko | 신규 (Spec-Kit `commands/{clarify,tasks}.md` specops-ko 경유) | `commands/{clarify,tasks}.md` |
| commands/start           | `obra/superpowers commands/brainstorm.md` · `affaan-m/ECC commands/orchestrate.md` | — |
| hooks · templates · scripts | — | `specops-ko {hooks,templates,scripts}/` |

각 skill frontmatter `reference_upstream:` 에 위 경로가 **1차 upstream + 2차 specops-ko 선례** 순으로 병기돼 있다.

### PoC 검증 절차 (아카이브 — 2026-04-22 PASS)

```bash
# 1. 마켓플레이스 등록 (1회)
claude plugin marketplace add ~/Project/0.Claude/specops-auto-ko

# 2. 플러그인 설치 / 갱신
claude plugin marketplace update specops-auto-ko-local

# 3. Claude Code 재시작

# 4. 신규 빈 프로젝트에서 검증:
cd "$(mktemp -d)" && claude
#    자연어 "CSV 줄 수 세기 CLI 만들어줘" → Lifecycle 자동 진입

# 5. 또는 슬래시 진입:
/start <기능 설명>
```

PoC 판정 기준 및 실측 결과는 `docs/case-studies/2026-04-22-specops-auto-ko-v0.0-poc-pass.md` 참조.

## 완료한 기능

### pre:governance-capture hook — `20260424-governance-capture`

- PostToolUse + Stop hook 2 종, 외부 `hooks/rules.jsonl` 기반 5 시드 룰 (R-1~R-5)
- 원칙 1 (투명성) · 원칙 5 (한계 고백) 위반 자동 감지 → `.specops/<FID>/friction-log.jsonl` append (FID 미감지 시 `.specops/friction-log.jsonl` 전역 fallback)
- Soft Warn (`additionalContext`) 만 사용, Hard Block 미사용
- 성능 실측 p95 69ms / median 67ms (macOS bash 3.2.57 · jq 1.7, AC-8 < 200ms 충족)
- bats 미사용 · 기존 bash `PASS=0; FAIL=0` 테스트 컨벤션 준수
- 세부 설계: `.specops/20260424-governance-capture/` (spec / clarifications / plan / tasks / dispatch-log)

## 다음 단계

**Phase 2 (dogfood) — 완료** (`20260422-csv-lines`). csv-lines CLI 로 Lifecycle 전 9 단계 실사용 검증 통과.

**Phase 3 (v0.1) — 백로그 (실측 근거 우선)**:
- **P0** F-11 clarify 기본 필수 고정 — `skills/clarifying-ko/SKILL.md` + `skills/using-specops-auto-ko-ko/SKILL.md`
- **P0** F-12 implementing-ko "TDD 체인 집약 dispatch" ESCAPE HATCH 조항 — `skills/implementing-ko/SKILL.md`
- **P1** F-13 specifying-ko NFR 실측 우선 가이드 — `skills/specifying-ko/SKILL.md`
- **P2** F-14 짝 아티팩트 교차 리뷰 패턴 문서화 — `docs/patterns/`
- (기존 예정) ECC `autonomous-loops` 흡수 (Sequential Pipeline · De-Sloppify)
- (기존 예정) Superpowers `writing-skills` · `executing-plans` · `finishing-a-development-branch` 선별 흡수
- (기존 예정) `github/spec-kit` 직접 clone (§15.7 미확정 항목 해소 후)

## 참조

- 설계 case-study: `~/Project/0.Claude/specops-ko/docs/case-studies/2026-04-21-specops-auto-ko-design.md §15`
- 원본 메타 skill: `obra/superpowers@v5.0.7 skills/using-superpowers/SKILL.md`
- 원본 SessionStart hook: `obra/superpowers@v5.0.7 hooks/session-start`
- 로컬 upstream 캐시:
  - Superpowers: `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/`
  - ECC: `~/.claude/plugins/cache/everything-claude-code/everything-claude-code/1.2.0/`
- specops-ko: `~/Project/0.Claude/specops-ko/`

---

*초기화: 2026-04-21 · P1 구조 표준화: 2026-04-22 · **v0.0 PoC Gold PASS: 2026-04-22** · Phase 2 dogfood 완료 · Phase 3 v0.1 백로그 확정*
