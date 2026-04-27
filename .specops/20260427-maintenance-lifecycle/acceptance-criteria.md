<!-- FID: 20260427-maintenance-lifecycle -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — 20260427-maintenance-lifecycle

> 이 파일은 **스프린트 계약서**입니다. `/specify`가 생성하고 `/clarify`가 append 수정하며, 이후 단계는 **읽기 전용**입니다. Evaluator(clarifier-ko, analyzer-ko, code-reviewer-ko, verifier-ko)는 이 계약만을 판정 기준으로 삼습니다.
>
> **§유형: 신규** — 본 보강안 자체는 specops-auto-ko 에 신규 capability 추가. 회귀 방지 must AC 강제 면제. 단 AC-7 이 신규 chain 무손상을 별도 보장.

## 계약 항목

각 AC 는 Given/When/Then 형식으로 **관찰 가능한 결과** 를 기술합니다. 구현 세부사항은 포함하지 않습니다.

---

### AC-1: Phase B 회귀 AC 강제 — 누락 시 BLOCK

**Given** dogfood FID `20260427-test-bugfix-fixture` 가 spec.md `§유형: 유지보수` 라벨 + acceptance-criteria.md 에 `AC-R-*` 0 개로 작성되어 있고
**When** sprint-contracts-ko evaluator 가 호출되면
**Then** 판정 JSON 의 `verdict = "BLOCK"` 이고 `blocking_acs` 배열에 "회귀 AC 누락" 또는 동등 이유 포함

**검증 방법**: `bash scripts/dogfood-evaluator-test.sh 20260427-test-bugfix-fixture` (또는 동등 수동 재현 — sprint-contracts-ko evaluator 호출 후 판정 JSON 확인)
**관련 FR**: FR-1, FR-2, FR-14
**우선순위**: must

---

### AC-2: Phase B 회귀 AC 포함 시 PASS

**Given** AC-1 의 fixture FID 에 `AC-R-1` 1 개를 append 한 상태에서
**When** sprint-contracts-ko evaluator 를 재호출하면
**Then** 판정 JSON 의 `verdict = "PASS"` 이고 `blocking_acs` 배열이 비어 있다

**검증 방법**: AC-1 동일 명령 + AC-R-1 append 후 재호출
**관련 FR**: FR-1, FR-2
**우선순위**: must

---

### AC-3: Phase A 유지보수 분기 진입 + current-state.md 산출

**Given** specifying-ko 가 args 첫 줄에 `__entry: maintain` 키워드를 받은 상태에서 (또는 `/maintain` 슬래시 진입)
**When** Step 1 이 실행되면
**Then** `.specops/<FID>/current-state.md` 가 templates/current-state.md 의 5 항목 (변경 대상 / 호출자·의존 / 기존 테스트 / 관찰 가능 동작 / 회귀 위험) 모두 채워진 형태로 산출되고, ★ HARD GATE ("분석 결과 검토. 진행? [y/n]") 가 발동

**검증 방법**: dogfood FID `20260427-test-natural-bugfix` 입력 → `find .specops/20260427-test-natural-bugfix/current-state.md` 확인 + 5 항목 grep
**관련 FR**: FR-3, FR-4, FR-5
**우선순위**: must

---

### AC-4: Phase A — spec.md §유형 라벨 자동 기재

**Given** AC-3 의 분기로 specifying-ko 가 진입한 상태에서
**When** Step 6 (스펙 문서 작성) 이 완료되면
**Then** `.specops/<FID>/spec.md §1 개요` 에 `**§유형**: 유지보수` 라벨이 자동 기재되고, acceptance-criteria.md 에 `AC-R-1` 회귀 must AC 가 ≥ 1 개 자동 포함된다

**검증 방법**: dogfood FID 의 spec.md grep `**§유형**: 유지보수` + acceptance-criteria.md grep `AC-R-`
**관련 FR**: FR-4, FR-6, FR-1
**우선순위**: must

---

### AC-5: Phase D — 자연어 maintenance 신호 매칭

**Given** 메타 skill `using-specops-auto-ko-ko` 가 보강 적용된 상태에서
**When** 사용자가 `"auth.js 토큰 만료 버그 고쳐줘"` 를 입력하면
**Then** 메타 skill 이 maintenance flag 분류 후 specifying-ko 호출 시 args 첫 줄에 `__entry: maintain` 키워드를 합성 전달하고, transcript 의 announce 메시지에 "Using specifying-ko (maintenance) to ..." 형태로 분류 결과 표시

**검증 방법**: dogfood 입력 후 transcript 검토 + 후속 specifying-ko Step 1 분기가 [유지보수 분기] 로 동작하는지 확인
**관련 FR**: FR-7, FR-12, NFR-5 (5 원칙 1 투명성)
**우선순위**: must

---

### AC-6: Phase D — /maintain 슬래시 진입

**Given** `commands/maintain.md` 가 신설된 상태에서
**When** 사용자가 `/maintain payment 모듈 리팩터링` 슬래시를 입력하면
**Then** command 가 메타 skill 활성 확인 → analyzing-ko 호출 → specifying-ko Step 1 [유지보수 분기] 진입 chain 이 동작하고, AC-3 / AC-4 와 동등한 산출물이 생성된다

**검증 방법**: dogfood `/maintain 20260427-test-slash-refactor` → AC-3 / AC-4 검증 명령 재실행
**관련 FR**: FR-8
**우선순위**: must

---

### AC-7: 신규 chain 무손상 (회귀 방지 — §유형 = 신규에도 별도 강제)

**Given** 4 Phase 모두 적용된 상태에서
**When** 사용자가 `/start CSV 줄 수 세기 CLI (test FID)` 또는 `"CSV 줄 수 세기 CLI 만들어줘"` 자연어 입력 시
**Then**:
1. analyzing-ko 가 호출되지 않는다
2. specifying-ko Step 1 이 [신규 분기] 로 동작 (DESIGN.md / screens/ 점검만)
3. spec.md `§유형 = 신규` 라벨 자동
4. acceptance-criteria.md 에 `AC-R-*` 회귀 AC 가 강제되지 않는다
5. 기존 신규 FID `20260427-csvstat-cli` 와 비교했을 때 chain 동작이 동일하다

**검증 방법**: dogfood `/start 20260427-test-newfeature-csv` → `find .specops/20260427-test-newfeature-csv/` 결과에 current-state.md / impact-analysis.md 부재 확인 + spec.md §유형 grep
**관련 FR**: FR-4, FR-6 (분기 정확성)
**우선순위**: must

---

### AC-8: Phase C — analyzing-ko 신설 + 두 산출물 + HARD GATE

**Given** `skills/analyzing-ko/SKILL.md` + `templates/impact-analysis.md` 가 신설된 상태에서
**When** maintenance flag 진입 시 analyzing-ko 가 호출되면
**Then**:
1. `.specops/<FID>/current-state.md` 와 `.specops/<FID>/impact-analysis.md` 두 파일 모두 산출
2. impact-analysis.md 가 templates/impact-analysis.md 의 3 항목 (외부 영향·마이그/롤백·관련 PR/이슈) 모두 채움
3. ★ HARD GATE ("분석 결과 검토. 진행? [y/n]") 발동
4. specifying-ko Step 1 [유지보수 분기] 본문이 "analyzing-ko 결과 참조" 메시지 출력 + 재분석 안 함

**검증 방법**: dogfood `/maintain 20260427-test-slash-refactor` → `find` 로 두 파일 확인 + specifying-ko transcript 검토
**관련 FR**: FR-9, FR-10, FR-11
**우선순위**: must

---

### AC-9: trivial 자동 판정 — 회귀 AC 강제 면제

**Given** maintenance FID 의 변경 라인이 ≤ 5 로 분석된 상태에서
**When** specifying-ko 가 spec.md `§유형` 라벨 부여 시
**Then**:
1. `§유형: trivial` 라벨 자동
2. acceptance-criteria.md 에 회귀 AC 강제 발동 안 함 (sprint-contracts-ko evaluator 가 trivial 면제 인식)

**검증 방법**: dogfood FID `20260427-test-trivial-typo` (1 줄 typo 수정 시나리오) → spec.md §유형 grep + sprint-contracts-ko 판정 JSON 의 verdict = PASS (회귀 AC 0 개여도)
**관련 FR**: FR-13
**우선순위**: should

---

### AC-10: 통합 검증 — 4 시나리오 모두 evidence.md 에 기록

**Given** 4 Phase 모두 구현된 상태에서
**When** verifying-evidence-ko 가 호출되면
**Then** evidence.md 에 다음 4 시나리오 결과가 모두 PASS 로 기록된다:
1. AC-7 신규 chain 무손상
2. AC-3 + AC-4 + AC-5 자연어 유지보수 (E2E)
3. AC-3 + AC-4 + AC-6 슬래시 유지보수 (E2E)
4. AC-1 + AC-2 회귀 AC 누락 detection / 포함 시 PASS

**검증 방법**: `cat .specops/20260427-maintenance-lifecycle/evidence.md` → 4 시나리오 결과 grep
**관련 FR**: 전체
**우선순위**: must

---

### AC-11: 본가 동기화 추적성 — reference_upstream frontmatter

**Given** 본 보강안의 모든 신규/변경 SKILL.md / template / commands 파일에서
**When** 파일 frontmatter 를 검사하면
**Then** `reference_upstream:` 키가 존재하고 (a) 본가 obra/superpowers@v5.0.7 의 관련 파일 또는 (b) "specops-auto-ko 독자 추가 (본가 미존재)" 명시가 포함된다

**검증 방법**: `grep -l 'reference_upstream' skills/analyzing-ko/SKILL.md commands/maintain.md templates/current-state.md templates/impact-analysis.md` + 각 파일의 frontmatter 확인
**관련 FR**: NFR-3
**우선순위**: must

---

### AC-12: README.md Lifecycle Chain 섹션 갱신

**Given** 4 Phase 구현 완료 후
**When** `README.md` 의 Lifecycle Chain 섹션을 grep 하면
**Then** `analyzing-ko` 와 `commands/maintain.md` 가 chain 다이어그램에 추가되어 있고, 기존 chain (`/start → specifying-ko → ...`) 도 유지된다

**검증 방법**: `grep -E 'analyzing-ko|maintain' README.md`
**관련 FR**: NFR-4
**우선순위**: must

---

### AC-13: entry signal prefix 형식 (clarify Q-A append)

**Given** 메타 skill 또는 `/maintain` 슬래시 진입에서 specifying-ko 호출 시 args 합성 단계에서
**When** maintenance flag 가 args 첫 줄에 prepend 되면
**Then** prepend 되는 약속어는 정확히 `<!-- entry: maintain -->` HTML 주석 형식이며, specifying-ko Step 1 의 args 파싱이 본 약속어를 검사하여 [유지보수 분기] 진입을 결정한다

**검증 방법**: dogfood transcript 에서 specifying-ko 가 받은 args 첫 줄 grep `<!-- entry: maintain -->` + 분기 결과 확인. 다른 prefix (`__entry:`, `[entry:]`) 검사 시 [신규 분기] 또는 분류 모호 1 문항 발동
**관련 FR**: FR-5, FR-12
**우선순위**: must

---

### AC-14: trivial 라벨 자동 판정 시점 (clarify Q-B append)

**Given** maintenance FID 진입 후 analyzing-ko 가 current-state.md §1 "변경 대상 식별" 의 파일·라인 범위 메타를 산출한 상태에서
**When** specifying-ko 가 §유형 라벨 부여 시
**Then** analyzing-ko §1 메타의 라인 범위 합산이 ≤ 5 면 `§유형: trivial` 자동 부여 (사용자 자기선언과 결합 — 사용자가 명시 거부 시 trivial 미부여)

**검증 방법**: dogfood FID `20260427-test-trivial-typo` 에서 analyzing-ko current-state.md §1 라인 범위 ≤ 5 확인 후 specifying-ko 가 spec.md §1 개요 에 `§유형: trivial` 자동 기재 grep
**관련 FR**: FR-13
**우선순위**: should

---

### AC-15: analyzing-ko gh CLI 미가용 fallback (clarify Q-C append)

**Given** analyzing-ko 가 호출된 환경에서 `gh --version` 명령이 실패 (gh CLI 미설치 또는 미인증) 한 상태에서
**When** impact-analysis.md §관련 PR/이슈 항목 산출 시
**Then**:
1. `git log` 기반으로 PR 머지 commit 히스토리 요약 (`git log --merges --grep='Merge pull'` 또는 동등 명령)
2. impact-analysis.md 본문에 "데이터 출처: git log (gh CLI 미가용 — 한계 고백)" 메타 명시
3. HARD GATE 차단 안 됨 (analyzing-ko chain 정상 진행)

**검증 방법**: dogfood 환경에서 `gh` 를 PATH 에서 일시 제거 후 analyzing-ko 호출 → impact-analysis.md grep `git log (gh CLI 미가용` + chain 진행 확인
**관련 FR**: FR-9, NFR-5
**우선순위**: should

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 `verify.md` 에 사유 기록
- **nice-to-have**: 여유가 있으면 반영. 미충족 시 BLOCK 없음

## 회귀 방지 AC (유지보수 FID 필수) — 본 FID 면제 사유

본 FID 의 §유형 = "신규" 이므로 `AC-R-*` 회귀 must AC 강제 면제. 단 AC-7 이 "신규 chain 무손상" 을 별도 보장하여 본가 superpowers v5.0.7 호환성 + 기존 신규 FID `20260427-csvstat-cli` / `20260424-r6-bash-test-gate` chain 동등성을 검증한다.

## 참조

- `skills/sprint-contracts-ko/SKILL.md` — 계약서 운용 규약
- `templates/spec.md`, `templates/acceptance-criteria.md` — 작성 포맷
- `~/.claude/plans/valiant-splashing-deer.md` — 승인된 plan §통합 검증 4 시나리오

---

*작성: specifying-ko · 2026-04-27 · FID: 20260427-maintenance-lifecycle · 생성 커맨드: /start*
