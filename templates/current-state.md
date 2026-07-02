<!-- FID: <YYYYMMDD-kebab-slug> -->
<!-- OWNER_COMMAND: /specify (유지보수 분기) or /maintain -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: specops-auto-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# 현재 시스템 분석 (Current State) — <FID>

> 유지보수 진입 시 specifying-ko Step 1 (Phase A 단독) 또는 analyzing-ko (Phase C 적용 후) 가 산출. 변경 대상의 baseline 캡처 → spec.md / impact-analysis.md / 회귀 AC / trivial 자동 판정 (§1 라인 범위 메타) 의 근거.

## 1. 변경 대상 식별

- 파일: `<path/to/file.ts>` (Lines: <range — 합산이 trivial 자동 판정 메타 source. ≤ 5 → trivial 자동>)
- 진입점 함수/심볼: `<symbol>`
- 관련 모듈: <list>

## 2. 호출자/의존 매핑

- 호출자: `<grep -rn 'symbol' --include='*.ts'>` 결과 요약
- 의존: <외부 lib / 내부 모듈>

## 3. 기존 테스트 커버리지

- 관련 테스트: `<test/path>` (예: `tests/auth.test.ts::token-expiry-*`)
- 커버되지 않는 경로: <list>

## 4. 관찰 가능 동작 (Baseline)

| # | Input | 현재 Output | 비고 |
|---|---|---|---|
| 1 | <example> | <result> | <note> |

## 5. 회귀 위험 메모

- <위험 1: 변경이 X 흐름에 영향>

---

*작성: specifying-ko Step 1 (Phase A) 또는 analyzing-ko (Phase C) · <날짜> · FID: <FID>*
