<!-- FID: 20260427-maintenance-lifecycle -->
<!-- OWNER_COMMAND: /verify -->
<!-- reference_upstream: specops-auto-ko verifying-evidence-ko 표준 패턴 + 20260424-decomposing-test-conventions 인라인 답습 -->
<!-- layer: Lifecycle-Artifact -->

# Evidence — 20260427-maintenance-lifecycle

> AC-10 통합 검증 산출물. 본 evidence.md 는 **인라인 모드 산출물 검증** (5 commit · git diff · grep) 이며, **behavioral verification 은 next-session fresh execution 으로 deferred**.

## 0. 검증 한계 (advisor 외부 검증 결과 반영 — 최우선 명시)

**검증 강도 분류** (advisor 협의 결과):

| 강도 | 정의 | 본 evidence.md 적용 |
|---|---|---|
| **structural** | artifact 존재 + grep 매칭 + 작성자가 본 세션에서 작성한 파일을 grep | 11 AC 가 structural |
| **behavioral** | skill / command 가 실제 호출되어 관찰된 동작 | 4 AC 가 behavioral |
| **meta** | 다른 AC 결과를 집약 (AC-10 자체) | AC-10 만 |

**behavioral 검증이 deferred 된 AC** — next-session fresh execution 필요:

- **AC-1 / AC-2**: sprint-contracts-ko evaluator 가 **실제 호출** 되어 BLOCK / PASS 판정 JSON 산출 검증 — 본 세션에서는 룰 텍스트 매칭만 (rule-tracing).
- **AC-3 / AC-4 / AC-5 / AC-6 / AC-9 / AC-13 / AC-14 / AC-15**: 메타 skill / specifying-ko / analyzing-ko / commands/maintain.md 의 **실제 fresh 세션 실행** 검증 — 본 세션에서는 산출물 파일 형식 + grep 검증만.
- 검증 책임: 본 보강안 머지 후 다음 사용자 세션에서 `/maintain auth.js 토큰 만료` 등 실제 입력 → 메타 skill / analyzing-ko / specifying-ko chain 동작 관찰.

**5 원칙 5 (한계 고백) 적용**: 본 evidence.md 는 정직하게 "structural 12 + behavioral 0 + meta 1 + rule-traced 2" 로 분류. "must 12/12 PASS" 단순 합산 표기는 사용 안 함.

## 1. 통합 검증 4 시나리오 (AC-10)

| # | 시나리오 | dogfood FID | 검증 강도 | 결과 |
|---|---|---|---|---|
| 1 | 신규 chain 무손상 | `20260427-test-newfeature-csv` | **structural** (current-state.md 부재 + AC-R 0 — 작성자가 신규 분기 예상 형식대로 작성) | structural PASS |
| 2 | 자연어 유지보수 | `20260427-test-natural-bugfix` | **structural** (메타 skill 자연어 분류 미실행 — args 합성을 수동 시뮬) | structural PASS |
| 3 | 슬래시 유지보수 | `20260427-test-slash-refactor` | **structural** (`/maintain` 슬래시 미실행 — analyzing-ko 산출물을 수동 시뮬) | structural PASS |
| 4 | 회귀 AC 누락 BLOCK / 포함 PASS | `20260427-test-bugfix-fixture` | **rule-traced** (sprint-contracts-ko 룰 텍스트 + fixture 비교 — evaluator 미호출) | rule-traced PASS |

## 2. AC 15 개별 매핑 검증

| AC | 우선순위 | 검증 강도 | 결과 | 증거 위치 |
|---|---|---|---|---|
| AC-1 | must | rule-traced | rule-traced PASS | sprint-contracts-ko 체크리스트 1 줄 + 안티패턴 1 항목 + B3 fixture 매칭 |
| AC-2 | must | rule-traced | rule-traced PASS | B3 fixture (AC-R-1 1 개 → 룰상 PASS) |
| AC-3 | must | structural | structural PASS | A4 dogfood current-state.md (수동 작성) — 5 항목 형식 매칭 |
| AC-4 | must | structural | structural PASS | A4 spec.md §유형 자동 라벨 (수동 작성) |
| AC-5 | must | structural | structural PASS | D1 메타 skill 신호 4 줄 + announce 룰 + D4 dispatch-log (수동) |
| AC-6 | must | structural | structural PASS | D2 commands/maintain.md + D4 dispatch-log + C5 갱신 |
| AC-7 | must | **structural-strong** | PASS | A5 신규 분기 — current-state.md 실제 부재 + AC-R 0 (실제 파일 시스템 검증) |
| AC-8 | must | **structural-strong** | PASS | C2 analyzing-ko/SKILL.md 신설 실재 + C6 두 산출물 실재 (실제 파일 검증) |
| AC-9 | should | structural | structural PASS | C6 trivial typo (§유형 trivial 수동 작성) |
| AC-10 | must | meta | meta PASS | 본 evidence.md 자체 |
| AC-11 | must | **behavioral-light** | PASS | I2 grep — 8 파일 frontmatter 실제 grep (작성 후 검증) |
| AC-12 | must | **structural-strong** | PASS | D3a + D3b README 실제 grep — `analyzing-ko`, `/maintain` 매칭 |
| AC-13 | must | structural | structural PASS | A4/D4 dispatch-log args first line + announce (수동 작성) |
| AC-14 | should | structural | structural PASS | A3 §유형 자동 로직 룰 + C6 trivial typo §1 라인 메타 (수동) |
| AC-15 | should | structural | structural PASS | C6 impact-analysis.md "데이터 출처: git log" (수동 작성 — gh 미실제 비활성화) |

**총합** — must 11 structural + behavioral-light 1 + meta 0 = **must 12/12 structural-or-stronger PASS · behavioral verification deferred to next-session execution (AC-1~6, AC-9, AC-13~15)**

**should 3/3 structural PASS · behavioral verification deferred**

## 3. 5 commit 추적

| commit | SHA | 내용 | 검증 가능성 |
|---|---|---|---|
| dispatch-log | `1205190` | 인라인 + F-12 집약 모드 결정 | 메타 결정 기록 |
| feat(B) | `a273dc8` | B1 + B2 + B3 회귀 AC 강제 + fixture | rule-traced 가능 |
| feat(A) | `a13228a` | A1 + A2/A3(F-12) + A4 + A5 | structural — A2/A3 SKILL.md 룰 추가 실재 |
| feat(D) | `bfc3f26` | D1 + D2 + D3a + D4 | structural — D2/D3a 파일 실재 |
| feat(C) | `9c36a87` | C1~C6 + D3b | structural-strong — C2 신규 SKILL + 두 template 실재 |

## 4. 5 원칙 준수

| 원칙 | 적용 위치 | 증거 |
|---|---|---|
| 1 투명성 | 메타 skill announce 메시지 (`(maintenance)`) + dispatch-log args trail | structural — 룰 텍스트 추가 / dispatch-log 수동 작성 |
| 2 문지기 | analyzing-ko ★ HARD GATE / specifying-ko Step 1 [유지보수 분기] HARD GATE | structural — SKILL.md 룰 텍스트 |
| 3 깊이 | analyzing-ko 5 + 3 항목 분석 룰 | structural — SKILL.md / template 5+3 항목 |
| 4 주권 | sprint-contracts-ko BLOCK only (Generator/Evaluator 분리) | rule-traced — 룰 텍스트 매칭 |
| 5 한계 고백 | gh CLI 미가용 fallback (git log) / 본가 web fetch skip / **본 evidence.md §0 검증 강도 분류** | structural + 본 §0 자체가 한계 고백 증거 |

## 5. 기존 신규 chain 무손상 검증 (AC-7 핵심)

기존 신규 FID 들의 chain 동작에 변동 없음:

- `20260424-r6-bash-test-gate` — 기존 신규 분기 진입 패턴 — 본 보강안 변경이 신규 분기 본문에 영향 0 확인 (specifying-ko Step 1 [신규 분기] 본문 그대로)
- `20260427-csvstat-cli` — 기존 신규 CLI 패턴 — 동일

**검증 강도**: structural-strong — 실제 git diff 검토 결과 신규 분기 본문 변경 없음 + AC-7 dogfood (`20260427-test-newfeature-csv`) 의 current-state.md 부재 실측.

## 6. behavioral 검증 deferred 항목 명세

다음 시나리오는 next-session fresh execution 으로 검증:

1. **메타 skill 자연어 분류**: "auth.js 버그 고쳐줘" 자연어 입력 → 메타 skill 이 maintenance flag 자동 세팅 + args 합성 (현재는 룰 텍스트만 확인)
2. **/maintain 슬래시 진입**: `/maintain payment 모듈 리팩터링` → commands/maintain.md Process 자동 실행 → analyzing-ko 호출 (현재는 command 파일 실재만 확인)
3. **analyzing-ko 자동 호출**: maintenance 진입 시 specifying-ko 앞에서 자동 호출 → current-state.md + impact-analysis.md 산출 → ★ HARD GATE (현재는 SKILL.md 룰 텍스트만)
4. **sprint-contracts-ko evaluator 실호출**: `20260427-test-bugfix-fixture` 의 AC-R-* 카운트 토글 시 실제 BLOCK / PASS 판정 JSON 산출 (현재는 룰 텍스트 매칭만 — rule-traced)
5. **gh CLI 비활성화 환경 fallback**: PATH 에서 gh 제거 → analyzing-ko 가 git log fallback 자동 적용 (현재는 SKILL.md 룰 텍스트 + impact-analysis.md 수동 작성)

### 6.1 검증 protocol 정형화 — `behavioral-verification-protocol.md`

위 5 항목의 verbatim 입력 + 예상 관찰 + pass/fail 판정 기준은 별도 문서로 정형화:

- **위치**: `.specops/20260427-maintenance-lifecycle/behavioral-verification-protocol.md`
- **용도**: 다음 fresh user-level Claude Code 세션 검증자용 핸드오프
- **블로커 사유 명시**: `skills/using-specops-auto-ko-ko/SKILL.md:13` `<SUBAGENT-STOP>` 조항으로 메타 skill 은 user-level 세션에서만 발화 → 본 세션 (작성자 세션) 에서 검증 시 circular 재현 (advisor 외부 검증 결과)
- **검증 후 후속**: protocol §6 절차 따라 본 evidence.md §0 / §6 갱신 + commit

**본 세션 추가 한계 고백 (5 원칙 5)**:
- 본 세션에서 deferred 5 항목의 **강도 상향 시도 차단** — advisor 권고 Path A 채택 결과
- behavioral 라벨 부착은 fresh 세션 검증 후에만 가능
- 본 세션은 protocol 작성 + handoff 까지만 책임

## 7. advisor 외부 검증

> 메모리 룰 "분석·설계 단계 advisor 의무 협의" 적용 — implementing 종료 시점 1 회 호출 완료.

**호출 시점**: 2026-04-27 commit 5 작성 직전.

**advisor 지적** (2 블로커):
- **B1. 검증 circular** — 대부분 AC 가 작성자가 작성한 dogfood 파일을 작성자가 grep. structural-only.
- **B2. §6 한계 고백 부족** — "must 12/12 PASS" 단순 합산이 검증 충실도 misleading.

**반영 결과**:
- §0 검증 한계 신설 (최우선 위치) — 검증 강도 분류 (structural / behavioral / rule-traced / meta) 표기
- §1 결과 표 + §2 AC 매핑 표에 검증 강도 컬럼 추가
- 총합 표기 정정: "must 12/12 structural-or-stronger PASS · behavioral verification deferred to next-session"
- §6 behavioral deferred 항목 5 건 명세

**advisor 의 추가 권고 (적용 완료)**:
- AC-1/AC-2 는 sprint-contracts-ko 룰 텍스트 + B3 fixture 매칭 으로 rule-traced 강화 (structural 보다 한 단계 강함)
- commit 5 메시지 본문에 "behavioral 검증 deferred" 명시

**advisor 협의 결과 채택 비율**: 2 블로커 100% 채택 + 권고 100% 적용.

### 7.1 advisor 추가 호출 — behavioral 검증 시도 차단 (2026-04-27 추가)

**호출 시점**: 본 evidence.md 작성 후 사용자 "behavioral 검증 fresh execution 진행" 요청 직후.

**advisor 지적** (1 블로커):
- **B3. 작성자 세션에서 behavioral 검증 시도 = circular 재현** — 메타 skill `<SUBAGENT-STOP>` 조항 (`skills/using-specops-auto-ko-ko/SKILL.md:13`) 으로 user-level 세션에서만 발화. Agent 도구 시뮬 / 본 세션 직접 슬래시 호출 모두 검증 자격 없음. evidence.md §0 한계 고백 패턴 재현 위험.

**반영 결과** (Path A 채택):
- `behavioral-verification-protocol.md` 신설 — 다음 fresh 세션 검증자용 verbatim 핸드오프
- evidence.md §6.1 추가 — protocol 참조 + 본 세션 한계 재명시
- behavioral 라벨 부착 시도 차단 — 본 세션에서는 strength 1 단계 상향 시도조차 안 함

**advisor 권고 Path A 채택**: 가장 정직 + 가장 빠름.

---

*작성: verifying-evidence-ko · 2026-04-27 · FID: 20260427-maintenance-lifecycle · advisor 외부 검증 2 회 완료 (제 1 회 / 제 2 회)*
