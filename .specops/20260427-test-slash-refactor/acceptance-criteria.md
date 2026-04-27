<!-- FID: 20260427-test-slash-refactor -->

# 수락 기준 — 20260427-test-slash-refactor (dogfood)

## 계약 항목

### AC-1: 가독성 개선

**Given** 변경 전 processor.js / **When** 리팩터 후 / **Then** 가독성 향상 (행동 동등)
**우선순위**: must

---

## 회귀 방지 AC (유지보수 FID 필수)

### AC-R-1: 정상 결제 흐름 보존

**Given** 정상 카드 / **When** processPayment / **Then** success — current-state.md §4 Input 1 동등
**우선순위**: must

### AC-R-2: 만료 카드 흐름 보존

**Given** 만료 카드 / **When** processPayment / **Then** declined — current-state.md §4 Input 2 동등
**우선순위**: must
