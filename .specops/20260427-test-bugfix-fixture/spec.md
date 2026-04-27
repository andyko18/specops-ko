<!-- FID: 20260427-test-bugfix-fixture -->
<!-- OWNER_COMMAND: /specify (dogfood fixture) -->
<!-- layer: Lifecycle-Artifact -->

# Test Bugfix Fixture — 20260427-test-bugfix-fixture

## 1. 개요

**§유형**: 유지보수
**목적**: B Phase fixture — 회귀 AC 강제 검증용 dogfood. sprint-contracts-ko evaluator 가 `§유형 = 유지보수` + `AC-R-* 0 개` 케이스에서 BLOCK 판정하는지 검증.

**배경**: 본 FID 는 implementation 대상이 아니라 **검증 fixture**. acceptance-criteria.md 의 회귀 AC 갯수 토글로 BLOCK / PASS 시뮬.

**성공 판정**: sprint-contracts-ko 룰 적용 시 (a) 회귀 AC 0 개 → BLOCK / (b) 회귀 AC 1 개 → PASS 로 판정.

## 2. 범위

### 포함
- 가상 토큰 만료 처리 변경 (실제 코드 없음 — fixture 메타만)

### 제외 (YAGNI)
- 실제 auth.js 수정 (fixture 라 코드 변경 없음)
- 실 evaluator 호출 (수동 grep 시뮬)

## 3. 사용자 시나리오

**사용자**: B Phase 검증 운영자
**상황**: sprint-contracts-ko 룰 동작 시뮬
**행동**: acceptance-criteria.md 의 AC-R-* 카운트 토글 후 grep 검증
**기대 결과**: 0 개 → BLOCK 근거 / 1 개 → PASS 근거

---

*작성: B3 dogfood · 2026-04-27 · FID: 20260427-test-bugfix-fixture*
