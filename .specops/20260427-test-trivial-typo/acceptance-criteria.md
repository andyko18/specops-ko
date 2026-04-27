<!-- FID: 20260427-test-trivial-typo -->

# 수락 기준 — 20260427-test-trivial-typo (dogfood)

## 계약 항목

### AC-1: typo 수정

**Given** 변경 전 docs/README.md / **When** typo 수정 / **Then** 정확한 철자 반영
**우선순위**: must

---

## 회귀 방지 AC (유지보수 FID 필수) — 본 FID 면제

§유형 = "trivial" (변경 라인 2 ≤ 5 자동) 이므로 `AC-R-*` 회귀 must AC 강제 면제.
sprint-contracts-ko evaluator 가 trivial 라벨 인식하여 BLOCK 안 함.
