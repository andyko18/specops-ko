---
name: start-lite-auto
disable-model-invocation: true
description: "[단일·경량·무인] clarify·plan 생략 + 설계 승인 자동 통과 — 화면/IF·Phase B/C·verify 유지, 고위험이면 풀 무인 경로로 자동 승격, PR 직전 단일 확인. specops-ko:specifying-ko 호출"
triggers:
  - "/start-lite-auto"
mode: ask
specops_version: 2.14.0
specops_layer: Lifecycle
reference_upstream: specops-ko 독자 추가 (commands/start-lite.md § auto variant)
---

# /start-lite-auto [<기능 설명>]

## 목적

`/start-lite` 의 **무인 변형**. clarify·plan 을 생략하는 경량 경로를 사용자 응답 없이 끝까지 진행하고, PR 생성 직전에 **1회만** 확인한다.

**사람의 검토가 가장 적은 경로다** — 명확화·계획 리뷰가 없고 설계 승인도 자동 통과다. 설계를 보는 것은 스펙 리뷰어(Phase B)·코드 리뷰어(Phase C)와 verify 뿐이다. 작은 변경에만 쓴다.

## Process

1. **메타 skill 활성 확인**
2. **args 앞 두 줄 prepend**:
   ```
   <!-- entry: lite -->
   <!-- auto: true -->
   <원본 기능 설명>
   ```
3. **즉시 `specops-ko:specifying-ko` 호출** — `[lite 분기]` + 무인 표지. spec §1 에 `**§lite**: true` · `**§유형**: trivial` · `**§auto**: true` 를 적고 설계·스펙 승인을 자동 통과한다
4. **이후 chain**: decomposing(1 task) → implementing(A + end-loaded B/C) → verifying → security → integration → performance → PR 게이트

## 고위험이면 자동 승격

`/start-lite` 는 strict 신호(auth·migration·결제/PII·파괴적 스키마 등)에서 멈추고 `/start` 를 안내한다. 무인에서는 **멈추지 않고 풀 무인 경로로 승격**한다 — 묻는 대신 검토 단계를 더 거친다.

- 진입 직후 신호가 보이면: `§lite` 를 쓰지 않고 `§유형: 신규` 로 적어 `/start-auto` 와 같은 경로(clarify → plan → plan 리뷰를 무인으로)로 간다
- 분해 단계에서 `LITE-STRICT-GUARD`(`risk-profile.sh` rc=3)가 잡으면: 제자리에서 clarify → plan 을 무인으로 수행한 뒤 분해를 다시 한다
- 승격 사실은 가정 다이제스트에 남는다. `SPECOPS_LITE_STRICT_OVERRIDE` 로 가드를 끄지 않는다

## 무인 동작

| 단계 | 무인 동작 | 정지? |
|---|---|---|
| specifying-ko intent·설계·스펙 승인 | 자동 통과 (추정 항목은 `(ASSUMED)`) | ❌ |
| 화면(5.5)·인터페이스(5.6) | 해당 시 자동 생성·반영 (`/start-auto` 와 동일) | ❌ |
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
- **화면·IF·Phase B/C·verify 생략** — 축약되는 것은 clarify·plan 과 사람의 확인뿐이다
- **큰 변경에 사용** — 구현 파일이 여럿이거나 AC 가 4건을 넘으면 분해 단계가 풀 경로로 올린다. 처음부터 `/start-auto` 가 맞다

## 참조

- `commands/start-lite.md` — 대화형 경량 진입
- `commands/start-auto.md` — 무인 동작·가정 다이제스트의 기준
- `commands/maintain-lite-auto.md` — 경량 유지보수 무인 자매
- `skills/specifying-ko/SKILL.md` — `[lite 분기]` · `무인 표지 (둘째 줄)`

---

*specops-ko v2.14.0 · 2026-10-08 · 경량 신규 무인 Lifecycle 진입 (clarify·plan 생략 + 승인 자동 통과, strict 자동 승격)*
