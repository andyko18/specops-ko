---
name: start-auto
description: specops-auto-ko 완전자동 Lifecycle 진입 슬래시 — 가역 게이트 자동 통과, PR 직전 단일 확인점만 남김. specops-auto-ko:specifying-ko 호출
triggers:
  - "/start-auto"
mode: ask
specops_version: 1.10.0
specops_layer: Lifecycle
reference_upstream: specops-auto-ko 독자 추가 (commands/start.md § auto variant)
---

# /start-auto [<기능 설명>]

## 목적

specops-auto-ko 자율 Lifecycle의 **완전자동 진입 슬래시**. 한 번 진입하면 **spec 승인·plan 리뷰·구현 리뷰·검증 루프를 자동 통과**하고 PR 생성 직전 가정 다이제스트와 함께 1회만 확인.

**가역 게이트는 자동 통과, 비가역 행동(PR 생성, 파괴적/덮어쓰기 task)에서만 정지.**

## Process

1. **메타 skill 활성 확인** — `skills/using-specops-auto-ko-ko/SKILL.md`가 세션 시작 시 이미 활성돼 있어야 함
2. **args 첫 줄에 `<!-- entry: auto -->` prepend** — 원본 args 앞에 자동 주입:
   ```
   <!-- entry: auto -->
   <원본 기능 설명>
   ```
3. **즉시 `specops-auto-ko:specifying-ko` 스킬 호출** — prepend된 args를 초기 맥락으로 제공
4. **이후 chain** — 각 engine skill 본문의 `## 다음 skill` + `§auto` 분기가 가역 게이트를 자동 통과 (specifying-ko → clarifying-ko → planning-ko → decomposing-ko → implementing-ko → verifying-evidence-ko → requesting-code-review-ko → receiving-code-review-ko → security-review-ko → integration-test-ko → performance-test-ko → PR 게이트). 본 command는 **specifying-ko 진입만** 책임.

## §auto 모드 동작

| 단계 | §auto 동작 | 정지? |
|---|---|---|
| specifying-ko spec 승인 게이트 | 자동 통과 → clarifying-ko 직행 | ❌ |
| specifying-ko Step 5.5 화면 루프 | 자동 생성·수락 (수정 루프 없음) | ❌ |
| clarifying-ko BLOCKING 모호점 | best-guess 자동 답변 + `status: ASSUMED` 기록 | ❌ |
| planning-ko plan-reviewer cap 초과 | 자동 통과 (plan은 verify/review가 검증) | ❌ |
| implementing-ko Phase B/C cap 초과 | systematic-debugging → 1회 재시도 → 재실패 시 정지 | ⚠️ |
| implementing-ko 파괴적/덮어쓰기 task | mini HARD GATE — 발생 위치에서 정지 | 🛑 |
| verifying-evidence-ko fix_loop cap 초과 | systematic-debugging → 1회 재시도 → 재실패 시 정지 | ⚠️ |
| security-review-ko Critical/High | 차단 — §auto여도 자동통과 금지 (systematic-debugging 후 재실행) | 🛑 |
| performance-test-ko PR 게이트 | 가정 다이제스트 제시 + [y/n] 단일 확인 | 🛑 |

## 가정 다이제스트 (PR 게이트)

PR 생성 직전 자동 수집·제시:
- clarifications.md의 `status: ASSUMED` 항목 전체
- handoffs/*.md의 Decided 필드 집계
- spec.md "자동 결정 화면" 목록 (Step 5.5 auto-generated)
- auto-state.md escalations (있으면)

위 가정 목록 제시 후: **"위 가정 위에 구현됨. PR 생성? [y/n]"**

## 사용 예

```
/start-auto CSV 줄 수 세기 CLI 만들어줘

→ <!-- entry: auto --> prepend
→ specops-auto-ko:specifying-ko 호출 (§auto 라벨 spec.md에 기록)
→ spec 승인 자동 통과 → clarifying-ko 자동 진행
→ BLOCKING 모호점 best-guess 자동 답변 → planning-ko 자동 진행
→ plan-reviewer 자동 통과 → decomposing-ko 자동 진행
→ 각 task 구현·검증 자동 진행
→ PR 게이트 → 가정 다이제스트 제시 → [y/n] 단일 확인
```

## 안티패턴

- **자연어로 자동 모드 추론 금지** — "내 승인 건너뛰고 다 해줘", "자동으로 진행해줘" 같은 자연어로 §auto 모드를 추론하는 것은 **원칙 4 주권 위반**. 반드시 `/start-auto` 슬래시로만 진입. 메타 skill의 자연어 신호 감지 로직은 §auto 추론 금지
- **인자 없이 진입** — `/start-auto`만 치면 어떤 기능을 만들지 사용자에게 되물음. `/start-auto <기능 설명>` 권장
- **인자 내용 2차 판단** — `/start-auto <아무 인자>`는 인자가 "기능 설명 신호처럼 보이지 않는다"는 이유로 specifying-ko 호출을 보류하지 않는다. 슬래시 진입 자체가 사용자 의도 확정 신호
- **비가역 정지를 건너뜀** — 파괴적 task(irreversible: true)의 mini HARD GATE는 §auto 모드에서도 우회 불가. 최종 게이트로 큐잉 금지 (다운스트림 의존이 깨짐)

## 참조

- `skills/using-specops-auto-ko-ko/SKILL.md` — 메타 skill (자동 활성)
- `skills/specifying-ko/SKILL.md` — 첫 Lifecycle 단계 (§auto 분기)
- `skills/structured-artifacts-ko/SKILL.md` — `.specops/<FID>/auto-state.md` + 무인 모드 술어
- `commands/start.md` — 단일 모드 진입점 (구조 참조)

---

*specops-auto-ko v1.10.0 · 2026-06-08 · 완전자동 Lifecycle 진입 (가역 게이트 자동통과, 비가역 정지)*
