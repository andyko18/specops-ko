<!-- FID: <YYYYMMDD-kebab-slug> -->
<!-- OWNER_COMMAND: /analyze -->
<!-- EVALUATOR: analyzer-ko -->
<!-- reference_upstream: github/spec-kit analysis-template + sprint-contracts -->
<!-- layer: Lifecycle-Artifact (Evaluator 산출) -->

# 일관성 분석 — <FID>

> analyzer-ko(Evaluator)가 spec·acceptance-criteria·plan·tasks를 교차 검토한 결과입니다. 여기서 BLOCK 판정 시 해당 단계 Generator를 재호출합니다.

## 판정 요약

```json
{
  "fid": "<FID>",
  "evaluator": "analyzer-ko",
  "timestamp": "<YYYY-MM-DDTHH:MM:SSZ>",
  "verdict": "PASS | BLOCK",
  "blocking_acs": [],
  "unresolved_open_questions": []
}
```

## 1. AC 매핑 매트릭스

`acceptance-criteria.md`의 각 AC가 `plan.md` · `tasks.md`에 매핑되는지.

| AC | 플랜 섹션 | 태스크 | 상태 |
|---|---|---|---|
| AC-1 | §2 파일 구조·§5.1 | 태스크 1, 2 | ✅ |
| AC-2 | §5.2 | 태스크 3 | ✅ |
| AC-3 | (미매핑) | — | ❌ BLOCK |
| AC-4 | §5.3 | 태스크 5 | ⚠️ 약함 |

## 2. 열린 질문 해소

`spec.md` §8의 열린 질문이 `clarifications.md`에서 답변됐는지.

| Q | 답변 | 플랜 반영 |
|---|---|---|
| Q1 | ✅ clarifications.md §1 | 플랜 §3 |
| Q2 | ✅ | 플랜 §4 |
| Q3 | ❌ 미답변 | — |

## 3. 가정 점검

`spec.md` §7 · `plan.md` §1의 가정이 여전히 유효한가?

- ✅ 가정 1: 코드베이스 내 검증됨
- ⚠️ 가정 2: 검증 필요 — `/plan` 재실행 시 실제 확인

## 4. TDD 준수 점검

`tasks.md`의 각 태스크가 RED→GREEN→REFACTOR 5 스텝을 갖추는가?

- 태스크 1: ✅
- 태스크 2: ✅
- 태스크 3: ⚠️ 스텝 2(실패 확인) 누락
- ...

## 5. 파괴적 작업 점검 (문지기)

`plan.md`·`tasks.md`의 파괴적 작업이 **확인 스텝·⚠️ 표기**를 갖추는가?

- 태스크 N (파일 삭제): ✅ 확인 스텝 존재
- 데이터 마이그레이션: ❌ 별도 스텝 없음 — BLOCK

## 6. 차단 사유 요약

verdict가 BLOCK일 때 차단 사유를 번호·이유·권고 3요소로.

### BLOCK-1
- **AC**: AC-3
- **이유**: tasks.md에서 AC-3에 매핑되는 태스크 없음
- **권고**: planner-ko 재호출. `/plan <FID>` 재실행. plan.md §5에 AC-3용 태스크 추가.

### BLOCK-2
- **AC**: (파괴적 작업)
- **이유**: 태스크 M에 데이터 마이그레이션이 있으나 확인 스텝 없음
- **권고**: task-decomposer-ko 재호출. `/tasks <FID>` 재실행. 태스크 M에 사용자 승인 스텝 추가.

## 7. 권고 다음 단계

- `verdict: BLOCK` → 사용자에게 차단 사유를 제시하고, 재호출할 커맨드 안내
- `verdict: PASS` → `/implement <FID>` 진행 가능

---

*작성: analyzer-ko · <날짜> · FID: <FID> · 생성 커맨드: /analyze*
