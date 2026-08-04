---
name: start-lite
description: "[단일·경량] clarify·plan ceremony 생략 Lifecycle 진입 — 화면/IF·Phase B/C·verify 유지. specops-ko:specifying-ko 호출"
triggers:
  - "/start-lite"
mode: ask
specops_version: 1.60.0
specops_layer: Lifecycle
reference_upstream: specops-ko 독자 추가 (commands/start.md § lite variant)
---

# /start-lite [<기능 설명>]

## 목적

`/start` 대비 **토큰 절감 진입**. clarify·plan ceremony만 생략하고, **화면(Step 5.5)·인터페이스(Step 5.6)·implement Phase B/C·verify/TDD/receipt**는 `/start`와 동일하게 유지한다.

슬래시 진입 = 축약 승인(별도 "축약할까요?" 질문 없음).

## Process

1. **메타 skill 활성 확인** — `skills/using-specops-ko/SKILL.md`가 세션 시작 시 이미 활성
2. **args 첫 줄에 `<!-- entry: lite -->` prepend**:
   ```
   <!-- entry: lite -->
   <원본 기능 설명>
   ```
3. **즉시 `specops-ko:specifying-ko` 호출** — prepend된 args 전달
4. **이후 chain (lite)**: specifying(화면/IF 포함) → decomposing(1 task) → implementing(A + end-loaded B/C) → verifying → requesting(end-loaded skip) → receiving → security → integration → performance → PR. clarifying·planning **호출 금지**.

## `/start` 대비

| 단계 | `/start` | `/start-lite` |
|---|---|---|
| clarifying / planning | ✅ | **skip** |
| 화면 5.5 / IF 5.6 | 조건부 ✅ | **동일 유지** |
| decompose | N tasks | **1 task** |
| Phase B/C | end-loaded ✅ | **필수 유지** |
| verify · TDD · receipt | ✅ | ✅ |
| request/receive | 수행 또는 end-loaded skip | end-loaded skip |

**strict 승격**: auth·migration·결제/PII·파괴적 스키마 등 strict 신호면 거부 후 `/start` 안내.

## 사용 예

```
/start-lite CSV 줄 수 세기 CLI

→ <!-- entry: lite --> prepend
→ specifying-ko (§lite + §유형 trivial, 화면/IF 해당 시 동일)
→ clarify/plan SKIP → decomposing 1 task → implement B/C → verify → …
```

## 안티패턴

- **자연어로 lite 추론 금지** — "가볍게 해줘" 등으로 `/start-lite`를 추론하지 않는다. 슬래시만. 원칙 4 주권.
- **인자 없이 진입** — 기능 설명을 modally 되묻기
- **인자 내용 2차 판단** — 슬래시 진입 후 specifying 호출 보류 금지
- **화면·IF 생략** — lite라도 UI/API·스키마 해당 시 Step 5.5/5.6 제외 금지
- **Phase B/C·verify 생략** — ceremony 축약이지 teeth 축약이 아님
- **고위험에 lite 고집** — strict 신호 시 `/start`로 승격

## 참조

- `commands/start.md` — 풀 신규 진입
- `commands/maintain-lite.md` — 경량 유지보수 자매
- `skills/specifying-ko/SKILL.md` — `[lite 분기]`

---

*specops-ko v1.60.0 · 2026-08-04 · 경량 신규 Lifecycle 진입 (clarify·plan skip, 화면/IF·B/C 유지)*
