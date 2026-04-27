<!-- FID: 20260427-analyzing-gh-fallback-refactor -->
<!-- OWNER_COMMAND: /maintain → analyzing-ko -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: specops-auto-ko 독자 추가 (본가 obra/superpowers@v5.0.7 미존재) -->
<!-- layer: Lifecycle-Artifact -->

# 영향 분석 (Impact Analysis) — 20260427-analyzing-gh-fallback-refactor

> **변경 규모 평가**: current-state.md §1 라인 합산 = 3 ≤ 5 → analyzing-ko Step 5 규약상 `trivial` 후보. 본 변경은 self-modifying skill (meta-circular) + mirror 의존 (template, AC, protocol) 이 다수라 **§1·§2 brief 작성 + §3 필수**. trivial 단순 case 가 아니다.

## 1. 외부 영향

- **API 호환성**: 본 프로젝트는 코드 라이브러리가 아닌 **skill-as-prompt 자산** → "API" 개념은 *skill body 텍스트의 의미 동등성* 으로 환산
  - **deprecate / breaking 없음** — Step 4 fallback 룰의 **의미** 가 동등하면 호환. 표현 변경은 OK.
  - **breaking 위험 1 건**: 만약 fallback 분기 조건을 `gh --version` 외에 추가 조건 (`gh auth status`, `gh pr list` GraphQL 응답 코드 등) 으로 확장 → AC-15 검증 방법 (현재는 `gh --version` 실패만 가정) 변경 필요 → AC-15 갱신 PR 동반 필수.
- **DB 스키마**: N/A (DB 부재)
- **공유 모듈 사용처** (skill body 텍스트 mirror):
  - `templates/impact-analysis.md` Lines 25–27 — Step 4 fallback 메타 문자열 mirror. 변경 시 동시 갱신.
  - `.specops/20260427-maintenance-lifecycle/acceptance-criteria.md` AC-15 (Lines 202–213) — Step 4 룰의 spec assertion. 의미 변경 시 갱신.
  - `.specops/20260427-maintenance-lifecycle/behavioral-verification-protocol.md` B-V4 (Lines 174–199) — fresh 세션 verbatim 검증 시나리오. 룰 동작 변경 시 protocol 재작성.
  - **import-style 검증**: `grep -rn "gh CLI\|gh --version\|gh pr list\|git log --merges" skills/ commands/ templates/` 결과 위 3 곳만 매칭 (`current-state.md` §2.3 인용).

## 2. 마이그레이션·롤백 경로

- **마이그레이션**: skill body 텍스트 단순 갱신 — 데이터·설정 이전 없음. **단**, mirror 3 건 (`templates/impact-analysis.md`, AC-15, B-V4) 동시 갱신 필요 → 단일 PR 원자성 유지 (분할 시 git bisect 시점 mirror 분기 발생 → broken docs).
- **롤백**: `git revert <commit>` 단순 가능 — skill body 만 변경. 단, 머지 후 fresh 세션이 변경된 룰로 다른 FID 산출물을 만들었다면 그 산출물은 롤백 대상 아님 (역사적 기록 보존). **부작용 없음**.
- **점진 배포 가능 여부**: feature flag 부재 (skill 은 즉시 활성). 단, 변경 PR 머지 → 다음 fresh 세션부터 적용 → 사실상 atomic switch. canary 불가능. → **B-V4 재검증을 머지 전 staging fresh 세션에서 수동 수행 권장**.

## 3. 관련 PR·이슈 히스토리 요약

- **데이터 출처**: **git log (gh CLI 가용하나 GitHub repo 미push — 한계 고백)**
  - 실측: `gh pr list --repo andyko/specops-auto-ko` → `GraphQL: Could not resolve to a Repository` (본 프로젝트가 GitHub 원격 미연결 로컬 전용)
  - 이는 current-state.md §3 R4 (gh 가용하나 repo 미push 중간 상태) 의 본 세션 자기 사례 — **리팩터링 범위 결정의 강한 근거**
- **관련 PR (git log --grep='analyzing\|gh CLI\|fallback')**:
  - `9c36a87 feat(C): analyzing-ko 신설 + impact-analysis.md + chain 재배선 + README D3b (C1~C6 + D3b)` — analyzing-ko 최초 신설 commit. 본 변경의 baseline.
  - `bfc3f26 feat(D): 메타 skill 신호 매칭 + /maintain 슬래시 + README (D1~D3a/D4)` — maintenance flag 진입 정의 (Phase D)
  - `bdf7719 spec(20260427-maintenance-lifecycle): 유지보수 Lifecycle 보강 명세 — B+A+D+C 4 Phase` — 4 Phase 설계
  - `8da198b clarify(20260427-maintenance-lifecycle): Q-A~Q-D 4 건 RESOLVED + AC-13/14/15 append` — AC-15 (gh fallback) 명세 진입
  - `5d442dc verify(20260427-maintenance-lifecycle): protocol verbatim 실재 파일 교체` — B-V4 verbatim 입력을 본 SKILL.md 로 교체 (본 세션 입력의 출처)
  - `503e1ae verify(20260427-maintenance-lifecycle): B-V4 sprint-contracts evaluator 3 변형 PASS` — 직전 검증 결과
- **관련 이슈**: gh issue list 사용 불가 (위 GraphQL 오류) → **이슈 추적 미수행 — 한계 고백**. 로컬 ticket 시스템 부재.
- **본 변경의 contextual 근거**:
  - B-V4 verbatim 시나리오 (line 197): "gh 강제 → analyzing-ko `## 체크리스트` 4 의 fallback 룰 본문 강도 상향" → 본 리팩터링이 이 verbatim 의도와 정합 가능
  - B-V4 verbatim 시나리오 (line 199): "HARD GATE 차단 → analyzing-ko `## 안티패턴` "gh 강제" 항목 강화" → 안티패턴 본문도 변경 검토 대상

## 4. Advisor 협의 메모 (2026-04-27)

`feedback_advisor_analysis_design.md` 의무 협의 결과 — 본 분석은 단순 trivial 가 아닌 **2 갈래 fork** 가 잠재한 결정:

- **Path A (텍스트 정리)**: Step 4 표현만 다듬음. 분기 조건 = `gh --version` 유지. AC-15 / template `impact-analysis.md` §3 / B-V4 mirror 동시 갱신만. 진정 trivial. spec.md §유형 = `trivial`.
- **Path B (동작 확장)**: 분기 조건 = `gh --version` + `gh pr list` GraphQL 응답 + `gh auth status` 다층 fallback. AC-15 신규 케이스 추가, B-V4 신규 시나리오, NFR 영향 (성능 — 다층 호출 latency). trivial 아님. spec.md §유형 = `유지보수` 정상 분기.

한국어 "리팩터링" 통상 의미는 **A 에 가까움** (구조·표현 정리, 동작 보존). 단 본 환경에서 R4 (gh 가용 + repo 미push) 가 **이 세션 자체에서 실측** 됐다는 사실이 B 의 동인이 될 수 있음 → **사용자 결정 사항** → HARD GATE 1 문항으로 분리 처리.

---

*작성: analyzing-ko · 2026-04-27 · FID: 20260427-analyzing-gh-fallback-refactor · 변경 규모: trivial 후보 (3 줄, 리팩터링 의도 재확인 필요)*
