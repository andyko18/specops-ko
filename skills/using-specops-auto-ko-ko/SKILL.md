---
name: using-specops-auto-ko-ko
description: 모든 대화 시작 시 활성 — specops-auto-ko 한국어 자율 Lifecycle 메타 skill. 사용자 입력에서 기능 요청 신호 감지 시 specops-auto-ko:specifying-ko 자동 호출 강제 (Superpowers using-superpowers 한국어 재창작 + 5원칙 주입)
layer: 1
reference_upstream: obra/superpowers@v5.0.7 skills/using-superpowers/SKILL.md
specops_version: 0.0.0
used_by: 모든 Claude Code 세션 (PoC v0.0 — 자동 활성 검증 단계)
---

# Harness 메타 스킬 — specops-auto-ko 자율 Lifecycle 진입

<SUBAGENT-STOP>
서브에이전트로 dispatch되어 특정 task를 실행 중이라면 본 skill 건너뜀.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
1% 가능성이라도 specops-auto-ko Lifecycle skill이 적용될 수 있다면 **반드시** 호출한다.

특히 사용자 입력이 다음 신호를 포함하면 즉시 `specops-auto-ko:specifying-ko` 호출:
- "X 기능을 만들고 싶어"
- "Y CLI / API / 모듈 신규"
- "Z를 구현해줘"
- "/start <기능>" 슬래시
- 명확한 신규 산출물 요청

> **경계**: `/start <인자>` 슬래시의 동작 정의는 `commands/start.md` 가 Source of Truth. 본 메타 skill 은 **자연어 입력** 의 신호 감지만 책임한다. `/start` 에 붙은 인자 내용이 "기능 설명으로 보이지 않는다"는 이유로 specifying-ko 호출을 보류하는 2차 판단은 `commands/start.md` 안티패턴 "인자 내용 2차 판단" 에 의해 금지 — 슬래시 진입은 무조건 specifying-ko 로 직행.

이는 협상 사항이 아니다. 합리화로 우회 금지.
</EXTREMELY-IMPORTANT>

## 우선순위

specops-auto-ko skill은 기본 시스템 동작을 override하나 **사용자 명시 지시가 항상 최우선**:

1. CLAUDE.md / 사용자 직접 지시 (최우선)
2. specops-auto-ko skill (기본 시스템 override)
3. 기본 시스템 프롬프트 (최하위)

CLAUDE.md가 "TDD 쓰지 말 것"이고 skill이 "항상 TDD"라면 → 사용자 지시 따름.

## 자율 Lifecycle 진입 흐름

```
사용자 입력
    ↓
본 메타 skill 자동 활성 (대화 시작 시)
    ↓
신호 감지?
    ↓ YES                              ↓ NO
specops-auto-ko:specifying-ko 호출            일반 응답
    ↓
spec.md + acceptance-criteria.md 작성
    ↓
HARD GATE: "spec 검토. 다음 skill(clarifying-ko) 진행? [y/n]"
    ↓ y
specops-auto-ko:clarifying-ko (skill 본문이 다음 chain 명시)
    ↓
... → planning-ko → decomposing-ko → implementing-ko (subagent dispatch) → verifying-evidence-ko → receiving-code-review-ko
    ↓
"PR 생성? [y/n]"
```

**핵심**: Conductor 에이전트 없음. 본 메타 skill + 각 engine skill 본문이 chain 형성.

## skill 호출 방법

Claude Code: `Skill` 도구 사용. skill 호출 시 내용이 로드되어 제시됨 — 그대로 따른다. skill 파일을 `Read` 도구로 직접 읽지 말 것.

호출 형식: skill 이름은 `specops-auto-ko:specifying-ko` 같은 namespace 포함.

## 적색 플래그 — 중단

다음 생각이 떠오르면 **중단하고 메타 skill 다시 검토**:

| 생각 | 실제 |
|---|---|
| "이건 단순 질문이라 skill 불필요" | 신호가 있는지 다시 보라 |
| "맥락 더 필요하니 clarifying부터" | specifying이 먼저. clarify는 specifying 종료 후 chain |
| "사용자가 이미 코드 보여줬으니 implementing 직진" | spec 없이 구현 금지. 5원칙 4·5 위반 |
| "skill 너무 무거워 보임" | 단순 질문이면 NO 분기로. 신호 있으면 무조건 호출 |
| "기억나는 skill이라 다시 안 읽음" | skill은 진화함. 매번 호출 |

## 5원칙 주입

| 원칙 | 본 skill 연결 |
|---|---|
| 1 투명성 | skill 호출 시 "Using <skill> to <purpose>" 명시 — 침묵 진행 금지 |
| 2 문지기 | 신호 감지는 binary — 회색지대 만들지 말 것 |
| 4 주권 | HARD GATE는 engine skill이 본문에서 강제. 메타 skill은 진입만 책임 |
| 5 한계 고백 | skill이 적합하지 않다고 판단되면 후행 단계에서 사용자에게 "이 skill로 충분한가?" 질문 가능 |


## 참조

- `obra/superpowers@v5.0.7 skills/using-superpowers/SKILL.md` — 원본
- `~/Project/0.Claude/specops-ko/docs/case-studies/2026-04-21-specops-auto-ko-design.md §15` — 본 skill 설계 근거
- `skills/engine/*-ko.md` (10건) — Phase 1 구축 완료
- `skills/harness/*-ko.md` (5건 + 본 skill) — 내부 규약
- `commands/start.md` — 슬래시 진입점
- `hooks/hooks.json` — SessionStart·Stop hook 매니페스트

---

*PoC v0.0 · 2026-04-21 · Phase 1 구축 완료 · Superpowers using-superpowers 한국어 재창작 + 5원칙 주입 + Lifecycle 신호 감지 추가*
