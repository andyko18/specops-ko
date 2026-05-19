<!-- FID: 20260518-plan-doc-reviewer -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md -->
<!-- layer: Lifecycle-Artifact -->

# Plan Document Reviewer 서브에이전트 명세 — 20260518-plan-doc-reviewer

## 1. 개요

**§유형**: 유지보수

**목적**: `planning-ko`의 §자체 검토 직후 독립 서브에이전트(Plan Document Reviewer)를 dispatch하여 자기평가 편향을 제거하고 플랜-스펙 정합성을 외부 시각으로 검증한다.

**배경**: 현재 `planning-ko`는 §자체 검토를 Claude 자신이 직접 수행한다. 같은 컨텍스트에서 작성된 플랜을 같은 모델이 검토하므로 같은 편향이 적용된다. `obra/superpowers`의 `plan-document-reviewer-prompt.md` 패턴은 이 문제를 독립 서브에이전트로 해소한다. 서브에이전트는 신선한 컨텍스트로 spec.md와 plan.md를 대조 검증하여 decomposing-ko 진입 전에 결함을 차단한다.

**성공 판정**: `planning-ko`가 플랜 작성 + 자체 검토 후 `plan-document-reviewer-prompt.md` 기반 서브에이전트를 dispatch하고, 서브에이전트가 APPROVED 또는 ISSUES FOUND 판정을 반환하면 완성.

## 2. 범위

### 포함
- `skills/planning-ko/SKILL.md` §자체 검토 수정 — 자체 체크리스트 후 서브에이전트 dispatch 지시 추가 (의존: plan-document-reviewer-prompt.md)
- `skills/planning-ko/plan-document-reviewer-prompt.md` 신규 생성 — obra 패턴 기반 Plan Reviewer 프롬프트 (독립 — 병렬 구현 가능)
- `scripts/tests/test-validate-structure.sh` planning-ko 파일 카운트 +1 (의존: plan-document-reviewer-prompt.md)

### 제외 (YAGNI)
- Plan Reviewer 판정 결과의 자동 수정 기능 (ISSUES FOUND 시 수동 확인만)
- 별도 evidence 파일 생성 (planning-ko §8 Advisor 협의 기록에 인라인 기록으로 충분)
- 다른 skill의 서브에이전트 리뷰 패턴 적용 (scope 외)

## 3. 사용자 시나리오

### 주요 시나리오
**사용자**: Claude Code (planning-ko 실행 중)
**상황**: `planning-ko`가 plan.md 작성 + §자체 검토(체크리스트) 완료 직후
**행동**: `plan-document-reviewer-prompt.md`의 지시로 general-purpose 서브에이전트 dispatch → spec.md + plan.md 대조 검증
**기대 결과**: 서브에이전트가 Completeness·Spec Alignment·Task Decomposition·Buildability 4축 검토 후 `APPROVED` 또는 `ISSUES FOUND: <내용>` 반환 → planning-ko가 결과를 반영하고 decomposing-ko 진입

### 보조 시나리오
**상황**: 서브에이전트가 ISSUES FOUND 반환
**행동**: planning-ko가 이슈를 plan.md에 반영하고 session-progress append 전에 수정
**기대 결과**: 수정된 plan.md로 decomposing-ko 진입

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | `planning-ko`는 §자체 검토 완료 후 `plan-document-reviewer-prompt.md` 기반 서브에이전트를 1회 dispatch한다 | must |
| FR-2 | `plan-document-reviewer-prompt.md`는 obra 패턴 준수 — Completeness·Spec Alignment·Task Decomposition·Buildability 4축 검토 | must |
| FR-3 | 서브에이전트는 `APPROVED` 또는 `ISSUES FOUND: <상세>` 중 하나로 판정을 반환한다 | must |
| FR-4 | `ISSUES FOUND` 시 planning-ko가 이슈를 plan.md에 반영 후 session-progress append로 진행한다 | must |
| FR-5 | `validate-structure.sh` planning-ko 파일 카운트가 신규 프롬프트 파일을 반영해 PASS한다 | must |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 서브에이전트 컨텍스트 | general-purpose subagent; spec.md + plan.md 경로를 프롬프트에 명시 |
| NFR-2 | 기존 chain 영향 | decomposing-ko 진입 지연(서브에이전트 1회 추가)만 허용 — 기존 인터페이스 불변 |
| NFR-3 | 프롬프트 파일 위치 | `skills/planning-ko/plan-document-reviewer-prompt.md` (planning-ko 디렉토리 내) |

## 6. 제약사항

- `spec.md`·`plan.md` 경로는 FID 기반 `.specops/<FID>/` 하위 — 서브에이전트에 정확한 경로 전달 필수
- `plan-document-reviewer-prompt.md`는 standalone 문서 — planning-ko SKILL.md가 dispatch 지시를 인라인으로 포함
- 서브에이전트 dispatch는 SKILL.md의 텍스트 지시 — bash 명령이 아닌 Claude 행동 명세

## 7. 데이터 모델

해당 없음 (bash 스크립트·SKILL.md 수정만).

## 8. 인터페이스

**입력**: planning-ko 내부에서 dispatch — `FID`, `spec.md 경로`, `plan.md 경로`
**출력**: 서브에이전트 반환값 — `APPROVED` 또는 `ISSUES FOUND: <상세>`

## 9. 열린 질문

없음 (clarifying-ko에서 해소 예정).

## 참조

- `.specops/20260518-plan-doc-reviewer/current-state.md` — 변경 대상 baseline
- `.specops/20260518-plan-doc-reviewer/impact-analysis.md` — 외부 영향 분석
- `obra/superpowers@v5.0.7 skills/writing-plans/plan-document-reviewer-prompt.md` — 원본 패턴

---

*작성: andyko · 2026-05-18 · FID: 20260518-plan-doc-reviewer · 생성 커맨드: /specify*
