---
name: start
description: "[단일·대화형] specops-ko 한국어 자율 Lifecycle 단일 기능 진입 슬래시 — specops-ko:specifying-ko 호출"
triggers:
  - "/start"
mode: ask
specops_version: 1.61.0
specops_layer: Lifecycle
reference_upstream: obra/superpowers@v5.0.7 commands/brainstorm.md
---

# /start [<기능 설명>]

## 목적

specops-ko 한국어 자율 Lifecycle의 **단일 진입 슬래시**. 자연어 진입(`"X 기능을 만들고 싶어"`)과 **동등한 진입점**이며, 사용자가 명시적으로 Lifecycle을 시작하고 싶을 때 사용.

## Process

1. **메타 skill 활성 확인** — `skills/using-specops-ko/SKILL.md`가 세션 시작 시 이미 활성돼 있어야 함. 아니면 수동으로 `Skill` 도구 호출
2. **즉시 `specops-ko:specifying-ko` 스킬 호출** — 전달된 `<기능 설명>`을 초기 맥락으로 제공
3. **이후 chain** — 각 engine skill 본문의 `## 다음 skill` 섹션이 자동 강제 (specifying-ko → clarifying-ko → planning-ko → decomposing-ko → implementing-ko → verifying-evidence-ko → requesting-code-review-ko → receiving-code-review-ko → security-review-ko → integration-test-ko → performance-test-ko → PR). 본 command는 **specifying-ko 진입만** 책임.
   - **implementing 기본**: `review_mode: end-loaded` — 태스크별 구현(A) 후 FID 단위 스펙·코드 리뷰(B·C) 각 1회. requesting은 end-loaded B/C 산출이 있으면 `review-skip.md`로 중복 리뷰 skip.

## 사용 예

```
/start CSV 줄 수 세기 CLI 만들어줘

→ 메타 skill 활성 확인
→ specops-ko:specifying-ko 호출
→ specifying-ko가 프로젝트 맥락 탐색 + 명확화 질문 시작
→ HARD GATE (설계 승인)
→ 사용자 y → specops-ko:clarifying-ko 자동 호출
→ ... (Lifecycle 자동 진행)
```

## 자연어 진입 vs 슬래시 진입

| 진입 방식 | 동작 | 비고 |
|---|---|---|
| `/start CSV 줄 수 세기 CLI` | 본 command 실행 + `specops-ko:specifying-ko` 호출 | 명시적 진입 |
| `"CSV 줄 수 세기 CLI 만들어줘"` (자연어) | 메타 skill이 신호 감지 → `specops-ko:specifying-ko` 자동 호출 | 암묵적 진입 (PoC v0.0 검증 대상) |

두 방식은 **기능적으로 동등**. PoC v0.0에서 자연어 진입이 실패하면 `/start` 슬래시가 **유일한 진입점**으로 격상 (§15.10 fallback).

## 안티패턴

- **인자 없이 진입** — `/start`만 치면 어떤 기능을 만들지 사용자에게 되물음 (modally). `/start <기능 설명>` 권장
- **인자 내용 2차 판단** — `/start <아무 인자>` 는 인자가 "기능 설명 신호처럼 보이지 않는다"는 이유로 `specops-ko:specifying-ko` 호출을 **보류하지 않는다**. 슬래시 진입 자체가 사용자 의도 확정 신호 (명시적 진입). 인자 적합성은 specifying-ko 가 HARD GATE 로 처리. 메타 skill 의 자연어 신호 감지 로직을 command 레이어에 복제 금지
- **구현 직진 요구** — `/start "그냥 바로 만들어"` 같은 명시 우회도 specifying-ko가 HARD GATE로 **거절**. 5원칙 4 주권 + 안티패턴 "너무 간단해서 설계 불필요" 적용
- **specifying-ko 생략** — /start 이후 planning-ko·implementing-ko를 직접 호출해도 chain 무결성 **깨짐**. 반드시 specifying-ko부터

## 참조

- `skills/using-specops-ko/SKILL.md` — 메타 skill (자동 활성)
- `skills/specifying-ko/SKILL.md` — 첫 Lifecycle 단계
- `skills/structured-artifacts-ko/SKILL.md` — `.specops/<FID>/` 경로 규약
- 설계 근거: specops-ko 설계 케이스 스터디 `2026-04-21-specops-auto-ko-design.md §15.5` (진입 흐름)
- 참조: affaan-m/everything-claude-code@1.2.0 commands/orchestrate.md

---

*specops-ko v1.61.0 · 2026-04-21 · 단일 진입 슬래시 (자연어 진입과 동등)*
