<!-- FID: 20260427-maintenance-lifecycle -->
<!-- OWNER_COMMAND: /clarify -->
<!-- reference_upstream: github/spec-kit + obra/superpowers@v5.0.7 brainstorming "User Review Gate" -->
<!-- layer: Lifecycle-Artifact -->

# Clarifications — 20260427-maintenance-lifecycle

**status**: RESOLVED
**timestamp**: 2026-04-27T09:45:00+09:00
**해소 건수**: 4 / 4 (BLOCKING 1 + DESIRABLE 3)
**HARD GATE**: 통과 — 잔여 BLOCKING 0

---

## Q-A · entry signal prefix 약속어 · BLOCKING

**근거**: specifying-ko Step 1 의 args 파싱 로직이 prefix 검사로 신규/유지보수 분기 판정. prefix 가 자연어 args 와 collision 되면 분기 오류 발생. (spec FR-5 / FR-12, AC-3 / AC-5 의 구현 의존)

**질문**: `__entry: maintain` 신호의 정확한 prefix 약속어를 어느 형식으로 고정할 것인가?

| 옵션 | 형식 | 자연어 collision |
|---|---|---|
| (a) | `__entry: maintain` (텍스트) | 가능 (낮음) |
| (b) ✅ | `<!-- entry: maintain -->` (HTML 주석) | **0** |
| (c) | `[entry: maintain]` (bracket) | 가능 |

**답변**: **(b) `<!-- entry: maintain -->`**

**근거 (사용자 채택)**:
- 자연어 args 가 HTML 주석으로 시작할 가능성 0
- structured-artifacts-ko 의 frontmatter HTML 주석 패턴 (`<!-- FID: -->`, `<!-- OWNER_COMMAND: -->`) 과 일관
- spec/AC 파일 frontmatter 와 동일 표기법 → 학습 비용 절감

**영향**:
- AC-13 신규 추가 (prefix 형식 검증)
- spec FR-5 의 args 파싱 로직 = `<!-- entry: maintain -->` 첫 줄 검사
- commands/maintain.md 의 specifying-ko 호출 args 합성 시 첫 줄에 본 주석 삽입
- 메타 skill (using-specops-auto-ko-ko) 의 자연어 신호 분류 결과 → args 합성 시 동일 주석 prepend

---

## Q-B · trivial 라벨 자동 판정 시점 · DESIRABLE

**근거**: spec FR-13 (trivial 라벨 = 변경 라인 ≤ 5 자동) 의 git diff 시점 미명시. specifying-ko 진입 시점은 변경 없음 — 어느 단계가 책임을 갖는가?

**질문**: trivial 자동 판정의 시점은?

| 옵션 | 시점 | 회수 비용 |
|---|---|---|
| (a) ✅ | analyzing 메타 사전 추정 (current-state.md §1 파일·라인 범위 메타) | 낮음 — clarifying 에서 갱신 가능 |
| (b) | implementing-ko 후 git diff 재계산 | 중 — spec/AC 수정 단계 어긋남 |
| (c) | sprint-contracts-ko verifying 시점 최종 판정 | 높음 — 회수 비용 ↑ |

**답변**: **(a) analyzing 메타 사전 추정**

**근거 (사용자 채택)**:
- spec/AC 단계에서 §유형 라벨 결정 → 후속 chain 일관성 확보
- clarifying-ko 단계에서 라벨 갱신 가능 (clarifying 의 AC append 권한)
- 늦게 판정할수록 회수 비용 ↑

**영향**:
- AC-14 신규 추가 (시점 검증 — should)
- spec FR-13 의 동작 시점 명시 = analyzing-ko current-state.md §1 메타 기반
- analyzing-ko 가 5 항목 산출 시 §1 "변경 대상 식별" 의 라인 범위를 합산하여 trivial 후보 표기 (사용자 자기선언과 결합)

---

## Q-C · analyzing-ko gh CLI 미가용 환경 fallback · DESIRABLE

**근거**: spec FR-9 의 analyzing-ko 가 PR/이슈 히스토리 요약을 위해 `gh` CLI 사용. 미가용 환경 (CI / 신규 머신) 처리 미명시.

**질문**: gh CLI 미가용 환경에서 analyzing-ko 의 fallback?

| 옵션 | 동작 | 트레이드오프 |
|---|---|---|
| (a) ✅ | git log + 한계 고백 (impact-analysis.md 에 "gh 미가용 — git log 사용" 명시) | 경고성 + 부분 정보 |
| (b) | 한계 고백만 (PR/이슈 요약 항목 자체 skip) | 정보 손실 |
| (c) | HARD GATE 차단 ("gh 설치 후 재진입") | 안전하나 경로 막힘 |

**답변**: **(a) git log + 한계 고백**

**근거 (사용자 채택)**:
- gh 미가용은 흔한 환경 — HARD GATE 차단은 과함
- git log 도 PR 머지 commit 추적 가능 (`git log --merges`, `git log --grep='Merge pull'`)
- 5 원칙 5 (한계 고백) 와 정합 — 부분 정보 + 한계 명시

**영향**:
- AC-15 신규 추가 (fallback 동작 검증 — should)
- spec FR-9 / NFR-5 의 fallback 정책 명시
- templates/impact-analysis.md §관련 PR/이슈 항목에 "데이터 출처: gh 또는 git log (gh 미가용 시 한계 고백)" 자동 메타 추가

---

## Q-D · README.md Lifecycle Chain 갱신 commit 위치 · DESIRABLE

**근거**: spec NFR-4 / AC-12 가 README.md Lifecycle Chain 섹션 갱신을 검증하지만, plan §변경 파일 총괄 에서 README 누락 + commit 위치 미명시.

**질문**: README.md 갱신을 어느 commit 에 포함하는가?

| 옵션 | 위치 | 작업 분할 |
|---|---|---|
| (a) ✅ | Phase D commit 안 | 4 commit, 1 PR (Q2 유지) |
| (b) | 별도 5 번째 commit `feat(docs): README ...` | 5 commit, 1 PR — git blame 명확 |
| (c) | PR 머지 직전 별도 갱신 | review 시점 미반영 위험 |

**답변**: **(a) Phase D commit 안**

**근거 (사용자 채택)**:
- Q2 결정 (4 commit, 1 PR) 구조 유지
- README 갱신 = `/maintain` 슬래시 + analyzing-ko 추가의 일부 → Phase D 와 의미적 결합
- git blame 손실은 `commit 3` 본문이 README 항목 명시로 완화 가능

**영향**:
- spec §2 포함 항목의 "README.md Lifecycle Chain 섹션 갱신" 위치 = commit 3 (Phase D)
- AC 차원의 신규 추가 불필요 (AC-12 가 이미 검증)
- commit 3 메시지 본문에 "README.md Lifecycle Chain 갱신 포함" 명시 (git blame trail)

---

## 신규 AC 추가 요약

본 clarifying 단계에서 acceptance-criteria.md 에 append 되는 AC:

| 신규 AC | 출처 | 우선순위 |
|---|---|---|
| AC-13 | Q-A 결정 (prefix 형식 검증) | must |
| AC-14 | Q-B 결정 (trivial 시점 검증) | should |
| AC-15 | Q-C 결정 (gh fallback 검증) | should |

기존 AC 수정 0 (clarifying-ko 안티패턴 "기존 AC 수정" 준수). spec.md 본문 수정 0 (clarifying-ko 안티패턴 "스펙 본문 수정" 준수).

---

## HARD GATE 통과 선언

- BLOCKING 잔여: 0 (Q-A RESOLVED)
- DESIRABLE 잔여: 0 (Q-B / Q-C / Q-D RESOLVED)
- spec §8 열린 질문 4 건 모두 RESOLVED
- 신규 AC 3 건 append 후 planning-ko 진입 허용

---

## 참조

- `.specops/20260427-maintenance-lifecycle/spec.md` §8 열린 질문
- `.specops/20260427-maintenance-lifecycle/acceptance-criteria.md` (AC-13/14/15 append 대상)
- `~/.claude/plans/valiant-splashing-deer.md` 승인된 plan
- `skills/clarifying-ko/SKILL.md` BLOCKING/DESIRABLE 기준

---

*작성: clarifying-ko · 2026-04-27 · FID: 20260427-maintenance-lifecycle · 생성 커맨드: /clarify*
