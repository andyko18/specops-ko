---
name: engine/requesting-code-review-ko
description: 태스크 완료, 주요 기능 구현, 머지 전 사용 — 결과물이 요구를 충족하는지 외부 리뷰어에게 검증 요청
layer: 2
reference_upstream:
  - obra/superpowers@v5.0.7 skills/requesting-code-review/SKILL.md
  - specops-ko skills/engine/requesting-code-review-ko.md
specops_version: 0.0.0
used_by: engine/verifying-evidence-ko (chain 진입), engine/receiving-code-review-ko (chain 출구)
---

# Engine 스킬 — 코드 리뷰 요청 (requesting-code-review)

코드 리뷰어 서브에이전트를 **이슈가 누적되기 전에** dispatch. 리뷰어는 당신의 세션 히스토리가 아니라 **정확히 조립된 평가용 컨텍스트**를 받는다. 리뷰어를 결과물에 집중시키고, 당신 자신의 컨텍스트도 계속된 작업용으로 보존한다.

**핵심 원칙**: **일찍 리뷰, 자주 리뷰.**

## 리뷰 요청 시점

**필수**:
- 서브에이전트 주도 개발의 **각 태스크 후**
- 주요 기능 완료 후
- main 머지 전

**선택이지만 가치 있음**:
- 막혔을 때 (새 관점)
- 리팩터링 전 (기준선 체크)
- 복잡한 버그 픽스 후

## 요청 방법

### 1. git SHA 획득

```bash
BASE_SHA=$(git rev-parse HEAD~1)  # 또는 origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

### 2. 코드 리뷰어 서브에이전트 dispatch

`Agent` 도구로 `code-reviewer`(또는 `oh-my-claudecode:code-reviewer`) 서브에이전트 호출. 다음 정보를 **전체 텍스트**로 포함:

**필수 필드**:
- `WHAT_WAS_IMPLEMENTED` — 방금 구축한 것
- `PLAN_OR_REQUIREMENTS` — 무엇을 해야 했는지 (플랜·요구사항)
- `BASE_SHA` — 시작 커밋
- `HEAD_SHA` — 종료 커밋
- `DESCRIPTION` — 간략 요약

### 3. 피드백 대응

- **Critical 이슈**: **즉시** 수정
- **Important 이슈**: 다음 단계 진행 **전에** 수정
- **Minor 이슈**: 기록 후 나중에
- **리뷰어가 틀렸으면**: 근거와 함께 pushback (본 스킬 `## 리뷰어가 틀렸을 때` 참조)

## 예시

```
[Task 2 방금 완료: 검증 함수 추가]

당신: 진행 전 코드 리뷰를 요청합니다.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[code-reviewer 서브에이전트 dispatch]
  WHAT_WAS_IMPLEMENTED: 대화 인덱스 검증·수리 함수
  PLAN_OR_REQUIREMENTS: docs/superpowers/plans/deployment-plan.md Task 2
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DESCRIPTION: verifyIndex() + repairIndex() 추가, 4 이슈 타입

[서브에이전트 반환]:
  강점: 깔끔한 아키텍처, 실제 테스트
  이슈:
    Important: 진행 표시기 누락
    Minor: 보고 간격 100이 매직 넘버
  평가: 진행 가능

당신: [진행 표시기 수정]
[Task 3 진행]
```

## 워크플로 통합

**서브에이전트 주도 개발**:
- **각 태스크 후** 리뷰
- 복합되기 전 이슈 포착
- 다음 태스크 전 수정

**인라인 실행**:
- **각 배치(3 태스크) 후** 리뷰
- 피드백 받고 적용, 계속

**애드혹 개발**:
- 머지 전 리뷰
- 막혔을 때 리뷰

## 레드 플래그

**절대 금지**:
- "간단하니까" 리뷰 생략
- Critical 이슈 무시
- Important 이슈 미해결로 진행
- 타당한 기술 피드백에 논쟁

**리뷰어가 틀렸을 때**:
- 기술 근거와 함께 pushback
- 동작을 증명하는 코드·테스트 제시
- 명확화 요청

## 5원칙 주입 (specops-auto-ko 고유)

| 원칙 | 본 스킬 적용 |
|---|---|
| 1 **투명성** | 리뷰 요청 payload 전문을 `.specops/<FID>/review-request.md`에 보존 |
| 2 **문지기** | Critical 미해결 상태로 머지 불가. 리뷰 생략도 불가 |
| 3 **깊이** | "간단해서 리뷰 불필요"는 거부 신호. 작은 PR도 리뷰 |
| 4 **주권 존중** | 사용자가 리뷰 생략을 명시 지시하지 않는 한 항상 리뷰 요청 |
| 5 **한계 고백** | 리뷰어 컨텍스트 부족 감지 시 "이 부분은 리뷰 범위 밖" 기록 |

## 참조

- upstream 원본: `obra/superpowers@v5.0.7 skills/requesting-code-review/SKILL.md`
- 템플릿: `obra/superpowers@v5.0.7 skills/requesting-code-review/code-reviewer.md` (v0.1+ 본 디렉토리에 포팅)
- specops-ko 한국어 선례: `skills/engine/requesting-code-review-ko.md`

## 다음 skill

리뷰 피드백 수령 직후 즉시 호출:

```
Skill: engine/receiving-code-review-ko
```

receiving-code-review-ko가 피드백을 어떻게 수용·검증·구현할지 강제한다. 본 requesting-code-review-ko는 **receiving-code-review-ko 이외의 다음 스킬을 호출하지 않는다**.
