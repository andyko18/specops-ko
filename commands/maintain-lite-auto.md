---
name: maintain-lite-auto
disable-model-invocation: true
description: "[유지보수·경량·무인] analyzing-mini + clarify·plan 생략 + 분석·설계 승인 자동 통과 — 화면/IF·Phase B/C·verify·AC-R-1 유지, 고위험이면 풀 무인 경로로 자동 승격, PR 직전 단일 확인"
triggers:
  - "/maintain-lite-auto"
mode: ask
specops_version: 2.14.0
specops_layer: Lifecycle
reference_upstream: specops-ko 독자 추가 (commands/maintain-lite.md § auto variant)
---

# /maintain-lite-auto [<대상 또는 변경 설명>]

## 목적

`/maintain-lite` 의 **무인 변형**. mini 분석 → 명세 → 구현 → 검증 → 리뷰를 사용자 응답 없이 끝까지 진행하고, PR 생성 직전에 **1회만** 확인한다. 작은 버그 수정·소규모 개선용이다.

**사람의 검토가 가장 적은 경로다** — 분석 검토·설계 승인이 자동 통과고 명확화·계획 리뷰가 없다. 회귀 AC(`AC-R-1`)·Phase B/C·verify 는 그대로다.

## Process

1. **메타 skill 활성 확인**
2. **args 앞 두 줄 prepend**:
   ```
   <!-- entry: maintain-lite -->
   <!-- auto: true -->
   <원본 대상·변경 설명>
   ```
3. **즉시 `specops-ko:analyzing-ko` 호출** — `[lite-mini 분기]` + 무인 표지: mini 분석 산출물 2종을 만들고 검토 게이트를 자동 통과한다
4. **`specifying-ko` [maintain-lite 분기]** — args 그대로. spec §1 에 `**§유형**: 유지보수` · `**§lite**: true` · `**§auto**: true` · `**자동 결정 분석**` 을 적는다
5. **이후 chain**: decomposing(1 task) → implementing(A + end-loaded B/C) → verifying → security → integration → performance → PR 게이트

## 고위험이면 자동 승격

strict 신호(auth·migration·결제/PII·파괴적 스키마 등)에서 `/maintain-lite` 는 멈추고 `/maintain` 을 안내한다. 무인에서는 **멈추지 않고 풀 무인 경로로 승격**한다.

- 분석 단계에서 신호가 보이면: mini 대신 **풀 분석 체크리스트**를 돌리고 `/maintain-auto` 와 같은 경로(clarify → plan → plan 리뷰를 무인으로)로 간다. analyzing 이 args 에 `<!-- promoted: lite -->` 를 더해 승격 사실을 넘긴다
- 분해 단계에서 `LITE-STRICT-GUARD`(`risk-profile.sh` rc=3)가 잡으면: 분석을 풀 체크리스트 기준으로 보강한 뒤 clarify → plan 을 무인으로 수행하고 분해를 다시 한다
- 승격 사실은 가정 다이제스트에 남는다. `SPECOPS_LITE_STRICT_OVERRIDE` 로 가드를 끄지 않는다

## 무인 동작

| 단계 | 무인 동작 | 정지? |
|---|---|---|
| analyzing-ko mini 분석 검토 게이트 | 자동 통과 — 분석 요약을 PR 게이트 다이제스트에 싣는다 | ❌ |
| specifying-ko intent·설계·스펙 승인 | 자동 통과 (추정 항목은 `(ASSUMED)`) | ❌ |
| strict 신호 · `LITE-STRICT-GUARD` | 풀 무인 경로로 자동 승격 | ❌ |
| implementing-ko 비가역·repo 밖 흔적 task | 발생 위치에서 정지 (`AUTO-HARD-GATE` · `NEEDS-APPROVAL`) | 🛑 |
| implementing-ko Phase B/C cap 초과 | systematic-debugging → 전역 재시도 1회 → 재실패 시 정지 | ⚠️ |
| verifying-evidence-ko fix_loop cap 초과 | systematic-debugging → 1회 재시도 → 재실패 시 정지 | ⚠️ |
| security-review-ko Critical/High | 차단 — 무인이어도 자동 통과 금지 | 🛑 |
| performance-test-ko PR 게이트 | 가정 다이제스트 + 개발 중 결정 제시 → [y/n] 단일 확인 | 🛑 |

## 안티패턴

- **자연어로 무인 모드 추론 금지** — "알아서 다 해줘", "승인 건너뛰고" 같은 자연어로 이 커맨드를 추론하지 않는다. 슬래시로만 진입한다(원칙 4 주권).
- **인자 없이 진입** — 대상·변경 설명을 되묻는다
- **인자 내용 2차 판단** — 슬래시 진입 후 첫 skill 호출을 보류하지 않는다
- **비가역 정지를 건너뜀** — 되돌릴 수 없는 작업·repo 밖 흔적은 무인에서도 그 자리에서 멈춘다. 최종 게이트로 미루지 않는다
- **자동 통과한 것을 숨김** — 묻지 않고 정한 것은 전부 PR 게이트의 가정 다이제스트에 나와야 한다
- **analyzing 완전 skip** — mini 라도 baseline·회귀 요약은 필수다(`AC-R-1` 의 근거)
- **화면·IF·Phase B/C·verify 생략** — 축약되는 것은 clarify·plan 과 사람의 확인뿐이다
- **신규 기능을 이 커맨드로 진입** — 기존 코드를 고치지 않는 요청이면 `/start-lite-auto` 다

## 참조

- `commands/maintain-lite.md` — 대화형 경량 유지보수 진입
- `commands/maintain-auto.md` — 무인 유지보수(풀 경로) · 승격 시 따르는 경로
- `commands/start-lite-auto.md` — 경량 신규 무인 자매
- `skills/analyzing-ko/SKILL.md` — `[lite-mini 분기]` · 무인 표지 처리
- `skills/specifying-ko/SKILL.md` — `[maintain-lite 분기]` · `무인 표지 (둘째 줄)`

---

*specops-ko v2.14.0 · 2026-10-08 · 경량 유지보수 무인 Lifecycle 진입 (analyze-mini + 승인 자동 통과, strict 자동 승격)*
