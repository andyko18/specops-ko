# Phase 2.5 dogfood checklist (수동 · run-all 비포함)

Wave C 관측·DX 검증용. API 키·토큰 비용이 들므로 CI/run-all에 넣지 않는다.

## 전제

- ACTIVE batch (`feat/<BATCH_ID>`) 또는 UI/IF 산출이 있는 PLAN_DONE FID 집합
- `ui-ux-pro-max` 또는 DESIGN.md fallback 경로 가용

## 체크리스트

1. [ ] Phase 2.5-A 화면 스펙 생성 (`screens/*.md` + `screens/*.html`)
2. [ ] Phase 2.5-B IF 갱신 (`.specops/memory/api-spec.md` · `data-model.md` 해당 섹션)
3. [ ] Phase 2.5-D `design-reviewer-ko` dispatch → `design-review.md` 저장
4. [ ] Critical≥1 시 §auto여도 **정지** (`HARD-GATE: design-reviewer Critical cap`)
5. [ ] Important-only + §auto → 자동통과 + queue/다이제스트 기록
6. [ ] design 산출물 docs-only 커밋 (코드 혼입 없음 · BYPASS 불요)
7. [ ] implement 경로: task receipt 후 `git add` / `git commit` **분리** 실행
8. [ ] (가능 시) fable 불가 → override 재dispatch 후  
      `metrics.jsonl`에 `phase=evaluator-degradation` · `fallback=true` 행 존재

## 기록

- 날짜:
- BATCH_ID / FID:
- Critical/Important 건수:
- degradation 메트릭 여부:
- 메모:
