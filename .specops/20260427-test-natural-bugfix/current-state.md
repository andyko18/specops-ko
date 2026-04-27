<!-- FID: 20260427-test-natural-bugfix -->
<!-- OWNER_COMMAND: /specify (유지보수 분기, dogfood) -->

# 현재 시스템 분석 (Current State) — 20260427-test-natural-bugfix

> A4 dogfood: 자연어 "auth.js 토큰 만료 버그 고쳐줘" maintenance 진입 시뮬. Phase A 단독 시점 — args 첫 줄 = `<!-- entry: maintain -->` 수동 시뮬.

## 1. 변경 대상 식별

- 파일: `src/auth.js` (Lines: 142-149 — 합산 8 라인, > 5 → trivial 아님 → 유지보수)
- 진입점 함수/심볼: `validateToken()`
- 관련 모듈: `src/api/middleware.js` (validateToken 호출자)

## 2. 호출자/의존 매핑

- 호출자: `grep -rn 'validateToken' src/ tests/` — `src/api/middleware.js:34`, `tests/auth.test.ts::token-*`
- 의존: `jsonwebtoken` (외부), `src/config/auth.js` (내부)

## 3. 기존 테스트 커버리지

- 관련 테스트: `tests/auth.test.ts::token-expiry-*` (3 케이스)
- 커버되지 않는 경로: 만료 epsilon edge (만료 직전 1 초 이내)

## 4. 관찰 가능 동작 (Baseline)

| # | Input | 현재 Output | 비고 |
|---|---|---|---|
| 1 | 만료 토큰 | 200 OK (버그 — 401 기대) | 본 fix 대상 |
| 2 | 정상 토큰 | 200 OK | 회귀 보존 대상 |
| 3 | 잘못된 서명 | 401 | 기존 정상 동작 |

## 5. 회귀 위험 메모

- 변경이 정상 토큰 흐름 (Input 2) 에 영향 → AC-R-1 회귀 AC 필수

---

*A4 dogfood · 2026-04-27 · FID: 20260427-test-natural-bugfix*
