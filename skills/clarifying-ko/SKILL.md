---
name: clarifying-ko
description: specifying-ko 완료 후 호출 — spec.md의 모호성·열린 질문을 사용자와 대화로 해소하고 clarifications.md 생성. BLOCKING 해소 전 planning-ko 진행 금지
layer: 2
reference_upstream: obra/superpowers@v5.0.7 skills/brainstorming/SKILL.md
  - obra/superpowers@v5.0.7 skills/brainstorming/SKILL.md (후반 "Spec Self-Review" + "User Review Gate" 분리)
  - github/spec-kit commands/clarify.md (specops-ko 경유)
  - specops-ko commands/clarify.md
specops_version: 1.10.0
used_by: specifying-ko (chain 진입), planning-ko (chain 출구)
---

# Engine 스킬 — 명확화 (clarifying)

`spec.md`의 모호성·열린 질문을 **사용자와 대화로 해소**하고 `clarifications.md`에 기록한다. 필요 시 `acceptance-criteria.md`를 append-only로 보강.

<HARD-GATE>
**BLOCKING 우선순위의 명확화 질문이 RESOLVED 상태가 되기 전까지** `specops-auto-ko:planning-ko`를 호출할 수 없다. DESIRABLE만 남았거나 전부 RESOLVED일 때만 planning-ko 진입 허용.

**[§auto 모드]** (`grep -qE '^\*\*§auto\*\*:[[:space:]]*true' .specops/<FID>/spec.md`):
BLOCKING 항목을 **best-guess 자동 응답**으로 처리한다:
- 합리적 기본값·컨텍스트 기반 추론으로 답변 선택
- clarifications.md Q-block에 `status: ASSUMED` 기재 + `**가정 근거**: <한 줄 이유>` 필드 추가
- **advisor() 보조 자문** (고영향 가정 한정 — 비용 통제): 가정이 **아키텍처·저장소·프로토콜·핵심 동작 입출력** 선택이면(또는 batch FR당 1회 묶음) best-guess 확정 **전** `advisor()` 1회 호출 → 권고를 best-guess 입력에 반영하고 `**가정 근거**`에 `advisor 의견: <요지>` 기록. **UI 세부·로깅·비치명 엣지·trivial 가정은 advisor 트리거 제외**(기존 best-guess 단독).
- **graceful fallback**: `advisor()` 미연결·미응답·실패 시 즉시 기존 best-guess 단독 진행 + `**가정 근거**`에 `advisor 미연결 — 자기추론` 기록(투명성). advisor 하드 의존 금지.
- **주권 보존**: advisor 반영 가정도 `status: ASSUMED` 유지 — advisor 는 1 의견이며 최종 확인은 PR 게이트 다이제스트의 사용자 몫.
- 이 가정은 performance-test-ko PR 게이트의 **가정 다이제스트**로 집계된다
- BLOCKING 자동 처리 후 planning-ko 직행 (사용자 응답 대기 없음)
</HARD-GATE>

## 필수 전제

본 skill 은 `specifying-ko` 완료 후 **반드시 한 번 호출**된다. spec §열린질문 카운트가 0 이더라도 호출해 BLOCKING 탐지·DESIRABLE 발굴을 수행한다. 생략 금지 — negotiable 아님.

**근거**: dogfood FID `20260422-csv-lines` 실측 — specifying 이 Q1~Q4 수집 후에도 clarifying 가 추가 DESIRABLE 3 건 (exit code · 에러 포맷 · 빈 파일 동작) 을 발굴해 AC-6/AC-7 신규 append. specifying 단독으로는 AC 계약 완결 불가 (FRICTION-LOG F-11).

## 체크리스트

다음 각 항목을 순서대로 태스크로 만들어 완료한다:

1. **입력 아티팩트 확인** — `.specops/<FID>/spec.md` + `.specops/<FID>/acceptance-criteria.md` 존재. 없으면 specifying-ko 선행 요청하고 **중단**
2. **모호성 탐지** — spec.md §열린 질문 + AC Given/When/Then 완결성 + 충돌·이중 해석 소지
3. **우선순위 분류** — BLOCKING vs DESIRABLE. (BLOCKING=0 이고 §auto 아니면 → 아래 `## 경량 모드 (lite)` 섹션 참조)
4. **사용자 대화** — 존댓말, BLOCKING은 한 번에 하나, DESIRABLE은 독립 시 최대 3건 묶음
5. **기존 clarifications.md 회전** — 있으면 `bash hooks/rotate-evaluator-artifact.sh .specops/<FID>/clarifications.md` 실행
6. **clarifications.md 작성** — 판정 JSON + 질문별 답변
7. **acceptance-criteria.md append** — 신규 AC만 추가, 기존 AC 수정 금지
8. **timestamp 주입** — `bash hooks/inject-evaluator-timestamp.sh .specops/<FID>/clarifications.md`
9. **session-progress append** — `bash scripts/session-progress-append.sh <FID> /clarify 완료 "clarifications.md (N 쟁점 해소)"` 호출. `specops-auto-ko:planning-ko` 다음 단계 안내
10. **전환** — `specops-auto-ko:planning-ko` 호출

## 경량 모드 (lite) — BLOCKING 0 자동 탐지

**[§auto 이외 분기]**: Step 2 모호성 탐지 결과가 `spec §열린질문=0 AND AC Given/When/Then 완결`이면 **BLOCKING=0 판정** → 경량 분기:

1. BLOCKING 질문 생략 (0건이므로 정당).
2. **DESIRABLE 발굴 1회 수행** (F-11 보존 — specifying 단독 AC 완결 불가 근거):
   - DESIRABLE 발굴 ≥1건 → 최대 3건 묶음 질문 1회 (사용자 응답).
   - DESIRABLE 0건 → 즉시 통과 (묶음 불필요).
3. clarifications.md 상단에 `**mode**: lite` 명시 (투명성 — 경량 분기 적용 기록).
4. 이후 Step 6~10 정상 수행 (clarifications.md 작성·AC append·timestamp·session-progress·전환).

**경량 모드 금지 조건**: spec §열린질문 ≥1 OR AC Given/When/Then 미완결 → 기존 풀 모드(BLOCKING 한 번에 하나). §auto 모드는 이미 best-guess 자동이므로 경량 분기 비적용(중복 회피).

> 근거: 실측 최근 8 FID 중 7개 BLOCKING≈0 형식 통과. 경량 모드는 비용 절감하되 F-11(DESIRABLE 발굴) 보존.

## 모호성 탐지 기준

**BLOCKING** (해소 없이 plan 진행 불가):
- 핵심 동작의 입출력이 결정 안 됨
- 아키텍처 선택지가 미확정 (저장소·프레임워크·프로토콜)
- AC Given/When/Then 중 필수 분기가 비어 있음
- 스펙이 두 가지로 해석되어 **근본적으로 다른 구현**을 초래
- **§유형=`foundation`** 이고 `.specops/memory/frontend-architecture.md` 또는 `.specops/memory/backend-architecture.md` 에 `<...>` 형태의 미해소 placeholder 가 있으면 **기술 프레임워크 확정을 BLOCKING 질문으로 강제** — RESOLVED 전 planning-ko 진입 차단

**DESIRABLE** (가정으로 진행 가능):
- UI 세부 (색상·버튼 텍스트)
- 비-치명적 엣지 케이스 처리 선택
- 로깅 수준·포맷
- 성능 임계값 (합리적 기본값 존재)

## 사용자 대화 규칙

- **BLOCKING**: 한 번에 한 질문, **객관식 선호**. 답변 결과가 다음 질문에 영향을 주므로 묶지 않음
- **DESIRABLE**: 주제가 동질·상호 독립이면 최대 3건 묶음 허용. 답변 간 의존 발생 시 즉시 개별 모드로 전환
- 질문은 **코드·구현이 아니라 의도**를 물음. "어느 라이브러리?" 대신 "어느 조건에 최적화할까요?"

## 예시

```
/start 트랜스크립트 캐시 기능 → specifying-ko 완료 → clarifying-ko 진입

명확화 질문 #1 (BLOCKING)
  "spec.md §3에 캐시 저장소가 미확정입니다. 세 가지 옵션:
   (1) 파일 캐시 (.cache/ 디렉토리)
   (2) Redis (서버 필요)
   (3) SQLite (단일 파일)
  어느 것을 선호하시나요?"

사용자: "1번"

→ clarifications.md §Q1에 RESOLVED 기록
→ AC-5 신규 append: "캐시 파일은 .cache/ 디렉토리에 저장된다"

명확화 질문 #2 (BLOCKING)
...

모든 BLOCKING RESOLVED → planning-ko 진입 허용
```

## clarifications.md 포맷

```markdown
# Clarifications — <FID>

**status**: RESOLVED | BLOCKED | ASSUMED
**timestamp**: <auto-injected ISO-8601>
**mode**: full | lite   (경량 모드 적용 시 lite — BLOCKING 0 자동 탐지)

## Q1 · <topic> · BLOCKING

**질문**: <사용자에게 제시한 질문>

**답변**: <사용자 응답>

**영향**: AC-5 신규 추가

## Q2 · <topic> · BLOCKING · ASSUMED   ← §auto 모드 자동 응답

**질문**: <판단이 필요했던 질문>

**답변 (자동)**: <best-guess 선택된 답변>

**가정 근거**: <컨텍스트 기반 추론 한 줄>

**영향**: AC-X 반영 예정

## Q3 · ...
```

## 5원칙 주입 (specops-auto-ko 고유)

| 원칙 | 본 스킬 적용 |
|---|---|
| 1 **투명성** | 질문의 **근거**를 함께 제시 — "왜 이걸 물어야 하는가" |
| 2 **문지기** | BLOCKING 미해결 상태로 planning 진입 시도는 **거절** |
| 3 **깊이** | "아마 이럴 것"으로 답 대체 금지. 반드시 사용자에게 물음 |
| 4 **주권 존중** | 답변을 대신 고르지 않음. 옵션만 제시 |
| 5 **한계 고백** | 답변이 범위 밖이면 "이 부분은 이후 단계에서 결정" 기록 |

## 안티패턴

- 스펙 본문 **수정** — `spec.md`는 specifying-ko 소유. 여기서는 읽기만
- **기존 AC 수정** — append만 허용
- 사용자 답변 **추측** — 모르면 반드시 물음
- **구현 제안** — planning-ko 단계

## 참조

- `skills/specifying-ko/SKILL.md` — 선행 스킬
- `skills/structured-artifacts-ko/SKILL.md` — 아티팩트 경로 규약
- `templates/acceptance-criteria.md` — AC 포맷
- upstream 근거: `obra/superpowers@v5.0.7 skills/brainstorming/SKILL.md` 후반 "Spec Self-Review" + "User Review Gate"
- specops-ko 선례: `commands/clarify.md`

## 다음 skill

모든 BLOCKING RESOLVED + clarifications.md 저장 + AC append 완료 후 즉시 호출:

```
Skill: specops-auto-ko:planning-ko
```

BLOCKED 상태로 남으면 chain 정지. 사용자 개입 필요.
