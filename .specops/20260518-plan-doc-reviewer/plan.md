<!-- FID: 20260518-plan-doc-reviewer -->
<!-- OWNER_COMMAND: /plan -->
<!-- reference_upstream: github/spec-kit plan-template.md + obra/superpowers writing-plans -->
<!-- layer: Lifecycle-Artifact -->

# Plan Document Reviewer 서브에이전트 구현 플랜 — 20260518-plan-doc-reviewer

> **에이전트 워커용**: 필수 하위 스킬 — `specops-auto-ko:implementing-ko` (권장) 또는 `specops-auto-ko:decomposing-ko` 사용. 스텝은 체크박스 `- [ ]` 문법으로 추적.

**목표**: `planning-ko`의 §자체 검토 후 독립 서브에이전트(Plan Document Reviewer)를 dispatch하여 자기평가 편향 없이 플랜-스펙 정합성을 검증한다.

**아키텍처**: `skills/planning-ko/plan-document-reviewer-prompt.md`를 신규 생성 (obra 패턴 기반, Completeness·Spec Alignment·Task Decomposition·Buildability 4축). `skills/planning-ko/SKILL.md` §자체 검토 섹션에 dispatch 지시 5~8줄을 추가. 서브에이전트는 FID별 spec.md + plan.md를 읽고 APPROVED 또는 ISSUES FOUND 판정을 반환.

**기술 스택**: Markdown (SKILL.md 텍스트 지시 + 프롬프트 파일)

**관련 AC**: AC-1, AC-2, AC-3, AC-4, AC-R-1

---

## 1. 가정 (5원칙 5번)

- `obra/superpowers plan-document-reviewer-prompt.md`와 동일한 "Approve unless serious gaps" 정책을 따름
- SKILL.md는 Claude 행동 명세 — bash 명령이 아닌 텍스트 지시로 서브에이전트 dispatch 표현
- `.structure-baseline`이 `skills/*/SKILL.md` 카운트만 추적하므로 `plan-document-reviewer-prompt.md` 추가 시 baseline 수동 업데이트 불필요

## 2. 파일 구조

### 생성
- `skills/planning-ko/plan-document-reviewer-prompt.md` — Plan Reviewer 서브에이전트 프롬프트 (obra 패턴, 4축 검토)

### 수정
- `skills/planning-ko/SKILL.md:130-141` — §자체 검토 섹션에 dispatch 지시 추가 (기존 체크리스트 보존 + 서브에이전트 호출 지시 append)

### 삭제
- 없음

## 3. 데이터 모델

해당 없음.

## 4. 계약

**plan-document-reviewer-prompt.md 출력 계약**:
- `APPROVED` — 심각한 갭 없음, decomposing-ko 진입 허용
- `ISSUES FOUND: <항목별 상세>` — 이슈 내용 명시. planning-ko가 반영 후 진행

**SKILL.md dispatch 지시 위치**: §자체 검토 기존 3개 항목(L134-140) **뒤**, §5원칙 주입(L142) **앞**

## 5. 태스크 개요

1. **T1** — `plan-document-reviewer-prompt.md` 신규 생성 (프롬프트 본문 + 4축 체크리스트 + 판정 형식)
2. **T2** — `SKILL.md` §자체 검토 수정 (dispatch 지시 삽입)
3. **T3** — AC 검증 (grep 명령으로 AC-1~AC-4, AC-R-1 충족 확인)

T1 → T2 → T3 순차 의존.

## 6. 위험과 완화

| 위험 | 영향 | 완화 |
|---|---|---|
| SKILL.md §자체 검토 수정 시 기존 텍스트 파괴 | H | T2에서 기존 3개 항목 전문 보존 확인 + AC-R-1 grep 검증 |
| plan-document-reviewer 프롬프트가 obra 패턴과 불일치 | M | T1에서 4축 + APPROVED/ISSUES FOUND 형식 명시 |
| validate-structure.sh 오탐 | L | baseline은 SKILL.md만 추적 — 신규 prompt 파일 무영향 |

## 7. 자체 검토 (5원칙 체크리스트)

- [x] **투명성**: T1(프롬프트 생성 이유: obra 패턴), T2(SKILL.md 수정 이유: 자기평가 편향 제거), T3(AC 검증) 각각 근거 명시
- [x] **문지기**: 파괴적 작업 없음 (텍스트 파일 수정만)
- [x] **주권 존중**: 사용자 승인 필요 지점 없음 (유지보수 범위 내)
- [x] **한계 고백**: §1 가정 3건 명시

## 8. Advisor 협의 기록

해당 없음 — 본 plan 작성 중 불확실 지점 없음. spec.md + clarifications.md에서 obra 패턴 준용 + baseline 비영향이 이미 확인됨.

## 9. 다음 단계

`/tasks 20260518-plan-doc-reviewer` — 본 플랜을 바이트-사이즈 TDD 태스크로 분해.

---

*작성: andyko · 2026-05-18 · FID: 20260518-plan-doc-reviewer · 생성 커맨드: /plan*
