<!-- FID: 20260427-maintenance-lifecycle -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md + obra/superpowers@v5.0.7 (브랜치 패턴) -->
<!-- layer: Lifecycle-Artifact -->

# specops-auto-ko 유지보수 Lifecycle 보강 명세 — 20260427-maintenance-lifecycle

## 1. 개요

**목적**: specops-auto-ko 자율 Lifecycle 에 **유지보수 분기** (버그픽스·리팩터링·기능 변경) 를 일급 지원하여 기존 코드 분석·회귀 방지를 강제한다.

**배경**: 현행 Lifecycle 은 신규 생성에 최적화되어 있고, 유지보수 진입 시 기존 시스템 분석 단계 부재 + 회귀 방지 AC 강제 부재 + 자연어 신호 매칭 누락 문제가 있다. 본가 superpowers v5.0.7 도 동일 한계 (brainstorm command deprecated, brainstorming SKILL 본문은 specifying 흡수 — 유지보수 전용 분기 부재). 본 보강안은 specops-auto-ko 가 본가에 앞서 구현하는 차별화 포인트.

**§유형**: **신규** (specops-auto-ko 플러그인에 신규 capability 추가 — 기존 유지보수 아님 → 회귀 AC 강제 면제. 단 통합 검증 시나리오 1 이 신규 chain 무손상 별도 보장)

**성공 판정**: `/maintain auth.js 토큰 만료 버그` 입력 시 analyzing-ko (current-state.md + impact-analysis.md) ★ HARD GATE → specifying-ko 유지보수 분기 → spec.md `§유형: 유지보수` 라벨 + acceptance-criteria.md 회귀 must AC ≥ 1 자동 강제가 chain 종단까지 동작.

## 2. 범위

### 포함

DAG 신호: **CHAIN — Phase 간 결합 존재** (B 의 §유형 라벨이 A 산출 의존, A 의 진입 분기가 D 산출 의존, C 가 A 산출물 흡수 + D 진입 신호 의존). plan §위험 "Deploy 는 4 Phase 완료 후 일괄" 와 일관.

- **Phase B**: `templates/acceptance-criteria.md` 회귀 AC 섹션 + `skills/sprint-contracts-ko/SKILL.md` 검증 1 줄 (독립 — 단독 가능)
- **Phase A**: `templates/current-state.md` 신설 + `skills/specifying-ko/SKILL.md` Step 1 분기 (의존: B 의 §유형 라벨)
- **Phase D**: `skills/using-specops-auto-ko-ko/SKILL.md` 신호 매칭 + `commands/maintain.md` 신설 (의존: A 의 진입 분기)
- **Phase C**: `skills/analyzing-ko/SKILL.md` 신설 + `templates/impact-analysis.md` 신설 + chain 재배선 3 곳 (의존: A, D)
- **README.md Lifecycle Chain 섹션 갱신**: `analyzing-ko` + `commands/maintain.md` 추가 반영 (위치 미확정 — Phase D 안 / 별도 commit 중 §8 Q-D 로 clarifying 위임. NFR-4 + AC-12 가 검증 책임)
- **통합 검증 4 시나리오**: 신규 회귀 / 자연어 유지보수 / 슬래시 유지보수 / 회귀 AC 누락 detection (의존: B, A, D, C 모두)

### 제외 (YAGNI)

- `/maintain` 외 추가 진입 슬래시 (`/refactor`, `/bugfix` 등)
- analyzing-ko 의 자동 코드 분석 (사람이 grep/Read 로 직접 작성)
- impact-analysis.md 의 외부 시스템 자동 호출 (PR/이슈 히스토리만 `gh` CLI 사용)
- 본가 superpowers 와의 자동 sync 메커니즘 (수동 frontmatter 추적)
- analyzing-ko 의 영향 분석 결과 자동 trivial 판정 (Q3 자기선언 + 줄 수 임계 ≤ 5 와 충돌)

## 3. 사용자 시나리오

### 주요 시나리오 — 자연어 유지보수 진입

**사용자**: specops-auto-ko 플러그인 사용자 (다른 Claude Code 프로젝트에서 유지보수 진행)
**상황**: `auth.js` 의 토큰 만료 처리에 버그가 있어 수정 필요
**행동**: `"auth.js 토큰 만료 버그 고쳐줘"` 자연어 입력
**기대 결과**:
1. 메타 skill `using-specops-auto-ko-ko` 가 maintenance flag 로 분류
2. analyzing-ko 가 `current-state.md` (5 항목 baseline) + `impact-analysis.md` (외부 영향·마이그/롤백·PR/이슈 요약) 산출
3. ★ HARD GATE: 사용자가 분석 결과 검토 후 진행 승인
4. specifying-ko Step 1 [유지보수 분기] 가 analyzing-ko 결과 참조 (재분석 생략)
5. spec.md `§유형: 유지보수` 라벨 자동 + acceptance-criteria.md `AC-R-1: 기존 토큰 정상 흐름은 변경되지 않는다` must AC 자동 강제
6. clarifying-ko → planning-ko → … → verifying-evidence-ko 가 회귀 AC 도 검증

### 보조 시나리오 — 슬래시 유지보수 진입

**행동**: `/maintain payment 모듈 리팩터링`
**기대 결과**: 자연어 진입과 동일 chain. command 가 Skill args 첫 줄에 `__entry: maintain` 키워드 합성하여 specifying-ko 로 전달.

### 보조 시나리오 — trivial 변경

**행동**: 1~5 줄 typo 수정 진입 시 `spec.md §개요` 에 `§유형: trivial` 라벨 자동 부여
**기대 결과**: sprint-contracts-ko 가 회귀 AC 강제 면제

### 보조 시나리오 — 신규 chain 무손상

**행동**: `/start CSV 줄 수 세기 CLI`
**기대 결과**: 4 Phase 모두 적용 후에도 현재와 100% 동일 흐름. analyzing-ko 미호출, §유형 = "신규", 회귀 AC 강제 X.

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | `templates/acceptance-criteria.md` 에 "회귀 방지 AC (유지보수 FID 필수)" 섹션 + `AC-R-N` 템플릿 추가 | must |
| FR-2 | `skills/sprint-contracts-ko/SKILL.md` Evaluator 체크리스트에 "유지보수 FID 인 경우 회귀 방지 must AC ≥ 1 포함 확인" 1 줄 + 안티패턴 "회귀 AC 없는 유지보수 FID" 추가 | must |
| FR-3 | `templates/current-state.md` 신설 — baseline 5 항목 (변경 대상 / 호출자·의존 / 기존 테스트 / 관찰 가능 동작 / 회귀 위험) | must |
| FR-4 | `skills/specifying-ko/SKILL.md` Step 1 에 신규/유지보수 분기 추가. 유지보수 시 5 항목 mini-checklist + `current-state.md` 산출 + ★ HARD GATE | must |
| FR-5 | `skills/specifying-ko/SKILL.md` Step 1 분기가 args 첫 줄 `__entry: maintain` 키워드 검사로 분기 결정 (Q1) | must |
| FR-6 | spec.md `§유형: 유지보수 / 신규 / trivial` 라벨 자동 기재 (specifying-ko 가 분기 결정 시) | must |
| FR-7 | `skills/using-specops-auto-ko-ko/SKILL.md` 신호 예시에 "버그 / 리팩터링 / 수정 / 개선 / 변경" 4 줄 추가. 분류 후 Skill args 첫 줄에 `__entry: maintain` 합성 | must |
| FR-8 | `commands/maintain.md` 신설 — `/start` 와 동등 진입 패턴, frontmatter trigger `/maintain`. analyzing-ko 호출 후 specifying-ko 로 chain | must |
| FR-9 | `skills/analyzing-ko/SKILL.md` 신설 — current-state.md (A 의 5 항목) + impact-analysis.md (외부 영향·마이그/롤백·PR/이슈) 산출 + ★ HARD GATE | must |
| FR-10 | `templates/impact-analysis.md` 신설 — 외부 영향 / 마이그/롤백 / 관련 PR·이슈 요약 3 항목 | must |
| FR-11 | C 적용 시 `skills/specifying-ko/SKILL.md` Step 1 유지보수 분기 본문이 "analyzing-ko 결과 참조" 로 축약 (재분석 생략) | must |
| FR-12 | 메타 skill 의 `__entry` 합성이 자연어 진입에서도 동작 (분류 결과 → args 합성) | must |
| FR-13 | spec.md `§유형: trivial` 라벨이 변경 라인 ≤ 5 자동 부여 (specifying-ko 가 git diff 줄 수 계산 — 단 analyzing-ko 가 산출한 current-state.md §1 파일·라인 범위 메타로 사전 추정 허용) | should |
| FR-14 | 회귀 AC 누락 시 sprint-contracts-ko evaluator 가 verdict = BLOCK + blocking_acs 에 "회귀 AC 누락" 명시 (Generator/Evaluator 분리 — 자동 회귀 호출 안 함) | must |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 성능 (신규 chain) | 신규 분기 진입 시 추가 latency = 0 (Step 1 분기는 신규에서 기존과 동일 경로) |
| NFR-2 | 호환성 | bash 3.2+ (macOS 실측 · Linux 미검증) — 본 작업은 SKILL.md / template / commands 편집이라 bash 의존 없음 |
| NFR-3 | 유지보수성 | 모든 변경에 `reference_upstream` frontmatter 명시 + "specops-auto-ko 독자 추가" 주석 → 본가 변경 추적 시 diff 비교 가능 |
| NFR-4 | 문서화 | README.md Lifecycle Chain 섹션이 analyzing-ko + maintain.md 추가 반영 (Phase D 의 일부) |
| NFR-5 | 5 원칙 준수 | 1 투명성 (skill 호출 announce), 2 문지기 (binary 신호), 4 주권 (HARD GATE 사용자 검토), 5 한계 고백 (분류 모호 시 사용자 확인) |

## 6. 제약사항

- **기술 스택**: Markdown (SKILL.md / template / commands), bash 3.2+ (기존 hooks 호환), gh CLI (impact-analysis.md PR/이슈 요약 — 선택)
- **의존성**: `obra/superpowers@v5.0.7` reference_upstream 명시 유지. `templates/spec.md` / `templates/acceptance-criteria.md` 기존 포맷 호환.
- **호환성**: 기존 신규 FID 들 (`20260424-r6-bash-test-gate`, `20260427-csvstat-cli`, `20260427-screen-design` 등) 의 evaluator 결과는 보강 전과 동일해야 함 (회귀 AC 강제 발동 안 됨).
- **Generator/Evaluator 분리**: sprint-contracts-ko evaluator 는 BLOCK 판정만. specifying-ko / clarifying-ko 자동 호출 금지.
- **Deploy 단위**: 4 Phase 완료 후 일괄 (1 PR, 4 commit). Phase 단위 부분 ship 금지 (plan §위험).

## 7. 가정 (5 원칙 5 — 한계 고백)

- 본가 superpowers v5.0.7 의 `brainstorming SKILL` 본문 흡수 패턴 분석은 specops-auto-ko 의 specifying-ko + clarifying-ko frontmatter 의 reference_upstream 인용 + start.md 의 "(deprecated하지만 진입 패턴 참고)" 주석에 근거. 본가 v5.0.7 release 의 실제 디렉토리 구조 web fetch 검증은 미수행 (advisor 가 "보강 결정에 영향 없음" 으로 skip 정당화).
- `/maintain` 슬래시 진입 시 사용자가 인자 없이 진입할 가능성 있으나 `/start` 안티패턴 ("인자 없이 진입") 동일 처리 — modally 되묻기.
- analyzing-ko 의 PR/이슈 히스토리 요약은 `gh` CLI 가용 환경 가정. 미가용 시 한계 고백 ("PR/이슈 요약 미수행") 명시.
- specifying-ko 의 git diff 줄 수 계산 (FR-13) 은 첫 진입 시점에는 변경이 없으므로 analyzing-ko 산출 current-state.md §1 의 파일·라인 범위 메타로 사전 추정. 실제 구현 후 재계산 필요할 수 있음 (clarifying-ko 단계에서 라벨 갱신 가능).

## 8. 열린 질문

`/clarify` 단계에서 해소할 사항.

- Q-A: `__entry: maintain` args 키워드의 정확한 prefix 약속어 — `__entry:` / `<!-- entry: -->` / `[entry: maintain]` 중 어느 것? (collision 회피 목적)
- Q-B: trivial 라벨 자동 판정 시 git diff 시점 — specifying-ko 진입 시점은 변경 없음. analyzing-ko current-state.md §1 메타로 사전 추정 vs implementing-ko 후 재계산 vs sprint-contracts-ko evaluator 가 verifying 시점에 최종 판정?
- Q-C: analyzing-ko 의 `gh` CLI 미가용 환경 fallback — 한계 고백 (NFR-5 5 원칙 5) 으로 충분한가, 아니면 git log 만 사용?
- Q-D: README.md Lifecycle Chain 섹션 갱신을 Phase D 안에 두는가, 별도 5 번째 commit 으로 분리하는가? (현재 plan §변경 파일 총괄 에 README 미명시 — 누락)

## 9. Advisor 협의 기록

본 spec 작성 자체는 plan 의 advisor 협의 결과 (B-1, B-2, M-3~M-6) 를 승계. spec 작성 중 추가 advisor 호출 없음.

| 일시 | 질의 요지 | advisor 권고 | 채택 여부 | 반영 위치 |
|---|---|---|---|---|
| 2026-04-27 (plan 단계) | Phase 독립성 모순 + 변경 파일 카운트 오류 + 4 마이너 | 블로커 2 수정 / 마이너 4 반영 / 본가 web fetch skip | 전체 채택 | plan.md §advisor 협의 결과 + 본 spec §2~§6 |

> 본 spec 작성 중 advisor 추가 호출 사유 없음 — plan 본문 + 명확화 4 회 (Q1~Q4) + 본가 관계 1 회 결정으로 모호 지점 모두 해소. 단 §8 Q-A~Q-D 4 건은 clarifying-ko 위임.

## 10. 참조

- 승인된 plan: `~/.claude/plans/valiant-splashing-deer.md` (2026-04-27)
- `skills/specifying-ko/SKILL.md` Step 1 / §165 "기존 코드베이스 작업"
- `skills/sprint-contracts-ko/SKILL.md` Evaluator 체크리스트 / 안티패턴
- `skills/using-specops-auto-ko-ko/SKILL.md` §19~24 신호 매칭
- `commands/start.md` 자매 진입로 + 안티패턴 "인자 내용 2 차 판단"
- `templates/acceptance-criteria.md` AC 템플릿
- 본가 비교: `obra/superpowers@v5.0.7` (brainstorm command deprecated, brainstorming SKILL 흡수)
- 기존 dogfood FID 참고: `.specops/20260424-r6-bash-test-gate/` (HARD-GATE 기계적 차단 예시)

---

*작성: specifying-ko · 2026-04-27 · FID: 20260427-maintenance-lifecycle · 생성 커맨드: /start*
