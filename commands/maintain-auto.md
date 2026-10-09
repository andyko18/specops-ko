---
name: maintain-auto
disable-model-invocation: true
description: "[유지보수·무인] 기존 코드 수정 Lifecycle 무인 진입 — 분석 검토·설계 승인·명확화 자동 통과, 회귀 AC·리뷰·verify 유지, PR 직전 단일 확인. specops-ko:analyzing-ko 호출"
triggers:
  - "/maintain-auto"
mode: ask
specops_version: 2.18.0
specops_layer: Lifecycle
reference_upstream: specops-ko 독자 추가 (commands/maintain.md § auto variant)
---

# /maintain-auto [<대상 또는 변경 설명>]

## 목적

`/maintain` 의 **무인 변형**. 영향 분석 → 명세 → 명확화 → 계획 → 구현 → 검증 → 리뷰를 사용자 응답 없이 끝까지 진행하고, PR 생성 직전에 **가정 다이제스트와 함께 1회만** 확인한다.

**줄어드는 것은 사람의 확인뿐이다.** 분석 산출물(current-state·impact-analysis) · 회귀 AC(`AC-R-1`, 스키마면 `AC-R-2`) · plan 리뷰 · Phase B/C · verify 는 `/maintain` 과 같다.

## Process

1. **메타 skill 활성 확인**
2. **args 앞 두 줄 prepend**:
   ```
   <!-- entry: maintain -->
   <!-- auto: true -->
   <원본 대상·변경 설명>
   ```
3. **즉시 `specops-ko:analyzing-ko` 호출** — 둘째 줄의 무인 표지를 보고 분석 검토 ★ HARD GATE 를 **자동 통과**한다(산출물 2종은 그대로 만든다)
4. **`specifying-ko` [유지보수 분기]** — args 그대로. spec §1 에 `**§auto**: true` 와 `**자동 결정 분석**` 1줄을 적는다. 이후 chain 은 각 skill 의 `§auto` 분기가 가역 게이트를 자동 통과한다

## 무인 동작

| 단계 | 무인 동작 | 정지? |
|---|---|---|
| analyzing-ko 분석 검토 게이트 | 자동 통과 — 분석 요약을 PR 게이트 다이제스트에 싣는다 | ❌ |
| specifying-ko intent·설계·스펙 승인 | 자동 통과 (추정 항목은 `(ASSUMED)`) | ❌ |
| clarifying-ko BLOCKING 모호점 | best-guess 자동 답변 + `status: ASSUMED` | ❌ |
| planning-ko plan-reviewer cap 초과 | Important 만 남으면 자동 통과 · **Critical 이 남으면 정지** | ⚠️ |
| implementing-ko 비가역·repo 밖 흔적 task | 발생 위치에서 정지 (`AUTO-HARD-GATE` · `NEEDS-APPROVAL`) | 🛑 |
| implementing-ko Phase B/C cap 초과 | systematic-debugging → 전역 재시도 1회 → 재실패 시 정지 | ⚠️ |
| verifying-evidence-ko fix_loop cap 초과 | systematic-debugging → 1회 재시도 → 재실패 시 정지 | ⚠️ |
| security-review-ko Critical/High | 차단 — 무인이어도 자동 통과 금지 | 🛑 |
| performance-test-ko PR 게이트 | 가정 다이제스트 + 개발 중 결정 제시 → [y/n] 단일 확인 | 🛑 |

## `/maintain` 대비

| | `/maintain` | `/maintain-auto` |
|---|---|---|
| 분석 산출물 · 회귀 AC · 리뷰 · verify | ✅ | ✅ (동일) |
| 분석 검토 · 설계 승인 · 명확화 질문 | 사용자 응답 | **자동 통과 + 다이제스트** |
| 사용자 확인 지점 | 4~5회 | PR 직전 1회 (+ 비가역 정지) |

> 분석이 틀리면 "무엇을 보존할지"가 틀린다. 무인에서는 그 검토를 사람이 하지 않으므로, PR 게이트에서 **자동 통과한 분석** 절을 먼저 읽는다.

## 안티패턴

- **자연어로 무인 모드 추론 금지** — "알아서 다 해줘", "승인 건너뛰고" 같은 자연어로 이 커맨드를 추론하지 않는다. 슬래시로만 진입한다(원칙 4 주권).
- **인자 없이 진입** — 대상·변경 설명을 되묻는다
- **인자 내용 2차 판단** — 슬래시 진입 후 첫 skill 호출을 보류하지 않는다
- **비가역 정지를 건너뜀** — 되돌릴 수 없는 작업·repo 밖 흔적은 무인에서도 그 자리에서 멈춘다. 최종 게이트로 미루지 않는다
- **자동 통과한 것을 숨김** — 묻지 않고 정한 것은 전부 PR 게이트의 가정 다이제스트에 나와야 한다
- **신규 기능을 이 커맨드로 진입** — 기존 코드를 고치지 않는 요청이면 `/start-auto` 다

## 참조

- `commands/maintain.md` — 대화형 유지보수 진입
- `commands/start-auto.md` — 무인 동작·가정 다이제스트의 기준
- `skills/analyzing-ko/SKILL.md` — 무인 표지 처리
- `skills/specifying-ko/SKILL.md` — `무인 표지 (둘째 줄)`

---

*specops-ko v2.18.0 · 2026-10-09 · 무인 유지보수 Lifecycle 진입 (분석 검토·설계 승인 자동 통과, 회귀 AC 유지, plan 리뷰 Critical 정지)*
