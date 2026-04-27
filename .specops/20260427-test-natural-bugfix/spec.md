<!-- FID: 20260427-test-natural-bugfix -->
<!-- OWNER_COMMAND: /specify (유지보수 분기, dogfood) -->

# auth.js 토큰 만료 버그 수정 — 20260427-test-natural-bugfix

## 1. 개요

**§유형**: 유지보수 (라인 합산 8 > 5 — trivial 아님. specifying-ko Step 6 §유형 자동 부여 결과)
**목적**: A4 dogfood — 자연어 maintenance 진입 + §유형 자동 라벨 + 회귀 AC 강제 검증.

**배경**: validateToken() 이 만료 토큰에 200 반환하는 버그.

## 2. 범위

### 포함
- src/auth.js validateToken() 만료 처리 수정

### 제외 (YAGNI)
- 다른 인증 흐름 변경

## §참조

- `current-state.md` — Phase A specifying-ko Step 1 산출
- `acceptance-criteria.md` — AC-1 + AC-R-1

---

*A4 dogfood · FID: 20260427-test-natural-bugfix*
