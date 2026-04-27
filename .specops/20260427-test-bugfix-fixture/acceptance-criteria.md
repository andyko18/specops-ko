<!-- FID: 20260427-test-bugfix-fixture -->
<!-- OWNER_COMMAND: /specify (dogfood) -->

# 수락 기준 — 20260427-test-bugfix-fixture

> §유형 = 유지보수. 본 fixture 는 회귀 AC 갯수 토글로 BLOCK / PASS 시뮬.

## 계약 항목

### AC-1: 토큰 만료 처리

**Given** 만료 토큰
**When** API 호출
**Then** 401 반환

**검증 방법**: 가상 시나리오 (fixture)
**우선순위**: must

---

## 회귀 방지 AC (유지보수 FID 필수)

### AC-R-1: 기존 정상 토큰 흐름 보존

**Given** 정상 토큰 (만료 전)
**When** 동일 API 호출
**Then** 200 반환 — 변경 없음

**검증 방법**: 가상 회귀 테스트 (fixture)
**관련 FR**: 회귀 방지
**우선순위**: must

---

## 우선순위 규약

- **must**: BLOCK 가능
- **should**: 미충족 시 사유 기록
