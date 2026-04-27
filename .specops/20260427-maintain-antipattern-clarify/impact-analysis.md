# impact-analysis.md — `commands/maintain.md` 안티패턴 항목 표현 강화

> **trivial 경로** (current-state.md §1 라인 합산 = 1 ≤ 5) → §1 외부 영향 / §2 마이그레이션 생략. §3 만 작성.

## 3. 관련 PR · 이슈 · 커밋 히스토리

데이터 출처: `git log` (gh CLI 가용성 확인 완료 — `gh --version` = 2.83.2 / 단, 본 repo 는 PR 기반이 아닌 직접 커밋 워크플로우라 `gh pr list` 결과 0 건 → git log 가 1 차 source)

| 커밋 | 관련성 | 비고 |
|---|---|---|
| `b664592` | **fix(v0.0): /start 인자 처리 단일화 — 인자 내용 2차 판단 금지** | sister 파일 (`commands/start.md`) 의 동일 항목을 강화한 선행 fix. 본 fix 의 표현 모델 |
| `bfc3f26` | **feat(D): 메타 skill 신호 매칭 + /maintain 슬래시 + README** | `commands/maintain.md` 신설 시점 — 현 모호 표현이 도입된 origin |
| `9c36a87` | **feat(C): analyzing-ko 신설 + impact-analysis.md + chain 재배선** | maintain.md `## Process` 가 analyzing-ko 선행으로 갱신됐으나 안티패턴 항목은 미수정 (본 fix 가 잔여 cleanup) |
| `5d442dc` | **verify(20260427-maintenance-lifecycle): protocol verbatim 실재 파일 교체** | behavioral-verification-protocol.md §83 가 본 항목 강화 필요를 명시한 verification 출처 |

**한계 고백** (5 원칙 5):

- 본 repo 는 PR-less 직접 커밋 워크플로우 → `gh pr list` 0 건은 정상. PR 기반 토론 / 리뷰 코멘트 source 없음.
- behavioral-verification-protocol.md §83 의 "강화 필요" 판정 근거 (어느 protocol 실행에서 fail 이 관찰됐는지) 는 protocol 본문에 명시되지 않음 — verification 은 fix 후 protocol 재실행으로만 close.
