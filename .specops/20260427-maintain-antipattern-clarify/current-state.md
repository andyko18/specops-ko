# current-state.md — `commands/maintain.md` 안티패턴 "인자 내용 2 차 판단" 항목 baseline

## 1. 변경 대상 식별 (라인 범위 — trivial 자동 판정 source)

- 파일: `commands/maintain.md`
- 라인: 47 (단일 bullet, 1 line)
- 라인 합산: **1 ≤ 5 → trivial** (analyzing-ko Step 5 자동 판정)

baseline 본문 (verbatim):

```
- **인자 내용 2 차 판단** (`/start` 와 동일) — 슬래시 진입 자체가 의도 확정. 인자 적합성은 specifying-ko Step 1 분기 검증 1 문항이 처리
```

## 2. 호출자/의존 매핑

| 참조 위치 | 형태 | 비고 |
|---|---|---|
| `skills/using-specops-auto-ko-ko/SKILL.md` §"경계" (line 34) | 본 안티패턴을 **`commands/start.md` 항목** 으로 인용 (maintain.md 미인용) | maintain.md 표현 강화에 영향 없음 |
| `.specops/20260427-maintenance-lifecycle/behavioral-verification-protocol.md:73` | "인자 내용 2 차 판단 안티패턴 회피" 룰을 maintain.md `## 안티패턴` 으로 지목 | 본 fix 의 verification 출처 |
| `.specops/20260427-maintenance-lifecycle/behavioral-verification-protocol.md:83` | "인자 내용 2 차 판단 발생 → `## 안티패턴` 항목 본문 강화 필요" — 본 버그 식별 fail-mode | fix 완료 후 protocol §83 재현 안 됨을 검증 |
| `commands/start.md:53` | sister 항목 — 강화된 표현의 **레퍼런스 모델** | 표현 일관성 유지 대상 |

자동화된 import / 코드 의존 없음 (정적 마크다운).

## 3. 기존 테스트 커버리지

- **자동화 테스트**: 없음 (slash command 본문은 정적 마크다운)
- **수동 검증 source**: `.specops/20260427-maintenance-lifecycle/behavioral-verification-protocol.md` Path A §3 (인자 내용 2 차 판단 안티패턴 회피)
- 커버리지 한계 고백 (5 원칙 5): protocol verbatim 외 자동 회귀 가드 없음 → fix 후 protocol 재실행으로만 검증

## 4. 관찰 가능 동작 (Baseline 모호점)

현재 line 47 본문이 다음 3 지점에서 모호:

| 모호점 | 증상 |
|---|---|
| `(`/start` 와 동일)` 단축 표기 | 본문이 부재 — 독자가 start.md 를 cross-read 해야 룰 확정 |
| `1 문항이 처리` | "1 문항" 의 정체 불명 (어떤 질문? 어디서? 누가 묻는가?) |
| 핵심 금지·강제 룰 누락 | start.md:53 가 명시한 ① "보류하지 않는다" ② "메타 skill 자연어 신호 감지 로직 복제 금지" 가 maintain.md 본문에 부재 |

start.md:53 (강화된 sister 항목, 레퍼런스):

```
- **인자 내용 2차 판단** — `/start <아무 인자>` 는 인자가 "기능 설명 신호처럼 보이지 않는다"는 이유로 `specops-auto-ko:specifying-ko` 호출을 **보류하지 않는다**. 슬래시 진입 자체가 사용자 의도 확정 신호 (명시적 진입). 인자 적합성은 specifying-ko 가 HARD GATE 로 처리. 메타 skill 의 자연어 신호 감지 로직을 command 레이어에 복제 금지
```

## 5. 회귀 위험

- **표현 불일치 위험**: start.md 와 maintain.md 가 sister 항목인데 본문 길이·구체성 비대칭 → 향후 수정자가 두 곳 동기화 잊을 가능성. fix 시 두 본문이 의미적으로 동치임을 명시.
- **메타 skill §"경계" 재인용 필요성**: 메타 skill 은 `/start` 안티패턴만 인용 중. fix 후 `/maintain` 안티패턴도 동급 인용 추가가 *separately* 검토 필요 — 본 FID 범위 밖 (별도 maintenance work).
- **scope 제한**: 본 fix 는 `commands/maintain.md:47` 단일 라인 재작성. 다른 파일 (start.md, 메타 skill, protocol) 변경 금지.
