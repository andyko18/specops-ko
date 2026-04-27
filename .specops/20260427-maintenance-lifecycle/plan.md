<!-- FID: 20260427-maintenance-lifecycle -->
<!-- OWNER_COMMAND: /plan -->
<!-- reference_upstream: github/spec-kit plan-template.md + obra/superpowers@v5.0.7 writing-plans -->
<!-- layer: Lifecycle-Artifact -->

# 유지보수 Lifecycle 보강 (B+A+D+C) 구현 플랜 — 20260427-maintenance-lifecycle

**목표**: specops-auto-ko 자율 Lifecycle 에 유지보수 분기를 일급 지원 — analyzing-ko 신설, specifying-ko Step 1 분기, 메타 skill 신호 매칭, /maintain 슬래시, 회귀 AC 강제까지 4 Phase 일괄 deploy.

**아키텍처**: 메타 skill 의 신호 분류 → `<!-- entry: maintain -->` args 합성 → analyzing-ko (current-state.md + impact-analysis.md ★ HARD GATE) → specifying-ko 유지보수 분기 → spec.md `§유형: 유지보수` 라벨 자동 + acceptance-criteria.md 회귀 must AC 자동 강제 → sprint-contracts-ko BLOCK only evaluator. 신규 chain (`/start CSV ...`) 은 무손상.

**기술 스택**: Markdown (SKILL.md / template / commands), bash 3.2+ (기존 hooks 호환), gh CLI (선택 — git log fallback 보유)

**관련 AC**: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8, AC-9, AC-10, AC-11, AC-12, AC-13, AC-14, AC-15 (전체 15)

---

## 1. 가정 (5원칙 5번)

- 본가 superpowers v5.0.7 의 brainstorming SKILL 흡수 패턴 검증은 reference_upstream frontmatter + start.md "(deprecated)" 주석 인용으로 충분 (web fetch 미수행 — advisor skip 정당화).
- analyzing-ko 의 PR/이슈 히스토리 요약은 `gh` CLI 가용 환경 가정. 미가용 시 git log fallback (clarify Q-C 결정 → AC-15).
- specifying-ko Step 1 의 args 파싱 prefix 약속어 = `<!-- entry: maintain -->` (clarify Q-A 결정 → AC-13). 자연어 args 가 HTML 주석으로 시작할 가능성 0 가정.
- trivial 자동 판정의 라인 범위 메타 source = analyzing-ko current-state.md §1 (clarify Q-B 결정 → AC-14). Phase A 단독 적용 시점에는 specifying-ko Step 1 mini-checklist 의 §1 라인 범위 메타로 대체.
- `.specops/` 가 .gitignore 등록되어 있으나 다른 FID 들이 이미 tracked. 신규 산출물은 `git add -f` 로 stage (다른 FID 와 동일 운영 패턴).

## 2. 파일 구조

### 생성 (4 개)

- `templates/current-state.md` — 유지보수 baseline 5 항목 template (Phase A — 변경 대상 / 호출자·의존 / 기존 테스트 / 관찰 가능 동작 / 회귀 위험)
- `templates/impact-analysis.md` — 영향 분석 3 항목 template (Phase C — 외부 영향 / 마이그레이션·롤백 / 관련 PR·이슈)
- `skills/analyzing-ko/SKILL.md` — 분석 전담 신규 스킬 (Phase C — current-state.md + impact-analysis.md 산출 + ★ HARD GATE)
- `commands/maintain.md` — 유지보수 진입 슬래시 (Phase D 신설 + Phase C 갱신 — analyzing-ko 호출 chain)

### 수정 (4 개 + README 1 개)

- `templates/acceptance-criteria.md` — "## 회귀 방지 AC (유지보수 FID 필수)" 섹션 + `AC-R-N` template 추가 (Phase B)
- `skills/sprint-contracts-ko/SKILL.md` — Evaluator 체크리스트 1 줄 + 안티패턴 항목 1 개 추가 (Phase B)
- `skills/specifying-ko/SKILL.md` — Step 1 분기 추가 (Phase A) → Phase C 에서 본문 축약 ("analyzing-ko 결과 참조"). Process 흐름 섹션 ASCII 흐름도 maintenance 분기 추가
- `skills/using-specops-auto-ko-ko/SKILL.md` — §19~24 신호 매칭에 "버그/리팩터링/수정/개선/변경" 4 줄 추가 + Skill args 합성 로직 (Phase D) → Phase C 에서 chain 재배선 (analyzing-ko → specifying-ko)
- `README.md` — Lifecycle Chain 섹션에 analyzing-ko + commands/maintain.md 추가 (Phase D commit 안에 포함 — clarify Q-D 결정)

### 삭제

없음.

## 3. 데이터 모델

별도 `data-model.md` 분리 불필요. 산출물 데이터 형식은 Markdown 만:

| 산출물 | Owner Phase | 위치 | 섹션 |
|---|---|---|---|
| `current-state.md` | A 신설 / C 흡수 | `.specops/<FID>/` | §1~§5 (변경 대상 / 호출자·의존 / 기존 테스트 / 관찰 가능 동작 / 회귀 위험) |
| `impact-analysis.md` | C | `.specops/<FID>/` | §1~§3 (외부 영향 / 마이그·롤백 / 관련 PR·이슈) |
| `acceptance-criteria.md` 의 `AC-R-N` 회귀 AC | B 강제 | `.specops/<FID>/` | "회귀 방지 AC (유지보수 FID 필수)" 섹션 |

## 4. 계약 (약속어)

API 없음. specifying-ko Step 1 args 파싱 약속어만:

```
args 첫 줄 = "<!-- entry: maintain -->"  → [유지보수 분기]
args 첫 줄 ≠ "<!-- entry: maintain -->"  → [신규 분기] (현재 동작)
```

메타 skill (`using-specops-auto-ko-ko`) 의 자연어 신호 분류 결과 → `<!-- entry: maintain -->` args 첫 줄 prepend 합성.

`/maintain` command 의 Process 2 단계: command 가 `<!-- entry: maintain -->\n<원본 인자>` 형태로 specifying-ko 호출.

## 5. 태스크 개요

bite-sized 태스크 분해는 `/tasks` (decomposing-ko) 에서 상세화. 본 plan 은 **카테고리와 순서** 만:

### 카테고리 — Phase 별 commit 단위 (clarify Q2: 4 commit, 1 PR)

```
commit 1: feat(B): 회귀 AC must 강제
  - B1. templates/acceptance-criteria.md 회귀 AC 섹션 추가  → AC-1, AC-2 근거
  - B2. skills/sprint-contracts-ko/SKILL.md Evaluator 체크리스트 + 안티패턴 추가
  - B3. dogfood FID `20260427-test-bugfix-fixture` (회귀 AC 누락 BLOCK / 포함 PASS) 작성·실행

commit 2: feat(A): specifying-ko Step 1 유지보수 분기 + current-state.md
  - A1. templates/current-state.md 신설 (5 항목)
  - A2. skills/specifying-ko/SKILL.md Step 1 분기 추가 + ASCII 흐름도 갱신
  - A3. specifying-ko §유형 라벨 자동 기재 로직 (유지보수 / 신규 / trivial)
  - A4. Phase A 단독 시점의 trivial 사전 추정 = specifying-ko §1 라인 범위 메타 활용
  - A5. dogfood `20260427-test-natural-bugfix` + `20260427-test-newfeature-csv` (AC-3/4/7/13/14 검증)

commit 3: feat(D): 메타 skill 신호 매칭 + /maintain 슬래시 + README
  - D1. skills/using-specops-auto-ko-ko/SKILL.md 신호 예시 4 줄 + args 합성 로직
  - D2. commands/maintain.md 신설 (analyzing-ko 호출 chain — Phase C 에서 갱신될 자리)
  - D3. README.md Lifecycle Chain 섹션 갱신 (analyzing-ko + maintain.md 추가)
  - D4. dogfood `20260427-test-slash-refactor` (AC-5/6/12 검증)

commit 4: feat(C): analyzing-ko 신설 + impact-analysis.md + chain 재배선
  - C1. templates/impact-analysis.md 신설 (3 항목)
  - C2. skills/analyzing-ko/SKILL.md 신설 (current-state + impact-analysis 산출 + ★ HARD GATE + gh fallback)
  - C3. skills/specifying-ko/SKILL.md Step 1 본문 축약 ("analyzing-ko 결과 참조")
  - C4. skills/using-specops-auto-ko-ko/SKILL.md chain 재배선 (analyzing-ko → specifying-ko)
  - C5. commands/maintain.md Process 갱신 (analyzing-ko → specifying-ko 2 단)
  - C6. dogfood `20260427-test-slash-refactor` 재실행 (AC-8 검증) + `20260427-test-trivial-typo` (AC-9 검증) + gh fallback 시뮬 (AC-15)

통합 검증 (commit 4 끝 또는 별도):
  - I1. evidence.md 작성 (AC-10 — 4 시나리오 PASS)
  - I2. reference_upstream frontmatter 일괄 grep 검증 (AC-11)
```

### Phase 간 결합 (DAG: CHAIN — plan §위험 일괄 deploy)

- B → A: A 의 specifying-ko Step 1 §유형 라벨이 B 의 회귀 AC 강제를 트리거 (`§유형: 유지보수` 라벨 → 회귀 AC ≥ 1 강제)
- A → D: D 의 메타 skill 신호 매칭 / /maintain 슬래시가 A 의 진입 분기 사용 (`<!-- entry: maintain -->` args 합성)
- A, D → C: C 의 analyzing-ko 가 A 의 5 항목 흡수 + D 의 maintain.md Process 갱신
- 모든 Phase → 통합 검증: AC-10 evidence.md

**Deploy 단위 = 4 commit, 1 PR** (clarify Q2). Phase 별 부분 ship 금지.

## 6. 위험과 완화

high-level plan §위험 6 건 + clarify 단계 추가 1 건 = 총 7 건 승계.

| 위험 | 영향 | 완화 |
|---|---|---|
| Phase D 신호 매칭 신규/유지보수 오분류 | M | specifying-ko Step 1 에 분류 검증 1 문항 추가 — 사용자 즉시 정정 |
| Phase C `impact-analysis.md` 가 작은 변경에 과한 산출물 | M | analyzing-ko 본문에 "변경 규모 평가 → 작은 변경은 impact-analysis 생략 가능" 분기 명시 |
| Phase B 회귀 AC 강제로 trivial 1 줄 변경 무거워짐 | M | spec.md §유형 = "trivial" 라벨로 강제 면제 (Q-B 결정 → analyzing 메타 사전 추정) |
| 본가 superpowers 와 차이 누적 → 동기화 비용 | L | 모든 변경에 `reference_upstream` frontmatter "specops-auto-ko 독자 추가" 명시 (NFR-3 / AC-11) |
| `current-state.md` / `impact-analysis.md` stale 화 | L | FID-scoped 산출물이라 stale 위험 작음. 동일 FID 재진입 시 회전 정책 (clarifying-ko `rotate-evaluator-artifact.sh` 패턴) |
| Phase 간 결합 — 부분 ship 시 chain 깨짐 | H | **Deploy 는 4 Phase 완료 후 일괄** (설계 원칙). 각 Phase 끝 단위 검증 + 4 Phase 완료 시점 통합 검증 4 시나리오 |
| Phase A→C rework — Step 1 인라인이 C 에서 이전+축약 (절반 throwaway) | L | 1~2 시간 비용 인정. plan §위험 표에 명시. 대안 (A 생략 C 직행) 은 D 진입 신호 부재로 더 비효율 |

## 7. 자체 검토 (5원칙 체크리스트)

- [x] **투명성**: 각 태스크 카테고리 (commit 1~4) 에 "왜" 한 줄이 §5 각 commit 헤더에 명시 (`회귀 AC must 강제` / `Step 1 유지보수 분기 + current-state.md` 등)
- [x] **문지기**: 파괴적 작업 별도 스텝 분리 — 본 작업은 Markdown 편집이라 파괴적 작업 없음. 단 dogfood FID 시나리오 실행 시 `.specops/<test-FID>/` 디렉토리 생성·정리는 운영 문서로 분리 (사용자 확인 ⚠️ 표시 — decomposing-ko 단계에서 task 별 명시)
- [x] **주권 존중**: 사용자 승인 지점 명시 — 4 commit 끝마다 사용자 검토 (decomposing-ko 단계의 task 5 스텝 마지막 "커밋 + 사용자 검토" 가 ⚠️ 게이트). 통합 검증 evidence.md 도 ⚠️ 사용자 검토 후 PR 생성
- [x] **한계 고백**: §1 가정 5 건 채워짐 (web fetch 미수행 / gh fallback / args prefix 약속어 / trivial 메타 source / .specops gitignore 운영 패턴)

## 8. Advisor 협의 기록

| 일시 | 질의 요지 | advisor 권고 | 채택 여부 | 반영 위치 |
|---|---|---|---|---|
| 2026-04-27 (high-level plan 작성 단계) | Phase 독립성 모순 + 변경 파일 카운트 오류 + 4 마이너 (AC-R-N 컨벤션 / A→C rework 비용 / §검증 추상성 / dogfooding §유형 라벨) | 블로커 2 수정 / 마이너 4 반영 / 본가 web fetch skip 정당화 | 전체 채택 | `~/.claude/plans/valiant-splashing-deer.md` §advisor 협의 결과 + spec.md §9 + 본 plan.md §1 가정 / §6 위험 |

> 본 plan.md (Lifecycle plan.md) 작성 중 advisor 추가 호출 사유 없음 — high-level plan 단계의 협의 결과 + specifying Q1~Q4 + clarifying Q-A~Q-D 의 결정으로 모호 지점 모두 해소. 본 plan.md 는 그 결정의 implementation 카테고리 매핑일 뿐.

## 9. 다음 단계

`specops-auto-ko:decomposing-ko` 호출 — 본 plan.md 의 §5 카테고리 (commit 1~4) 를 bite-sized TDD 태스크 (2~5 분 단위, 5 스텝 패턴) 로 분해하여 `tasks.md` 산출. dogfood FID 별 task 명시.

실행 방식 결정은 decomposing-ko 후 사용자에게 안내:

1. **서브에이전트 주도 (권장)** — `specops-auto-ko:implementing-ko` 가 task 별 fresh 서브에이전트 dispatch + 2 단계 리뷰
2. **인라인 실행** — 본 세션 배치 + 체크포인트 리뷰

---

*작성: planning-ko · 2026-04-27 · FID: 20260427-maintenance-lifecycle · 생성 커맨드: /plan*
