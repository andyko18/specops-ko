---
name: sprint-contracts-ko
description: acceptance-criteria.md를 스프린트 계약서로 취급하고, Evaluator는 오직 계약서와 산출물만 비교한다
layer: 3
reference_upstream: revfactory/harness@v1.0 skills/sprint-contracts/SKILL.md
specops_version: 1.0.0
used_by: specops-auto-ko:implementing-ko (spec-reviewer-ko 서브에이전트 dispatch 시 AC 계약 검증), specops-auto-ko:clarifying-ko (AC append)
---

# Harness 기법 4 — Sprint Contracts

## 개념

`acceptance-criteria.md`는 **계약서**다. 이후 모든 단계의 판정 기준이 된다. Evaluator는 계약서와 산출물만 비교하고, 구현 세부사항을 평가하지 않는다.

## 계약 항목 템플릿 (Given/When/Then)

```markdown
### AC-1: <기능 이름>

**Given** <전제 조건·초기 상태>
**When** <사용자/시스템 동작>
**Then** <관찰 가능한 결과>

**검증 방법**: <수동 재현 단계 또는 자동 테스트 경로>
**우선순위**: must | should | nice-to-have
```

예:

```markdown
### AC-3: 캐시 만료 재조회

**Given** 캐시 유효기간이 60초로 설정되어 있고, 60초가 경과한 상태에서
**When** 동일 키로 조회 요청이 들어오면
**Then** 원본 API가 호출되고 응답이 새 캐시에 저장된다

**검증 방법**: `pytest tests/test_cache.py::test_expiry_refetch`
**우선순위**: must
```

## 규칙

1. `acceptance-criteria.md`는 `/specify` 시점에 작성. `/clarify`에서만 **수정 가능**, 이후 단계는 **읽기 전용**.
2. 모든 AC는 **관찰 가능한 결과**로 서술. "내부적으로 ... 호출" 같은 구현 디테일 금지.
3. 우선순위: `must` 항목 전부 충족되지 않으면 `/verify`는 PASS 불가.
4. Evaluator는 계약서의 AC 번호로 참조(`AC-3 실패`)하여 판정.

## 체크리스트 (Evaluator)

- [ ] `acceptance-criteria.md` 전문을 읽었는가?
- [ ] 산출물이 각 `must` AC를 충족하는지 하나씩 확인했는가?
- [ ] 미충족 AC를 명시적으로 나열했는가? (번호·이유)
- [ ] 계약에 없는 기능을 평가하지 않았는가? (scope creep 방지)
- [ ] 판정 결과를 `analysis.md`/`review.md`/`verify.md`에 JSON 블록으로 기록했는가?
- [ ] 유지보수 FID (`spec.md §유형 = 유지보수`) 인 경우 회귀 방지 must AC (`AC-R-*`) ≥ 1 포함 확인 — 미포함 시 `verdict = BLOCK`. 단 `§유형 = trivial` (변경 라인 ≤ 5 자동) 인 경우 면제

## 판정 JSON 블록 포맷

```json
{
  "fid": "20260420-rss-cache",
  "evaluator": "analyzer-ko",
  "timestamp": "2026-04-20T12:00:00Z",
  "verdict": "PASS | BLOCK",
  "ac_results": [
    {"ac": "AC-1", "pass": true},
    {"ac": "AC-3", "pass": false, "reason": "캐시 만료 후 재조회 시 stale 값 반환됨 (tests/test_cache.py::test_expiry_refetch 실패)"}
  ],
  "blocking_acs": ["AC-3"]
}
```

## 안티패턴

- 계약서에 **구현 방법**을 적음 (예: "Redis를 사용한다") → Given/When/Then 형식 이탈
- `/specify` 이후 계약 변경 — 추가 요구사항은 `/clarify`에서만 반영
- Evaluator가 계약에 없는 품질 기준으로 BLOCK (개인 취향) → 계약 재협상이 필요
- `must`와 `should`를 구분하지 않음 — 우선순위 없이 모두 BLOCK 사유가 됨
- **회귀 AC 없는 유지보수 FID** — `§유형 = 유지보수` 인데 `AC-R-*` 0 개로 작성. **회귀 검증 근거 없음** → BLOCK. clarifying-ko 단계에서 `AC-R-*` append 가능. `§유형 = trivial` (변경 라인 ≤ 5 자동) 시에만 면제

## 예시: BLOCK 판정

```markdown
# analysis.md

## 판정: BLOCK

### 차단 AC
- AC-3 (캐시 만료 재조회): `tasks.md`의 태스크 5가 만료 처리 로직을 포함하지 않음
- AC-7 (에러 로깅): `plan.md` §3에서 로깅 모듈 책임 미명시

### 권고
planner-ko 재호출 필요. `/plan 20260420-rss-cache` 재실행.
```
