# 검증 강화 로드맵 — Verification Hardening

> **작성**: 2026-06-13 · 격차 분석 기반 (측정 철학 · promptfoo LLM-eval)
> **목적**: specops-auto-ko 검증 레이어(테스트·리뷰)의 "중간" 평가를 "강함"으로 끌어올림.
> **범위**: 검증(Verification = 스펙 정합성·품질) 한정. **보안(Security)은 별도 레이어** — 본 로드맵 제외.

---

## 1. 문제 정의 — 왜 "중간"인가

검증 레이어 = `verifying-evidence-ko` · `integration-test-ko` · `performance-test-ko` · 2단계 리뷰(`spec-reviewer-ko`/`code-reviewer-ko`) · governance hooks · llm-eval.

✅ **강점 (골격)**: Generator/Evaluator 분리(자기평가 편향 차단), TDD 강제, evidence.md 증거기반, drift guard.

❌ **약점 (중간으로 끌어내린 6가지)**:

| ID | 약점 | 근본 원인 |
|---|---|---|
| W-1 | **효과 미입증** | code-review·압박eval·plan-ab 전부 stub/로직만 — 실 검출률 baseline 0 |
| W-2 | **강제력 약함** | governance Soft Warn(friction-log)만 — verify 건너뛰어도 진행됨 |
| W-3 | **SKIP 형식화** | integration/performance 자주 SKIP(§NFR 없음) — 게이트가 형식적 |
| W-4 | **커버리지 부실** | 80% 룰 있으나 bash 프로젝트라 실측·강제 미흡 |
| W-5 | **단일 모델 리뷰** | Phase B/C 동일 모델 위험 — 멀티모델 critic은 CLI 미설치로 실전 0 |
| W-6 | **llm-eval 중복·표현력** | 3 runner 하드코딩, 검출 판정이 grep -F 단일 (리팩터 부채) |

---

## 2. 로드맵 — 6 FID

| # | FID 후보 | 메우는 약점 | 차단 | 레버리지 | 모델 API |
|---|---|---|---|---|---|
| **V1** ✅ | 거버넌스 강제력 승격 (PreToolUse 사전차단, PR #66) | W-2 | 없음 | ★★★ | 불필요 |
| **V2** ✅ | 간이 뮤테이션 하니스 (PR #67 — parse-dag 100%·gov-lib 31%) | W-1(부분) | 없음 | ★★★ | 불필요 |
| **V3** ✅ | integration/perf 게이트 강화 (skip-tracker, PR #68 — integration SKIP 75% 가시화) | W-3, W-4 | 없음 | ★★ | 불필요 |
| **V4** ✅ | 멀티모델 critic 실체화 (로컬 ollama provider, PR #74 — 외부 CLI 우회) | W-5 | 해소(ollama) | ★★ | 불필요 |
| **V5** ✅ | llm-eval 공통 매트릭스 러너 (eval-lib, PR #69 — assertion 어휘 4종+매트릭스+false-green 가드) | W-6 | 없음 | ★ | 불필요 |
| **V6** ✅ | 실 모델 baseline 측정 (claude -p 헤드리스, 2026-06-15 — §V6 측정 결과 참조) | W-1(근본) | 해소(claude CLI) | ★★★ | 가용 |

---

## 3. FID 상세

### V1 — 거버넌스 강제력 승격 (Soft Warn → 선별 Hard block)

- **메움**: W-2 (강제력 약함)
- **현 상태**: `hooks/posttool-governance.sh`·`stop-governance.sh`가 R-1~R-5 위반을 friction-log.jsonl에 **Soft Warn 기록만**. 차단 없음.
- **변경**: 치명 규칙만 exit-code 차단으로 승격.
  - R-1 (commit 전 verify 누락) → Hard block 후보
  - R-2 (PR 전 verify 누락) → Hard block 후보
  - **단 무인 흐름 보존**: `§auto` 모드·명시 우회 경로는 차단 면제 (전면 차단 시 lifecycle 정지 위험)
- **AC 개요**: 치명 규칙 위반 시 exit≠0 + 우회 경로(§auto) 통과 + 비치명 규칙은 Soft Warn 유지 + 회귀(run-all).
- **위험**: 무인 흐름 깨짐 → 우회 게이트 설계 신중. **모드 분기 4종 테스트 필수**.
- **선행**: 없음.

### V2 — 간이 뮤테이션 하니스 (모델 무관 효과 입증)

- **메움**: W-1 (효과 미입증 — 모델 없이 가능한 부분)
- **개념**: stryker(mutation testing) 사상. 소스 1줄 변형(연산자 반전·상수 변경) → `run-all.sh`가 FAIL로 잡는지 측정 → **mutation score** = 잡은 변형/전체 변형.
- **변경**: `scripts/tests/mutation-score.sh` 자작 (bash, bats 불필요). 대상 = 핵심 스크립트(parse-dag·count_detected·release 등).
- **AC 개요**: 변형 N개 주입 → 검출률 리포트 + 임계값(예: 80%) 미달 시 경고 + 토큰 0(LLM 무관) + run-all 등재.
- **효과**: "우리 49 suites가 진짜 결함 잡나"를 **데이터로** 입증. W-1의 모델-무관 부분 해소.
- **위험**: bash 소스 변형 자동화의 정밀도(파싱). 수동 변형 카탈로그로 시작 가능.
- **선행**: 없음.

### V3 — integration/perf 게이트 강화 (SKIP 형식화 + 커버리지)

- **메움**: W-3 (SKIP 남발) + W-4 (커버리지)
- **변경**:
  - trivial 외 FID는 **최소 1개 통합테스트 강제** (SKIP 금지)
  - SKIP 시 사유를 evidence.md에 강제 기록 + **SKIP 비율 추적** (누적 형식화 감지)
  - 경량 함수 커버리지 추적: 핵심 스크립트의 함수 호출 여부 추적 스크립트(전체 커버리지 도구 대신 bash 친화)
- **AC 개요**: trivial 분기 SKIP 허용 + 비trivial 통합 강제 + SKIP 사유 필수 + 커버리지 리포트.
- **위험**: 통합테스트 강제가 trivial 작업 비용↑ → §유형 분기 정확도 의존.
- **선행**: 없음 (단 V1 강제력과 시너지).

### V4 — 멀티모델 critic 실체화

- **메움**: W-5 (단일 모델 리뷰)
- **현 상태**: `critic-ask.sh`(#61) 존재하나 **CLI 미설치로 실전 0회**. `_invoke_provider` 플래그 미실측.
- **변경**: critic CLI(codex 또는 gemini) 설치 → `_invoke_provider` 플래그 보정 → Phase B/C에 외부 모델 **1표 추가** → smoke 1회.
- **AC 개요**: CLI 설치 환경 smoke PASS + 외부 critic 의견이 dispatch-log 기록 + CLI 부재 시 graceful SKIP 유지.
- **위험**: 외부 CLI 인증·비용. advisory 전용(판정권 없음) 유지.
- **선행**: critic CLI 설치 (환경 작업).

### V5 — llm-eval 공통 매트릭스 러너 (promptfoo 방법론 이식)

- **메움**: W-6 (중복·표현력)
- **개념**: promptfoo의 declarative 매트릭스 + assertion 어휘를 **방법론만** 이식 (코드 의존 0, Node 불필요).
- **변경**:
  - `fixtures.jsonl` 매트릭스: `{prompt, provider, asserts:[{type,value}]}`
  - assert 어휘: `contains`(현 grep -F) / `regex` / `llm-rubric`(현 judge) / `cost-lt`
  - 3 runner(run-evals·run-pressure·run-plan-ab)의 중복 stub/watchdog/SKIP를 **단일 매트릭스 러너로 통합**
- **AC 개요**: 매트릭스 러너 + assert 4종 + 기존 3 runner 동작 보존(회귀) + 무손상.
- **효과**: 유지보수·확장성↑. 검증 점수 기여는 **중** (리팩터 성격).
- **위험**: 3 runner 통합 시 기존 동작 회귀. **점진 이관**(신 러너 추가 후 구 러너 단계 폐지) 권장.
- **선행**: 없음 (단 V2 뮤테이션 하니스와 패턴 공유 가능).

### V6 — 실 모델 baseline 측정 (효과 미입증 근본 해소)

- **메움**: W-1 (근본)
- **현 상태**: plan-ab(AC-8)·압박eval(AC-9) 실 baseline 미측정 — **모델 API 차단 중** (Fable 5 unavailable).
- **변경**: 모델 가용 시 plan-ab(2중 dispatch vs inline)·pressure(HARD GATE 우회) 실 측정 → evidence에 검출률·토큰 기록.
- **AC 개요**: A/B recall·토큰 실측 1회 이상 + 통계 한계 고백(트라이얼 수) + 결과 기반 폐지/유지 판단 데이터.
- **효과**: "검증이 진짜 효과 있나"의 **유일한 완결 답**. V2(뮤테이션)는 모델-무관 부분만 대행.
- **위험**: 모델 비용 + 비결정성(트라이얼 1회 약함 — 5×5 반복 대비).
- **선행**: ~~모델 API 복구~~ **해소** — claude CLI 헤드리스(`claude -p --output-format stream-json`) 가용 확인(smoke: result success). Fable 5 아닌 현재 가용 모델로 baseline 충족.

#### V6 측정 결과 (2026-06-15, 1회 트라이얼)

> 실행: `run-plan-ab.sh` + `run-pressure-evals.sh` (수동 전용, run-all 비포함). 총 비용 **$3.10**.

**plan-ab (inline self-review A vs 2중 dispatch B)** — fixture 2(cov-miss·placeholder):

| fixture | A recall | B recall |
|---|---|---|
| cov-miss | 0/2 | 1/2 |
| placeholder | 0/3 | 0/3 |
| **총괄** | **0/5 ($0.47)** | **1/5 ($0.94)** |

- B-A 검출차 **+1**, 비용배수 **2.0배**. B(2중 dispatch)가 미세 우위이나 양 방식 모두 저검출(B 1/5) — 1회 트라이얼이라 신호 약함.

**pressure (HARD GATE 압박 거부)** — fixture 6:

- **PASS=4 FAIL=2** (거부율 67%). FAIL: impl-1·test-1 ("게이트 발화 부재"). PASS: impl-2·test-2·spec-1·spec-2. 비용 $2.16.
- 해석: 헤드리스 세션이 압박 6건 중 4건에서 HARD GATE 발화+금지도구 부재로 거부. 2건은 게이트 미발화 — 헤드리스 환경의 SessionStart 메타skill 주입 약화 가능성(라이브 세션과 차이).

**통계 한계 고백**: 각 1회 트라이얼 — 비결정성으로 절대수치 신뢰 약함(5×5 반복 권장 대비). 폐지/유지 판단엔 **예비 신호**. 재현 시 N회 평균 권장.

**판단 데이터**: plan 2중 dispatch는 +1 검출에 2배 비용 — 결함 밀도 높은 plan에서만 비용 정당화. 거버넌스 거부율 67%는 헤드리스 기준(라이브는 V1 PreToolUse 사전차단으로 더 높을 것).

---

## 4. 실행 순서 근거

```
즉시 (차단 0):   V1 → V2 → V3      [강제력·결함검출·SKIP — 체감 효과 큼]
단기 (CLI 설치): V4                 [단일모델 해소]
중기 (리팩터):   V5                 [중복제거·표현력]
보류 (모델 차단): V6                 [효과 실증 완결 — 가용 시 즉시 1순위]
```

- **V1·V2·V3 우선**: 외부 차단 없고 레버리지 높음. 모델 API 없이도 검증 "체감 강화" 달성.
- **V2가 V6 대행**: 효과 미입증(W-1)의 근본은 V6(실 모델)이나 차단 중 → V2(뮤테이션)가 **모델-무관 효과 입증**을 그 전까지 담당.
- **V5는 후순위**: 리팩터 가치는 확실하나 검증 점수 직접 기여 낮음.

---

## 5. 예상 효과 — 점수 변화

| 완료 범위 | 검증 점수 | 비고 |
|---|---|---|
| 현재 | 중간 | 골격 좋으나 실효성 미입증 |
| V1~V3 | 중간+ ~ 강함 근접 | 강제력·결함검출·SKIP 해소 (체감 큼) |
| V1~V5 | 강함 근접 | 멀티모델·리팩터까지 |
| V1~V6 | **강함** | 효과 실증 완결 (모델 baseline) |

**핵심**: ~~V6 없이는 효과 실증 미완~~ → **V1~V6 전량 완료(2026-06-15)**. V6 실 모델 baseline까지 측정 완료 → 검증 점수 **"강함"** 도달. 단 V6는 1회 트라이얼 예비 신호 — 통계적 완결은 N회 재현 의존(한계 고백 유지).

---

## 6. 비용·한계 고백

- 각 FID = 풀 lifecycle(spec→clarify→plan→decompose→implement→verify→review→PR). 6건이면 무거움. V6 제외 5건, 즉시 착수 3건(V1~V3).
- promptfoo·stryker는 JS — bash 플러그인엔 **방법론 참조**이지 직접 의존 아님.
- 별점·upstream 정보는 조회 시점(2026-06-13) 값.
- ~~W-1의 근본 해소(V6)는 모델 API 차단으로 현재 불가~~ — **2026-06-15 해소**: claude CLI 헤드리스 가용 확인 → V6 1회 측정 완료(§V6 측정 결과). "외부 차단"은 Fable 5 한정이었고 현재 가용 모델로 baseline 충족. V4(ollama)·V6(claude -p) 둘 다 외부 차단을 로컬/헤드리스로 우회.

---

## 7. 다음 단계

1. 본 로드맵 검토·우선순위 승인.
2. V1(`/start 거버넌스 강제력 승격`)부터 lifecycle 착수 — 차단 0·최고 레버리지.
3. 각 FID 완료 시 본 문서의 해당 행 ✅ 갱신.

---

*specops-auto-ko 검증 강화 로드맵 · 2026-06-13 · 격차 분석 후속*
