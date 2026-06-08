<!-- FID: 20260609-release-manifest-r6-doc-fix -->
<!-- layer: Lifecycle-Artifact -->

# Handoff — specifying-ko → clarifying-ko

## Decided
- §유형: 유지보수 (라인 합산 ~31줄)
- T2: (b) R-6 disabled — `"enabled": false`. gbrain-ko "manual-only" 설계 우선.
- T1-b: release.sh FR-7에 `_sed_i` 패턴으로 manifest bump 추가 (README 패턴 재사용)
- T1-a: plugin.json/marketplace.json 즉시 v1.10.0 패치
- T4: 문서 4건 일괄 동기화

## Rejected
- T2(a): gbrain-append producer chain 편입 — 이번 스코프 아님
- validate-structure.sh 교차검증 강화 — T3 별도 스프린트

## Risks
- release.sh `_sed_i` 패턴이 JSON 멀티라인 구조에서 오동작 가능 — 실측 필요
- T5.c 어서션 갱신 누락 시 test-rules.sh FAIL

## Remaining
- clarifying-ko: spec 내 모호성·BLOCKING 쟁점 해소
