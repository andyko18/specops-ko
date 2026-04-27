<!-- FID: 20260427-test-natural-bugfix -->

# 수락 기준 — 20260427-test-natural-bugfix (dogfood)

## 계약 항목

### AC-1: 만료 토큰 401 반환

**Given** 만료 토큰 / **When** API 호출 / **Then** 401 반환 (현재 버그 = 200 반환)
**우선순위**: must

---

## 회귀 방지 AC (유지보수 FID 필수)

### AC-R-1: 정상 토큰 흐름 보존

**Given** 정상 토큰 / **When** API 호출 / **Then** 200 반환 — 변경 없음 (current-state.md §4 Input 2 baseline)
**우선순위**: must
