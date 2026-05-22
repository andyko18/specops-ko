---
name: advisor-ko
description: 기획·분석·설계·개발 중 애매한 부분/모르는 부분 발생 시 항상 적용 — advisor 도구로 외부 자문을 받아 단정·합리화·circular 검증을 차단
layer: 2
reference_upstream: specops-auto-ko 독자 추가 (Anthropic Claude Code advisor 도구 활용 패턴)
specops_version: 1.1.1
used_by: specops-auto-ko:using-specops-auto-ko-ko (cross-cutting), specops-auto-ko:specifying-ko, specops-auto-ko:analyzing-ko, specops-auto-ko:planning-ko, specops-auto-ko:implementing-ko
---

# Advisor 활용 원칙

`advisor` 는 본 세션의 전체 conversation 을 자동 전송받는 외부 reviewer 모델. 단정·합리화·자기-편향 (self-confirmation bias) 을 차단해 specops-auto-ko 의 5 원칙 (특히 원칙 1 투명성 · 원칙 5 한계 고백) 을 강화한다.

**트레이드오프:** advisor 호출은 latency + 토큰 비용을 발생시킨다. 자명한 작업 (typo fix, 단순 rename, 1 줄 변경 등) 은 호출하지 않는다. **애매성 / 미확신 / 결정 갈래** 가 있을 때만 호출.

---

## 원칙 1 — 호출 시점 (When)

**다음 중 하나 이상에 해당하면 호출 의무.** 합리화로 우회 금지.

- **substantive work 직전** — 첫 파일 편집·첫 commit·첫 결정 발화 직전
- **task 완료 직전** — 산출물 (spec/plan/evidence 등) durable 하게 저장한 후, 종결 발화 전
- **stuck 상태** — 같은 에러 2 회 이상 / 접근 불일치 / 결과가 가설과 안 맞음
- **접근 변경 고려 시** — 다른 방향 검토 의도 발생 시
- **circular 검증 위험** — 본 세션이 작성한 산출물을 본 세션이 검증하는 패턴 감지 시

**specops-auto-ko 연결:** 원칙 5 한계 고백 + 단계별 HARD GATE 보강

---

## 원칙 2 — 단계별 호출 시점 (Where)

| 단계 | skill | advisor 호출 시점 | 산출물 반영 |
|---|---|---|---|
| **기획** | `specifying-ko` | spec.md §유형 분류 모호 / NFR 미확신 / YAGNI 경계 모호 | spec.md §N 메모 |
| **분석** | `analyzing-ko` | impact 5 항목 작성 중 외부 영향 범위 모호 / 회귀 위험 미확신 | impact-analysis.md §N 메모 |
| **설계** | `planning-ko` | (이미 강제) bite-sized task 분해 중 의존 관계 모호 | **plan.md §8 Advisor 협의 기록** (의무) |
| **개발** | `implementing-ko` | 서브에이전트 dispatch 전 task 의도 모호 / DAG 분기 결정 | dispatch-log.md 섹션 |
| **검증** | `verifying-evidence-ko` | structural-only 검증의 circular 위험 감지 시 | evidence.md §advisor 외부 검증 |

**specops-auto-ko 연결:** planning-ko §8 패턴을 다른 단계로 일반화

---

## 원칙 3 — 호출 형식 (How)

**파라미터 없음.** `advisor()` 호출 시 본 세션의 전체 conversation 이 자동 전송된다 — task 설명, 모든 tool call 과 result, 사고 과정 모두 포함.

```
advisor()
```

추가 prompt 작성 불필요. advisor 가 직접 보고 판단한다.

**호출 후 처리:**
- advisor 권고를 진지하게 수용. 단순 self-test 통과는 advisor 권고 반박 근거 아님
- empirical 증거 (파일 내용 / 테스트 결과 / 1 차 출처) 가 advisor 와 충돌하면 한 번 더 advisor 호출 (reconcile call) — 단순 swap 금지
- advisor 의 specific 주장을 검증할 때만 추가 도구 호출

**specops-auto-ko 연결:** 원칙 4 주권 (사용자 명시 지시 우선) — advisor 도 1 의견, 사용자 결정 최우선

---

## 원칙 4 — 회피 시점 (When NOT)

**호출하지 않을 때:**
- 단순 lookup (정확한 file path 알고 있음, 단순 grep 결과 확인)
- typo fix / 1 줄 rename / 기계적 변환
- 직전 tool result 가 명확히 다음 행동 지시
- 사용자가 explicit 결정 명시 ("X 로 진행해" 같은 직접 지시)
- 동일 task 에서 advisor 1 회 이상 호출 후 새 정보 없음

**호출 빈도:** 긴 작업에서 1 회 이상 (commit 전 + 종결 직전 권장). 짧은 reactive task 는 0~1 회.

**specops-auto-ko 연결:** 원칙 2 문지기 (회색지대 만들지 말 것 — binary 결정)

---

## 5 원칙 매핑 요약

| advisor 원칙 | specops-auto-ko 5 원칙 |
|---|---|
| 1 호출 시점 (When) | 원칙 5 한계 고백 (불확실 시 명시) |
| 2 단계별 시점 (Where) | 원칙 1 투명성 (단계마다 외부 검증 흔적) |
| 3 호출 형식 (How) | 원칙 4 주권 (advisor 도 1 의견) |
| 4 회피 시점 (When NOT) | 원칙 2 문지기 (binary 결정) |

---

## 5원칙 주입 (specops-auto-ko 고유)

| 원칙 | 본 skill 적용 |
|---|---|
| 1 **투명성** | advisor 호출 결과를 plan.md §8 또는 spec.md §협의 기록에 명시 |
| 2 **문지기** | substantive work 전 advisor 미호출 = 원칙 2 위반 |
| 3 **깊이** | advisor 의견과 자체 근거 충돌 시 reconcile call 의무 |
| 4 **주권** | advisor 판단이 사용자 결정과 충돌 시 사용자 개입 요청 |
| 5 **한계 고백** | "advisor 미호출 = 자체검토만" 상태 명시 |

## 참조

- `skills/karpathy-ko/SKILL.md` — 동일한 cross-cutting skill 패턴
- `skills/planning-ko/SKILL.md` L177 — `## 8. Advisor 협의 기록` 섹션 (이미 강제)
- `skills/using-specops-auto-ko-ko/SKILL.md` — 메타 skill cross-cutting 주입 위치

---

*v1.1.1 · 2026-05-07 · specops-auto-ko 독자 추가 (advisor 도구 활용 패턴 정형화)*
