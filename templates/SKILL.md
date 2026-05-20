---
name: "{{skill-name}}"
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
description: "{{one-line description — 어떤 상황에 사용, 핵심 기능}}"
layer: "{{1|2|3}}"
reference_upstream: "{{owner/repo@version path 또는 specops-auto-ko 독자 추가}}"
specops_version: "{{semver — 예: 1.0.0}}"
used_by: "{{호출 스킬 목록 — 예: specops-auto-ko:implementing-ko}}"
=======
=======
>>>>>>> origin/feat/20260518-to-prd
=======
>>>>>>> origin/feat/20260519-plan-eng-review
description: "{{one-line description}}"
layer: "{{1|2|3}}"
reference_upstream: "{{owner/repo@version path 또는 specops-auto-ko 독자 추가}}"
specops_version: "{{semver}}"
used_by: "{{호출 스킬 목록}}"
<<<<<<< HEAD
<<<<<<< HEAD
>>>>>>> origin/feat/20260518-skill-conventions
=======
>>>>>>> origin/feat/20260518-to-prd
=======
>>>>>>> origin/feat/20260519-plan-eng-review
---

# {{Skill Title}}

## 개요

<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
{{이 skill이 무엇을 하는가. 1~2 문장.}}

## 사용 시점

{{언제 이 skill을 사용하는가. 조건·트리거 기술.}}

## 프로세스 / 체크리스트

{{구체적 단계. 체크리스트 형식 권장.}}

1. **Step 1: ...**
2. **Step 2: ...**

## 5원칙 주입 (specops-auto-ko 고유)

| 원칙 | 본 skill 적용 |
|---|---|
| 1 **투명성** | {{이 skill에서 투명성 원칙 적용 방법}} |
| 2 **문지기** | {{이 skill에서 파괴적 작업 방지 방법}} |
| 3 **깊이** | {{이 skill에서 깊이 원칙 적용 방법}} |
| 4 **주권 존중** | {{이 skill에서 사용자 주권 보장 방법}} |
| 5 **한계 고백** | {{이 skill의 알려진 한계}} |

## 참조

- `{{관련 skill 또는 파일 경로}}` — {{설명}}
- upstream 원본: `{{reference_upstream 값}}`

## 다음 skill

{{이 skill 완료 후 호출할 skill. 또는 "chain 종료" 명시.}}
=======
=======
>>>>>>> origin/feat/20260518-to-prd
=======
>>>>>>> origin/feat/20260519-plan-eng-review
{{스킬의 목적과 핵심 원칙을 2~3문장으로 설명}}

**핵심 원칙**: **{{한 줄 핵심}}**

## 체크리스트 / 프로세스

다음 각 항목을 순서대로 수행한다:

1. **{{스텝 1}}** — {{설명}}
2. **{{스텝 2}}** — {{설명}}
3. **{{스텝 N}}** — {{설명}}

## 5원칙 주입 (specops-auto-ko 고유)

| 원칙 | 본 스킬 적용 |
|---|---|
| 1 **투명성** | {{이 스킬에서 투명성 원칙 적용 방법}} |
| 2 **문지기** | {{이 스킬에서 문지기 원칙 적용 방법}} |
| 3 **깊이** | {{이 스킬에서 깊이 원칙 적용 방법}} |
| 4 **주권 존중** | {{이 스킬에서 주권 존중 원칙 적용 방법}} |
| 5 **한계 고백** | {{이 스킬에서 한계 고백 원칙 적용 방법}} |

## 참조

- `{{관련 upstream 원본 경로}}` — {{설명}}
- `{{관련 specops-ko 선례}}` — {{설명}}

## 다음 skill

{{이 스킬 완료 후 자동으로 호출되는 다음 스킬 명시. chain 종료점이면 "chain 종료" 명시}}
<<<<<<< HEAD
<<<<<<< HEAD
>>>>>>> origin/feat/20260518-skill-conventions
=======
>>>>>>> origin/feat/20260518-to-prd
=======
>>>>>>> origin/feat/20260519-plan-eng-review

```
Skill: specops-auto-ko:{{next-skill-name}}
```
