# NEEDS_APPROVAL 처리 절차 (implementing-ko 보조 문서)

> `skills/implementing-ko/SKILL.md` `## 구현자 상태 처리` 에서 참조. 구현자(`agents/implementer-ko.md`)가 `NEEDS_APPROVAL` 을 반환했을 때만 읽는다.

**대상**: 구현자가 비가역·범위 변경 작업(복구 어려운 삭제·요청 범위 밖 변경)에서 **멈추고** 승인을 요청한 것이다. 구현자는 무인 모드에서도 이 문턱을 넘지 않으므로(AUTO-HARD-GATE 와 같은 방향) **부모가 받는 쪽이다** — 무응답으로 두면 태스크가 조용히 멈춘다.
1. 구현자 보고의 작업 내용·영향 범위·되돌림 방법을 **원문 그대로** 사용자에게 제시하고 승인을 묻는다: `NEEDS-APPROVAL: <task-id> <작업 요약> — 진행하시겠습니까? [y/n]` (§auto 도 예외 없음 — 위 AUTO-HARD-GATE 형식과 같다).
2. `y` → 승인 사실을 `.specops/<FID>/dispatch/<task-id>-approval.md` 에 1줄(`<ts> 사용자 승인: <작업 요약>`)로 적고, 재dispatch 프롬프트에 그 **경로만** 추가한다(context.md 는 emit-context 가 재생성하므로 직접 편집하지 않는다). 승인 범위 밖 작업은 다시 NEEDS_APPROVAL 이다.
3. `n` → 해당 태스크를 건너뛰지 말고 멈춘다: 대안(범위 축소·분해)을 사용자와 정한 뒤 재dispatch, 합의가 없으면 Lifecycle 정지.
4. `§batch` 는 사용자와 직접 대화할 수 없다 — 해당 FR 을 **halt** 하고 `dispatch-log.md` 에 `NEEDS_APPROVAL <task-id> <사유>` 행을 남겨 오케스트레이터(start-all)가 최종 게이트로 올리게 한다. 승인 없이 진행·우회 금지.
5. 어느 경로든 `dispatch-log.md` 에 `NEEDS_APPROVAL` 행(요청·결정)을 남긴다(투명성).

