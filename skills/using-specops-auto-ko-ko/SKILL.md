---
name: using-specops-auto-ko-ko
description: 모든 대화 시작 시 활성 — specops-auto-ko 한국어 자율 Lifecycle 메타 skill. 사용자 입력에서 기능 요청 신호 감지 시 specops-auto-ko:specifying-ko 자동 호출 강제 (Superpowers using-superpowers 한국어 재창작 + 5원칙 주입)
layer: 1
reference_upstream: obra/superpowers@v5.0.7 skills/using-superpowers/SKILL.md
specops_version: 1.0.0
used_by: 모든 Claude Code 세션 (PoC v0.0 — 자동 활성 검증 단계)
---

# Harness 메타 스킬 — specops-auto-ko 자율 Lifecycle 진입

<SUBAGENT-STOP>
서브에이전트로 dispatch되어 특정 task를 실행 중이라면 본 skill 건너뜀.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
1% 가능성이라도 specops-auto-ko Lifecycle skill이 적용될 수 있다면 **반드시** 호출한다.

특히 사용자 입력이 다음 신호를 포함하면 즉시 `specops-auto-ko:specifying-ko` 호출:

**[신규 신호]** — `maintenance flag = false`:
- "X 기능을 만들고 싶어"
- "Y CLI / API / 모듈 신규"
- "Z를 구현해줘"
- "/start <기능>" 슬래시
- 명확한 신규 산출물 요청

**[유지보수 신호]** (Phase D — 신규 추가) — `maintenance flag = true`:
- "X 버그 고쳐줘 / 수정해줘"
- "Y 리팩터링 해줘"
- "Z 개선 / 변경"
- "/maintain <대상>" 슬래시

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
[선택] /brainstorming → brainstorming-ko (아이디어 탐색·수요 검증)
    ↓ (선택적 연결 — 강제 아님)
사용자 입력
    ↓
본 메타 skill 자동 활성 (대화 시작 시)
    ↓
신호 감지?
    ↓ YES                              ↓ NO
maintenance flag 분류 (Phase D 추가)        일반 응답
    ├─ false (신규)  → specifying-ko 직행 (args 그대로)
    └─ true (유지보수) → specifying-ko 호출 (args 첫 줄 "<!-- entry: maintain -->" prepend)
    ↓
spec.md + acceptance-criteria.md 작성
    ↓
HARD GATE: "spec 검토. 다음 skill(clarifying-ko) 진행? [y/n]"
    ↓ y
specops-auto-ko:clarifying-ko (skill 본문이 다음 chain 명시)
    ↓
... → planning-ko → decomposing-ko → implementing-ko (subagent dispatch) → verifying-evidence-ko → requesting-code-review-ko → receiving-code-review-ko → security-review-ko → integration-test-ko → performance-test-ko → PR
    ↓
"PR 생성? [y/n]"
```

**핵심**: Conductor 에이전트 없음. 본 메타 skill + 각 engine skill 본문이 chain 형성.

## maintenance flag 분류 로직 (Phase D — 신규 추가)

신호 감지 후 신규/유지보수 1 회 분류 → chain 진입 args 합성:

| flag | chain 진입 | args 합성 |
|---|---|---|
| `false` (신규) | specifying-ko 직행 | 원본 args 그대로 |
| `true` (유지보수) | **analyzing-ko 먼저** → specifying-ko (Phase C 적용 후) | args 첫 줄에 `<!-- entry: maintain -->` HTML 주석 prepend → 줄바꿈 후 원본 args |

**Phase C chain 재배선** (analyzing-ko 신설 후):
- maintenance flag = `true` → **analyzing-ko 호출** (★ HARD GATE) → analyzing-ko 가 specifying-ko 로 chain (args 그대로 전달, 첫 줄 약속어 유지)
- analyzing-ko 가 두 산출물 (current-state.md + impact-analysis.md) 산출 후 사용자 검토 통과 시 specifying-ko Step 1 [유지보수 분기] 가 두 산출물 참조

**announce 메시지** (5 원칙 1 투명성):
- `false` → "Using specifying-ko to <purpose>"
- `true` → "Using analyzing-ko (maintenance) to <purpose>" (Phase C 후) 또는 "Using specifying-ko (maintenance) to <purpose>" (Phase A 단독)

**분류 모호** (양쪽 신호 혼재) 시 사용자에게 1 문항 확인 — "신규 / 유지보수 어느 쪽?".

## 프로젝트 최초 진입 감지 (v2.0 신규)

신호 감지 후 maintenance 분류 **전에**, 프로젝트 부트스트랩 상태를 1 회 점검한다 (clarifications.md Q5 결정 — AND 조건 + 부분 부트 감지).

| `.specops/` | `CLAUDE.md` | 안내 | 메시지 |
|---|---|---|---|
| 부재 | 부재 | **전체 안내** | "프로젝트가 초기화되지 않았습니다. `/init-project` 권장 [y/N]" |
| 존재 | 부재 | 부분 안내 | "`CLAUDE.md` 가 없습니다. `/init-project --resume` 권장 [y/N]" |
| 부재 | 존재 | 부분 안내 | "`.specops/` 가 없습니다. `/init-project --resume` 권장 [y/N]" |
| 존재 | 존재 | 안내 X | (정상 specifying-ko 진입) |

**원칙**:
- **강제 X — 1 회 1 줄 안내**. 5원칙 4 (사용자 주권) 준수.
- `y` 응답 시: `/init-project` 호출 → 부트스트랩 완료 → 사용자에게 "이제 `/start \"<기능>\"` 재실행" 안내.
- `N` 또는 무응답 시: 그대로 specifying-ko 진입 (사용자가 부트스트랩 없이 진행 의지).
- `--resume` 플래그는 후속 릴리즈 (현재 안내 메시지로만 제시. 사용자가 입력하면 `/init-project` 가 Phase 1 의 충돌 정책으로 처리).

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

## Karpathy 행동 원칙 (cross-cutting)

구현 단계 진입 시 아래 4원칙이 자동 활성된다. 세부 내용: `specops-auto-ko:karpathy-ko`.

| Karpathy 원칙 | 핵심 규칙 | specops 연결 |
|---|---|---|
| 1 코드 작성 전 사고 | 가정 명시, 불확실 시 질문, 다중 해석 제시 | 원칙 1 투명성 + 원칙 5 한계 고백 |
| 2 단순성 우선 | 요청된 것만, 추측 기능·추상화 금지 | YAGNI + 원칙 4 주권 |
| 3 외과적 변경 | 요청과 직접 연결된 것만 변경, 기존 스타일 유지 | sprint-contracts-ko AC 범위 |
| 4 목표 기반 실행 | 모호한 지시 → 검증 가능한 체크포인트 변환 | acceptance-criteria.md + tdd-ko |


## Advisor 활용 (cross-cutting)

기획·분석·설계·개발 중 **애매한 부분/모르는 부분 발생 시 advisor 호출 의무**. 단정·합리화·circular 검증 차단. 세부 내용: `specops-auto-ko:advisor-ko`.

| 단계 | skill | advisor 호출 시점 |
|---|---|---|
| 기획 | specifying-ko | spec.md §유형 분류 모호 / NFR 미확신 |
| 분석 | analyzing-ko | impact 5 항목 작성 중 외부 영향 범위 모호 |
| 설계 | planning-ko | 이미 §8 Advisor 협의 기록 섹션 강제 |
| 개발 | implementing-ko | 서브에이전트 dispatch 전 task 의도 모호 |

자명한 작업 (typo / 1 줄 rename) 은 호출 회피. 긴 작업은 substantive work 직전 + 종결 직전 1 회 이상 권장.


## 자유작업 pending 처리 (freecomment-capture → mini-lifecycle 편입)

SessionStart 가 `<freecomment-pending>` 안내를 주입했으면, **다음 사용자 턴 시작 시** 자동 처리한다:

1. `.specops/pending-capture.jsonl` 각 레코드를 읽는다 (`{ts,files,prompt,type,fid}`).
2. 각 자유작업을 **요약**하고 `type` 을 프롬프트+변경파일 기준으로 **재분류**한다.
3. **귀속/신규 판정**: `bash scripts/freework-resolve-fid.sh "<레코드 fid>"` 호출.
   - 출력 `ATTACH:<fid>` → **귀속 분기** (진행 중 lifecycle): 새 FID 생성 안 함. `<fid>` 를 대상 FID 로 사용 (쉘로 추출 시 `fid=${out#ATTACH:}`) (4·5·6 단계 진행, freework.md·mkdir 생략).
   - 출력 `NEW` → **mini-FID 분기**: 요약 기반 `YYYYMMDD-<slug>` FID 생성. slug 불가 시 `YYYYMMDD-freework-<HHMM>`. 이어:
     - `mkdir -p .specops/<FID>`
     - `.specops/<FID>/freework.md` 작성 (`templates/freework.md` 의 `{{...}}` 치환 — prompt 빈값 시 `(빈값 — 변경파일 기반 추론)`).
4. **session-progress 기록**: `bash scripts/session-progress-append.sh <대상FID> /freework 완료 "<요약>"`.
5. **learnings 기록**: `bash scripts/gbrain-append.sh "<요약>" --fid <대상FID> --tags freelog,<type>` (fid 비빈값 — AC-6).
6. **freelog 기록**: `.specops/freelog.md` 에 `## YYYYMMDD` 하위 `- HH:MM [<type>] (<대상FID>) <files> — <요약>` append (escape 유의).
7. `type` 이 `design-change` 면 **requirements 반자동 연결** (승인형 — 기존 유지): requirements.md 확인 → 새 기능 요구사항 판단 → FR 초안 [y/n] → `bash scripts/requirements-append-fr.sh ...`.
8. 처리 완료 후 `.specops/pending-capture.jsonl` 을 **비운다** (멱등): `: > .specops/pending-capture.jsonl` (truncate — 빈 파일이라야 SessionStart `[ -s ]` 가 재안내 skip).
9. 사용자에게 **1줄 보고**: "자유작업 N건 기록함 — mini-FID M건(<FID목록>), 귀속 K건. (freelog.md)".

## 참조

- `obra/superpowers@v5.0.7 skills/using-superpowers/SKILL.md` — 원본
- specops-auto-ko 설계 케이스 스터디 `2026-04-21-specops-auto-ko-design.md §15` — 본 skill 설계 근거
- `skills/engine/*-ko.md` (10건) — Phase 1 구축 완료
- `skills/harness/*-ko.md` (5건 + 본 skill) — 내부 규약
- `commands/start.md` — 슬래시 진입점
- `commands/brainstorming.md` — 선택적 pre-init-project 탐색 진입점
- `skills/brainstorming-ko/SKILL.md` — 아이디어 탐색 skill
- `hooks/hooks.json` — SessionStart·Stop hook 매니페스트

---

*specops-auto-ko v1.0.0 · 2026-04-21 · Phase 1 구축 완료 · Superpowers using-superpowers 한국어 재창작 + 5원칙 주입 + Lifecycle 신호 감지 추가*
