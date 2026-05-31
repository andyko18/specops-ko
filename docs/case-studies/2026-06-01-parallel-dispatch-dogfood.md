# DAG-AWARE PARALLEL dispatch — dogfood 실증 기록

**날짜**: 2026-06-01
**대상**: `implementing-ko` L67-101 (DAG-AWARE PARALLEL 분기)
**결론**: 병렬 dispatch 경로는 **이미 specified 이며, 부모가 driving 할 때 메커니즘이 실제로 합성됨을 실증**. 단 cold `implementing-ko` 자동 라우팅 증명은 별개.

---

## 1. 배경 — 무엇이 미검증이었나

병렬 dispatch 는 "미구현"이 아니라 specified 상태였다:
- 지침: `implementing-ko` L67-101 (worktree-per-leaf → `dispatching-parallel-agents-ko` 멀티-Task → Phase B/C → 부모 `git apply --index` 머지)
- infra: `parse-dag.sh`(16 테스트)·`emit-context.sh`·`validate-context.sh`
- 안전장치: worktree 격리 · R8 leaf commit 권한 박탈 · R11 머지 race 차단

**미검증 2건**: ① 병렬 경로가 한 번도 실행 증명 안 됨 ② 부모 머지 로직(`git apply --index`)이 exercise 안 됨.

②는 `test-implementing-policy.sh` T2.a~c (PR #40) 로 단위검증됨. ① 이 본 dogfood 의 대상.

## 2. 실증 흐름 (수동 driving)

1. `scripts/tests/dag/fixtures/dogfood-parallel/tasks.md` 의 2 disjoint leaf DAG →
   **real `dag::find_independent_batch`** 가 `[T1 T2]` DISJOINT 판정 (병렬 자격)
2. worktree-per-leaf 2개 + dispatch-context 2개
3. **단일 assistant 메시지에 `implementer-ko` Agent 2개 동시 dispatch** ← bash 로 검증 불가한 핵심
4. 각 leaf 독립 worktree 에서 `git add` (R8 commit 금지 준수) → DONE
5. 부모가 각 worktree `diff --cached` → `git apply --index` 순차 합성 → 양쪽 landing

## 3. 증거 (timing 아닌 구조)

- **한 assistant turn 에 2개 Agent tool_use**, 별개 agentId (`a9dc56fa…` / `ab1f90f2…`) = 진짜 동시 실행 (harness 계약상 단일 메시지 멀티 tool_use = 병렬)
- 양쪽 산출물 부모 worktree 합성: `leaf A output` + `leaf B output`
- main 무오염 (worktree 정리, demo cruft 미커밋)

**실제 증명의 소재는 본 dogfood 를 수행한 세션 transcript** 다. bash 테스트로는 재현 불가(LLM 은 bash 안에서 안 돎).

## 4. 정직한 경계 (over-claim 금지)

- ✅ 증명: **부모가 L67-101 을 driving 할 때** parse-dag→worktree→병렬 Agent→`git apply --index` 머지 메커니즘이 합성됨
- ❌ 미증명: cold `implementing-ko` 호출이 **자동으로** 이 경로로 라우팅되는지 (실제 lifecycle 진입 필요, 본 실증은 수동 단계 실행)
- ❌ bash 영구 테스트 불가: 단일 메시지 멀티-Agent emit 은 CI-runnable bash 에 구조적으로 부재

## 5. 재실행 harness

`scripts/tests/dag/dogfood-parallel-harness.sh`:
- `run` — setup(real parse-dag→worktree→context) + **병렬 dispatch GAP 안내** (LLM 이 Agent 2개 실행 후 `verify`)
- `demo` — GAP 을 bash 파일작성으로 대체해 머지 glue 자동 완주 (CI green; **병렬성 미검증** — glue 만)
- `verify` / `teardown` — 머지 검증 / 정리

⚠️ `demo` 의 green 은 **머지 합성(glue) PASS** 이지 "병렬 dispatch 검증" 이 아니다. 병렬성 증명은 본 문서 §3 (transcript) 에만 존재한다.

---

*specops-auto-ko · 2026-06-01 · G3 dogfood 실증 + 재실행 harness*
