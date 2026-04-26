---
name: planning-ko
description: 스펙·요구사항이 확보된 다단계 작업에서 코드 건드리기 전에 사용 — 구현 플랜을 bite-sized task 단위로 작성
layer: 2
reference_upstream:
  - obra/superpowers@v5.0.7 skills/writing-plans/SKILL.md
  - specops-ko skills/engine/writing-plans-ko.md
specops_version: 0.0.0
used_by: specops-auto-ko:clarifying-ko (chain 진입), specops-auto-ko:decomposing-ko (chain 출구)
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

> **에이전트 워커용**: 필수 하위 스킬 — `specops-auto-ko:implementing-ko` (권장) 또는 `specops-auto-ko:decomposing-ko` 사용. 스텝은 체크박스 `- [ ]` 문법으로 추적.

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

완전한 플랜 작성 후, 새 눈으로 스펙과 대조. **이것은 자체 체크리스트**이지 서브에이전트 디스패치가 아님.

**1. 스펙 커버리지**: 스펙의 각 섹션/요구를 훑어보고, 그 요구를 구현하는 태스크를 짚을 수 있는가? 누락 나열.

**2. 플레이스홀더 스캔**: "플레이스홀더 금지" 섹션의 레드 플래그 검색. 수정.

**3. 타입 일관성**: 후반 태스크에서 쓴 타입·메서드 시그니처·속성명이 전반 태스크에서 정의한 것과 일치하는가? Task 3에서 `clearLayers()`였는데 Task 7에서 `clearFullLayers()`라면 버그.

이슈 발견 시 인라인 수정. 재검토 불필요 — 수정하고 진행. 스펙 요구에 태스크가 없으면 **태스크 추가**.

## 5원칙 주입 (specops-auto-ko 고유)

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
- 필수 하위 스킬: `specops-auto-ko:implementing-ko` (Superpowers subagent-driven-development 이식)
- 태스크별 fresh 서브에이전트 + 2단계 리뷰

**인라인 실행 선택 시**:
- 하위 스킬: `specops-auto-ko:decomposing-ko`로 태스크 분할 후 인라인 순차 실행
- 체크포인트마다 리뷰

## plan.md 필수 섹션

plan.md 작성 시 `templates/plan.md` 구조를 **정확히** 따른다. 특히 아래 두 섹션은 **반드시** 포함:

1. **`## 7. 자체 검토 (5원칙 체크리스트)`** — 체크리스트 4항목 모두 기재
2. **`## 8. Advisor 협의 기록`** — advisor() 호출 내역 또는 "해당 없음 — 본 plan 작성 중 불확실 지점 없음"

`## 8. Advisor 협의 기록` 부재 시 R-5 거버넌스 규칙이 트리거된다. 반드시 작성할 것.

## 참조

- `templates/plan.md` — 작성 포맷 (**정확히 따를 것**, 특히 §8 Advisor 협의 기록 섹션)
- `templates/tasks.md` — 태스크 분해 포맷
- upstream 원본: `obra/superpowers@v5.0.7 skills/writing-plans/SKILL.md`

## session-progress append (v0.4-pre P1 신설)

플랜 저장 직후, decomposing-ko 호출 직전에:
```
bash scripts/session-progress-append.sh <FID> /plan 완료 "plan.md"
```

## 다음 skill

플랜 저장 + session-progress append + 실행 방식 결정 후 즉시 호출:

```
Skill: specops-auto-ko:decomposing-ko
```

decomposing-ko가 플랜을 실행 가능한 태스크 리스트로 분해. 그 후 `specops-auto-ko:implementing-ko`로 전환.
