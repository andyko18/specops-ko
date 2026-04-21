# specops-auto-ko

**한국어 자율 Lifecycle Claude Code 플러그인** (v0.0 PoC · Phase 1 완료).

## 목적

Superpowers 메인 + ECC/Spec-Kit/Harness 보조. 슬래시 1회(`/start`) 또는 자연어 진입 후 **메타 skill이 단계·skill을 자동 chain**. specops-ko v0.2 자산 fork 베이스.

자세한 설계: `~/Project/0.Claude/specops-ko/docs/case-studies/2026-04-21-specops-auto-ko-design.md §15` (채택본).

## 현재 상태 — v0.0 PoC · Phase 1 구축 완료

검증 대상: **Superpowers 메타 skill 패턴이 Claude Code 플러그인 컨텍스트에서 자동 활성되는지**.

### 자산

```
specops-auto-ko/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── commands/
│   └── start.md                      ← 단일 진입 슬래시
├── hooks/
│   ├── hooks.json                    ← SessionStart + Stop 매니페스트
│   ├── context-reset.sh              ← 세션 진입 맥락 복원
│   ├── ensure-session-progress.sh    ← session-progress.md 보장
│   ├── rotate-evaluator-artifact.sh  ← 산출물 회전
│   ├── log-subagent-calls.sh         ← 서브에이전트 감사 로그
│   └── inject-evaluator-timestamp.sh ← timestamp 자동 주입
├── skills/
│   ├── harness/  (6건)
│   │   ├── using-specops-auto-ko-ko.md   ← 메타 skill (자동 활성)
│   │   ├── structured-artifacts-ko.md
│   │   ├── sprint-contracts-ko.md
│   │   ├── generator-evaluator-ko.md
│   │   ├── context-resets-ko.md
│   │   └── file-based-communication-ko.md
│   └── engine/  (10건 — Lifecycle 8단계 chain)
│       ├── specifying-ko.md           ← Superpowers brainstorming fork
│       ├── clarifying-ko.md           ← 신규 (Spec-Kit clarify 양식)
│       ├── planning-ko.md             ← Superpowers writing-plans fork
│       ├── decomposing-ko.md          ← 신규 (Spec-Kit tasks 양식)
│       ├── implementing-ko.md         ← Superpowers subagent-driven-development fork
│       ├── tdd-ko.md                  ← Superpowers test-driven-development fork
│       ├── verifying-evidence-ko.md   ← Superpowers verification-before-completion fork
│       ├── requesting-code-review-ko.md ← Superpowers requesting-code-review fork
│       ├── receiving-code-review-ko.md  ← Superpowers receiving-code-review fork
│       └── systematic-debugging-ko.md   ← Superpowers systematic-debugging fork (분기 호출)
├── templates/  (6건 — specops-ko 경유 Spec-Kit 양식)
├── scripts/  (5건 + tests/)
├── docs/
└── README.md
```

### Lifecycle chain

```
/start <기능>  (또는 자연어 "X 만들어줘")
    ↓
using-specops-auto-ko-ko (메타 · 자동 활성)
    ↓
engine/specifying-ko  — spec.md + acceptance-criteria.md
    ↓ HARD GATE
engine/clarifying-ko  — clarifications.md
    ↓ HARD GATE
engine/planning-ko    — plan.md
    ↓
engine/decomposing-ko — tasks.md
    ↓
engine/implementing-ko  ←─── (분기) engine/systematic-debugging-ko
    │ · 태스크별 fresh 서브에이전트
    │ · 2단계 리뷰 (스펙 준수 → 코드 품질)
    │ · 각 서브에이전트는 engine/tdd-ko 준수
    ↓
engine/verifying-evidence-ko  — evidence.md
    ↓
engine/requesting-code-review-ko
    ↓
engine/receiving-code-review-ko
    ↓
"PR 생성? [y/n]"
```

각 engine skill 본문 말미 `## 다음 skill` 섹션이 chain을 강제. Conductor 에이전트 없음.

### upstream 직접 차용 방침

| 자산 | 1차 · upstream | 2차 · specops-ko 한국어 선례 |
|---|---|---|
| harness/using-specops-auto-ko-ko | `obra/superpowers@v5.0.7 skills/using-superpowers/` | — |
| engine/specifying-ko | `obra/superpowers@v5.0.7 skills/brainstorming/` | `brainstorming-ko.md` |
| engine/planning-ko | `obra/superpowers@v5.0.7 skills/writing-plans/` | `writing-plans-ko.md` |
| engine/implementing-ko | `obra/superpowers@v5.0.7 skills/subagent-driven-development/` (+ 3 prompts) | `subagent-driven-development-ko.md` |
| engine/tdd-ko | `obra/superpowers@v5.0.7 skills/test-driven-development/` + `affaan-m/ECC skills/tdd-workflow/` | `tdd-ko.md` |
| engine/verifying-evidence-ko | `obra/superpowers@v5.0.7 skills/verification-before-completion/` + `affaan-m/ECC skills/verification-loop/` | `verifying-evidence-ko.md` |
| engine/receiving/requesting-code-review-ko | `obra/superpowers@v5.0.7 skills/{receiving,requesting}-code-review/` | 동명 한국어본 |
| engine/systematic-debugging-ko | `obra/superpowers@v5.0.7 skills/systematic-debugging/` | `systematic-debugging-ko.md` |
| engine/clarifying-ko · decomposing-ko | 신규 (Spec-Kit `commands/{clarify,tasks}.md` specops-ko 경유) | `commands/{clarify,tasks}.md` |
| commands/start | `obra/superpowers commands/brainstorm.md` · `affaan-m/ECC commands/orchestrate.md` | — |
| hooks · templates · scripts | — | `specops-ko {hooks,templates,scripts}/` |

각 skill frontmatter `reference_upstream:`에 위 경로가 **1차 upstream + 2차 specops-ko 선례** 순으로 병기돼 있다.

### PoC 검증 절차

```bash
# 1. 마켓플레이스 등록
claude plugin marketplace add ~/Project/0.Claude/specops-auto-ko

# 2. 플러그인 설치
claude plugin install specops-auto-ko@specops-auto-ko-local

# 3. Claude Code 재시작

# 4. 신규 빈 프로젝트에서 검증 (2 시나리오 모두 PASS 필요):
cd "$(mktemp -d)" && claude

#    (a) 자연어 "안녕" → 메타 skill 자동 활성 + 신호 감지 NO → 일반 응답
#    (b) 자연어 "CSV 줄 수 세기 CLI 만들어줘" → 메타 skill 활성 + 신호 YES → engine/specifying-ko 호출

# 5. 슬래시 진입 smoke (자연어 PoC 결과와 무관):
/start CSV 줄 수 세기 CLI

# 기대: engine/specifying-ko 호출 → spec.md 템플릿 진입 → HARD GATE 대기
```

### PoC 결과 → 다음 단계

- **2/2 PASS**: 현재 구조 유지. Phase 2 (dogfood) 진입
- **1/2 또는 0/2 PASS**: `skills/harness/using-specops-auto-ko-ko.md`의 **PoC 실패 시 Fallback** 섹션 diff 적용 후 재commit

## 다음 단계

**Phase 2 (dogfood)**: 실제 기능 하나(예: `cowsay-ko` CLI)를 specops-auto-ko Lifecycle로 빌드해 chain 무결성·GATE 동작·서브에이전트 dispatch 검증.

**Phase 3 (v0.1)**:
- ECC `autonomous-loops` 흡수 (Sequential Pipeline · De-Sloppify)
- `pre:governance-capture` hook — 5원칙 위반 자동 기록
- Superpowers `writing-skills`·`executing-plans`·`finishing-a-development-branch` 선별 흡수
- `github/spec-kit` 직접 clone (§15.7 미확정 항목 해소 후)

## 참조

- 설계 case-study: `~/Project/0.Claude/specops-ko/docs/case-studies/2026-04-21-specops-auto-ko-design.md §15`
- 원본 메타 skill: `obra/superpowers@v5.0.7 skills/using-superpowers/SKILL.md`
- 로컬 upstream 캐시:
  - Superpowers: `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/`
  - ECC: `~/.claude/plugins/cache/everything-claude-code/everything-claude-code/1.2.0/`
- specops-ko: `~/Project/0.Claude/specops-ko/`

---

*초기화: 2026-04-21 · v0.0 PoC · Phase 1 완료 · 사용자 PoC 검증 대기*
