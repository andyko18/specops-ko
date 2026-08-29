# specops-ko

**Claude Code 전용 한국어 자율 Lifecycle 플러그인** (v1.87.0)

슬래시 1회 또는 자연어 1회로 **spec → clarify → plan → decompose → TDD implement → verify → review → security → integration-test → performance-test → PR** 전 단계를 자동으로 이어서 진행한다.
한글로는 **명세 → 명확화 → 계획 → 분해 → TDD 구현 → 검증 → 리뷰 → 보안 → 통합 테스트 → 성능 테스트 → PR** 이다.

- **자율 chain** — 각 스킬 본문의 `## 다음 skill` 이 다음 단계를 강제한다. 단계마다 지시할 필요가 없다.
- **파일이 기억한다** — 모든 산출물은 `.specops/<FID>/` 에 남는다. 세션이 끊겨도 파일만 읽고 이어간다.
- **주장은 증거로만** — verify 없이 `git commit`·`gh pr create` 하면 훅이 실행 전에 차단한다.

> **도입을 검토 중이라면** → [docs/architecture.md](docs/architecture.md) — 무엇을 보장하고, **어떤 장치로** 보장하며, 무엇을 보장하지 **않는지**를 실측 수치와 함께 정리했다.

---

## 설치

```bash
# 1) 의존성 marketplace 선행 등록 (필수 — 없으면 설치 실패)
claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill

# 2) 설치
claude plugin marketplace add andyko18/specops-ko
claude plugin install specops-ko@specops-ko

# 3) 확인
/doctor
```

로컬 개발은 `claude plugin marketplace add /절대경로/specops-ko`.

---

## 빠른 시작

```bash
/init-project 재고관리          # 새 프로젝트 — 표준 문서 13종 부트스트랩 (1회)
/start-foundation "라우팅·인증"  # 공통 인프라 먼저 (선택, 1회)
/start "CSV 줄 수 세기 CLI"      # 기능 1건 구현
/maintain "auth.js 토큰 만료"    # 기존 코드 수정
/status                         # 지금 어디까지 왔나
```

자연어로 해도 된다 — "CSV 줄 수 세기 CLI 만들어줘" 처럼 쓰면 메타 스킬이 신호를 감지해 라우팅한다.

---

## 진입로

| 슬래시 | 용도 |
|---|---|
| `/init-project` | 프로젝트 초기화 — 표준 산출물 13종 부트스트랩 (1회) |
| `/start-foundation` | 공통부(라우팅·인증·레이아웃·공통 스키마) 먼저 개발 (1회) |
| `/start` | 신규 기능 1건 — 표준 경로 (대화형) |
| `/start-lite` | 신규 기능 경량 — clarify·plan 생략, 화면/IF·리뷰·verify 유지 |
| `/start-auto` | 신규 기능 무인 — 가역 게이트 자동 통과, PR만 확인 |
| `/start-all` · `/start-all-auto` | `requirements.md` FR 표 전체 일괄 구현 |
| `/maintain` · `/maintain-lite` | 기존 코드 수정 — 영향 분석 선행 + 회귀 AC 강제 |
| `/brainstorming` | (선택) 구현 전 아이디어 탐색 |
| `/design-screen(s)` · `/design-interface(s)` | lifecycle 밖 화면·인터페이스 단발 설계 |

**어느 걸 고를까**

```
새 프로젝트?  → /init-project → (필요 시) /start-foundation → /start-all 또는 기능마다 /start
기존 코드를 고치나?
  ├─ 아니오 (새 산출물) → /start        (무인: /start-auto · 경량: /start-lite)
  └─ 예   (수정·제거)   → /maintain     (경량: /maintain-lite)
```

> `-lite` 는 슬래시로만 진입한다. 자연어 "가볍게 해줘"를 lite 로 추론하지 않는다.

**공통부 · 일괄 진입 주의**

- `/start-all` 전 UI/BE/풀스택은 `.specops/memory/foundation-manifest.md` 필수 (Phase 0 HARD — 없으면 재사용 게이트가 침묵 SKIP)
- foundation 브랜치는 main 머지 후에 `/start-all` (`check-foundation-merged`)
- foundation IF 는 `foundation-baseline`, UI 셸은 `foundation-shell` 마커 — Phase 2.5 는 마커 밖만 건드린다
- `/start-all` 의 `queue.md` 는 `init-batch-queue.sh --classify` 가 기계 작성한다 (재개 시 재사용)
- `[공통]` FR 은 `/start-all` 에서 SKIP — 구현은 `/start-foundation` 담당

---

## Lifecycle

```
/start <기능>  ·  /maintain <대상>  ·  자연어
    ↓
using-specops-ko (메타)            신호 감지 → 신규 / 유지보수 분류
    ↓
analyzing-ko (분석)                current-state.md · impact-analysis.md      [유지보수만] ★ HARD GATE
    ↓
specifying-ko (명세)               spec.md · acceptance-criteria.md
    │                              └ 화면 설계(screens/*.md+html) · 인터페이스 설계(api-spec·data-model)
    ↓ ★ HARD GATE (승인)
clarifying-ko (명확화)             clarifications.md
    ↓ ★ HARD GATE
planning-ko (계획)                 plan.md   ← plan-reviewer-ko (플랜 리뷰)
    ↓
decomposing-ko (분해)              tasks.md + YAML DAG
    ↓
implementing-ko (구현)             태스크별 fresh dispatch · DAG 병렬
    │                              Phase B — spec-reviewer-ko (스펙 준수 리뷰)
    │                              Phase C — code-reviewer-ko (코드 품질·보안 리뷰)
    ↓
verifying-evidence-ko (검증)       evidence.md
    ↓
requesting-code-review-ko (리뷰 요청) → receiving-code-review-ko (리뷰 수용)
    ↓
security-review-ko (보안) → integration-test-ko (통합 테스트) → performance-test-ko (성능 테스트)
    │                       (해당 표면 없으면 graceful skip)
    ↓
"PR 생성? [y/n]" → finishing-a-development-branch-ko (브랜치 정리)
```

**HARD GATE** 는 되돌리기 비싼 지점(analyzing 분석 · specifying 명세 승인 · clarifying 명확화 · planning 계획 · PR)에서만 멈춘다. 나머지는 자동 통과한다.

**Generator ↔ Evaluator 분리** — 구현체(`implementer-ko`)와 평가자(`spec-reviewer-ko` · `code-reviewer-ko`)를 다른 서브에이전트로 나눠 자기평가 편향을 막는다. Evaluator 는 `role: evaluator` 로 Write/Edit 가 박탈된다. 기본 `review_mode: end-loaded` (FID 단위 B×1 + C×1), 레거시는 `per-task`.

---

## 산출물

FID 포맷은 `YYYYMMDD-kebab-slug`.

```
.specops/
├── memory/                  api-spec.md · data-model.md · foundation-manifest.md · learnings.jsonl
├── freelog.md               lifecycle 밖 자유작업 기록
└── <FID>/
    ├── spec.md · acceptance-criteria.md · clarifications.md · plan.md · tasks.md
    ├── current-state.md · impact-analysis.md      (유지보수 진입 시)
    ├── dispatch/ · reviews/ · evidence.md
    ├── session-progress.md                        (재개용)
    └── friction-log.jsonl                         (거버넌스 위반 기록)
```

---

## 거버넌스 엔진

훅이 규칙을 강제한다. **PreToolUse** 는 위반 도구 실행을 차단하고, **PostToolUse·Stop** 은 `friction-log.jsonl` 에 기록한다. **SessionStart** 는 메타 스킬 주입 + session-progress rehydrate 를 담당하며, 조립 순서 계약은 `anchor → freecomment-pending → reconcile → batch-resume → 메타 본문 → rehydrate` 다 (행동 지시 블록이 앞). `batch-resume` 는 조건부 — `ACTIVE` 마커가 남은 미완 batch 가 있을 때만 주입된다.

| Rule | 감지 조건 | 동작 |
|---|---|---|
| R-1 | `git commit` 전 verify 미호출 | 사전 차단 + 감사 |
| R-2 | `gh pr create` 전 verify 미호출 | 사전 차단 + 감사 |
| R-3 | 스킬 호출 전 "Using …" 선언 부재 | 감사 |
| R-4 | 성공 주장 + 테스트 러너 미실행 | 감사 (Stop) |
| R-5 | spec/plan 수정 + Advisor 협의 기록 누락 | 감사 (Stop) |
| R-6 | verify 후 gbrain-append 부재 | **비활성** (manual-only 설계) |

**실행-근거 gate** — verify 면제는 자기보고만으로 열리지 않는다. transcript 의 `tool_use ↔ tool_result` 를 join 해 러너가 실제로 `VERIFY: PASS` 를 출력했는지 확인한다.

**면제 4종** — `SPECOPS_GOVERNANCE_BYPASS=1`(+`SPECOPS_BYPASS_REASON` 필수) · docs/design-only 변경 · `.specops/` 부재(미사용 repo) · 판정 불가(fail-open).

---

## 운영 슬래시

| 슬래시 | 용도 |
|---|---|
| `/status` | 진행 중 FID 의 단계·아티팩트 현황 |
| `/doctor` | 설치·환경 건강 진단 8항목 (read-only) |
| `/gbrain` · `/log` | 세션 인사이트 조회 · 즉석 기록 |
| `/promote` | 자유작업 mini-FID 를 lifecycle 로 승격 |
| `/security-scan` | 온디맨드 SAST + DAST (`--self-config` 로 자기 번들 적대감사) |
| `/improve-arch` | deep module 기준 split/merge 권고 |
| `/e2e-test` | lifecycle 9단계 fixture 완주 검증 (수동, 토큰 비용) |
| `/release` · `/statusline-install` | 릴리즈 자동화 · HUD 상태줄 등록 |

---

## 자산 구조

```
specops-ko/
├── .claude-plugin/     plugin.json · marketplace.json
├── commands/           슬래시 진입로 24건
├── hooks/              SessionStart · PreToolUse · PostToolUse · Stop · Notification
│                       + rules.jsonl(규칙) · chain.yaml(chain edge 단일 SoT)
├── skills/             flat: skills/<name>/SKILL.md × 30
│                       layer 1 메타 · layer 2 Engine(lifecycle) · layer 3 Harness(원칙)
├── agents/             ← 8건  implementer · spec-reviewer · code-reviewer · plan-reviewer
│                              design-reviewer · red-team · blue-team · auditor
├── templates/          ← 34건 (lifecycle 19 + /init-project 산출 13 + 기타)
├── scripts/            doctor · release · gbrain · security-scan · dag/ · tests/ · _internal/
├── docs/               설계 노트 · 갭 분석 · upstream drift log
└── CLAUDE.md · DESIGN.md · CONTRIBUTING.md · CHANGELOG.md
```

내부 규약 상세(chain SoT · 분기 마커 · frontmatter 필수 필드 · design-first 대칭)는 [CLAUDE.md](CLAUDE.md), 설계 근거·한계·규모 실측은 [docs/architecture.md](docs/architecture.md) 참조.

---

## 개발 · 테스트

> **clone 마다 1회**: `bash scripts/_internal/install-git-hooks.sh` — pre-commit(구조 검증 ~5s) + pre-push(전체 테스트 ~330s) 게이트 설치.

```bash
bash scripts/tests/run-all.sh                    # 전체 (릴리즈 pre-flight 게이트와 동일)
bash scripts/_internal/validate-structure.sh     # 구조 무결성
bash scripts/tests/governance/test-rules.sh      # 거버넌스 R-1~R-6
bash scripts/tests/dag/test-parse-dag.sh         # DAG 파서
bash scripts/tests/llm-eval/run-evals.sh         # LLM smoke (수동, 토큰 비용)
```

**검증 현황** — lifecycle dogfood 5회 완주 · 전체 suite PASS · 거버넌스 p95 69ms (AC-8 < 200ms).
테스트 24,114줄 / 운영 스크립트 9,330줄 = **2.6 : 1** · mutation score 60% (기준 55%) · 구조 검사기 22종.

---

## 트러블슈팅

| 증상 | 조치 |
|---|---|
| 설치가 `cross-marketplace` 에러 | `ui-ux-pro-max-skill` marketplace 선행 등록 |
| commit 이 verify 누락으로 deny | 정상(R-1). verify 실행 후 재시도. 불가피하면 `SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON='<사유>'` |
| `file_counts FAIL` | `validate-structure.sh --update-baseline` |
| `version_sync` · `readme_counts FAIL` | README 헤더/footer 버전, 자산 구조 카운트가 실측과 불일치 |
| `chain_consistency FAIL` | `chain.yaml` · SKILL.md `## 다음 skill` · 메타 스킬 목록 세 곳 동기 수정 |
| 어디까지 했는지 모름 | `/status` · 환경 이상은 `/doctor` |

---

*초기화: 2026-04-21 · v1.0.0 릴리즈: 2026-04-26 · **최신: v1.87.0 (2026-08-29)** · Claude Code 전용*
