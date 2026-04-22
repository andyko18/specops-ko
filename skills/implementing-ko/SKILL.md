---
name: implementing-ko
description: 본 세션에서 구현 플랜을 태스크별로 실행할 때 사용 — 태스크별 fresh 서브에이전트 dispatch, 각 태스크마다 2단계 리뷰(스펙 준수 → 코드 품질)
layer: 2
reference_upstream:
  - obra/superpowers@v5.0.7 skills/subagent-driven-development/SKILL.md
  - obra/superpowers@v5.0.7 skills/subagent-driven-development/implementer-prompt.md
  - obra/superpowers@v5.0.7 skills/subagent-driven-development/spec-reviewer-prompt.md
  - obra/superpowers@v5.0.7 skills/subagent-driven-development/code-quality-reviewer-prompt.md
  - specops-ko skills/engine/subagent-driven-development-ko.md
specops_version: 0.0.0
used_by: specops-auto-ko:planning-ko (chain 진입), specops-auto-ko:verifying-evidence-ko (chain 출구)
---

# Engine 스킬 — 서브에이전트 주도 구현 (implementing)

플랜을 태스크별 **fresh 서브에이전트** dispatch로 실행. 각 태스크 후 **2단계 리뷰**: 스펙 준수 리뷰 먼저, 그다음 코드 품질 리뷰.

**왜 서브에이전트**: 전문 에이전트에게 **격리된 컨텍스트**로 태스크를 위임. 지시와 컨텍스트를 **정확히** 조립해 집중·성공을 보장. 서브에이전트는 **당신 세션의 컨텍스트·히스토리를 절대 상속하지 않는다** — 필요한 것만 당신이 구성해 넘긴다. 이로써 당신의 컨텍스트도 코디네이션 용도로 보존된다.

**핵심 원칙**: 태스크별 fresh 서브에이전트 + 2단계 리뷰(스펙 → 품질) = **고품질 + 빠른 반복**.

## 사용 시점

```
구현 플랜 있음?
    ↓ yes
태스크 대체로 독립적?
    ↓ yes
본 세션에서 진행?
    ↓ yes
→ implementing-ko (본 스킬)

↓ no (다른 세션 병렬) → 별도 실행 흐름 (v0.1+에 포팅)
```

태스크가 밀접하게 결합돼 있으면 → decomposing-ko 복귀해 재분해.

## 프로세스

```
플랜 1회 읽고 전 태스크 + 컨텍스트 추출 → TodoWrite 생성
    ↓
각 태스크마다:
  ┌─ 구현자 서브에이전트 dispatch (implementer-prompt)
  │     ↓
  │  질문 있음? → yes → 답변·컨텍스트 제공 → 재dispatch
  │     ↓ no
  │  구현자: 구현·테스트·커밋·자체검토
  │     ↓
  │  스펙 리뷰어 서브에이전트 dispatch
  │     ↓
  │  스펙 준수?
  │     │ no → 구현자가 수정 → 스펙 리뷰어 재리뷰
  │     │ yes
  │     ↓
  │  코드 품질 리뷰어 서브에이전트 dispatch
  │     ↓
  │  품질 승인?
  │     │ no → 구현자가 수정 → 품질 리뷰어 재리뷰
  │     │ yes
  │     ↓
  └─ TodoWrite 태스크 완료 표시
    ↓
다음 태스크? → loop
    ↓ 전부 완료
최종 코드 리뷰어 서브에이전트 (전체 구현)
    ↓
specops-auto-ko:verifying-evidence-ko 호출
```

## 예외 허용 · 동일 파일 쌍 TDD 체인

태스크 2 개 이상이 **동일 파일 쌍** (예: `src/X.sh` + `tests/test-X.sh`) 을 **순차 수정하는 TDD 체인** 이면 구현자 dispatch 를 **1 회로 집약**할 수 있다. 조건:

1. 각 태스크의 TDD 5 스텝 (RED → FAIL → GREEN → PASS → COMMIT) 을 **태스크 내부 embedded cycle** 로 구현자가 준수
2. 2 단계 리뷰 (Phase B 스펙 · Phase C 코드 품질) 는 **별도 리뷰어 dispatch 로 유지** — 집약 대상 아님
3. `dispatch-log.md` 에 집약 근거 (동일 파일 쌍 판정 · 태스크 LOC · TDD 사이클 구조) 명시 의무 (원칙 1 투명성)

**근거**: dogfood FID `20260422-csv-lines` 실측 — 5 태스크 전부 `csv-lines` + `tests/test-csv-lines.sh` 만 수정 · 총 40 LOC. 규약대로 15 dispatch 대신 3 dispatch (구현자 1 + 리뷰어 2) 로 집약해 27.1k 토큰 절감, Phase B/C 리뷰는 유지. `dispatch-log.md` Phase A/B/C 기록이 5 원칙 4 (주권) · 1 (투명성) 충족 증거 (FRICTION-LOG F-12).

**위 조건 불충족 시** 기본값 ("태스크별 fresh 서브에이전트 dispatch") 그대로 유지.

## 모델 선택

역할마다 **감당 가능한 가장 가벼운 모델** 사용. 비용·속도.

**기계적 구현 태스크** (격리된 함수, 명확한 스펙, 1~2 파일) → 빠르고 저렴한 모델. 잘 설계된 플랜은 대부분의 구현이 기계적.

**통합·판단 태스크** (다중 파일 조율, 패턴 매칭, 디버깅) → 표준 모델.

**아키텍처·설계·리뷰 태스크** → 가장 강력한 모델.

**태스크 복잡도 신호**:
- 1~2 파일, 완전한 스펙 → 저렴 모델
- 다중 파일, 통합 관심사 → 표준 모델
- 설계 판단·광범위한 코드베이스 이해 요구 → 최강 모델

## 구현자 상태 처리

구현자 서브에이전트는 네 가지 상태 중 하나 보고. 각각 적절히 처리:

**DONE**: 스펙 준수 리뷰로 진행.

**DONE_WITH_CONCERNS**: 구현자가 작업은 완료했으나 의문을 표시. 리뷰 전 우려사항 읽기. 정확성·범위 관련이면 **리뷰 전 처리**. 관찰(예: "이 파일이 커지고 있음")이면 메모 후 리뷰 진행.

**NEEDS_CONTEXT**: 구현자가 제공받지 못한 정보 필요. 누락된 컨텍스트 제공 후 재dispatch.

**BLOCKED**: 구현자가 태스크 완료 불가. 블로커 평가:
1. 컨텍스트 문제 → 컨텍스트 더 주고 **같은 모델**로 재dispatch
2. 더 강력한 추론 필요 → **더 강한 모델**로 재dispatch
3. 태스크가 너무 큼 → 더 작게 쪼개기
4. 플랜 자체가 잘못 → **사람에게 에스컬레이션**

**절대 금지**: 에스컬레이션 무시, 변경 없이 같은 모델로 재시도. 구현자가 막혔다고 말하면 **무언가 바뀌어야 한다**.

## 프롬프트 템플릿

동봉된 3개 프롬프트 파일을 그대로 사용 (v0.1+ 본 디렉토리에 포팅):

- `implementer-prompt-ko.md` — 구현자 서브에이전트 dispatch
- `spec-reviewer-prompt-ko.md` — 스펙 준수 리뷰어 dispatch
- `code-quality-reviewer-prompt-ko.md` — 코드 품질 리뷰어 dispatch

현재 Phase 1에서는 upstream 원본(`obra/superpowers@v5.0.7 skills/subagent-driven-development/*-prompt.md`)을 직접 참조해 즉석에서 한국어로 번역 사용.

## 레드 플래그 — 금지

**절대 금지**:
- main/master 브랜치에서 **명시 동의 없이** 구현 시작
- 리뷰 생략 (스펙 준수 OR 코드 품질)
- **미해결 이슈를 두고 진행**
- 구현 서브에이전트를 **병렬로** 여러 개 dispatch (충돌)
- 서브에이전트에게 **플랜 파일을 읽게 함** (전체 텍스트를 당신이 제공)
- 장면 설정 컨텍스트 생략 (서브에이전트는 태스크가 어디에 맞는지 이해해야 함)
- 서브에이전트 질문 무시 (진행 전에 답하기)
- "근접함"으로 스펙 준수 인정 (스펙 리뷰어가 이슈 발견 = 미완료)
- 리뷰 루프 생략 (리뷰어 이슈 발견 → 구현자 수정 → 다시 리뷰)
- 구현자 자체검토를 실제 리뷰로 대체 (둘 다 필요)
- **스펙 준수 ✅ 전에 코드 품질 리뷰 시작** (순서 어김)
- 어느 리뷰라도 이슈 미해결인 채 다음 태스크로 이동

**서브에이전트가 질문하면**:
- 명확하고 완전히 답변
- 필요하면 추가 컨텍스트 제공
- 구현으로 몰아치지 말 것

**리뷰어가 이슈 발견하면**:
- 구현자(같은 서브에이전트)가 수정
- 리뷰어 재리뷰
- 승인까지 반복
- 재리뷰 생략 금지

**서브에이전트가 태스크 실패하면**:
- **수정 서브에이전트**를 구체 지시로 dispatch
- 수동 수정 금지 (컨텍스트 오염)

## 이점

**수동 실행 대비**:
- 서브에이전트가 자연스럽게 TDD 따름
- 태스크별 fresh 컨텍스트 (혼동 없음)
- 병렬 안전 (서브에이전트끼리 간섭 없음)
- 서브에이전트가 질문 가능 (시작 전과 진행 중 모두)

**병렬 세션 실행 대비**:
- 같은 세션 (전환 없음)
- 연속 진행 (대기 없음)
- 리뷰 체크포인트 자동

**효율**:
- 파일 읽기 오버헤드 없음 (컨트롤러가 전체 텍스트 제공)
- 컨트롤러가 **정확히 필요한 컨텍스트만** 조립
- 서브에이전트는 처음부터 완전한 정보 보유
- 질문이 작업 **시작 전에** 노출 (작업 후가 아니라)

**품질 게이트**:
- 자체검토가 핸드오프 전 이슈 포착
- 2단계 리뷰: 스펙 준수 → 코드 품질
- 리뷰 루프로 수정이 실제 동작함 보장
- 스펙 준수로 과잉·부족 구축 방지
- 코드 품질로 구현이 잘 만들어졌음 보장

**비용**:
- 서브에이전트 invoke 수 증가 (구현자 + 리뷰어 2명 / 태스크)
- 컨트롤러 사전 작업 증가 (모든 태스크 전체 추출)
- 리뷰 루프로 이터레이션 추가
- 그러나 **일찍 이슈 잡음** (나중에 디버깅보다 쌈)

## 5원칙 주입 (specops-auto-ko 고유)

| 원칙 | 본 스킬 적용 |
|---|---|
| 1 **투명성** | 서브에이전트 dispatch 시 지시·컨텍스트 **전체 기록** (`.specops/<FID>/dispatch-log.md`) |
| 2 **문지기** | 파괴적 명령은 서브에이전트에게도 **명시 확인 루틴** 삽입 |
| 3 **깊이** | BLOCKED 상태는 에스컬레이션. 우회 금지 |
| 4 **주권 존중** | 리뷰 루프에서 이슈 발견 시 **사용자에게 알림** — 자동 수정 전 확인 |
| 5 **한계 고백** | 서브에이전트 자체검토 보고를 **독립 검증 없이** 수용 금지 |

## 통합

**필수 워크플로 스킬**:
- `specops-auto-ko:planning-ko` — 본 스킬이 실행할 플랜 작성
- `specops-auto-ko:verifying-evidence-ko` — 전체 구현 후 검증
- `specops-auto-ko:requesting-code-review-ko` — 리뷰어 서브에이전트용 리뷰 템플릿

**서브에이전트가 사용해야 하는 스킬**:
- `specops-auto-ko:tdd-ko` — 서브에이전트는 각 태스크를 TDD로

**실패 시**:
- `specops-auto-ko:systematic-debugging-ko` — BLOCKED 블로커가 버그성이면 호출

## 참조

- upstream 원본: `obra/superpowers@v5.0.7 skills/subagent-driven-development/SKILL.md` + 3 프롬프트
- specops-ko 한국어 선례: `skills/engine/subagent-driven-development-ko.md`

## 다음 skill

모든 태스크 완료 + 최종 코드 리뷰 통과 후 즉시 호출:

```
Skill: specops-auto-ko:verifying-evidence-ko
```

verifying-evidence-ko가 "증거 기반 완료 선언"을 강제한다. 본 implementing-ko는 **verifying-evidence-ko 이외의 다음 스킬을 호출하지 않는다**.
