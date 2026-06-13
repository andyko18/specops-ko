# 샘플 구현 플랜 — placeholder fixture

## 5. 태스크 개요
1. T1 — 핵심 로직 구현 (AC-1)
   - 적절한 에러 처리 추가   <!-- 의도된 결함: 플레이스홀더 "적절한 에러 처리" -->
   - TODO: 엣지 케이스 채우기   <!-- 의도된 결함: TODO 플레이스홀더 -->
2. T2 — Task 1과 유사하게 구현   <!-- 의도된 결함: "유사" 코드 생략 -->

## 4. 계약
- handleRequest(req) → resp
- 후반 태스크에서 handleReq() 사용   <!-- 의도된 결함: handleRequest vs handleReq 타입 불일치 -->
