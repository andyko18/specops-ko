# specops-auto-ko

**한국어 자율 Lifecycle Claude Code 플러그인** (v0.0 PoC · P1 구조 표준화 완료).

## 목적

Superpowers 메인 + ECC/Spec-Kit/Harness 보조. 슬래시 1회(`/start`) 또는 자연어 진입 후 **메타 skill이 단계·skill을 자동 chain**. specops-ko v0.2 자산 fork 베이스.

자세한 설계: `~/Project/0.Claude/specops-ko/docs/case-studies/2026-04-21-specops-auto-ko-design.md §15` (채택본).

## 현재 상태 — v0.0 PoC · P1 구조 표준화 완료

검증 대상: **Superpowers 메타 skill 패턴이 Claude Code 플러그인 컨텍스트에서 자동 활성되는지**.

**P1 진입 동기**: 초기 Phase 1 flat `.md` skill 배치는 Claude Code 2.1 의 skill discovery 규약(`skills/<name>/SKILL.md`)과 어긋나 메타 skill 이 available skills 목록에 노출되지 않았다. P1에서 전체 skill 을 표준 디렉토리 구조로 승격하고 `hooks/session-start.sh` 를 추가해 **Superpowers 와 동일 경로**로 자동 주입한다.

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

### PoC 검증 절차

```bash
# 1. 마켓플레이스 등록 (1회)
claude plugin marketplace add ~/Project/0.Claude/specops-auto-ko

# 2. 플러그인 설치 / 갱신
claude plugin marketplace update specops-auto-ko-local  # 또는 install specops-auto-ko@specops-auto-ko-local

# 3. Claude Code 재시작 (구조 변경을 discovery 에 반영하려면 필수)

# 4. 신규 빈 프로젝트에서 검증 (2 시나리오 모두 PASS 필요):
cd "$(mktemp -d)" && claude

#    (a) 자연어 "안녕" → 메타 skill 자동 활성 + 신호 감지 NO → 일반 응답
#    (b) 자연어 "CSV 줄 수 세기 CLI 만들어줘" → 메타 skill 활성 + 신호 YES → specops-auto-ko:specifying-ko 호출

# 5. 슬래시 진입 smoke (자연어 PoC 결과와 무관):
/start CSV 줄 수 세기 CLI

# 기대:
#   · session start 시 <EXTREMELY_IMPORTANT>specops-auto-ko 자율 Lifecycle 플러그인이 활성화돼 있다 ... </EXTREMELY_IMPORTANT> 블록 주입 확인
#   · specops-auto-ko:specifying-ko 호출 → spec.md 템플릿 진입 → HARD GATE 대기
```

### PoC 결과 → 다음 단계

- **2/2 PASS**: 구조 유지. Phase 2 (dogfood) 진입
- **1/2 또는 0/2 PASS**: `skills/using-specops-auto-ko-ko/SKILL.md` 의 **PoC 실패 시 Fallback** 섹션 diff 적용 후 재commit

## 다음 단계

**Phase 2 (dogfood)**: 실제 기능 하나(예: `cowsay-ko` CLI)를 specops-auto-ko Lifecycle 로 빌드해 chain 무결성·GATE 동작·서브에이전트 dispatch 검증.

**Phase 3 (v0.1)**:
- ECC `autonomous-loops` 흡수 (Sequential Pipeline · De-Sloppify)
- `pre:governance-capture` hook — 5원칙 위반 자동 기록
- Superpowers `writing-skills`·`executing-plans`·`finishing-a-development-branch` 선별 흡수
- `github/spec-kit` 직접 clone (§15.7 미확정 항목 해소 후)

## 참조

- 설계 case-study: `~/Project/0.Claude/specops-ko/docs/case-studies/2026-04-21-specops-auto-ko-design.md §15`
- 원본 메타 skill: `obra/superpowers@v5.0.7 skills/using-superpowers/SKILL.md`
- 원본 SessionStart hook: `obra/superpowers@v5.0.7 hooks/session-start`
- 로컬 upstream 캐시:
  - Superpowers: `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/`
  - ECC: `~/.claude/plugins/cache/everything-claude-code/everything-claude-code/1.2.0/`
- specops-ko: `~/Project/0.Claude/specops-ko/`

---

*초기화: 2026-04-21 · P1 구조 표준화: 2026-04-22 · v0.0 PoC · 사용자 검증 대기*
