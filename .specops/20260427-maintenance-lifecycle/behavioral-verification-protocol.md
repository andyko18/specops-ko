<!-- FID: 20260427-maintenance-lifecycle -->
<!-- OWNER_COMMAND: /verify (behavioral 후속) -->
<!-- reference_upstream: evidence.md §6 deferred 항목 5 건 정형화 -->
<!-- layer: Lifecycle-Artifact -->

# Behavioral Verification Protocol — 20260427-maintenance-lifecycle

> **목적**: evidence.md §6 의 5 건 deferred 항목을 **다음 fresh user-level Claude Code 세션** 에서 검증하기 위한 verbatim 입력 + 예상 관찰 + pass/fail 판정 기준 정형화.
>
> **본 세션 검증 불가 사유**: `skills/using-specops-auto-ko-ko/SKILL.md:13` 의 `<SUBAGENT-STOP>` 조항 — 메타 skill 은 user-level 세션에서만 발화. 본 세션은 보강안 작성자 세션이라 다시 circular 검증 (evidence.md §0 한계 패턴 재현). advisor 외부 검증 결과 본 세션에서 강도 상향 불가 확정 (2026-04-27).

## 0. 사전 조건

1. **새 Claude Code 세션 시작** — 본 세션이 아닌 **별도 사용자 세션** 에서만 실행
2. 작업 디렉토리: `/Users/andyko/Project/0.Claude/specops-auto-ko`
3. 머지 SHA 확인:
   - `<TBD — 본 verbatim 교체 commit>` (verify protocol verbatim 실재 파일 교체 — 2026-04-27 B-V1 1차 검증 결과 반영)
   - `62f12f3` (verify behavioral protocol — Path A 채택)
   - `bd8c6b7` (verify evidence.md AC-10/11)
   - `9c36a87` (Phase C analyzing-ko 신설)
   - `bfc3f26` (Phase D 메타 skill 신호 + /maintain)
   - `a13228a` (Phase A specifying-ko Step 1 분기)
   - `a273dc8` (Phase B 회귀 AC + fixture)
4. **검증자 = 보강안 비참여 사용자** 권장 (불가능하면 동일 사용자라도 fresh 세션 가능)

## 1. B-V1 — 메타 skill 자연어 분류

### Verbatim 입력
```
commands/maintain.md 의 인자 2 차 판단 안티패턴 항목 본문 표현이 모호한 버그를 고쳐줘
```

> **verbatim 교체 이력 (2026-04-27)**: 초기 입력 (`auth.js 토큰 만료 처리 버그`) 은 specops-auto-ko 환경에 미존재 파일을 가정해 fresh 세션 (B-V1 1차 검증) 에서 analyzing-ko 가 baseline 캡처 거부 + 사전 차단으로 응답 — 5 원칙 5 한계 고백 정상 동작 검증됐으나 HARD GATE / 산출물 5+3 항목 검증은 도달 못 함. **본 입력은 specops-auto-ko 실재 파일 (`commands/maintain.md`) 을 가리켜 baseline 캡처 가능**.

### 예상 관찰
1. 세션 시작 시 system-reminder 로 메타 skill (`specops-auto-ko:using-specops-auto-ko-ko`) 활성 표기
2. 입력 직후 메타 skill 신호 분류 — `[유지보수 신호]` 매칭 ("버그 고쳐줘")
3. 어시스턴트가 announce 메시지 출력:
   - **Phase C 적용 후**: `"Using analyzing-ko (maintenance) to <목적>"`
   - (Phase A 단독이라면 `"Using specifying-ko (maintenance) to <목적>"`)
4. analyzing-ko 호출 시 args 첫 줄에 `<!-- entry: maintain -->` HTML 주석 prepend, 둘째 줄에 원본 입력
5. analyzing-ko 가 `.specops/<FID>/` 디렉토리 생성 + `current-state.md` + `impact-analysis.md` 산출 시도

### PASS 판정 기준
- [ ] announce 메시지에 `(maintenance)` 표기 존재
- [ ] 첫 호출 skill = `specops-auto-ko:analyzing-ko` (specifying-ko 가 아님)
- [ ] dispatch-log 또는 어시스턴트 출력에 args 첫 줄 `<!-- entry: maintain -->` 약속어 확인 가능
- [ ] 모든 4 항목 충족 시 PASS, 1 개 누락 시 FAIL

### FAIL 시 후속 조치
- announce 누락 → 메타 skill `## maintenance flag 분류 로직` 의 announce 룰 본문 강도 상향 필요
- specifying-ko 직행 (analyzing-ko 우회) → 메타 skill `Phase C chain 재배선` 룰 본문 강도 상향 필요
- 약속어 누락 → 메타 skill args 합성 룰 강도 상향 필요

---

## 2. B-V2 — `/maintain` 슬래시 진입

### Verbatim 입력
```
/maintain skills/sprint-contracts-ko/SKILL.md 회귀 AC 체크리스트 항목 본문 개선
```

> **verbatim 교체 이력 (2026-04-27)**: 초기 입력 (`payment 모듈 결제 실패 처리 개선`) 은 specops-auto-ko 환경에 미존재 모듈을 가정 → 동일한 사전 차단 예상. 본 입력은 specops-auto-ko 실재 파일 기반.

### 예상 관찰
1. `commands/maintain.md` 가 Source of Truth 로 발화
2. Process 스텝 1~4 순차 실행:
   - 스텝 1 — 메타 skill 활성 확인 (passive)
   - 스텝 2 — analyzing-ko 호출 (args 합성)
   - 스텝 3 — 사용자 검토 통과 후 specifying-ko 호출
   - 스텝 4 — 이후 자동 chain
3. **인자 내용 2 차 판단 안티패턴 회피** — "결제 실패 처리 개선" 이 신규처럼 들려도 maintain 으로 진입 (commands/maintain.md `## 안티패턴` 룰)

### PASS 판정 기준
- [ ] `/maintain` 슬래시 인식 + Process 발화
- [ ] analyzing-ko 첫 호출 (specifying-ko 가 아님)
- [ ] args 첫 줄에 `<!-- entry: maintain -->` 약속어 prepend
- [ ] "신규 신호처럼 보임" 이유로 진입 보류 안 함 (안티패턴 회피)

### FAIL 시 후속 조치
- specifying-ko 직행 → `commands/maintain.md` Process 본문 명시도 부족 또는 메타 skill 우회
- 인자 내용 2 차 판단 발생 → `## 안티패턴` 항목 본문 강화 필요

---

## 3. B-V3 — analyzing-ko HARD GATE

### Verbatim 입력
B-V1 또는 B-V2 의 후속 — 별도 입력 없이 chain 흐름

### 예상 관찰
1. analyzing-ko `## 체크리스트` 1~7 순차 실행:
   - 1: `.specops/<FID>/` 디렉토리 보장
   - 2: `current-state.md` 5 항목 작성
   - 3: `impact-analysis.md` 3 항목 작성
   - 4: gh CLI 가용성 점검 (`gh --version` 실행)
   - 5: 변경 규모 평가 (≤5 라인 → trivial 자동, >5 → 3 항목 모두)
   - 6: ★ HARD GATE — `"분석 결과 검토. 진행? [y/n]"` 출력
   - 7: session-progress append (`bash scripts/session-progress-append.sh ...`)
2. 사용자 `n` 응답 → specifying-ko 호출 안 함
3. 사용자 `y` 응답 → specifying-ko 호출 + args 첫 줄 약속어 유지

### PASS 판정 기준
- [ ] 두 산출물 (`current-state.md` + `impact-analysis.md`) 실제 파일 생성
- [ ] `current-state.md` 5 항목 (변경 대상 / 호출자 / 테스트 / Baseline / 회귀 위험) 모두 작성
- [ ] `impact-analysis.md` 3 항목 (외부 영향 / 마이그레이션 / 히스토리) 모두 작성 (또는 trivial 자동 시 §3 만)
- [ ] HARD GATE 메시지 발화
- [ ] `n` 응답 시 specifying-ko 호출 차단 확인 (chain 멈춤)

### FAIL 시 후속 조치
- 산출물 누락 → analyzing-ko `## 체크리스트` 본문 강도 상향
- HARD GATE 우회 → `<HARD-GATE>` 태그 본문 강도 상향
- `n` 응답 무시 → HARD GATE 룰 본문 차단 명시도 강화

---

## 4. B-V4 — sprint-contracts-ko evaluator 실호출

### Verbatim 입력 (3 변형)

#### 변형 4-A: AC-R 누락 (BLOCK 예상)
1. `.specops/20260427-test-bugfix-fixture/acceptance-criteria.md` 백업 (`cp ...md ...md.bak`)
2. 파일 편집 — `## 회귀 방지 AC` 섹션 전체 삭제 (AC-R-1 0 개)
3. 새 세션에서 입력:
   ```
   /verify 20260427-test-bugfix-fixture
   ```
   (또는 sprint-contracts-ko evaluator 직접 호출)

#### 변형 4-B: AC-R-1 포함 (PASS 예상)
4. 백업 복원 (`mv ...md.bak ...md`)
5. 동일 명령 재실행

#### 변형 4-C: trivial 면제 (PASS 예상)
6. `spec.md §유형 = trivial` 로 임시 변경 (또는 별도 fixture 생성)
7. AC-R-1 없는 상태에서 동일 명령 — 면제 룰 발동

### 예상 관찰
- **변형 4-A**: evaluator 가 sprint-contracts-ko `## 체크리스트` 마지막 항목 (회귀 must AC ≥ 1) 검사 → 미충족 → `verdict: BLOCK` JSON 산출
- **변형 4-B**: 동일 검사 → AC-R-1 1 개 → `verdict: PASS` JSON 산출
- **변형 4-C**: trivial 면제 룰 발동 → `verdict: PASS` JSON 산출

### PASS 판정 기준
- [ ] 변형 4-A → JSON `verdict: BLOCK` + `blocking_acs` 에 회귀 AC 누락 사유 포함
- [ ] 변형 4-B → JSON `verdict: PASS`
- [ ] 변형 4-C → JSON `verdict: PASS` (trivial 면제 발동)
- [ ] 3 변형 모두 결정론적 — 같은 입력 재실행 시 동일 verdict

### FAIL 시 후속 조치
- 변형 4-A 가 PASS → sprint-contracts-ko 회귀 룰 미발동 → SKILL.md `## 체크리스트` / `## 안티패턴` 본문 강도 상향
- 변형 4-C 가 BLOCK → trivial 면제 룰 미발동 → SKILL.md 면제 조항 본문 강도 상향
- 비결정론 → evaluator 호출 시점 prompt 일관성 점검

### 후처리
- 백업 복원 확인 (`diff` 로 fixture 원본 일치)

---

## 5. B-V5 — gh CLI fallback 환경 검증

### Verbatim 입력 (PATH 조작 후)

#### 사전 셋업
```bash
# gh CLI 가용성 우선 확인
which gh

# gh 가 있으면 PATH 임시 제거
export PATH=$(echo $PATH | tr ':' '\n' | grep -v gh | paste -sd ':' -)
which gh  # → command not found 확인
```

#### 입력
```
/maintain skills/analyzing-ko/SKILL.md 의 gh CLI fallback 로직 리팩터링
```

> **verbatim 교체 이력 (2026-04-27)**: 초기 입력 (`auth.js 토큰 갱신 로직 리팩터링`) 은 specops-auto-ko 환경에 미존재 파일을 가정 → 사전 차단 예상. 본 입력은 specops-auto-ko 실재 파일 (`skills/analyzing-ko/SKILL.md` — Phase C 신설) 기반.

### 예상 관찰
1. analyzing-ko `## 체크리스트` 4 발화 — `gh --version` 시도
2. 실패 감지 → fallback 으로 `git log --merges --grep='Merge pull'` 실행
3. `impact-analysis.md` §3 에 다음 메타 명시:
   ```
   데이터 출처: git log (gh CLI 미가용 — 한계 고백)
   ```
4. HARD GATE 차단 안 됨 (gh 미가용은 BLOCK 사유 아님 — clarify Q-C 결정)

### PASS 판정 기준
- [ ] `impact-analysis.md` §3 에 "데이터 출처: git log" 메타 존재
- [ ] "한계 고백" 또는 "5 원칙 5" 표기 존재 (한계 명시)
- [ ] HARD GATE 차단 없음 (chain 진행 가능)
- [ ] gh 명령 시도 흔적 (실패 출력) 어시스턴트 로그에 가시화

### FAIL 시 후속 조치
- gh 강제 → analyzing-ko `## 체크리스트` 4 의 fallback 룰 본문 강도 상향
- 한계 고백 누락 → `## 5 원칙 주입` 표 5 행 본문 강화
- HARD GATE 차단 → analyzing-ko `## 안티패턴` "gh 강제" 항목 강화

### 후처리
- PATH 복원 (`exec $SHELL` 또는 새 셸 세션)

---

## 6. 검증 결과 evidence.md 반영 절차

5 항목 검증 완료 후:

1. 새 evidence.md `§7 behavioral 검증 결과` 추가:
   - 표 형식 — `B-V# / 결과 / 산출물 위치 / SHA`
2. evidence.md §0 검증 강도 분류 갱신:
   - 5 항목 `behavioral` 강도로 승격
   - 총합 표기 정정: "must 12/12 behavioral PASS · should 3/3 behavioral PASS"
3. evidence.md §6 deferred 항목 명세를 `§6 (RESOLVED)` 로 변경
4. **검증 부산물 정리** — fresh 세션이 만든 검증용 `.specops/<신규 FID>/` 디렉토리 점검:
   ```bash
   git status                                   # 새 디렉토리 확인
   git clean -fd .specops/<검증용 FID>/         # tracked 안 된 부산물 제거
   ```
   (실재 변경이 있어 본 commit 에 포함하고 싶다면 별도 commit 으로 분리)
5. commit: `verify(20260427-maintenance-lifecycle): behavioral protocol B-V1~V5 PASS`

---

## 7. 본 protocol 자체의 한계 (5 원칙 5)

- 본 protocol 은 **본 세션에서 작성** 됐으므로, fresh 세션 검증 시 protocol 표현 자체가 검증 편향을 유발할 가능성 존재
- 가능한 완화: 검증자가 protocol 을 **읽지 않은 채** 자연어 입력만 사용 → 검증 후 protocol 과 비교 (blind verification)
- 본 한계는 evidence.md §6 RESOLVED 시점에 동일하게 명시 필요

---

*작성: verifying-evidence-ko (post-implementation behavioral protocol) · 2026-04-27 · FID: 20260427-maintenance-lifecycle · advisor 권고 Path A 채택 결과*
