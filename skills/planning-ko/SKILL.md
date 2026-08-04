---
name: planning-ko
description: 스펙·요구사항이 확보된 다단계 작업에서 코드 건드리기 전에 사용 — 구현 플랜을 bite-sized task 단위로 작성
layer: 2
reference_upstream: obra/superpowers@v5.0.7 skills/writing-plans/SKILL.md
  - obra/superpowers@v5.0.7 skills/writing-plans/SKILL.md
  - specops-ko skills/engine/writing-plans-ko.md
specops_version: 1.61.0
used_by: clarifying-ko (chain 진입), decomposing-ko (chain 출구), /start-all (Phase 2 batch plan-review)
---

# Engine 스킬 — 구현 플랜 작성 (planning)

## 개요

엔지니어가 **코드베이스 컨텍스트 0이고 안목도 의심스럽다**고 가정하고, 포괄적 구현 플랜을 작성한다. 각 태스크에서 건드릴 파일, 코드, 테스트, 참조할 문서, 테스트 방법까지 모두 문서화. 전체 플랜을 **bite-sized 태스크**로 제공. DRY·YAGNI·TDD·잦은 커밋.

숙련 개발자이지만 **우리 도구 세트나 문제 도메인은 거의 모른다**고 가정. 좋은 테스트 설계도 잘 모른다고 가정.

**시작 시 선언**: "planning-ko 스킬로 구현 플랜을 작성합니다."

**컨텍스트**: 전용 worktree에서 실행 (specifying → clarifying 단계에서 생성됨).

**플랜 저장 경로**: `.specops/<FID>/plan.md`
- 사용자 선호가 있으면 그 경로 우선

## 범위 점검

스펙이 여러 독립 서브시스템을 담으면 specifying 단계에서 서브프로젝트 스펙으로 쪼개졌어야 함. 그러지 않았다면 **지금이라도 분해 제안** — 서브시스템별 별도 플랜으로. 각 플랜은 단독으로 **동작하는·테스트 가능한 소프트웨어**를 산출해야 함.

## 파일 구조

태스크 정의 전에, 어떤 파일을 만들고 수정할지 + 각 파일의 책임을 **먼저 매핑**. 여기서 분해 결정이 확정된다.

- 명확한 경계·잘 정의된 인터페이스로 단위 설계. 각 파일은 **하나의 명확한 책임**
- 한 번에 컨텍스트에 담을 수 있는 코드일수록 추론과 편집이 정확. 작고 집중된 파일 선호
- **함께 변하는 파일은 함께 있다**. 기술 계층이 아니라 책임으로 분할
- 기존 코드베이스는 **기존 패턴 따름**. 코드베이스가 대형 파일을 쓰면 일방적 재구조화 금지. 다만 수정 중인 파일이 통제불능이면 분할을 플랜에 포함하는 것도 합당

이 구조가 태스크 분해의 근거. 각 태스크는 **독립적으로 의미가 통하는** 자족적 변경을 산출해야 함.

## Bite-Sized 태스크 단위

**각 스텝 = 단일 행동 (2~5분)**:
- "실패 테스트 작성" — 스텝
- "실패 확인 위해 실행" — 스텝
- "최소 구현 작성" — 스텝
- "테스트 통과 확인 실행" — 스텝
- "커밋" — 스텝

## 플랜 문서 헤더

**모든 플랜은 이 헤더로 시작**:

```markdown
# [기능명] 구현 플랜

> **에이전트 워커용**: 필수 하위 스킬 — `specops-ko:implementing-ko` (권장) 또는 `specops-ko:decomposing-ko` 사용. 스텝은 체크박스 `- [ ]` 문법으로 추적.

**목표**: [한 문장 — 무엇을 만드는가]

**아키텍처**: [2~3 문장 — 접근]

**기술 스택**: [주요 기술·라이브러리]

---
```

## 태스크 구조

````markdown
### Task N: [컴포넌트명]

**파일**:
- 생성: `exact/path/to/file.py`
- 수정: `exact/path/to/existing.py:123-145`
- 테스트: `tests/exact/path/to/test.py`

- [ ] **Step 1: 실패 테스트 작성**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: 실패 확인 실행**

실행: `pytest tests/path/test.py::test_name -v`
예상: FAIL with "function not defined"

- [ ] **Step 3: 최소 구현 작성**

```python
def function(input):
    return expected
```

- [ ] **Step 4: 통과 확인 실행**

실행: `pytest tests/path/test.py::test_name -v`
예상: PASS

- [ ] **Step 5: 커밋**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: 특정 기능 추가"
```
````

## 플레이스홀더 금지

각 스텝은 엔지니어가 필요한 **실제 내용**을 담아야 함. 다음은 **플랜 실패** — 절대 쓰지 말 것:

- "TBD", "TODO", "implement later", "fill in details"
- "적절한 에러 처리 추가" / "유효성 검증 추가" / "엣지 케이스 처리"
- "위에 대한 테스트 작성" (실제 테스트 코드 없이)
- "Task N과 유사" (코드 반복 — 엔지니어가 순서와 무관하게 읽을 수 있음)
- 무엇을 할지만 설명하고 **어떻게**를 보여주지 않는 스텝 (코드 스텝은 코드 블록 필수)
- 어떤 태스크에도 정의 없는 타입·함수·메서드 참조

## 기억할 것

- **정확한 파일 경로** 항상
- **모든 스텝에 완전한 코드** — 스텝이 코드를 바꾸면 코드를 보여라
- **정확한 명령과 기대 출력**
- DRY·YAGNI·TDD·잦은 커밋

## 자체 검토

완전한 플랜 작성 후, 새 눈으로 스펙과 대조.

**1. 스펙 커버리지**: 스펙의 각 섹션/요구를 훑어보고, 그 요구를 구현하는 태스크를 짚을 수 있는가? 누락 나열.

**2. 플레이스홀더 스캔**: "플레이스홀더 금지" 섹션의 레드 플래그 검색. 수정.

**3. 타입 일관성**: 후반 태스크에서 쓴 타입·메서드 시그니처·속성명이 전반 태스크에서 정의한 것과 일치하는가? Task 3에서 `clearLayers()`였는데 Task 7에서 `clearFullLayers()`라면 버그.

이슈 발견 시 인라인 수정. 자체 체크리스트는 재실행 불필요 — 수정 후 아래 독립 검증으로 진행. 스펙 요구에 태스크가 없으면 **태스크 추가**.

## 독립 리뷰 (plan-reviewer 서브에이전트)

### [§batch 분기] plan-reviewer DEFER (Phase 2 batch 1회)

```bash
grep -qE '^\*\*§batch\*\*:' .specops/<FID>/spec.md && echo BATCH || echo SINGLE
```

**`**§batch**` 감지 시** (`/start-all` Phase 1):

1. 자체 검토(위 절)까지 완료 후 **`plan-reviewer-ko` dispatch 하지 않음**
2. 외부 critic(`critic-ask.sh`) **per-FR 미호출**
3. decomposing-ko 진입 **허용** — 아래 「FAIL 시 decomposing 차단」HARD GATE는 **본 경로에 적용하지 않음**(검사는 `/start-all` Phase 2)
4. `.specops/<FID>/dispatch-log.md`에 기록:
   `| <N> | <ISO-8601> | plan-reviewer | DEFERRED | — | Phase 2 batch |`
5. session-progress: `/plan 완료 "plan.md (plan-reviewer DEFERRED → Phase 2 batch)"`
6. handoff Remaining에 `plan-reviewer DEFERRED → Phase 2 batch` 명시
7. 즉시 `## 실행 전환` / `## 다음 skill`(decomposing-ko)

**금지**: §batch인데 Phase 1에서 plan-reviewer를 돌리는 것(비용·시점 계약 위반).

**비-batch** (`/start`·foundation 등 §batch 부재): 아래 기존 독립 리뷰 절차 **그대로**.

### 비-batch — plan-reviewer dispatch

자체 검토 통과 후 `specops-ko:plan-reviewer-ko` 서브에이전트를 dispatch해 plan.md를 독립 검증한다. 이 리뷰어는 **spec 대조 2관점(스펙 커버리지·스펙 정합) + 엔지니어링 4관점(TDD·플레이스홀더·파일경계·타입일관성)** 6관점을 fresh 시각으로 수행한다 (구 general-purpose Plan Document Reviewer 의 spec 대조 역할을 전용 Evaluator 로 흡수 — 20260723, dispatch 1회로 단일화).

**dispatch:** `Agent` 도구, `subagent_type: "specops-ko:plan-reviewer-ko"`
입력: `.specops/<FID>/spec.md`(요구 원본) + `.specops/<FID>/plan.md`(검토 대상) 경로

**판정 처리 (cap=2):**

`PLAN-REVIEW-RESULT: FAIL` — Critical/Important 이슈 발견 시 **HARD GATE 발동**: decomposing-ko 진입 차단 + plan.md 수정 요청.

| 결과 | 처리 |
|---|---|
| `PLAN-REVIEW-RESULT: PASS` | `## 실행 전환` 진행 (decomposing-ko 허용) |
| `PLAN-REVIEW-RESULT: FAIL` (초기 시도) | **decomposing-ko 진입 차단** — 이슈 목록 기반 plan.md 수정 → 재dispatch (1회 허용) |
| `PLAN-REVIEW-RESULT: FAIL` (재dispatch 후 재검토) | `HARD-GATE: plan-reviewer cap 초과 — 사용자 결정 필요` 출력 후 중단 |

**Evaluator 모델 불가 fallback (P1 — 20260718)**: `plan-reviewer-ko` 도 `model: fable` 고정이라 fable 불가(크레딧 소진) 시 dispatch 가 실패한다. 이때 **부모 self-review 로 후퇴 금지** — 같은 `plan-reviewer-ko` 를 **독립 서브에이전트로 가용 모델 override 재dispatch**(Agent `model` 인자)해 Generator↔Evaluator 분리를 보존한다. dispatch-log 에 `plan-reviewer-ko (모델 fallback: fable 불가 → <모델>)` 기록. 상세 규약은 `skills/implementing-ko/SKILL.md` "Evaluator 모델 불가 fallback" 참조(동일 원칙).

**[§auto 모드]** (`grep -qE '^\*\*§auto\*\*:[[:space:]]*true' .specops/<FID>/spec.md`):
cap 초과 시 HARD GATE 대신 **자동 통과** (가역 — plan은 verify/review 단계가 검증). dispatch-log.md에 "plan-reviewer cap 초과 → §auto 자동통과" 기록. cap 초과 자동통과 **직전** `advisor()` 1회 자문 시도 → 권고 요지를 dispatch-log.md에 기록(보조 입력 — plan 판정 권한 없음, 가역 게이트라 자동 진행). `advisor()` 미연결 시 자문 없이 자동통과 진행(graceful fallback — 하드 의존 금지).

**dispatch-log.md 기록** (`.specops/<FID>/dispatch-log.md` — 부재 시 `templates/dispatch-log.md` 복사):

| <N> | <ISO-8601> | plan-reviewer | plan-reviewer-ko | PASS\|FAIL | - |

### 외부 critic 병행 (advisory — multimodel-critic)

**비-batch만**: plan-reviewer **최종 PASS 직후** 1회 (§auto cap 초과 자동통과 경로 포함 — 자동통과도 진행 확정이므로 동일 호출. FAIL 루프 중에는 미호출):

1. `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/critic-ask.sh templates/critic-prompt-plan.md --files .specops/<FID>/plan.md`
2. 의견 출력 시 (`CRITIC[<provider>]:`): 요지 1~2문장을 plan.md §8 에 행 추가 —
   `| <ts> | 외부 critic (<provider>) | <요지> | 참고 | §N |`
3. `CRITIC: SKIP/FAIL` → dispatch-log 1줄만 기록 (plan.md §8 미기재 — 잡음 방지)
4. **advisory**: 외부 의견은 참고 입력 — PASS/FAIL **판정 권한 없음** (판정은 plan-reviewer 소관)

**§batch**: per-FR critic **미호출**. `/start-all` Phase 2 batch plan-review **PASS 후** 오케스트레이터가 대표 plan 1개 또는 전 plan 경로로 critic **최대 1회**(또는 dispatch-log에 `CRITIC: SKIP (batch defer)`). 판정 권한 없음은 동일.

## 5원칙 주입 (specops-ko 고유)

| 원칙 | 본 스킬 적용 |
|---|---|
| 1 **투명성** | 태스크 설명은 **근거 명시**. "왜 이 파일을 먼저?" |
| 2 **문지기** | 파괴적 작업(DB 마이그레이션·프로덕션 설정 변경)은 **별도 태스크 + 명시 확인** |
| 3 **깊이** | 스펙이 모호하면 planning 중단 → specifying 복귀 |
| 4 **주권 존중** | 핵심 결정점은 사용자 리뷰 요청 |
| 5 **한계 고백** | "이 태스크는 가정 기반" 태그 |

## 실행 전환

플랜 저장 후 실행 방식 선택 제시:

> "플랜을 `.specops/<FID>/plan.md`에 저장했습니다. 두 가지 실행 옵션:
>
> **1. 서브에이전트 주도 (권장)** — 태스크별 fresh 서브에이전트 dispatch, 태스크 간 리뷰, 빠른 반복
>
> **2. 인라인 실행** — 본 세션에서 배치 실행, 체크포인트마다 리뷰
>
> 어느 쪽으로 할까요?"

**서브에이전트 주도 선택 시**:
- 필수 하위 스킬: `specops-ko:implementing-ko`
- 태스크별 fresh 서브에이전트 + 2단계 리뷰

**인라인 실행 선택 시**:
- 하위 스킬: `specops-ko:decomposing-ko`로 태스크 분할 후 인라인 순차 실행
- 체크포인트마다 리뷰

## plan.md 필수 섹션

plan.md 작성 시 `templates/plan.md` 구조를 **정확히** 따른다. 특히 아래 두 섹션은 **반드시** 포함:

1. **`## 7. 자체 검토 (5원칙 체크리스트)`** — 체크리스트 4항목 모두 기재
2. **`## 8. Advisor 협의 기록`** — advisor() 호출 내역 또는 "해당 없음 — 본 plan 작성 중 불확실 지점 없음"

`## 8. Advisor 협의 기록` 부재 시 R-5 거버넌스 규칙이 트리거된다. 반드시 작성할 것.

## 참조

- `templates/plan.md` — 작성 포맷 (**정확히 따를 것**, 특히 §8 Advisor 협의 기록 섹션)
- `templates/tasks.md` — 태스크 분해 포맷
- `skills/structured-artifacts-ko/SKILL.md` — .specops/<FID>/ 아티팩트 경로 규약
- `skills/karpathy-ko/SKILL.md` — Think·Simplicity·Surgical·Goal 4원칙 (cross-cutting)

## 공유 유틸 창발 중복 경고 (P2 — 20260718 test2 회고)

foundation-manifest 는 **사전 선언된** 공통부 재사용만 게이트한다 — 그런데 **여러 형제 FID 가 각자 만드는 유틸이 창발적으로 중복**되는 건 못 잡는다(전방 계약 ≠ 후방 탐지). test2 실측: `mask_block_comments`·`PRUNE`/`ANALYZE_EXT` 리터럴이 **4~5 FID 에 복제**돼 "sysprobe-lib 승격" backlog 가 반복 발생했다.

**plan 작성 시 판별**: 이 플랜의 태스크가 **재사용 가능한 유틸리티**(파싱 헬퍼·공유 상수·전처리 함수 등 — 이 기능 고유 로직이 아니라 형제 기능도 쓸 만한 것)를 만드는가?

- **그렇다** → 그 로직을 **공통 lib**(예: `<project>/lib` · foundation 모듈)에 배치하도록 플랜에 명시하고, `.specops/memory/foundation-manifest.md` 에 등재 후보로 기재한다. per-FID 인라인 복제 금지.
- **판단 애매** → plan.md 에 `공유후보: <유틸명> (창발 중복 리스크)` 1줄 기록 → 리뷰·후속 FID 가 인지. **advisor 자문 권장**(조기 분리 가치 — test2 learning: advisor 가 '조합 vs 재구현' 조기 포착).

**하드 게이트 아님** — 판단 도구다. 목적은 "3번째 복제가 생기기 전에 승격"이지 차단이 아니다.

## foundation 분기 — manifest 산출 지시

spec.md §유형=`foundation` 인 플랜은 **반드시** 태스크 목록 마지막에 다음 태스크를 포함한다:

> **[foundation 전용 마지막 태스크]** 공통부 구현 완료 후 `templates/foundation-manifest.md` 를 기반으로 실제 모듈 경로·역할을 채워 `.specops/memory/foundation-manifest.md` 에 저장한다.

이 태스크가 없으면 후속 `/start <기능>` 시 decomposing-ko HARD GATE 가 `foundation-manifest.md` 를 발견하지 못해 재사용 게이트가 동작하지 않는다.

**강제**: 이는 산문 권고가 아니다 — `verifying-evidence-ko` 의 **foundation manifest 산출 게이트**가 §유형=foundation 인 FID 완료 시 `.specops/memory/foundation-manifest.md` 존재+채움을 검사하여 누락 시 `VERIFY: FAIL` 로 완료를 차단한다(태스크 누락·파일 미작성 모두). 즉 manifest 없이는 foundation lifecycle 이 완료 선언될 수 없다.

## session-progress append (v0.4-pre P1 신설)

플랜 저장 직후, decomposing-ko 호출 직전에:
```
bash "${CLAUDE_PLUGIN_ROOT}"/scripts/session-progress-append.sh <FID> /plan 완료 "plan.md"
```

## Handoff 기록 (다음 skill 진입 직전 필수)

`decomposing-ko` 호출 직전 `.specops/<FID>/handoffs/planning.md` 작성 (structured-artifacts-ko 규약 4필드: Decided/Rejected/Risks/Remaining).

## 다음 skill

플랜 저장 + session-progress append + 실행 방식 결정 + handoff.md 기록 후 즉시 호출:

```
Skill: specops-ko:decomposing-ko
```

decomposing-ko가 플랜을 실행 가능한 태스크 리스트로 분해. 그 후 `specops-ko:implementing-ko`로 전환.
