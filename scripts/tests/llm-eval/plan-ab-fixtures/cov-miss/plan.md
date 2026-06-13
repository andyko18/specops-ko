# 샘플 구현 플랜 — cov-miss fixture

**관련 AC**: AC-1, AC-2, AC-3

## 5. 태스크 개요
1. T1 — 파서 구현 (AC-1)
2. T2 — 검증기 구현 (AC-2)
<!-- 의도된 결함: AC-3 이 어느 태스크에도 매핑 안 됨 (커버리지 누락) -->

## 4. 계약
- parse_input() → result
- validateResult() 호출   <!-- 의도된 결함: §5 는 parse_input 인데 §4 는 parseInput 미정의·validateResult 명명 불일치 (타입 일관성) -->
