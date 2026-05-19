---
name: clarifying-ko
description: specifying-ko 완료 후 호출 — spec.md의 모호성·열린 질문을 사용자와 대화로 해소하고 clarifications.md 생성. BLOCKING 해소 전 planning-ko 진행 금지
layer: 2
reference_upstream: obra/superpowers@v5.0.7 skills/brainstorming/SKILL.md
  - obra/superpowers@v5.0.7 skills/brainstorming/SKILL.md (후반 "Spec Self-Review" + "User Review Gate" 분리)
  - github/spec-kit commands/clarify.md (specops-ko 경유)
  - specops-ko commands/clarify.md
specops_version: 1.0.0
used_by: specops-auto-ko:specifying-ko (chain 진입), specops-auto-ko:planning-ko (chain 출구)
---

# Engine 스킬 — 명확화 (clarifying)

`spec.md`의 모호성·열린 질문을 **사용자와 대화로 해소**하고 `clarifications.md`에 기록한다. 필요 시 `acceptance-criteria.md`를 append-only로 보강.

<HARD-GATE>
**BLOCKING 우선순위의 명확화 질문이 RESOLVED 상태가 되기 전까지** `specops-auto-ko:planning-ko`를 호출할 수 없다. DESIRABLE만 남았거나 전부 RESOLVED일 때만 planning-ko 진입 허용.
</HARD-GATE>

## 필수 전제

본 skill 은 `specifying-ko` 완료 후 **반드시 한 번 호출**된다. spec §열린질문 카운트가 0 이더라도 호출해 BLOCKING 탐지·DESIRABLE 발굴을 수행한다. 생략 금지 — negotiable 아님.

**근거**: dogfood FID `20260422-csv-lines` 실측 — specifying 이 Q1~Q4 수집 후에도 clarifying 가 추가 DESIRABLE 3 건 (exit code · 에러 포맷 · 빈 파일 동작) 을 발굴해 AC-6/AC-7 신규 append. specifying 단독으로는 AC 계약 완결 불가 (FRICTION-LOG F-11).

## 체크리스트

다음 각 항목을 순서대로 태스크로 만들어 완료한다:

1. **입력 아티팩트 확인** — `.specops/<FID>/spec.md` + `.specops/<FID>/acceptance-criteria.md` 존재. 없으면 specifying-ko 선행 요청하고 **중단**
2. **모호성 탐지** — spec.md §열린 질문 + AC Given/When/Then 완결성 + 충돌·이중 해석 소지
3. **우선순위 분류** — BLOCKING vs DESIRABLE
4. **사용자 대화** — 존댓말, BLOCKING은 한 번에 하나, DESIRABLE은 독립 시 최대 3건 묶음
5. **기존 clarifications.md 회전** — 있으면 `bash hooks/rotate-evaluator-artifact.sh .specops/<FID>/clarifications.md` 실행
6. **clarifications.md 작성** — 판정 JSON + 질문별 답변
7. **acceptance-criteria.md append** — 신규 AC만 추가, 기존 AC 수정 금지
8. **timestamp 주입** — `bash hooks/inject-evaluator-timestamp.sh .specops/<FID>/clarifications.md`
9. **session-progress append** — `bash scripts/session-progress-append.sh <FID> /clarify 완료 "clarifications.md (N 쟁점 해소)"` 호출. `specops-auto-ko:planning-ko` 다음 단계 안내
10. **전환** — `specops-auto-ko:planning-ko` 호출

## 모호성 탐지 기준

**BLOCKING** (해소 없이 plan 진행 불가):
- 핵심 동작의 입출력이 결정 안 됨
- 아키텍처 선택지가 미확정 (저장소·프레임워크·프로토콜)
- AC Given/When/Then 중 필수 분기가 비어 있음
- 스펙이 두 가지로 해석되어 **근본적으로 다른 구현**을 초래

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

**status**: RESOLVED | BLOCKED
**timestamp**: <auto-injected ISO-8601>

## Q1 · <topic> · BLOCKING

**질문**: <사용자에게 제시한 질문>

**답변**: <사용자 응답>

**영향**: AC-5 신규 추가

## Q2 · ...
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
