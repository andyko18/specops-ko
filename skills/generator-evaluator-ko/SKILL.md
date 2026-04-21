---
name: generator-evaluator-ko
description: 생성 에이전트와 평가 에이전트를 엄격히 분리하여 자기평가 편향을 차단한다 (OMC 흡수)
layer: 1
reference_upstream: obra/omc + revfactory/harness + Anthropic harness-design-long-running-apps (2025)
specops_version: 0.1.0
---

# Harness 기법 3 — Generator / Evaluator 분리

## 개념

같은 에이전트가 자기 산출물을 평가하면 **확증 편향**이 발생한다. 생성(Generator)과 평가(Evaluator)를 다른 에이전트·다른 세션·다른 역할로 분리해 교차 금지 원칙을 강제한다.

## 페어 매트릭스

| 단계 | Generator | 산출 | Evaluator | 검증 산출 |
|---|---|---|---|---|
| 명세 | specifier-ko | spec.md, acceptance-criteria.md | clarifier-ko | clarifications.md |
| 설계 | planner-ko | plan.md, data-model.md, contracts/ | analyzer-ko | analysis.md (PASS/BLOCK) |
| 분해 | task-decomposer-ko | tasks.md | analyzer-ko | analysis.md 보강 |
| 구현 | implementer-ko | 코드 + session-progress 갱신 | code-reviewer-ko | review.md |
| 검증 종합 | — | (앞 모든 산출물) | verifier-ko | verify.md (JSON) |

**Generator 4** (specifier, planner, task-decomposer, implementer) / **Evaluator 4** (clarifier, analyzer, code-reviewer, verifier).

## 엄격 규칙

1. **교차 금지**: Generator는 판정하지 않고, Evaluator는 새 산출물을 만들지 않는다.
2. **프롬프트 헤더 의무 선언**: 서브에이전트 dispatch 프롬프트 첫 줄에 다음 중 하나를 명시.
   - `You are a GENERATOR. You MUST produce <output artifact>. You MUST NOT judge prior outputs.`
   - `You are an EVALUATOR. You MUST produce ONLY a judgment artifact (PASS/BLOCK). You MUST NOT modify prior artifacts.`
3. **세션 분리**: Generator 세션과 Evaluator 세션은 별개 서브에이전트 호출로 분리. context-resets 스킬 준수.
4. **파일 통로만**: Evaluator는 Generator의 산출 파일만 읽는다. Generator의 사고 과정·중간 메모에 접근 금지.

## 체크리스트 (커맨드 구현 시)

- [ ] 커맨드 frontmatter `specops_generator_or_evaluator` 필드가 올바른가?
- [ ] Generator 커맨드는 `specops_artifact_out`에 **새 파일**을 명시하는가?
- [ ] Evaluator 커맨드는 `specops_artifact_out`에 **판정 파일**만 명시하는가?
- [ ] 서브에이전트 호출 시 역할 선언 헤더를 포함하는가?
- [ ] Evaluator가 BLOCK 판정 시, 수정은 Generator 재호출로 이뤄지는가? (Evaluator가 직접 고치지 않음)

## 안티패턴

- 같은 에이전트가 "쓰고 검토하고 수정" 전부 수행 → 자기평가 편향
- Evaluator가 "빠르니까 내가 고칠게요" 라며 산출물 수정 → 재현 불가능한 수정 사슬 발생
- Generator가 "내가 봐도 문제없어 보여요" 라며 평가 생략 → Evaluator 우회
- Gen/Eval 페어 바깥의 에이전트가 산출물 수정 → 소유권 위반

## 예시

**GOOD**: `/analyze` 실행 → analyzer-ko가 `plan.md`를 읽고 `analysis.md`에 "BLOCK: 태스크 3이 acceptance-criteria 2번을 충족하지 않음" 기록 → 사용자가 `/plan` 재실행 → planner-ko가 `analysis.md`의 BLOCK 사유를 읽고 `plan.md` 갱신.

**BAD**: `/analyze` 실행 중 analyzer-ko가 `plan.md`의 태스크 3을 직접 수정. → 계약 위반. planner-ko의 소유물을 건드림.
