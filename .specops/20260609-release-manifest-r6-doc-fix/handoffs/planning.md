<!-- FID: 20260609-release-manifest-r6-doc-fix -->
<!-- layer: Lifecycle-Artifact -->

# Handoff — planning-ko → decomposing-ko

## Decided
- 6개 태스크 구성: T1(TDD RED) → T2(TDD GREEN) → T3(R-6 비활성화 + test-rules.sh) → T4a(manifest 즉시 수정) → T4b(문서 동기화) → T5(CHANGELOG 백필)
- plan-reviewer-ko FAIL(T4 파일 5개 초과) → T4를 T4a(plugin.json+marketplace.json 2파일)와 T4b(README+maintain.md+SKILL.md 3파일)로 분할
- plan-reviewer-ko 재dispatch PASS (Critical=0, Important=0, Minor=3)
- T3 제약: rules.jsonl R-6 disabled + test-rules.sh T5.c stop=2 반드시 동일 커밋

## Rejected
- T4를 더 잘게 분할 — Minor만 남아 불필요
- T3과 T4a 병합 — 개념적 경계 유지

## Risks
- release.sh `_sed_i` JSON 멀티라인 오동작 가능 — T2 Step 5에서 TDD 검증으로 실측
- validate-structure.sh baseline이 v1.9.0 기대 → T4a 후 갱신 필요

## Remaining
- decomposing-ko: tasks.md YAML DAG 생성
- implementing-ko: T1→T2→T3→T4a→T4b→T5 순차 실행
