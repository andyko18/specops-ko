---
name: harness/context-resets
description: 각 Lifecycle 커맨드 종료 시 세션 컨텍스트를 리셋하고 session-progress.md에서만 맥락을 재주입한다
layer: 1
reference_upstream: revfactory/harness + Anthropic harness-design-long-running-apps (2025)
specops_version: 0.1.0
---

# Harness 기법 2 — Context Resets

## 개념

장시간 Lifecycle을 한 세션에 이어가면 컨텍스트가 오염된다. 이전 단계의 시행착오·폐기된 가설·중간 산출물이 다음 단계 판단에 섞여 들어온다. **각 커맨드 종료 시 의도적으로 맥락을 끊고**, 다음 커맨드는 **`session-progress.md`** 와 **`.specops/<FID>/`** 에서만 필요한 것을 읽어 재시작한다.

## 원칙

- 서브에이전트는 **매번 fresh 세션**에서 호출한다. 프롬프트에는 읽어야 할 파일 경로만 담는다.
- 에이전트는 **이전 대화 내용을 기억하지 못한다고 가정**하고 항상 파일에서 시작한다.
- 재주입 경로는 오직 두 개: (a) `session-progress.md` (무엇까지 했는가), (b) `.specops/<FID>/*.md` (산출물).

## 체크리스트

1. 커맨드 종료 시 `session-progress.md`에 **무엇이 끝났고 다음 커맨드는 무엇인지** 한 줄 append.
2. 다음 커맨드 착수 시 `session-progress.md` 마지막 10~20줄만 읽어 "현재 FID", "직전 단계", "차단 요소"를 파악.
3. 직전 단계 산출물이 필요하면 **파일로 다시 읽어라**. 대화에서 기억나는 내용으로 진행하지 마라 — 부정확하다.
4. Generator/Evaluator 전환 시 반드시 리셋. 예: planner-ko 종료 → analyzer-ko 호출 시 대화 맥락 단절.
5. 세션이 실제로 종료(Claude Code 재시작)되어도 `session-progress.md`만으로 복귀 가능해야 한다.

## session-progress.md 포맷

```markdown
# Session Progress — <project-name>

## <FID-1> · <제목>
- 2026-04-20 10:00 /specify 완료 (spec.md, acceptance-criteria.md)
- 2026-04-20 10:30 /clarify 완료 (clarifications.md — 3개 쟁점 해소)
- 2026-04-20 11:10 /plan 완료 (plan.md, data-model.md)
- 2026-04-20 11:30 /tasks 완료 (tasks.md — 12 바이트-사이즈 태스크)
- 2026-04-20 12:00 /analyze BLOCK (analysis.md — 태스크 3 계약 위반)
- 2026-04-20 13:00 /plan 재실행 완료
- 2026-04-20 13:20 /analyze PASS

## <FID-2> · ...
```

한 줄 규칙: `<YYYY-MM-DD HH:MM> <command> <상태> (<산출·메모>)`.

## 안티패턴

- 세션 맥락만 믿고 파일 재독 없이 다음 커맨드 진행
- `session-progress.md` 업데이트 누락 — 세션 재시작 후 복귀 불가
- 전역 로그에 **모든 대화 내용**을 담으려 함 — 의도는 "재시작에 필요한 최소 단서"뿐
- 이전 커맨드의 피드백을 구두로 전달받아 구현 — 반드시 Evaluator가 쓴 `analysis.md` 또는 `review.md` 파일을 읽어라

## v0.2 확장 예고

`hooks/context-reset.sh`가 새 세션 진입을 감지해 자동으로 `session-progress.md` 마지막 블록을 주입. v0.1은 수동 재독.
