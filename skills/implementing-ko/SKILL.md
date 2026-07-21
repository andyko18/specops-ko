---
name: implementing-ko
description: 본 세션에서 구현 플랜을 태스크별로 실행할 때 사용 — 태스크별 fresh 서브에이전트 dispatch, 각 태스크마다 2단계 리뷰(스펙 준수 → 코드 품질)
layer: 2
reference_upstream: obra/superpowers@v5.0.7 skills/subagent-driven-development/SKILL.md
  - obra/superpowers@v5.0.7 skills/subagent-driven-development/SKILL.md
  - obra/superpowers@v5.0.7 skills/subagent-driven-development/implementer-prompt.md
  - obra/superpowers@v5.0.7 skills/subagent-driven-development/spec-reviewer-prompt.md
  - obra/superpowers@v5.0.7 skills/subagent-driven-development/code-quality-reviewer-prompt.md
  - specops-ko skills/engine/subagent-driven-development-ko.md
specops_version: 1.47.2
used_by: decomposing-ko (chain 진입), verifying-evidence-ko (chain 출구)
---

# Engine 스킬 — 서브에이전트 주도 구현 (implementing)

플랜을 태스크별 **fresh 서브에이전트** dispatch로 실행. 각 태스크 후 **2단계 리뷰**: 스펙 준수 리뷰 먼저, 그다음 코드 품질 리뷰.

**왜 서브에이전트**: 전문 에이전트에게 **격리된 컨텍스트**로 태스크를 위임. 지시와 컨텍스트를 **정확히** 조립해 집중·성공을 보장. 서브에이전트는 **당신 세션의 컨텍스트·히스토리를 절대 상속하지 않는다** — 필요한 것만 당신이 구성해 넘긴다. 이로써 당신의 컨텍스트도 코디네이션 용도로 보존된다.

**핵심 원칙**: 태스크별 fresh 서브에이전트 + 2단계 리뷰(스펙 → 품질) = **고품질 + 빠른 반복**.

## 설계 계약 준수 (design-first 후진 teeth)

사전 설계 산출물이 존재하면 구현은 이를 **계약**으로 준수한다 (specifying-ko 의 정방향 design-first 가 구현까지 이어지도록 — 화면·인터페이스 대칭):

- `screens/{name}.md`·`.html` — 화면 기능의 **UI 계약** (Step 5.5 산출)
- `.specops/memory/api-spec.md`·`api-spec-consumer.md`·`data-model.md` — **인터페이스(제공·소비)/스키마 계약** (Step 5.6 design-first · Phase 8g 산출)

`emit-context.sh`(decomposing Step 10b)가 설계 산출물(`api-spec.md`·`api-spec-consumer.md`·`data-model.md`·`screens/`) 존재 시 dispatch 컨텍스트의 **§6 설계 계약** 섹션에 경로를 **자동 포함**한다(Wave 2 배선 — 부재 시 §6 생략 graceful). 구현자는 §6 계약을 준수하고, 어긋나야 할 불가피한 근거가 있으면 **사용자 확인 후** 진행하며, `verifying-evidence-ko` 의 "memory 설계 동기화 점검"(역방향 안전망)이 사후 검증한다. (정방향 계약(§6 자동 emit) + 역방향 net 으로 design-first 의 전·후진 teeth 를 모두 확보)

## 사용 시점

```
구현 플랜 있음?
    ↓ yes
태스크 대체로 독립적?
    ↓ yes
본 세션에서 진행?
    ↓ yes
→ implementing-ko (본 스킬)
   단일 세션 내 독립 leaf 2+ → DAG-AWARE PARALLEL 분기 (v0.4a부터 지원)
   단일 leaf 또는 chain → SEQUENTIAL 분기

↓ no (다른 세션 병렬) → 별도 실행 흐름 (현재 미지원 — 본 세션 내 직렬 처리)
```

태스크가 밀접하게 결합돼 있으면 → decomposing-ko 복귀해 재분해.

## 프로세스 (다단계 wave — dag::find_ready 기반)

```
플랜 + tasks.md 1회 읽기 → TodoWrite 생성
    ↓
DAG 초기화 (bash "${CLAUDE_PLUGIN_ROOT}"/scripts/dag/parse-dag.sh)
    yaml=$(dag::extract_yaml .specops/<FID>/tasks.md)
    done=""   ← 완료 task id 집합 (공백 구분 문자열, 초기 빈)
    ↓
[WAVE LOOP] ─────────────────────────────────────────────────
ready=$(dag::find_ready "$yaml" $done)
    ↓
ready 비어 있음? → 전부 완료 → loop 종료
    ↓
ready 내 disjoint batch 선별 (dag::find_independent_batch 로직):
    batch ≥ 2 leaf + outputs disjoint?
    ├─ yes (병렬 분기) → DAG-AWARE PARALLEL ─────────────┐
    └─ no (단일 ready 또는 chain) → SEQUENTIAL          │
                                                          │
SEQUENTIAL 분기 (1 태스크씩):                            │
  ready 중 1개 선택:                                      │
    ┌─ 구현자 dispatch (implementer-ko)                   │
    │     ↓                                                │
    │  Phase B: spec-reviewer-ko dispatch                 │
    │     ↓                                                │
    │  Phase C: code-reviewer-ko dispatch                 │
    │     ↓                                                │
    └─ TodoWrite 완료 → done에 task-id 추가              │
    ↓                                                      │
→ WAVE LOOP 재진입 (find_ready(done) 로 다음 frontier)   │
                                                          │
DAG-AWARE PARALLEL 분기: ←────────────────────────────────┘
  각 batch leaf에 대해:
    - .specops/<FID>/dispatch/<task-id>-context.md 존재 확인
      (decomposing-ko Step 10b 에서 emit-context.sh 자동 산출)
    - bash "${CLAUDE_PLUGIN_ROOT}"/scripts/dag/validate-context.sh <path> — exit 0 확인
    - using-git-worktrees-ko 호출 — leaf별 worktree (.worktrees/<FID>-<task-id>/)
    ↓
  dispatching-parallel-agents-ko 호출 (DAG-aware 모드):
    - batch leaf id 배열 + context md path 배열 전달
    - 각 leaf Task 도구 병렬 호출 (단일 메시지 다중 tool_use)
    - 각 leaf: implementer-ko in worktree
    ↓
  결과 수집:
    - leaf NEEDS_CONTEXT 반환 시 → 컨텍스트 보강 후 재dispatch (R8)
    - leaf DONE 시 → proposed_commit_message 수집

  **Wave 2 (FID 20260514) — emit-context 자동 산출**: decomposing-ko Step 10b 가 `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/dag/emit-context.sh <FID>` 로 `.specops/<FID>/dispatch/<task-id>-context.md` 5섹션을 자동 산출하므로, 본 skill 의 컨텍스트 작성 단계는 §5 worktree 라인 sed 갱신만으로 축약된다. 컨텍스트 파일 부재 시 → decomposing-ko 재진입 요청 (HARD GATE).
    ↓
  Phase B (병렬): 각 leaf별 spec-reviewer-ko dispatch (병렬)
    ↓
  Phase C (병렬): 각 leaf별 code-reviewer-ko dispatch (Phase B PASS 후)
    ↓
  부모 머지 (R11 git race 차단):
    - 머지 순서: output count 적은 leaf 먼저
    - leaf staged diff 추출: `git -C .worktrees/<FID>-<task-id>/ diff --cached > /tmp/<task-id>.patch`
    - main worktree 이식: `git apply --index /tmp/<task-id>.patch` (충돌 시 abort → 에스컬레이션)
    - 부모가 commit (leaf 권한 박탈, R8) — fast-forward 불가 (leaf는 R8로 commit 없음)
    ↓
  부모 머지 완료 → done에 batch task-id 추가
    ↓
→ WAVE LOOP 재진입 (find_ready(done) 로 다음 wave frontier)
    ─────────────────────────────────────────────────────────
    ↓ ready 비어 있으면 (전부 완료)
최종 코드 리뷰어 (전체 구현) — 단, 태스크 수==1 이면 SKIP (per-task C 중복, E2)
    ↓
specops-auto-ko:verifying-evidence-ko 호출
```

**DAG 파싱 실패 fallback (advisor 협의 13:00)**: `dag::find_independent_batch` 가 빈 출력 + stderr WARN 반환 → SEQUENTIAL 분기로 자동 fallback. 강제 차단 안 함 (v0.4a; v0.4b strict mode 옵션 검토).

## F-12 ESCAPE HATCH 재정의 (v0.4a — 동일 파일 쌍 집약 vs DAG 병렬)

v0.4a DAG 자동 라우팅 도입 후 F-12 ESCAPE HATCH 의미가 정정됐다 (advisor 협의 13:00):

| 시나리오 | 처리 방식 | 근거 |
|---|---|---|
| **동일 파일 쌍 TDD 체인** (예: T1·T2 모두 `src/X.sh` + `tests/test-X.sh` 수정) | 구현자 1 dispatch 집약 (Phase A) + 별도 Phase B/C — **순차** | 동일 파일 = outputs overlap → DAG 가 자동으로 batch 형성 안 함 |
| **독립 leaf 2+** (출력 disjoint) | DAG-AWARE PARALLEL 분기 (v0.4a 신규) — **병렬** | dag::find_independent_batch 가 자동 식별 |
| **1 leaf + chain** | 기본 SEQUENTIAL 분기 — **순차** | 일반 케이스 |

**F-12 집약 조건** (동일 파일 쌍 시):

태스크 2 개 이상이 **동일 파일 쌍** (예: `src/X.sh` + `tests/test-X.sh`) 을 **순차 수정하는 TDD 체인** 이면 구현자 dispatch 를 **1 회로 집약**할 수 있다. 조건:

1. 각 태스크의 TDD 5 스텝 (RED → FAIL → GREEN → PASS → COMMIT) 을 **태스크 내부 embedded cycle** 로 구현자가 준수
2. 2 단계 리뷰 (Phase B 스펙 · Phase C 코드 품질) 는 **별도 리뷰어 dispatch 로 유지** — 집약 대상 아님
3. `dispatch-log.md` 에 집약 근거 (동일 파일 쌍 판정 · 태스크 LOC · TDD 사이클 구조) 명시 의무 (원칙 1 투명성)

**근거**: dogfood FID `20260422-csv-lines` 실측 — 5 태스크 전부 `csv-lines` + `tests/test-csv-lines.sh` 만 수정 · 총 40 LOC. 규약대로 15 dispatch 대신 3 dispatch (구현자 1 + 리뷰어 2) 로 집약해 27.1k 토큰 절감, Phase B/C 리뷰는 유지. `dispatch-log.md` Phase A/B/C 기록이 5 원칙 4 (주권) · 1 (투명성) 충족 증거 (FRICTION-LOG F-12).

**위 조건 불충족 시** 기본값 ("태스크별 fresh 서브에이전트 dispatch") 그대로 유지.

## 최종 리뷰 right-size — 단일 태스크 중복 제거 (E2, 20260718 경제성)

Wave loop 완료 후의 **최종 코드 리뷰어(전체 구현)** 는 **태스크 간 통합**(경계·교차 영향)을 검토하는 단계다. 그런데 **FID 의 태스크가 1개**(§유형=trivial 단축, 또는 단일 태스크로 분해된 경우)면 "전체 구현" = "그 1 태스크"이고, 이미 Phase C(`code-reviewer-ko`)가 그 태스크의 전체 산출물을 리뷰했다 → **최종 리뷰는 literal 중복**이므로 skip 한다.

- **게이트: 태스크 수 == 1 일 때만 skip** (기계적 — 판단 아님). **태스크 2개 이상이면 최종 리뷰 유지** — 태스크 간 통합·경계는 per-task C 가 못 보는 표면이라 중복이 아니다.
- **품질 손실 0**: 제거 대상은 동일 산출물의 **두 번째 리뷰**지 새로운 검토가 아니다. Phase B/C 자체는 **무변경**(Generator↔Evaluator 분리·스펙/품질 분리 불변).
- `dispatch-log.md` 에 `최종 리뷰 SKIP (단일 태스크 — Phase C 중복 제거, E2)` 기록 (F-12 와 동일 투명성 규약, 원칙 1).
- **주의**: 이건 **안전한 유일한 리뷰 축소**다. 멀티태스크 Phase B/C 를 줄이는 건 금지 — 그 리뷰가 실제 Critical(RBAC 권한상승 등)을 잡는 품질의 원천이다. 경제성은 중복 제거로만 얻고 품질 표면은 건드리지 않는다.

## Phase B/C 자동 재dispatch 정책 (Wave 2 U5)

| Phase | FAIL 시 동작 | 재dispatch subagent_type | cap | cap 초과 시 |
|---|---|---|---|---|
| B (spec-reviewer-ko FAIL) | reviewer feedback (`reviews/<task-id>-B-feedback.md`) 을 추가 컨텍스트로 1회 자동 재dispatch | `specops-auto-ko:implementer-ko` | task 당 1회 (B=1/2) | HARD GATE: `HARD-GATE: <task-id> Phase B cap 초과 — 사용자 결정 필요` |
| C (code-reviewer-ko FAIL) | reviewer feedback (`reviews/<task-id>-C-feedback.md`) 을 추가 컨텍스트로 1회 자동 재dispatch | `specops-auto-ko:implementer-ko` | task 당 1회 (C=1/2) | HARD GATE: `HARD-GATE: <task-id> Phase C cap 초과 — 사용자 결정 필요` |

**cap=2 (Phase별 독립)** — Phase B 최대 2회 시도 (`B=0/2` → `B=1/2` → `B=2/2 EXCEEDED`), Phase C 최대 2회 시도 (`C=0/2` → `C=1/2` → `C=2/2 EXCEEDED`). Phase B/C 는 각자 독립된 cap 을 가지며 공유하지 않는다. cap 초과 시 자동 진행 금지 — 사용자 입력 대기 (5원칙 4 주권).

## Evaluator 모델 불가 fallback (P1 — 20260718 test2 정주행 회고)

Phase B/C Evaluator(`spec-reviewer-ko`·`code-reviewer-ko`)는 `model: fable` 고정이다 — 리뷰어가 세션 모델과 무관하게 **강한 모델**을 쓰도록 보장하는 의도적 설계. 그런데 **fable 이 불가**(크레딧 소진·overload)해 Evaluator dispatch 가 실패하면 Generator↔Evaluator 분리가 위협받는다. **아래 순서를 강제**한다:

1. **같은 Evaluator 를 독립 서브에이전트로 재dispatch** 하되 **가용 모델을 override**(Agent 도구 `model` 인자로 세션 모델 등 지정, fable 아님). fresh 서브에이전트 = **부모와 분리된 컨텍스트**라 Generator↔Evaluator 불변식이 보존된다 — 독립성은 **모델 차이가 아니라 컨텍스트 분리**에서 온다.
2. **절대 부모 self-review 로 후퇴 금지** — 부모(생성자)가 자기 산출을 리뷰하면 Evaluator=Generator 편향(자기평가)이다. **test2 실측 근거**: 부모(opus) self-review 가 놓친 Critical(I-1 self-gate exit 마스킹)을 **독립 비-fable 리뷰어가 잡았다**. 즉 **독립-약한 모델 ≫ 편향-강한 모델**.
3. `dispatch-log.md` 에 degradation 명시: `Phase C: code-reviewer-ko (모델 fallback: fable 불가 → <모델>) PASS/FAIL` (원칙 1·5 — 투명성·한계 고백).
4. 이건 **graceful floor** 지 fable 등가가 아니다 — 리뷰 깊이가 낮아질 수 있으니, 크레딧 복구 후 **보안·인증·DB 등 고위험 FID 는 fable 로 재리뷰 권고**(dispatch-log 에 재리뷰 필요 플래그).

> **[기계 검사 — 미기록은 VERIFY 를 막는다]** (20260721 test1 dogfood): 위 3·4 항(degradation 기록)과 아래 감사 추적은 **프로즈가 아니다**. `scripts/_internal/check-review-audit.sh` 가 `reviews/<task-id>-[BC]-{report,feedback}.md` ↔ `dispatch-log.md` 행을 대조하고, `run-verification.sh` 가 이를 호출해 **미기록 리뷰가 있으면 `VERIFY: PASS` 를 거부**한다 (실행-근거 게이트 → 커밋도 안 열림). 실측 근거: test1 `20260717-approval-rbac` 이 `reviews/T10-B-report.md` 만 남기고 dispatch-log 행을 누락했는데 아무도 못 잡았다. **한계**: 이 검사는 **누락 전용**이다 — 행은 썼는데 내용이 거짓인 경우(부모 인라인 판정을 서브에이전트로 기재)는 자기보고라 파일 대조로 못 잡는다. 그 층은 여전히 정직에 의존한다.

> **[B/C 판정 file-based 감사 추적]** (20260716 dogfood 관찰 B — Phase C 리뷰어가 "B PASS 근거가 부모 선언뿐" 지적): Phase B·C 판정은 **PASS 여도** `reviews/<task-id>-B-report.md`(·`-C-report.md`) 로 저장한다 — 판정·AC별 근거 요약(리뷰어 반환 그대로). FAIL 피드백(`-B-feedback.md`)만 파일화하고 PASS 는 대화 선언으로 흘리면, Phase C 는 B 통과 자격을 검증 불가능한 부모 말로 수용하게 되고(file-based-communication 위반) 사후 감사 추적이 비어버린다. Phase C dispatch 프롬프트에는 `-B-report.md` **경로**를 포함한다.

**[§auto 모드] cap 초과 처리** (`grep -qE '^\*\*§auto\*\*:[[:space:]]*true' .specops/<FID>/spec.md`):

cap 초과 시 HARD GATE 대신 **systematic-debugging-ko → 전역 재시도** 흐름:

```
auto-state.md 읽기 (.specops/<FID>/auto-state.md — 없으면 auto_retry_count=0 으로 간주)
auto_retry_count < 1?
  ├─ YES → auto_retry_count += 1 저장 + escalations 기록
  │        → specops-auto-ko:systematic-debugging-ko 호출
  │        → 복귀 후 task 재dispatch (loop 재진입)
  └─ NO  → HARD GATE (무인 종료):
           "AUTO-HARD-GATE: <task-id> Phase B/C 전역 재시도 초과 (1/1)
            FAIL: <이슈 목록>
            systematic-debugging 또는 사용자 개입 필요"
```

**auto-state.md 경로**: `.specops/<FID>/auto-state.md` (structured-artifacts-ko 규약).
**카운터 공유**: implementing-ko와 verifying-evidence-ko가 동일 `auto_retry_count`를 공유 — per-FID 전역.

## pre-dispatch irreversible 게이트 (§auto 전용)

각 task dispatch **직전**, tasks.md YAML에서 `irreversible: true` 필드를 확인:

```bash
# 해당 task-id 의 irreversible 필드 확인
grep -A5 "id: <task-id>" .specops/<FID>/tasks.md | grep "irreversible: true"
```

**3-way 분기**:
- `§batch` 감지 → 진행 (오케스트레이터 책임)
- `§auto` 감지 + `irreversible: true` → **mini HARD GATE (발생 위치에서 정지)**:
  ```
  AUTO-HARD-GATE: <task-id> 비가역 작업 — 최종 게이트로 큐잉 불가
  내용: <task 헤더 요약>
  진행하시겠습니까? [y/n]
  ```
  `n` 시 → Lifecycle 종료. `y` 시 → 진행.
- 단일 모드 + `irreversible: true` → task 내부 Step 0 (기존 동작)

**reviewer 출력 파일 경로 규약** (file-based-communication-ko 준수 — reviewer 는 read-only, 부모가 저장):
- `.specops/<FID>/reviews/<task-id>-B-report.md` — **부모가 spec-reviewer-ko 판정 보고서(PASS/FAIL 무관)를 수신 후 저장**
- `.specops/<FID>/reviews/<task-id>-B-feedback.md` — FAIL 시 implementer-ko 재dispatch 용 (B-report 와 동일 내용이거나 이슈 발췌)
- `.specops/<FID>/reviews/<task-id>-C-feedback.md` — **부모가 code-reviewer-ko 출력을 수신 후 저장**

전달 규약 (본문 페이로드 금지 — 항상 **경로만**):
- **PASS 경로 (Phase B→C)**: Phase B PASS 시 부모는 `reviews/<task-id>-B-report.md` 경로를 Phase C(code-reviewer-ko) dispatch context.md 의 "Phase B PASS 보고서" 항목에 **경로로** 명시. code-reviewer-ko 는 이 경로를 read 해 PASS 진입 자격을 확인 (경로 누락 시에만 SKIP).
- **FAIL 경로**: Phase B/C FAIL 직후 부모가 reviewer 출력을 위 feedback 경로에 저장한 뒤 implementer-ko 재dispatch, 경로만 추가 컨텍스트로 전달.

## dispatch-log.md 자동 append (Wave 2 U5)

task 시작 시 `.specops/<FID>/dispatch-log.md` 부재면 `templates/dispatch-log.md` 복사로 생성. 매 시도(Phase A/B/C)마다 해당 task-id 블록에 1행 append:

```
| # | <ISO-8601> | <Phase> | <agent> | PASS|FAIL | <feedback path 또는 -> |
```

footer 의 `재시도 누적: B=N/2 C=N/2 (cap=2)` 카운트도 시도마다 갱신. cap 초과 시 자동 진행 금지, 사용자 결정 대기.

## 모델 라우팅 (역할별 고정)

서브에이전트 모델은 **각 `agents/<name>.md` frontmatter 의 `model:` 필드로 역할별 고정**된다 (커밋 97c672b — "서브에이전트 모델 라우팅 고정"). 부모가 dispatch 마다 티어를 동적 판단하지 않는다 — Generator/Evaluator 역할이 곧 모델을 결정한다.

| 역할 | 에이전트 | model | 근거 |
|---|---|---|---|
| Generator (구현) | `implementer-ko` | opus | 구현 품질 우선 — 다운그레이드 금지 |
| Evaluator (Phase B/C·설계) | `spec-reviewer-ko`·`code-reviewer-ko`·`plan-reviewer-ko` | fable | 평가 엄밀성 최우선 (최강 추론) |
| self-config 감사 | `red-team-ko`·`blue-team-ko`·`auditor-ko` | inherit | 세션 최상위 모델 계승 |

**설계 원칙 — 품질 편향(비용 다운그레이드 아님)**: specops 는 "가장 가벼운 모델" 비용 절감 전략을 **의도적으로 채택하지 않는다**. 단순 태스크라도 haiku 로 낮추지 않고, 역할별로 품질에 필요한 모델을 고정한다. (Agent 도구 `model` 파라미터를 부모가 임의로 재정의하지 않는다 — 에이전트 frontmatter 가 단일 소스.)

**재dispatch 시**: BLOCKED 는 모델 부족이 아니라 **컨텍스트·태스크 분해 문제**로 다룬다 (구현자는 이미 opus 고정). 컨텍스트 보강 또는 더 작은 태스크로 분할해 재dispatch — 모델 상향이 아님.

## 구현자 상태 처리

구현자 서브에이전트는 네 가지 상태 중 하나 보고. 각각 적절히 처리:

**DONE**: 스펙 준수 리뷰로 진행.

**DONE_WITH_CONCERNS**: 구현자가 작업은 완료했으나 의문을 표시. 리뷰 전 우려사항 읽기. 정확성·범위 관련이면 **리뷰 전 처리**. 관찰(예: "이 파일이 커지고 있음")이면 메모 후 리뷰 진행.

**NEEDS_CONTEXT**: 구현자가 제공받지 못한 정보 필요. 누락된 컨텍스트 제공 후 재dispatch.

v0.4a W2 — leaf subagent 가 다음 6 트리거 중 하나라도 발견 시 즉시 NEEDS_CONTEXT 반환 (추측 금지):
1. 5 컨텍스트(담당 AC / spec.md 섹션 / test 명령 / 수정 허용 파일 whitelist / worktree 경로) 중 1개 이상 누락
2. 담당 AC ID 가 acceptance-criteria.md 에서 발견 안 됨
3. spec.md 섹션 경로가 존재하지 않거나 빈 라인 범위
4. 테스트 명령 실행 자체가 실패 (test 파일 없음)
5. whitelist 외 파일을 수정해야 task 완수 가능 — 부모에 컨텍스트 보강 요청
6. worktree 경로 존재 안 함 또는 git worktree 가 아님

부모 검증: dispatch 직전 `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/dag/validate-context.sh .specops/<FID>/dispatch/<task-id>-context.md` 실행 — exit 1 시 dispatch 보류. 표준 포맷: `templates/dispatch-context.md`.

> **[스코프 이관 규약]** (트리거 5 = whitelist 외 파일 수정 필요 — verify-exec-gate 잔여 backlog): 이관은 **tasks.md 가 SoT** 다. dispatch context 파일만 수기 보강하는 것을 **금지**한다 — ① tasks.md 와 drift ② emit-context 재실행 시 수기 보강 증발 ③ 후속 wave 의 outputs-disjoint 병렬 판정이 **낡은 outputs 로 계산**되어 두 leaf 가 같은 파일을 병렬 편집(R11 git race). 처리 순서:
> 1. `.specops/<FID>/tasks.md` YAML 의 해당 task `outputs`(필요시 `inputs`)를 먼저 갱신 — 이관 사유 1줄 주석
> 2. `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/dag/emit-context.sh <FID>` 재실행 (dispatch context 재생성 — 수기 편집 금지) + §5 worktree 라인 sed 재갱신 (재생성으로 리셋됨)
> 3. **미완 wave 의 outputs-disjoint 재판정** — 이관으로 두 task 의 outputs 가 겹치게 되면 해당 쌍은 병렬 금지 → 순차 강등
> 4. dispatch-log 에 `SCOPE-MOVED: <task-id> +<file> (<사유>)` 1줄 기록 후 재dispatch

**BLOCKED**: 구현자가 태스크 완료 불가. 블로커 평가 (구현자 모델은 opus 고정 — 해법은 모델 상향이 아니라 컨텍스트·분해·에스컬레이션):
1. 컨텍스트 문제 → 컨텍스트 더 주고 재dispatch
2. 더 강력한 추론 필요 → 태스크를 더 작게 분해하거나 사람에게 에스컬레이션 (모델은 이미 최상 — 상향 불가)
3. 태스크가 너무 큼 → 더 작게 쪼개기
4. 플랜 자체가 잘못 → **사람에게 에스컬레이션**

**절대 금지**: 에스컬레이션 무시, 변경 없이 재시도. 구현자가 막혔다고 말하면 **무언가 바뀌어야 한다** (컨텍스트·태스크 크기·플랜).

## 에이전트 정의 파일

3개 에이전트가 `agents/` 디렉토리에 정의돼 있다:

- `agents/implementer-ko.md` — 구현자 서브에이전트 (Phase A)
- `agents/spec-reviewer-ko.md` — 스펙 준수 리뷰어 (Phase B)
- `agents/code-reviewer-ko.md` — 코드 품질 리뷰어 (Phase C)

각 에이전트는 **자신의 namespace subagent_type** 으로 dispatch 한다 — Phase A 는 `subagent_type: "specops-auto-ko:implementer-ko"`, Phase B 는 `"specops-auto-ko:spec-reviewer-ko"`, Phase C 는 `"specops-auto-ko:code-reviewer-ko"` (Generator/Evaluator 분리 — 리뷰어를 implementer 로 dispatch 금지). 모두 `templates/dispatch-context.md` 포맷의 컨텍스트 파일을 입력으로 받는다.

## 레드 플래그 — 금지

**절대 금지**:
- main/master 브랜치에서 **명시 동의 없이** 구현 시작
- 리뷰 생략 (스펙 준수 OR 코드 품질)
- **미해결 이슈를 두고 진행**
- 구현 서브에이전트를 **상태 공유 시 병렬로** dispatch (충돌, R11). v0.4a 정정: outputs disjoint 한 독립 leaf 2+ 는 `dispatching-parallel-agents-ko` DAG-aware 모드로 자동 병렬 권장 — `dag::find_independent_batch` 가 자동 식별. **상태 공유 (같은 파일 수정) 시에만 병렬 금지**
- 서브에이전트 프롬프트에 **파일 본문(payload)을 인라인 첨부** — `file-based-communication-ko` 위반. 경로만 전달하고 서브에이전트가 `.specops/<FID>/*.md`·`dispatch/<task-id>-context.md` 를 직접 read 해야 한다 (컨트롤러 컨텍스트 오염 방지)
- 장면 설정 컨텍스트 생략 (서브에이전트는 태스크가 어디에 맞는지 이해해야 함)
- 서브에이전트 질문 무시 (진행 전에 답하기)
- "근접함"으로 스펙 준수 인정 (스펙 리뷰어가 이슈 발견 = 미완료)
- 리뷰 루프 생략 (리뷰어 이슈 발견 → 구현자 수정 → 다시 리뷰)
- 구현자 자체검토를 실제 리뷰로 대체 (둘 다 필요)
- **스펙 준수 ✅ 전에 코드 품질 리뷰 시작** (순서 어김)
- 어느 리뷰라도 이슈 미해결인 채 다음 태스크로 이동

**서브에이전트가 질문하면**:
- 명확하고 완전히 답변
- 필요하면 추가 컨텍스트 제공
- 구현으로 몰아치지 말 것

**리뷰어가 이슈 발견하면**:
- 구현자(같은 서브에이전트)가 수정
- 리뷰어 재리뷰
- 승인까지 반복
- 재리뷰 생략 금지

**서브에이전트가 태스크 실패하면**:
- **수정 서브에이전트**를 구체 지시로 dispatch
- 수동 수정 금지 (컨텍스트 오염)

## 이점

**수동 실행 대비**:
- 서브에이전트가 자연스럽게 TDD 따름
- 태스크별 fresh 컨텍스트 (혼동 없음)
- 병렬 안전 (서브에이전트끼리 간섭 없음)
- 서브에이전트가 질문 가능 (시작 전과 진행 중 모두)

**병렬 세션 실행 대비**:
- 같은 세션 (전환 없음)
- 연속 진행 (대기 없음)
- 리뷰 체크포인트 자동

**효율**:
- 컨트롤러 컨텍스트 보존 (파일 본문 미적재 — 경로만 전달, 서브에이전트가 필요 시 직접 read)
- 컨트롤러가 `dispatch-context.md` 로 **정확히 필요한 컨텍스트 경로만** 조립
- 서브에이전트는 지정된 파일을 read 해 완전한 정보 도달
- 질문이 작업 **시작 전에** 노출 (작업 후가 아니라)

**품질 게이트**:
- 자체검토가 핸드오프 전 이슈 포착
- 2단계 리뷰: 스펙 준수 → 코드 품질
- 리뷰 루프로 수정이 실제 동작함 보장
- 스펙 준수로 과잉·부족 구축 방지
- 코드 품질로 구현이 잘 만들어졌음 보장

**비용**:
- 서브에이전트 invoke 수 증가 (구현자 + 리뷰어 2명 / 태스크)
- 컨트롤러 사전 작업 증가 (모든 태스크 전체 추출)
- 리뷰 루프로 이터레이션 추가
- 그러나 **일찍 이슈 잡음** (나중에 디버깅보다 쌈)

## 5원칙 주입 (specops-auto-ko 고유)

| 원칙 | 본 스킬 적용 |
|---|---|
| 1 **투명성** | 서브에이전트 dispatch 시 지시·컨텍스트 **전체 기록** (`.specops/<FID>/dispatch-log.md`) |
| 2 **문지기** | 파괴적 명령은 서브에이전트에게도 **명시 확인 루틴** 삽입 |
| 3 **깊이** | BLOCKED 상태는 에스컬레이션. 우회 금지 |
| 4 **주권 존중** | 리뷰 루프에서 이슈 발견 시 **사용자에게 알림** — 자동 수정 전 확인 |
| 5 **한계 고백** | 서브에이전트 자체검토 보고를 **독립 검증 없이** 수용 금지 |

## 통합

**필수 워크플로 스킬**:
- `specops-auto-ko:planning-ko` — 본 스킬이 실행할 플랜 작성
- `specops-auto-ko:verifying-evidence-ko` — 전체 구현 후 검증
- `specops-auto-ko:requesting-code-review-ko` — 리뷰어 서브에이전트용 리뷰 템플릿

**서브에이전트가 사용해야 하는 스킬**:
- `specops-auto-ko:tdd-ko` — 서브에이전트는 각 태스크를 TDD로

**실패 시**:
- `specops-auto-ko:systematic-debugging-ko` — BLOCKED 블로커가 버그성이면 호출

## 참조

- specops-ko 한국어 선례: `skills/engine/subagent-driven-development-ko.md`
- `skills/generator-evaluator-ko/SKILL.md` — 2단계 리뷰(스펙·품질) 분리 원칙
- `skills/context-resets-ko/SKILL.md` — fresh 서브에이전트 세션 보장
- `skills/karpathy-ko/SKILL.md` — Think·Simplicity·Surgical·Goal 4원칙 (cross-cutting)

## Handoff 기록 (다음 skill 진입 직전 필수)

`verifying-evidence-ko` 호출 직전 `.specops/<FID>/handoffs/implementing.md` 작성 (structured-artifacts-ko 규약 4필드: Decided/Rejected/Risks/Remaining). 특히 Remaining 섹션에 "검증이 필요한 AC story 목록" 명시.

## session-progress append (v0.4-pre P1 신설)

모든 태스크 완료 직후, verifying-evidence-ko 호출 직전에:
```
bash "${CLAUDE_PLUGIN_ROOT}"/scripts/session-progress-append.sh <FID> /implement DONE "Task 1~N 완료, PASS=N FAIL=0, 커밋 <SHA>..<SHA>"
```

## 다음 skill

모든 태스크 완료 + 최종 코드 리뷰 통과 + session-progress append 후 즉시 호출:

```
Skill: specops-auto-ko:verifying-evidence-ko
```

verifying-evidence-ko가 "증거 기반 완료 선언"을 강제한다. 본 implementing-ko는 **verifying-evidence-ko 이외의 다음 스킬을 호출하지 않는다**.
