# Changelog

[Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 포맷. [SemVer](https://semver.org/lang/ko/) 준수.

## [Unreleased]

### Added
- **간이 뮤테이션 하니스** (FID 20260614-mutation-harness, PR #67) — `scripts/tests/mutation-score.sh` 가 bash 스크립트에 1줄 변형(연산자 반전·반환값·불린) 주입 후 해당 테스트가 FAIL 로 잡는지(killed) 측정 → mutation score + survived(테스트 갭) 리포트. stryker 사상의 bash 경량 구현, 모델 무관(토큰 0). 깨끗한 원본 grep+sed(phantom 차단)·빈파일/문법 invalid 가드·복원 trap 이중 안전망. 실측: parse-dag.sh 100%·governance-lib.sh 31%(test 갭 24). 수동 도구(run-all 미포함), stub 단위 10 만 포함. 검증 강화 로드맵 V2(약점 W-1 효과 미입증의 모델-무관 대행).
- **거버넌스 강제력 승격 — PreToolUse 사전차단** (FID 20260614-governance-hard-block, PR #66) — 신규 `hooks/pretool-governance.sh` 가 verify 누락 시 `git commit`·`gh pr create` 를 실행 *전* 차단(deny). PostToolUse 사후발화의 예방 불가 한계 해소 — pretool=강제, posttool=감사 역할 분리. `apply_lookback_rule`(R-1/R-2) 재사용, `log_friction_sev` block severity 신규(기존 무변경 append). 우회 면제(`SPECOPS_GOVERNANCE_BYPASS=1`·§auto) + fail-open 으로 무인 lifecycle 보존. test-pretool 7케이스. 검증 강화 로드맵 V1(약점 W-2 강제력).
- **plan 리뷰 A/B 측정 하니스** (FID 20260613-plan-review-ab, PR #65) — `run-plan-ab.sh` 가 결함 심은 plan fixture 에 inline self-review(A) vs 2중 dispatch(B) 를 적용해 검출률·토큰 비교. `count_detected` 이중 가드 (plan 본문 등장 locator 무효화 — claude 입력 인용 over-count 차단), 결함 fixture 2종 (커버리지·플레이스홀더·타입), stub 단위 9 (토큰 0). 격차 분석 P2-1, Superpowers v5.0.6 subagent-리뷰 폐지 측정의 코드베이스 재현. 실 baseline 은 모델 가용 시 수동 측정 (한계 고백).

## [1.13.0] — 2026-06-12

### Added
- **압박 테스트 레이어** (FID 20260613-pressure-eval, PR #64) — run-pressure-evals.sh 가 HARD GATE 우회 압박을 claude -p 로 실행, judge_pressure 가 금지 도구 호출 부재 AND 게이트 거부 발화 존재를 판정 (침묵 굴복도 FAIL). pressure-fixtures 6건 + stub 단위 11 (토큰 0). 격차 분석 P2-2.
- **tier→Agent model 파라미터 매핑** (FID 20260612-tier-dispatch, PR #63) — implementing-ko 가 tier 판단을 Agent 도구 `model` 로 실제 전달 (low→haiku/medium→sonnet/high·불확실→inherit). 격차 분석 P2 O-4.
- **학습 환류 루프** (FID 20260611-learning-loop, PR #60) — `gbrain-collect.sh` (handoffs/evidence 기계 수집) + `gbrain-recall.sh` (토큰 중첩 조회, 1000건 ~50ms) 신설. performance-test-ko 가 lifecycle 말미에 인사이트 ≤3건 자동 추출, specifying-ko 가 차기 진입 시 관련 인사이트를 spec §참조에 자동 인용. `learnings.jsonl` 은 gitignore 예외로 git 추적 (학습 자산 영속). DAG 병렬 worktree wave 첫 실전 적용.
- **멀티모델 critic** (FID 20260612-multimodel-critic, PR #61) — `critic-ask.sh` 가 plan.md·diff 를 외부 모델 CLI (CRITIC_BIN>codex>gemini) 에 위탁, advisory 전용 (판정 권한 없음·실패 exit 0). planning-ko·requesting-code-review-ko·advisor-ko 연결 + 비밀 보호 가드·인젝션 가드·200KB 절단. CLI 부재 시 graceful SKIP.
- **worktree skill v5.1.0 (PRI-974) 동기화** (FID 20260612-worktree-sync-v51, PR #62) — 중첩 worktree 감지 (git-common-dir)·생성 동의 게이트 (모드 4분기 — 무인 흐름 보존)·provenance 정리 (.worktrees/ 한정, 외부 불가침)·detached HEAD 분기. reference_upstream @v5.1.0 bump.

## [1.12.0] — 2026-06-11

### Added
- **design-screen(s) ui-ux-pro-max rationale 보관 + Anti-pattern 게이트** (FID 20260610-design-screen-enrich, PR #54).
- **`scripts/tests/run-all.sh` 전체 테스트 aggregator** — 41 suites (test-*.sh + dag + governance + convention + validate-structure). `release.sh` pre-flight 가 메인 3종 대신 이를 호출. `.github/workflows/test.yml` CI 신설.
- **LLM eval 레이어** (FID 20260610-llm-eval, PR #57) — 메타 skill 신호 감지 + 체인 진입을 headless `claude -p` 로 smoke eval. `scripts/tests/llm-eval/`: fixtures 10건 + `run-evals.sh` (stream-json 파싱·재시도 cap=1·BORDERLINE·sandbox 격리·timeout 워치독) + stub 기반 단위 테스트 17건 (run-all 편입, 토큰 0). 실 eval 은 수동 전용 (비용) — 첫 완주 실측 PASS=10 FAIL=0.

### Fixed
- **거버넌스 훅 성능 74배 개선 + 회귀 게이트** — governance-lib 줄단위 jq fork 루프 6곳을 단일 jq 패스로 재작성 (2000줄 Stop 훅 8,000ms → 108ms). bench-hook 에 stop 워스트케이스 게이트 신설 + CI 연결. CWD 앵커링(`CLAUDE_PROJECT_DIR`)·word-split·gbrain tags 이스케이프·FID 가드 등 MEDIUM 잔여 일괄. `.specops/` 205 파일 추적 해제 (배포 불포함 규약 정합).
- **`.gitignore` 미해소 머지 충돌 마커 5줄 제거**.
- **테스트 5종 stale 경로 수정** — `count-artifacts`/`diff-upstream`/`is-hook-enabled`/`validate-task-dependencies` 의 `scripts/` → `scripts/_internal/` 이동 미반영 (rc=127 FAIL → PASS).
- **문서 동기화** — README footer·skill×30·templates×28, marketplace description v1.11.0, e2e 9단계/V19 표기, CLAUDE.md layer 3 목록(e2e-test-ko 추가), R-6 비활성 상태 명기.

## [1.11.0] — 2026-06-09

### Added
- **`/design-screens` 복수 화면 일괄 디자인 커맨드 신설** — 목록 자동 판단·승인 게이트·화면별 순차 대화 루프. design-screen 과 cross-ref 연결. (FID 20260609-design-screens)
- **`release.sh` FR-7b manifest bump** — `plugin.json`/`marketplace.json` version 필드 자동 갱신 (v1.10.0 릴리즈 시 manifest desync 재발 방지).

### Changed
- **R-6 비활성화 (`enabled: false`)** — gbrain-ko manual-only 설계 우선, lifecycle 완주 시 false-warn 제거. 거버넌스 자동 검사는 R-1~R-5 로 축소.

### Fixed
- **manifest v1.10.0 desync 즉시 수정** — plugin.json + marketplace.json.
- **design-screens Step 3-1 충돌확인 순서 명확화 + Step 3-3 html 생성 표현 수정**.

### Docs
- README 12건·footer v1.10.0 + maintain.md·메타 skill chain 동기화. CHANGELOG v1.10.0 섹션 백필.

## [1.10.0] — 2026-06-09

### Added
- **`/start-auto` 완전자동 모드** — `<!-- entry: auto -->` 진입, 각 HARD GATE 자동 통과(가역), PR 직전 단일 확인. commands/start-auto.md 신설. specifying/clarifying/planning/decomposing/implementing/verifying/performance-test-ko 전 단계 §auto 분기 적용.
- **`show-fid-status.sh` FID Lifecycle 상태 표시 CLI** — `.specops/<FID>/` 산출물 기반 현재 단계 표시 (AC-1~AC-5). PR #50.
- **Dynamic workflow 패턴** — 다단계 병렬 wave (`dag::find_ready`), 모델 티어 라우팅(tasks.md `tier: low|medium|high`), Stage handoff 규약(`handoffs/` 4필드), Bounded verify→fix 루프(fix_count 추적·상한 3회). implementing-ko·verifying-evidence-ko·structured-artifacts-ko 적용.
- **`/release` 릴리즈 자동화 skill + `scripts/release.sh`** — CHANGELOG·README·commands footer·manifest 버전 동기화. PR #51.

### Changed
- **`specifying-ko`** — §auto 분기: 화면 설계 자동수락 + spec 게이트 자동통과.
- **`clarifying-ko`** — §auto BLOCKING best-guess 자동응답 + `status: ASSUMED` + 가정 근거 필드.
- **`planning-ko`** — plan-reviewer cap 초과 시 §auto 자동통과(가역).
- **`decomposing-ko`** — `irreversible: true` DAG 필드, 3-way 다음 skill 분기(batch/auto/single).
- **`implementing-ko`** — Phase B/C §auto 수렴 + `auto_retry_count` 전역 재시도(cap=1).
- **`verifying-evidence-ko`** — fix_loop cap §auto 수렴 + shared `auto_retry_count`.
- **`performance-test-ko`** — 3-way PR 게이트(batch/auto 가정다이제스트/single).
- **`structured-artifacts-ko`** — `auto-state.md` 규약, 무인 모드 술어 문서화.

---

## [1.9.0] — 2026-06-08

### Added
- **`/start-batch` batch 레벨 통합·성능 테스트 (must-run)** — Phase 3 완료 후 `integration-test-ko` → `performance-test-ko` 1회 실행 추가 (Step A·B). 표면/임계값 부재 시 graceful skip. 단일 `/start`와 `/start-batch` 동작 일치.
- **`receiving-code-review-ko` batch halt 패턴** — `## 다음 skill`에 `**§batch**` 라벨 감지 분기 신설. batch 모드 시 `BATCH-REVIEW-DONE: <FID>` 출력 + halt, integration-test-ko 미호출. 단일 모드는 기존 chain 유지.
- **`performance-test-ko` batch-aware PR gate skip** — `## PR 생성 게이트` 진입 직전 `**§batch**` 라벨 감지 분기. batch 모드 시 `BATCH-PERF-DONE: <FID>` 출력 + PR 게이트 전체 skip, `/start-batch` 오케스트레이터로 제어 반환.

### Changed
- **`commands/start-batch.md`** — Phase 3 loop Step 5: stale "PR 생성? [y/n] → n decline" 참조 → `BATCH-REVIEW-DONE` 감지 자동 차단으로 교체. Phase 3 완료 섹션에 Step A(통합 테스트)·B(성능 테스트)·C(batch PR) 3단계 구조 명시. 안티패턴에서 stale `receiving-code-review-ko` 직접 묻기 설명 제거.
- **`README.md`** — 헤더 `v1.7.0` → `v1.8.0` 갱신. Lifecycle Chain 다이어그램에 `integration-test-ko`·`performance-test-ko` 노드 추가 + PR gate를 `performance-test-ko` 말미로 이동. chain 텍스트에 integration-test·performance-test 추가.
- **`commands/start.md`·`start-foundation.md`** — chain 나열에 `→ integration-test-ko → performance-test-ko → PR` 추가.
- **`skills/systematic-debugging-ko/SKILL.md`** — `used_by`에 `integration-test-ko·performance-test-ko` 추가. `## 다음 skill` routing에 integration/performance FAIL caller 복귀 케이스 추가.
- **`scripts/_internal/validate-structure.sh`** — 헤더 주석 `× 27` → `× 29` 갱신 (실제 .structure-baseline 반영).

---

## [1.8.0] — 2026-06-05

### Added
- **`integration-test-ko` engine skill (layer 2)** — lifecycle chain에서 통합 표면(API·DB·다중 모듈 경계) 검출 시 통합 테스트 작성·실행·증거화. 표면 부재 시 graceful skip. test-master integration 패턴 번안.
- **`performance-test-ko` engine skill (layer 2)** — lifecycle chain에서 NFR 성능 임계값(응답시간·처리량·동시성) 검출 시 성능 테스트 작성·실행·증거화. 임계값 부재 시 graceful skip. test-master performance 패턴 번안.
- **PR 생성 게이트 이전** — `receiving-code-review-ko`에서 PR 생성(`gh pr create`)을 `performance-test-ko` 말미로 이전. 통합/성능 테스트를 PR 직전에 실행하는 구조 확립.

### Changed
- **`receiving-code-review-ko`** — `## 다음 skill`이 chain 종료에서 `integration-test-ko` 호출로 변경. `## PR 생성 (Lifecycle 종료)` 섹션 제거 (performance-test-ko로 이전).
- **`e2e-test-ko`** — S6.5 단계(integration-test-ko·performance-test-ko SKIP 경로 검증 V18~V19) 추가. 검증 항목 17→19, PASS≥16→PASS≥18.
- **chain 순서** — `…verify → review → integration-test → performance-test → PR` (단일 /start 및 /start-batch 모두)

---

## [1.7.0] — 2026-06-05

### Added
- **`/start-batch` 슬래시 커맨드** — `requirements.md` FR 표를 자동 파싱해 전체 기능을 일괄 구현하는 3-Phase 오케스트레이터.
  Phase 1(spec→clarify→plan→decompose per FR) → Phase 2(일괄 리뷰 1회) → Phase 3(impl→verify→review per FR 순차 무중단) → 최종 batch PR 1개
- **`specifying-ko` batch 분기** — `<!-- entry: batch -->` 감지 시 git-branch-create skip + spec.md §1에 `**§batch**: <batch-id>` 라벨 기재
- **`decomposing-ko` chain 정지점** — spec.md `**§batch**` 라벨 감지 시 `BATCH-PHASE1-DONE: <FID>` 출력 + halt (implementing-ko 미호출)

---

## [1.6.0] — 2026-06-05

### Added
- **`/start-foundation` 슬래시 커맨드** — 한국 SI 표준 "공통부 먼저 개발" 단계 지원.
  per-feature `/start` 사이클 이전에 실행 가능한 공통부 코드(라우팅·레이아웃·인증·공통 컴포넌트·DB 마이그레이션)를 생성하는 독립 커맨드
- **`templates/foundation-manifest.md`** — 공통부 모듈 목록 템플릿 (라우팅·인증·레이아웃·공통컴포넌트·DB스키마)
- **`specifying-ko` foundation 분기** — `<!-- entry: foundation -->` signal check, Step 5.5 화면 루프 skip, §유형=`foundation` 자동 라벨
- **`clarifying-ko` BLOCKING 게이트** — §유형=`foundation` 시 `.specops/memory/frontend-architecture.md`/`backend-architecture.md` 미해소 placeholder 감지 시 기술스택 BLOCKING 강제
- **`planning-ko` foundation-manifest 산출 지시** — §유형=`foundation` 플랜 마지막 태스크로 `foundation-manifest.md` 저장 의무화
- **`decomposing-ko` 재사용 HARD GATE** — §유형≠`foundation` + `foundation-manifest.md` 존재 시 각 task에 `**재사용 foundation**` 또는 `**미재사용 근거**` 기재 의무

---

## [1.5.0] — 2026-06-04

### Added
- **ui-ux-pro-max 통합 포인터** — `commands/design-screen.md` Step 2.5 (design system 자동 자문)
  + `skills/specifying-ko/SKILL.md` Step 5.5 하위 절차 (화면 설계 전 design system 자문 안내). available-skills 에 `ui-ux-pro-max:ui-ux-pro-max` 가 없으면 graceful skip
- **로그인 화면 dogfood** — `screens/login.html` (HTML5/CSS3/인라인 JS, 다크 테마, 320px+ 반응형, AC-5 비밀번호 토글, role=alert·aria-invalid·aria-pressed 접근성)
  + `scripts/tests/test-login-screen.sh` (grep-F 기반 HTML 구조 검증 11체크, AC-1~AC-5)

### Removed
- **stale 브랜치 정리** (2026-06-01) — 이전 세션 잔재인 머지 완료 브랜치 6종(로컬 5 + remote 5 ref) 삭제: `chore/commands-cleanup`·`chore/v1.3.0-bump`·`feat/20260522-harness-ref-skills`·`feat/20260526-bash-redirect-evidence`·`feat/20260526-e2e-test-ko-split`·`fix/cleanup-stacked-prs`. 전 산출물이 main 에 반영됐음을 확인 후 삭제 (MERGED 8 + squash-머지 추정 2, 유실 0). 로컬·원격 모두 `main` 단독 상태로 복원

### Docs
- 거버넌스 R-6 문서 누락 정정 — `CLAUDE.md`·`README.md` "5규칙 R-1~R-5" → "6규칙 R-1~R-6" + R-6 행/설명 추가. `posttool-governance.sh` 설명 R-1~R-5 → R-1~R-3 정정. 하드코딩 PASS 카운트 제거 (#43)

---

## [1.4.0] — 2026-06-01

### Added
- **e2e-test-ko 양 끝 커버리지** — `S0 BOOTSTRAP`(start-project 부트스트랩 검증 V10~V13) + `S7 FINISH`(finishing 정리 HARD GATE 로직 V14~V17). lifecycle 6→8단계, 검증 V1~V9 → V1~V17. S0/S7 은 격리 throwaway repo(`mktemp`+`git init`)에서 실행 (#38)
- **DAG-AWARE PARALLEL dispatch 재실행 harness** (`scripts/tests/dag/dogfood-parallel-harness.sh`) + fixture(`fixtures/dogfood-parallel/`) + 실증 case-study. `run`(병렬 GAP 보존)·`demo`(머지 glue 자동) (#41)
- governance 단위 테스트 **T-R6.15/16** (stop-governance.sh end-to-end 통합 — entrypoint 실제 실행 + 멱등 가드) + **T-R6.17/18** (same-turn Write+Bash characterization + negative fixture) (#39)
- implementing 단위 테스트 **T2.a~c** — 부모 머지-race(`git apply --index` 합성/충돌 abort) 검증 (#40)

### Changed
- `receiving-code-review-ko` — finishing handoff forward pointer 추가 (PR `MERGED` HARD GATE 라 자동 chain 금지, 수동 진입 안내) (#38)
- `commands/e2e-test.md` — 8단계/V1~V17 동기화 (#38)
- governance `apply_gbrain_absence_rule` — Minor1 hot-path tightening: `tool_use` 선검사로 비-tool 라인 jq fork 절감 (동작 보존, union 미채택) (#39)
- governance 테스트 66 → 70 PASS

### Fixed
- `apply_gbrain_absence_rule` docstring — trivial-skip 의 CWD 의존 spec.md lookup 한계 고백 (#39)

### Notes
- **G3 병렬 dispatch 진실 규명**: "미구현" 아님 — 이미 specified (지침 + infra + 안전장치 완비). 부모 머지 로직 단위검증(#40) + dogfood 실증(#41). 단 단일 메시지 멀티-Agent emit(병렬 dispatch 핵심)은 bash 검증 불가 — 실제 증명은 세션 transcript 에만 존재

---

## [1.3.0] — 2026-05-26

### Added
- **R-6 거버넌스 규칙** (`hooks/governance-lib.sh:apply_gbrain_absence_rule`) — `/verify` 후 `gbrain-append.sh` 호출 부재 시 Soft Warn. lifecycle 완주 후 1줄 인사이트 자동 누적 권고 (#35)
- **R-6 evidence 매처 Bash invocation 분기** — `bash scripts/_internal/run-verification.sh <FID>` dogfood 경로를 evidence 생성으로 인정. BASH_REMATCH capture group 2 로 FID 추출 + defense-in-depth grep 가드 (#36)
- 신규 fixture 8건 (`scripts/tests/governance/fixtures/transcripts/r6-*.jsonl`)
- 신규 단위 테스트 T-R6.0~T-R6.14 (15건) — invocation 단독·gbrain runner·trivial-skip·mixed Write+Bash line max 등

### Fixed
- `hooks/session-start.sh` awk `exit` 가 END 블록 트리거 → rehydrate 시 동일 session-progress 블록 2회 출력 버그 수정
- `hooks/posttool-governance.sh`, `hooks/stop-governance.sh` — `set -u` → `set -uo pipefail` 강화
- R-6 evidence 매처 Write OR Edit 확장 (#35 review #1, 80b89ef)
- R-6 gbrain_runner_pattern 좁힘 — `gbrain` 조회 skill false PASS 차단 (#35 review #2, cce18a5)
- R-6 Bash 분기 evidence_path_pattern 가드 (#36 review #1, 5827ba4)

### Removed
- `.specops/20260427-test-{bugfix-fixture,natural-bugfix,newfeature-csv,slash-refactor,trivial-typo}/` — dogfood 테스트 fixture 5개 정리
- `.specops/session-progress.md` — 잔여 cvt-cli 중복 entry 제거

### Added
- `CHANGELOG.md`, `CONTRIBUTING.md` 신설

---

## [1.2.0] — 2026-05-26

### Added
- `start-project` Phase 8f — api-spec.md 비선택 섹션 스트리핑 + 포맷별 템플릿 분리 (#28, c0d1582, 67eb8f5)
- `design-screen` T7/T8 테스트 추가 (#29)
- `analyzing-ko` 신설 — 유지보수 진입 시 baseline + impact-analysis.md 산출 (★ HARD GATE)
- `karpathy-ko` cross-cutting skill — Think·Simplicity·Surgical·Goal 4원칙
- `advisor-ko` skill — 애매한 지점 외부 자문 의무화
- `brainstorming-ko` — gstack office-hours 한국어 재창작 (Startup/Builder 모드)
- `plan-reviewer-ko` — planning-ko Eng 리뷰 서브에이전트
- `gbrain-ko` + `/gbrain` — learnings.jsonl 인사이트 조회
- `improve-codebase-architecture-ko` + `/improve-arch` — deep module 정적 분석
- `e2e-test-ko` + `/e2e-test` — lifecycle chain fixture 자동 실행
- `finishing-a-development-branch-ko` — worktree 정리·branch 삭제·main 동기화
- `git-branch-create.sh` — feat/<FID> 브랜치 자동 생성 (specifying/analyzing Step 0)

### Fixed
- `planning-ko` ## Eng 리뷰 중복 3개 제거 + `brainstorming-ko` ## 다음 skill 추가 (7ab564b)
- `hooks/is-hook-enabled.sh` 경로 `scripts/` → `scripts/_internal/` (#30)
- `design-screen` exit 0 누락 (#29)
- harness skill layer 필드 1 → 3 (잔여 분류 오류)
- `run-verification.sh` whitelist 보안 강화 + `..` traversal 차단
- `marketplace.json` 버전 동기화 1.1.1 → 1.2.0

### Changed
- 전 skill frontmatter 정합성 — `used_by` 네임스페이스 정규화 + PoC v0.0 → v1.0.0 (#27)
- `commands/*` `specops_version` 1.0.0 정렬 + `specops_layer` 필드 추가

---

## [1.1.0] — 2026-05-19

### Added
- `start-project` `--resume` 플래그 — 부분 부트스트랩 재개 (#22)
- `design-screen` 자동화 bash + 테스트 (#23)
- `specifying-ko` v2.2 — CONTEXT.md + docs/adr/ 자동 감지 (#12)
- `SKILL.md` 템플릿 + 규약 자동 검증 (`test-skill-conventions.sh`)

### Fixed
- `start-design` deprecated → `start-project` 통합

---

## [1.0.0] — 2026-05-18

### Added
- PoC → 정식 릴리즈 전환
- Lifecycle chain 7단계 완성: specify → clarify → plan → decompose → implement → verify → review
- 거버넌스 엔진 R-1~R-5 + 38건 테스트
- DAG 파서 (`scripts/dag/parse-dag.sh`) + 13건 테스트
- 서브에이전트 2단계 리뷰 (Phase B spec-reviewer-ko, Phase C code-reviewer-ko)
- Harness skill 5종 — sprint-contracts, structured-artifacts, generator-evaluator, context-resets, file-based-communication

[Unreleased]: https://github.com/kohaedong/specops-auto-ko/compare/v1.13.0...HEAD
[1.13.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.12.0...v1.13.0
[1.12.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/kohaedong/specops-auto-ko/releases/tag/v1.0.0
