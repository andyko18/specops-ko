<!-- FID: 20260427-test-bugfix-fixture -->
<!-- OWNER_COMMAND: sprint-contracts-ko (Evaluator) -->
<!-- layer: Lifecycle-Artifact -->

# Sprint-Contracts 평가 — 20260427-test-bugfix-fixture

## 입력 산출물

- `spec.md` (§유형 = 유지보수)
- `acceptance-criteria.md` (AC-1 must, AC-R-1 must)

## 체크리스트

- [x] `acceptance-criteria.md` 전문을 읽었는가? → YES
- [x] 산출물이 각 `must` AC 를 충족하는지 하나씩 확인했는가? → fixture 메타 검증 (실제 코드 산출물 없음, 본 fixture 의 검증 대상은 룰 적용 자체)
- [x] 미충족 AC 를 명시적으로 나열했는가? → 미충족 없음
- [x] 계약에 없는 기능을 평가하지 않았는가? → scope 준수
- [x] 판정 결과를 JSON 블록으로 기록 → 본 파일 하단
- [x] 유지보수 FID 회귀 방지 must AC (`AC-R-*`) ≥ 1 포함 확인 → **AC-R-1 (must) 1 개 포함, 충족**

## 판정 근거

1. **§유형 = 유지보수** (`spec.md` L9) → 회귀 AC 게이트 발동.
2. **AC-R-1 = must** (`acceptance-criteria.md` L23–31) → 회귀 AC ≥ 1 충족.
3. AC-1 / AC-R-1 모두 Given/When/Then 형식 준수, 우선순위 명시, 구현 디테일 없음.
4. `spec.md` §성공 판정 (L14) — 회귀 AC 1 개 → **PASS** 시뮬 분기 일치.

## 판정 JSON

```json
{
  "fid": "20260427-test-bugfix-fixture",
  "evaluator": "sprint-contracts-ko",
  "timestamp": "2026-04-27T00:00:00Z",
  "verdict": "PASS",
  "ac_results": [
    {"ac": "AC-1", "pass": true},
    {"ac": "AC-R-1", "pass": true}
  ],
  "blocking_acs": [],
  "regression_ac_count": 1,
  "regression_gate": "exempt-by-presence"
}
```

## 비고

- 본 FID 는 dogfood fixture. 회귀 AC 0 개 → BLOCK 분기 시뮬은 `acceptance-criteria.md` 의 §회귀 방지 AC 섹션을 제거한 후 재평가하면 검증 가능 (현재 PASS 분기만 검증).
- `§유형 = trivial` 면제 조건은 본 fixture 에 해당하지 않음 (변경 라인 ≤ 5 자동 토큰 부재, 명시적 §유형 = 유지보수).

---

*평가: sprint-contracts-ko Evaluator · 2026-04-27 · FID: 20260427-test-bugfix-fixture*
