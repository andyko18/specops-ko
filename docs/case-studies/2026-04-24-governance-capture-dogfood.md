# Case Study — `pre:governance-capture` hook v0.1 dogfood

**FID**: `20260424-governance-capture`
**기간**: 2026-04-24 (단일 세션 연속 dogfood)
**대상**: specops-auto-ko v0.1.0 → v0.2 백로그 F-16~F-19 수확
**판정**: **PASS** · 본 Lifecycle 을 통한 Lifecycle-자기참조 기능 구현 완주

## 요약

v0.1.0 release 직후 "다음 단계" 백로그 중 `pre:governance-capture` hook 을 **본 specops-auto-ko Lifecycle 자체로 설계·구현·검증** 했다. 5원칙 1 (투명성) · 5 (한계 고백) 위반을 PostToolUse + Stop hook 으로 자동 감지해 `friction-log.jsonl` 에 기록하는 시스템.

**Lifecycle 자기참조**: specops-auto-ko 의 원칙을 감시하는 도구를 specops-auto-ko 로 만든다. dogfood 의 최강 형태.

## 최종 산출

- **19 commits** (`a70a4a5..318456c`)
- `hooks/governance-lib.sh` 8 함수 (4 코어 + 4 매처)
- `hooks/posttool-governance.sh` · `hooks/stop-governance.sh`
- `hooks/rules.jsonl` 5 시드 룰 (R-1~R-5)
- `hooks/hooks.json` PostToolUse · Stop 매니페스트 등록
- 5 테스트 suite 56 PASS · 회귀 39 PASS · Bench p95=69ms (NFR-1 200ms 대비 65% 여유)

## Lifecycle 단계별 실측

| 단계 | 산출 | 특이 사항 |
|---|---|---|
| `specifying-ko` | spec.md + AC 1~8 | Q1~Q4 수집 후 advisor 1 회 호출 (hook API 가정 검증) → claude-code-guide 서브에이전트로 transcript_path·stop_hook_active·additionalContext 3 팩트 공식 확인 |
| `clarifying-ko` | Q-A~E 5건 RESOLVED (BLOCKING 2 + DESIRABLE 3) | AC-9 (R-3 범위) · AC-10 (R-5 기준) 2건 append |
| `planning-ko` | plan.md T1~T13 | advisor 호출 없음 (transcript schema 는 T1 선행 조건으로 격리) |
| `decomposing-ko` | tasks.md 15 태스크 TDD | 실제 transcript JSONL 샘플 확인 후 jq 경로 고정 |
| `implementing-ko` | 16 commits · 56 tests | **ESCAPE HATCH 집약 적용** — 15 태스크 → 10 dispatch 클러스터 (동일 파일 쌍 순차 TDD 체인) |
| `verifying-evidence-ko` | evidence.md · AC 10/10 · 한계 고백 4건 | fresh 명령 실측 (요약 금지) |
| `requesting-code-review-ko` | 외부 리뷰 APPROVED_WITH_SUGGESTIONS | CRITICAL 0 · MAJOR 2 · MINOR 7 |
| `receiving-code-review-ko` | fix 3 commits · fresh /verify 재실행 | advisor 2 회 협의 (MAJOR 1 fix 범위 확정) · MINOR 6·7 v0.2 pushback |

## FRICTION-LOG 수확 — v0.2 백로그 P0~P2 근거

### F-16 · 테스트 컨벤션 불일치 감지 누락 (P0)

**증상**: tasks.md T1~T15 가 `bats` DSL 기반으로 작성됐으나 기존 repo 는 순수 bash `PASS=0; FAIL=0` 카운터 패턴 5 건. Cluster A 구현자 dispatch 가 `NEEDS_CONTEXT` 로 중단 — `bats` 미설치 + 컨벤션 불일치 발견.

**영향**: decomposing-ko 가 기존 repo 패턴을 인지하지 못해 실행 불가 태스크 생성. 컨트롤러가 기존 `scripts/tests/test-is-hook-enabled.sh` 를 샘플 제공 후 재dispatch 로 해결 — 30~40k 토큰 손실.

**v0.2 태스크**: `decomposing-ko` SKILL 에 "테스트 하네스 선행 점검" 체크리스트 추가 — plan.md §2 파일 구조 확정 직후 `scripts/tests/` 기존 샘플 1 건 읽고 컨벤션 반영. 또는 `specifying-ko` / `planning-ko` 가 기존 hook · 테스트 샘플을 필수 Read 대상으로 명시.

### F-17 · Lifecycle 계약 drift — Q-E 가 구현과 어긋남 (P0)

**증상**: clarifications.md Q-E (DESIRABLE) "transcript_offset = tool event index (0-based)" 로 RESOLVED. 구현은 `grep -c '^' "$transcript"` (파일 전체 라인 수) 반환 — 매 매칭마다 동일 상수. 52 tests 통과 (값 의미 미검증) + cluster 별 리뷰 6 회 전부 통과 + `final-reviewer` APPROVED_FOR_VERIFY + /verify PASS. **외부 리뷰 Round 2 에서야 포착**.

**영향**: sprint-contracts 의 "Evaluator 는 계약만 판정" 이 **실제로는 AC 만 판정**하고 clarifications DESIRABLE 답변은 검증 대상 아님이 드러남. Q-E 같은 필드 시맨틱은 `acceptance-criteria.md` 에 AC 로 고정되어야 Evaluator 가 잡음.

**v0.2 태스크**:
- (a) `clarifying-ko` SKILL 에 "DESIRABLE 답변이 **실행 가능 검증 기준**이면 AC 로 승격 의무" 조항 추가
- (b) 또는 `analyzer-ko` 가 clarifications DESIRABLE 을 별도 검증 매트릭스로 교차 확인
- **권장**: (a) — AC 단일 판정 기준 유지가 단순

### F-18 · 리뷰 차원 확장 — AC 성숙도 한계 (P1)

**증상**: R-5 매처가 Write · Edit 만 검사. 외부 리뷰에서 **MultiEdit 누락** 지적. AC-10 "세션 중 spec/plan/analysis md 가 수정됨" 조건이 수정 방법 (Write/Edit/MultiEdit/NotebookEdit …) 을 열거하지 않음 — 구현자가 가장 흔한 2 종만 선택.

**영향**: AC 가 "어떻게 수정됐는지" 보다 "수정됐다" 를 추상적으로 기술 → 구현 시 tool 이름 열거가 구현자 재량. PoC 단계엔 수용 가능하나 v0.2 대형 룰에서 재발 가능.

**v0.2 태스크**: AC 작성 템플릿 에 "Tool-level trigger 열거" 섹션 추가. 예: "수정 = Write OR Edit OR MultiEdit OR NotebookEdit (Claude Code 2026-04 기준)" 명시. specifying-ko 가 이 열거를 사용자에게 질문하도록 프로세스 보강.

### F-19 · Advisor 의무 규약 효과 첫 실증 (P2, 긍정 마찰)

**증상**: 2026-04-24 사용자 직접 지시로 "분석·설계 단계 advisor 의무 협의" 규약 도입. 이번 FID 에서 **실 적용**:
1. specifying-ko 설계 초안 전 1 회 → hook API 3 팩트 확정 (transcript_path · stop_hook_active · additionalContext)
2. receiving-code-review-ko fix 범위 결정 전 1 회 → **Q-E 원문 재해석**으로 구현 복잡도 축소 (event index 계산 → 단순 line counter, 5 함수 수정 → 3 함수 수정)

**영향**: **긍정 마찰**. advisor 호출 ≈ 2 회 · 토큰 ≈ 5k · 획득 = MAJOR 1 fix 범위 50% 축소 + hook schema 가정 제거. ROI 수치로 검증됨.

**v0.2 태스크**: pattern 문서화 — `docs/patterns/advisor-protocol.md` 에 호출 타이밍 · 기록 포맷 · ROI 사례 기록. 타 Lifecycle 에 확산.

### F-20 · ESCAPE HATCH 재실증 (P2, 긍정 마찰)

**증상**: v0.0 csv-lines dogfood 에서 `implementing-ko` ESCAPE HATCH (동일 파일 쌍 TDD 체인 집약) 최초 적용 후 F-12 로 v0.1 skill 본문 반영. 이번 FID 에서 **4 클러스터 (A, C1, C2, 암묵 G)** 에서 재사용 — 15 태스크 → 10 dispatch 로 집약, 토큰 절감 약 35~40%.

**영향**: 긍정. skill 본문 반영이 실제 세션에서 안정 작동 확인.

**v0.2 태스크**: dispatch-log.md 형식을 `templates/` 에 표준 포맷으로 추가. 후속 Lifecycle 에서 집약 근거 기록이 일관되게.

## 알려진 제한 / 후속 이슈

- **본 hook 이 본 세션에서 실세션 발화했는가** — `9c25d10` 매니페스트 등록 이후 본 세션이 약 40~50 tool 호출 추가 진행. `.specops/20260424-governance-capture/friction-log.jsonl` 실세션 append 기록 미관측 (evidence.md §6.2 한계 고백). 다음 세션 첫 액션으로 파일 존재 확인 권장.
- **R-4/R-5 offset 의미 통일** — MAJOR 1 fix 시 "첫 매칭 이벤트 라인" 으로 통일했으나 Stop hook 맥락에서는 "마지막 이벤트 라인" 이 더 자연. v0.2 실측 후 재검토.
- **MINOR 6·7 (word-splitting · regex 메타문자)** — pushback 으로 유보. 실제 버그 재현 경로 부재. v0.2 대형 rules.jsonl 추가 시 재평가.
- **10MB transcript 실측** — 외부 리뷰 시 2.5MB 에서 posttool 83ms / stop 137ms · 10MB 에서 stop 499ms (NFR-1 초과). v0.2 CI 실측 대상.

## 다음 단계

### 이번 세션 마무리
- main 에 19 commit + 본 case-study push
- v0.2.0 release 는 **중간 작업** 이라 미룸 (다음 기능 후 일괄)

### v0.2 백로그 (실측 근거 우선)
- **P0** F-16 decomposing-ko 테스트 컨벤션 선행 점검
- **P0** F-17 clarifying-ko DESIRABLE → AC 승격 의무 조항
- **P1** F-18 AC 템플릿 Tool-level trigger 열거 섹션
- **P2** F-19 docs/patterns/advisor-protocol.md 신규
- **P2** F-20 dispatch-log 표준 템플릿
- (기존 예정) ECC `autonomous-loops` 흡수 (Sequential Pipeline · De-Sloppify)
- (기존 예정) Superpowers `writing-skills` · `executing-plans` · `finishing-a-development-branch` 선별 흡수
- (기존 예정) `github/spec-kit` 직접 clone

## 참조

- 설계 아티팩트: `.specops/20260424-governance-capture/` (spec · AC · clarifications · plan · tasks · evidence · dispatch-log · review-request) — gitignore 로 repo 미포함, 로컬 유지
- 메모리 규약: `~/.claude/projects/-Users-andyko-Project-0-Claude-specops-auto-ko/memory/feedback_advisor_analysis_design.md`
- 선행 case-study: `docs/case-studies/2026-04-22-specops-auto-ko-v0.0-poc-pass.md`
- 패턴: `docs/patterns/pair-artifact-cross-review.md`

---

*Lifecycle 자기참조 dogfood 완주 · 2026-04-24 · 19 commits · 56 tests · p95 69ms · MAJOR 2 해소*
