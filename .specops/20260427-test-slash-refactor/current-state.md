<!-- FID: 20260427-test-slash-refactor -->
<!-- OWNER_COMMAND: /maintain (Phase D dogfood) -->

# 현재 시스템 분석 — 20260427-test-slash-refactor

> D4 dogfood: `/maintain payment 모듈 리팩터링` 슬래시 진입 시뮬.

## 1. 변경 대상 식별

- 파일: `src/payment/processor.js` (Lines: 80-145 — 합산 66 라인, > 5 → 유지보수)
- 진입점: `processPayment()`

## 2. 호출자/의존 매핑

- 호출자: `src/api/checkout.js`, `src/admin/refund.js`
- 의존: `stripe-sdk` (외부)

## 3. 기존 테스트 커버리지

- 관련 테스트: `tests/payment.test.ts` (5 케이스)

## 4. 관찰 가능 동작

| # | Input | 현재 Output |
|---|---|---|
| 1 | 정상 카드 결제 | success |
| 2 | 만료 카드 | declined |

## 5. 회귀 위험 메모

- 리팩터링이라 동작 변경 없어야 함 → AC-R 다수 필요
