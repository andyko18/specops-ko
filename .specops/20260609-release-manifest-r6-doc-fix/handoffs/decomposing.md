<!-- FID: 20260609-release-manifest-r6-doc-fix -->
<!-- layer: Lifecycle-Artifact -->

# Handoff — decomposing-ko → implementing-ko

## Decided
- 6개 태스크 (T1→T2 체인, T3/T4a/T4b/T5 병렬 leaf)
- DAG 자체 검증 PASS: leaf=[T1, T3, T4a, T4b, T5], 초기 배치 5건
- emit-context.sh PASS: dispatch/ 6파일 산출
- 분기: §batch 없음, §auto 없음 → 단일 모드 (implementing-ko 직행)

## Rejected
- T4a/T4b 추가 분할 — 파일 경계 3개 이하 유지 중이므로 불필요

## Risks
- T1 RED 테스트가 "1.9.0" 반환 대신 빈 문자열 반환 가능 (PLUGIN_ROOT 환경변수 미전달 시)
- T3 동시 커밋 미준수 시 pre-flight FAIL — 구현 중 주의

## Remaining
- implementing-ko: T1→T2→T3→T4a→T4b→T5 순서로 dispatch
