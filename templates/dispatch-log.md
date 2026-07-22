<!-- FID: <YYYYMMDD-kebab-slug> -->
<!-- OWNER_COMMAND: /implement -->
<!-- MUTABLE_BY: /implement (각 시도마다 append) -->
<!-- reference_upstream: specops-ko 독자 추가 (Wave 2 U9) -->
<!-- layer: Lifecycle-Artifact -->

# Dispatch Log — <FID>

> 본 파일은 `implementing-ko` 가 task 시작 시 자동 생성(template 복사)하고, 매 시도(Phase A/B/C)마다 1행 append 합니다. cap=2 (Phase B 1회 + Phase C 1회) 초과 시 HARD GATE.

## task-<id>: <컴포넌트명>

| # | 시각 | Phase | agent | 결과 | feedback 경로 |
|---|---|---|---|---|---|
| 1 | <ISO-8601> | A | implementer-ko | PASS | - |
| 2 | <ISO-8601> | B | spec-reviewer-ko | FAIL | reviews/<task-id>-B-feedback.md |
| 3 | <ISO-8601> | A (재) | implementer-ko | PASS | - |
| 4 | <ISO-8601> | B (재) | spec-reviewer-ko | PASS | - |
| 5 | <ISO-8601> | C | code-reviewer-ko | PASS | - |

**재시도 누적: B=1/2 C=0/2 (cap=2)**

---

*template — `implementing-ko` 가 task 별로 블록 추가*
