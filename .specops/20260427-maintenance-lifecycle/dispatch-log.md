<!-- FID: 20260427-maintenance-lifecycle -->
<!-- OWNER_COMMAND: /implement -->
<!-- reference_upstream: obra/superpowers@v5.0.7 subagent-driven-development + specops-auto-ko 자체 운영 관행 (20260424-decomposing-test-conventions 답습) -->
<!-- layer: Lifecycle-Artifact -->

# Dispatch Log — 20260427-maintenance-lifecycle

본 FID 의 implementing-ko 실행 기록. 5 원칙 1 (투명성) · 4 (주권 존중) · 5 (한계 고백) 충족 증거.

## 실행 모드 결정

**모드**: 인라인 (본 세션 수동 편집)
**근거**: 사용자 명시 결정 (2026-04-27 turn — implementing-ko 진입 직전 2 회 동의).

| 결정 | 사용자 응답 | 비고 |
|---|---|---|
| 1차 — 실행 방식 | 서브에이전트 주도 | planning-ko 의 표준 옵션 |
| 2차 — F-12 집약 적용 | **인라인 + F-12 집약** (Recommended) | 유사 FID `20260424-decomposing-test-conventions` 패턴 답습. 1 차 결정 override. |

**subagent dispatch 생략 근거** (implementing-ko 본문 §F-12 ESCAPE HATCH):

1. 본 FID 의 편집 대상 8 파일 (Modify 5 + Create 4 — Modify 4 + Create 4 + README 1):
   - `templates/acceptance-criteria.md`
   - `templates/current-state.md` (NEW)
   - `templates/impact-analysis.md` (NEW)
   - `skills/sprint-contracts-ko/SKILL.md`
   - `skills/specifying-ko/SKILL.md` (A2/A3 동일 파일 쌍 → F-12 집약)
   - `skills/using-specops-auto-ko-ko/SKILL.md`
   - `skills/analyzing-ko/SKILL.md` (NEW)
   - `commands/maintain.md` (NEW)
   - `README.md` (D3a/D3b 동일 파일 — commit 분리지만 동일 파일)
2. 22 task 가 본질적으로 Markdown 편집 (각 ≤ 50 라인 추가/수정. 총 LOC 예상 < 1500)
3. 메인 세션 컨텍스트에 plan/spec/clarify/tasks 모두 적재 — 서브에이전트 격리 가치 < 호출 비용
4. 유사 FID `20260424-decomposing-test-conventions/dispatch-log.md` 의 인라인 + F-12 집약 패턴 답습 (정당화 본문 인용 가능)

**상충 신호 처리**: 1 차 사용자 결정 (서브에이전트 주도) 과 2 차 결정 (인라인 + F-12 집약) 충돌 시 **2 차 결정 우선** — 사용자가 1 차 결정 후 추가 컨텍스트 (유사 FID 패턴) 제공받고 명시 override.

## Phase 분할 (commit 단위 — clarify Q2 + project verify convention)

| commit | 내용 | 담당 | 검증 |
|---|---|---|---|
| commit 1 (`feat(B)`) | B1 + B2 + B3 (templates/AC + sprint-contracts-ko + dogfood fixture) | 본 세션 | 5 스텝 grep 검증 |
| commit 2 (`feat(A)`) | A1 + A2/A3 (F-12 집약) + A4 + A5 | 본 세션 | dogfood 자연어/신규 분기 |
| commit 3 (`feat(D)`) | D1 + D2 + D3a + D4 (D3b 는 commit 4) | 본 세션 | dispatch-log args trail |
| commit 4 (`feat(C)`) | C1 + C2 + C3 + C4 + C5 + C6 + D3b | 본 세션 | 3 dogfood 시나리오 |
| commit 5 (`verify`) | I1 + I2 통합 검증 (evidence.md + frontmatter grep) | 본 세션 | AC-10/11 |

**2 단계 리뷰 원칙 유지**: Phase 별 commit 직전 본 세션이 (a) 스펙 준수 self-review (acceptance-criteria.md 매핑 확인) → (b) 코드 품질 self-review (git diff 시각 검토) 순서. Phase B 실패 시 해당 task 복귀.

**5 원칙 5 한계 고백**: self-review 는 동일 컨텍스트라 편향 가능 — 통합 검증 commit (verify) 단계에서 advisor() 1 회 호출하여 외부 검증.

## 태스크 진행 로그

(각 commit 완료 시 append)

### commit 1 — Phase B (회귀 AC must 강제)

- [ ] B1: templates/acceptance-criteria.md 회귀 AC 섹션 추가
- [ ] B2: skills/sprint-contracts-ko/SKILL.md Evaluator 체크리스트 + 안티패턴
- [ ] B3: dogfood fixture FID `20260427-test-bugfix-fixture` (BLOCK / PASS 시뮬)
- [ ] git commit: `feat(B): 회귀 AC must 강제 + dogfood fixture (B1/B2/B3)`

### commit 2 — Phase A (specifying-ko Step 1 분기)

- [ ] A1: templates/current-state.md 신설 (5 항목)
- [ ] A2 + A3 (F-12 집약): skills/specifying-ko/SKILL.md Step 1 분기 + §유형 라벨 자동
- [ ] A4: dogfood `20260427-test-natural-bugfix` (자연어 유지보수 + dispatch-log args trail)
- [ ] A5: dogfood `20260427-test-newfeature-csv` (신규 chain 무손상)
- [ ] git commit: `feat(A): specifying-ko Step 1 유지보수 분기 + current-state.md (A1~A5)`

### commit 3 — Phase D (메타 skill + /maintain + README)

- [ ] D1: skills/using-specops-auto-ko-ko/SKILL.md 신호 매칭 + args 합성
- [ ] D2: commands/maintain.md 신설 (Phase D 시점 specifying-ko 직행)
- [ ] D3a: README.md Lifecycle Chain — Phase D 시점 (analyzing-ko 부재)
- [ ] D4: dogfood `20260427-test-slash-refactor` (슬래시 유지보수)
- [ ] git commit: `feat(D): 메타 skill 신호 매칭 + /maintain 슬래시 + README (D1~D3a/D4)`

### commit 4 — Phase C (analyzing-ko + impact-analysis + chain 재배선 + D3b)

- [ ] C1: templates/impact-analysis.md 신설 (3 항목)
- [ ] C2: skills/analyzing-ko/SKILL.md 신설 (HARD GATE + gh fallback)
- [ ] C3: skills/specifying-ko/SKILL.md Step 1 본문 축약 (analyzing-ko 결과 참조)
- [ ] C4: skills/using-specops-auto-ko-ko/SKILL.md chain 재배선
- [ ] C5: commands/maintain.md Process 갱신 (analyzing-ko 추가)
- [ ] C6: dogfood Phase C 통합 (AC-8/9/14/15)
- [ ] D3b: README.md analyzing-ko 단계 추가 (commit 4 — git bisect broken docs 방지)
- [ ] git commit: `feat(C): analyzing-ko 신설 + impact-analysis.md + chain 재배선 + README D3b (C1~C6 + D3b)`

### commit 5 — verify (통합 검증)

- [ ] I1: evidence.md 작성 (AC-10 — 4 시나리오 PASS)
- [ ] I2: reference_upstream frontmatter 일괄 grep 검증 (AC-11)
- [ ] advisor() 1 회 호출 (편향 방지 — 5 원칙 5 한계 고백)
- [ ] git commit: `verify(20260427-maintenance-lifecycle): evidence.md AC-10/11 (I1, I2)`

## 관련 파일

- `tasks.md` — 태스크 원본 (스텝 상세)
- `plan.md` — 파일 구조 · 위험
- `acceptance-criteria.md` — AC 1~15 검증 대상
- `~/.claude/plans/valiant-splashing-deer.md` — 승인된 high-level plan

---

*생성: 2026-04-27 · FID: 20260427-maintenance-lifecycle*
