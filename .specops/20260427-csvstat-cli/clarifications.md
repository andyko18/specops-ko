# Clarifications — 20260427-csvstat-cli

**status**: RESOLVED
**timestamp**: 2026-04-27T00:00:00+09:00

## Q1 · 빈 CSV 처리 · DESIRABLE

**질문**: 헤더만 있고 데이터 행이 없는 CSV 입력 시 동작은?

**답변**: `rows: 0`, `columns: N`, 각 컬럼 `0 unique`, exit 0

**영향**: AC-9 신규 추가

---

## Q2 · 헤더 없는 CSV · DESIRABLE

**질문**: 첫 행이 데이터인 CSV(헤더 없음) 입력 시 동작은?

**답변**: 첫 번째 행을 항상 헤더로 간주. 범위 밖 케이스이므로 별도 처리 없음 (YAGNI). `csv.DictReader` 기본 동작과 일치.

**영향**: 구현 참고사항만. 신규 AC 없음.

---
