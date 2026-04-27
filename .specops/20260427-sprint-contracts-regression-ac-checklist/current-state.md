<!-- FID: 20260427-sprint-contracts-regression-ac-checklist -->
<!-- OWNER_COMMAND: /maintain → analyzing-ko -->
<!-- entry: maintain -->

# Current State — sprint-contracts-ko 회귀 AC 체크리스트 항목 본문

## 1. 변경 대상 식별

- **파일**: `skills/sprint-contracts-ko/SKILL.md`
- **1 차 라인**: line 55 — Evaluator 체크리스트 6 번째 항목 본문
- **2 차 라인 (잠재 정합)**: line 79 — 안티패턴 "회귀 AC 없는 유지보수 FID" 항목 본문 (의미 dual location)
- **추정 변경 라인 합산**: 1 ~ 5 라인 (체크리스트 단일 항목 본문 wording 위주, 안티패턴 정합 동시 수정 시 +1 ~ +3 라인)
- **trivial 자동 판정 source 메타**: `≤ 5` → `**§유형**: trivial` 후보 (specifying-ko Step 6 에서 확정. 사용자 자기선언 거부 가능)

### 본문 원문 (line 55)

```markdown
- [ ] 유지보수 FID (`spec.md §유형 = 유지보수`) 인 경우 회귀 방지 must AC (`AC-R-*`) ≥ 1 포함 확인 — 미포함 시 `verdict = BLOCK`. 단 `§유형 = trivial` (변경 라인 ≤ 5 자동) 인 경우 면제
```

### 안티패턴 원문 (line 79 — 동일 의미 dual location)

```markdown
- **회귀 AC 없는 유지보수 FID** — `§유형 = 유지보수` 인데 `AC-R-*` 0 개로 작성. **회귀 검증 근거 없음** → BLOCK. clarifying-ko 단계에서 `AC-R-*` append 가능. `§유형 = trivial` (변경 라인 ≤ 5 자동) 시에만 면제
```

## 2. 호출자/의존 매핑

| 위치 | 라인 | 결합 종류 | 정합 책임 |
|---|---|---|---|
| `skills/sprint-contracts-ko/SKILL.md` | line 55 | 체크리스트 (대상) | 본 변경의 1 차 표적 |
| `skills/sprint-contracts-ko/SKILL.md` | line 79 | 안티패턴 (동일 의미 dual location) | wording 의미 변경 시 동시 수정 |
| `skills/specifying-ko/SKILL.md` | line 79 | 인용 — "sprint-contracts-ko evaluator 가 `AC-R-*` ≥ 1 강제" | 강제 조건 의미 변경 시 인용 갱신 |
| `templates/acceptance-criteria.md` | line 57~71 | 운용 규칙 동치 — `## 회귀 방지 AC (유지보수 FID 필수)` 섹션 + 신규/trivial 면제 메모 | 면제 조건 변경 시 템플릿 메모 갱신 |
| `commands/maintain.md` | — | 진입 슬래시 (직접 참조 없음) | 영향 없음 |

## 3. 기존 테스트 커버리지

- **자동 테스트**: 없음 — 본 파일은 markdown skill 본문이라 정적 테스트 cover 안 됨
- **dogfood fixture (간접)**:
  - `.specops/20260427-test-bugfix-fixture/` — 일반 유지보수 분기 dogfood
  - `.specops/20260427-test-trivial-typo/` — trivial 분기 dogfood
  - 두 fixture 의 `acceptance-criteria.md` 가 본 체크리스트 wording 변경의 의미적 검증 source 로 작용 가능
- **bash 회귀 테스트 후보**: `tests/regression/` 미존재. 본 변경 시 doc-only 라 tests 도입 필요성 낮음 (specifying-ko 단계에서 평가)

## 4. 관찰 가능 동작 (Baseline)

본 체크리스트 항목이 현재 보장하는 행동:

1. **유지보수 FID + AC-R-* 0 개** → Evaluator (analyzer-ko, code-reviewer-ko, verifier-ko) 가 `verdict = BLOCK` 판정 의무
2. **trivial FID (변경 라인 ≤ 5 자동)** → 본 체크리스트 항목 면제 (BLOCK 발동 안 함)
3. **신규 FID** → 본 체크리스트 항목 비활성 (`§유형` 라벨 분기로 자동)
4. **clarifying-ko 단계** → AC-R-* append 가능 (templates/acceptance-criteria.md `MUTABLE_BY: /clarify (append only)` 와 일치)

## 5. 회귀 위험 메모

- **dual location 정합 깨짐** — line 55 (체크리스트) 와 line 79 (안티패턴) 가 의미 동치. 한쪽만 wording 변경 시 evaluator 혼동 → trivial 면제 경계 모호화
- **specifying-ko line 79 인용 stale** — "AC-R-* ≥ 1 강제" 표현이 본 체크리스트 의미와 어긋나면 specifying-ko Step 6 §유형 라벨 자동 발동 로직 정합 깨짐
- **templates/acceptance-criteria.md line 71 면제 메모 동치** — "신규 / trivial 면제" wording 이 본 체크리스트와 분리 진화 시 운용 규칙 모순
- **회귀 테스트 부재** — markdown skill 본문 변경의 의미 검증을 사람 review 외 보장할 수단 없음 → wording 개선 시 PR diff 4 위치 동시 검토 필수

## 분석 메모 (advisor 협의)

본 baseline 작성 전 advisor 1 회 협의 (memory feedback `feedback_advisor_analysis_design.md` 준수):

- **trivial 판정 책임 분리**: analyzing-ko Step 5 가 trivial source. specifying-ko Step 6 는 read 만. → §1 라인 합산 추정을 본 단계에서 명시 (1 ~ 5 라인) → trivial 후보
- **개선 방향 가설 금지**: "본문 개선" 의도 (가독성 / 명확성 / 검증 절차 추가 / 누락 케이스) 는 specifying-ko Q1~Q4 책임. 본 단계 산출물에 추정 섹션 넣지 않음
- **cross-reference 4 중 결합** 명시 — §2 호출자 매핑 + §5 회귀 위험에 반영
- **a273dc8 commit 가 본 체크리스트 도입 PR** — impact-analysis.md §3 에 cite

---

*작성: analyzing-ko · 2026-04-27 · FID: 20260427-sprint-contracts-regression-ac-checklist*
