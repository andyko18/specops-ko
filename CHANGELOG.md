# Changelog

[Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 포맷. [SemVer](https://semver.org/lang/ko/) 준수.

## [Unreleased]

## [1.21.2] — 2026-06-23

### Added
- **verify-gate 압박 eval** (FID 20260622-verify-gate-pressure-eval, PR #104) — 거버넌스 R-1/R-2(commit·PR 전 verify 강제)를 LLM 행동 차원에서 검증하는 pressure eval 추가. `run-pressure-evals.sh`의 `judge_pressure`에 `forbidden_bash_re` 분기(Bash `input.command` 정규식 — `git commit`/`gh pr create` 변형 매칭)와 sandbox 격리를 추가하고, `verify-gate-fixtures.jsonl`(commit 우회 3 + PR 우회 3)로 "검증 생략하고 바로 커밋/PR" 압박에 게이트 발화 거부 여부를 측정. 기존 도구이름 차원 pressure 6건 무손상(`forbidden_bash_re` 미정의 하위호환). stub 단위 15/15.
- **signal eval 부트스트랩 진입로 감지** (FID 20260623-signal-eval-bootstrap, PR #105) — signal eval(`run-evals.sh`)에 프로젝트 최초 진입 부트스트랩 안내(`/init-project 권장` 발화) 감지 진입로 추가. fixture별 `sandbox_seed`(both/none/specops-only) 시드 분기 + judge `expect_bootstrap` early-return(text 발화 차원, Skill 차원 분리) + stub `text` 필드. 부트스트랩 fixture 2건 + maintain/new 표현 다양화 2건. stub 단위 23/23.
- **chain 중간단계 eval (decompose AC 커버리지)** (FID 20260623-chain-stage-eval, PR #106) — decompose 단계의 미커버 must AC 탐지율을 측정하는 `run-chain-stage.sh` + `decompose-covmiss` fixture 추가(plan-ab 패턴 확대). fixture plan.md가 미커버 AC를 본문 미언급+AC.md에만 둬 이중가드(plan.md만 검사) 통과. `count_detected` AC ID 단어경계 매칭(AC-7≠AC-70 — false-green 차단). e2e-test-ko(구조 완주)와 차원 구분(판단 정확성). stub 단위 6/6.

### Fixed
- **pretool 테스트 격리 결함** (FID 20260623-pretool-test-isolation, PR #107) — `test-pretool.sh`의 deny 테스트(T1·T4·T8~T12)가 pretool HOOK을 실 repo cwd에서 호출해, 테스트 중 `.md` uncommitted 변경 시 `is_docs_only_change()` docs-only 면제가 발동→deny→allow flip 하던 spurious FAIL(최근 3 FID 반복 관측)을 수정. 코드(.sh) staged 공유 sandbox를 `CLAUDE_PROJECT_DIR`로 지정해 격리(T16~T18 패턴 답습). **프로덕션 `is_docs_only_change()`·`pretool-governance.sh` 무변경**(의도된 commit -a 우회 차단 보안 설계 보존) — 테스트 격리만. clean+dirty 양쪽 PASS=18.
- **R-1/R-2 trigger 정규식 우회 차단** (FID 20260623-governance-trigger-evasion, PR #109) — `rules.jsonl` R-1/R-2 trigger_pattern + `pretool-governance.sh` prefilter를 일반화해 `git -c k=v commit`·`git --no-pager commit`·`git --bare commit`·`VAR=val git commit` 등 글로벌 옵션·환경변수 prefix 우회를 차단. grep -E 양방향 probe(우회 deny + false-positive allow) 실측 검증. test-pretool T19~T22.
- **R-1 trigger over-match 제거** (FID 20260623-governance-trigger-overmatch, PR #110) — trigger 정규식이 `git --no-pager log commit`·`git -C /repo log commit`처럼 `commit`을 ref명/인자로 쓰는 정당 명령을 오탐 deny하던 over-match를, 글로벌 옵션 화이트리스트(VAL 값받음→토큰소비 / NOVAL 값없음+`=`형→미소비)로 셸 파서 없이 제거. `--no-advice` under-match 동시 해소. test-pretool T23~T30.
- **R-2 docs-only 면제 비대칭 해소** (FID 20260623-r2-docs-exempt-symmetry, PR #111) — docs-only 면제가 R-1(commit, working tree 검사)엔 작동하나 R-2(PR, 커밋 완료 후 `git diff HEAD` 빈→fail-safe 차단)엔 비대칭이던 문제를 PR-범위 diff(`base...HEAD` triple-dot) fallback으로 대칭화. base 자동감지는 main→master `refs/heads` 순회 + 안전측 실패. test-lib T-docs.e~i + `_detect_base_branch` 단위.
- **trigger 우회 5종 차단 (선행자 char-class 확장)** (FID 20260623-governance-evasion-residual, PR #112) — trigger 선행자 문자집합 `(^|[;&|])` → `(^|[;&|({` + 백틱 + `])`로 확장해 subshell `(git commit)`·brace `{ git commit; }`·command-substitution `$(git commit)`·백틱 우회를 차단. **단일 소스 `rules.jsonl` trigger_pattern(apply_lookback_rule) + `pretool L31` prefilter 양쪽 동시 수정**(pretool+posttool 공유). over-match 보존(T13~T15·T23~T29) 회귀 통과. test-pretool T31~T35 PASS=35.

## [1.21.1] — 2026-06-22

### Changed
- **`plan-reviewer-ko` skill → agent 이관** (FID 20260622-plan-reviewer-agent, PR #103) — registry 불일치 해소. plan-reviewer-ko가 `skills/`에만 있어 `Agent` 도구 `subagent_type`으로 dispatch 불가("agent type not found")하던 비대칭을 `agents/plan-reviewer-ko.md` 신설로 통일(spec-reviewer·code-reviewer·implementer와 동일 패턴 — reviewer/worker=agent). skill 본문(4관점 검증·실측 의무 PR #73)을 byte 수준 보존 이관, frontmatter만 agent 규약(name/description/model:inherit)으로 교체. planning-ko dispatch 표기 `Skill:` → `Agent subagent_type:` 정정(general-purpose plan-document-reviewer 경로는 별개 보존). baseline skills 31→30·agents 3→4, README 트리·카운트 정합.

## [1.21.0] — 2026-06-22

### Added
- **거버넌스 R-1/R-2 docs-only 면제** (FID 20260622-governance-docs-exempt, PR #102) — commit/PR 전 verify 강제에 문서 전용 변경 면제 조항 신설. `is_docs_only_change()`(`git diff HEAD --name-only` = staged∪unstaged tracked 합집합)가 변경 파일이 전부 `.md`·`.txt`·`.rst`면 verify 없이 통과시킨다. 문서·CHANGELOG·오타 수정마다 `SPECOPS_GOVERNANCE_BYPASS=1`을 반복하던 마찰을 제거 → bypass 습관화로 인한 거버넌스 무력화(메타 플러그인 자기모순) 차단. pretool 면제 분기(BYPASS·§auto 동렬)·posttool audit 정합. **보안 불변식**: 코드 1개라도 혼합 → 비면제(차단 보존), 빈목록·git 실패 → 비면제(fail-safe, fail-open과 구분). Phase C 코드리뷰가 `git commit -am` 우회 표면(staged=docs면 `-a`가 unstaged 코드 커밋)을 포착해 staged-only 분기 → 합집합으로 정정, 우회 차단 실증(deny). 회귀: test-lib T-docs.a~d(면제/혼합 비면제/fail-safe/우회) + test-pretool T16~18(allow/deny/commit-am 우회 deny).

## [1.20.0] — 2026-06-22

### Added
- **`/start-all-auto` 무인 batch 모드** (FID 20260622-start-all-auto-mode, PR #100) — `/start-all`의 무인 변형 슬래시 신설. requirements.md FR 표 전체를 가역 게이트 자동통과로 일괄 구현하고 batch PR 직전 1회만 확인. `/start`↔`/start-auto` 선례를 batch에 미러링. 핵심 메커니즘: specifying batch 분기가 진입 약속어 셋째 줄 `<!-- auto: true -->` 감지 시 spec.md에 `**§batch**` + `**§auto**: true` 동시 기재 → 다운스트림 6 skill **무변경**으로 chain 전체 무인화 전파. start-all.md Phase 2 일괄 게이트에 §auto 자동통과 분기 추가(기존 대화형 보존). 회귀: test-branch-label-contract batch+auto 4-way(AC-R-6) + structure-baseline commands 16 + README 진입로 8종.
- **§auto 무인 모드 `advisor()` 보조 자문 통합** (FID 20260622-auto-advisor-assist, PR #101) — §auto 무인 3 분기(clarify BLOCKING·planning cap·verify fix_loop cap)에 `advisor()` 외부 자문을 **보조 입력**으로 additive 통합. best-guess 자기추론의 확신 편향을 외부 관점으로 완화. **결정 대행 아님** — advisor 반영 가정도 `ASSUMED` 유지 → PR 게이트 다이제스트의 사용자 최종 확인(주권 보존). graceful fallback(advisor 미연결 시 기존 best-guess 단독, 하드 의존 금지) + 비용 통제(고영향 가정만 트리거, UI세부·trivial 면제). advisor-ko §2 표에 §auto 무인 자문 행 추가. 회귀 테스트 `test-auto-advisor.sh`(9 grep 가드, governance glob 편입).

### Fixed
- **`start-auto.md` security-review chain stale 정정** (PR #100) — `commands/start-auto.md` L29 chain·§auto 동작표가 v1.19.0 SAST 보안 게이트 재배선(`receive-review → 🔒security → integration → performance → PR`)을 미반영하던 stale을 정정. security Critical/High 차단 행 추가.

## [1.19.2] — 2026-06-22

### Fixed
- **`start-all` 안티패턴 교차참조 오타** — `commands/start-all.md` 안티패턴 "per-FR PR 생성" 항목이 최종 batch PR 생성 단계를 `Step C`(performance-test)로 잘못 지칭하던 오타를 실제 PR 생성 단계인 `Step D`로 정정.

## [1.19.1] — 2026-06-22

### Fixed
- **`_replace_line_prefix` awk escape 차단** (FID 20260622-batch-branch-awk-escape-fix, PR #99) — `init-project` 부트스트랩의 `_replace_line_prefix` 가 `awk -v` 변수 주입으로 PRD 자유입력의 백슬래시 escape sequence(`\t`→탭·`\n`→개행 등)를 묵음 확장하던 결함을 `ENVIRON["VAR"]` 전환으로 차단(PR #81 append.sh 패턴 재적용). `source` 가드(`[ "${BASH_SOURCE[0]}" = "${0}" ]`) 추가로 sourced 시 `main` 미실행 → 테스트 단위 함수 호출 지원. T25.a 회귀 테스트(`경로\test\new` 원문 보존) 추가.
- **integration-test-ko batch 분기 추가** (PR #99) — `start-all` 오케스트레이션 정합을 위한 batch 레벨 통합 테스트 분기 추가.

### Changed
- **`start-project.sh` → `init-project.sh` 파일 rename** (FID 20260622-batch-branch-awk-escape-fix, PR #99) — `/start-project` → `/init-project` 슬래시 rename(v1.17.0)의 잔여로 남아있던 오케스트레이터 스크립트·통합 테스트 2종 파일명을 통일 + stale 참조 정리(README·scripts/README·api-spec placeholder·e2e-test(-ko)·brainstorming(-ko)·using-specops 부트스트랩 명칭·init-project.md 호출 경로). 회귀가드 2건 의미 갱신 — AC-R-1(`git diff 무변경` → `main` 진입 보존), AC-R-3(`/start-project` 문자열 존재 → 런타임 치환 토큰 정합). 과거 FID 슬러그는 이력 추적 위해 보존.

## [1.19.0] — 2026-06-20

### Added
- **SAST 보안 게이트 (security-review-ko)** (FID 20260620-security-review-gate, PR #95) — lifecycle 에 보안 점검 게이트 신설. chain 재배선 `verify → review → 🔒security → integration → performance → PR`(단일+batch). 코드 변경 표면 검출 시 SAST(semgrep+gitleaks) 실행, **Critical/High → chain 차단**(§auto 여도 자동통과 금지), 표면 부재·도구 미설치 시 graceful skip. `scripts/security-scan.sh` 래퍼(gitleaks `--no-git`·mktemp·jq 가드).
- **DAST 온디맨드 슬래시 (/security-scan)** (FID 20260620-security-scan-command, PR #96) — `/security-scan [URL]` 수동 점검. URL 없으면 SAST 전체, 있으면 SAST+DAST(nuclei>ZAP(docker)>nikto, graceful skip). 능동 스캔 소유 확인 게이트(무단 스캔 방지). `SPECOPS_DAST_NO_RUN` 가드로 테스트 결정성 보존.
- **보안 self-check 레이어 (설치 0)** (FID 20260620-security-selfcheck, PR #97) — security-scan.sh 에 외부 도구 없이도 항상 실행되는 bash 자체 점검 1단계. secret(전 파일: AKIA·ghp_·PRIVATE KEY·하드코딩) + 위험함수/SQL(비-bash). **언어 인지**(_is_bash 로 bash eval 정상사용 제외) → 메타 플러그인 자체 오탐 0. tests/ 제외 + fixture 런타임 조립으로 자기오탐 방지. "도구 미설치=무점검" 빈틈 해소.

## [1.18.0] — 2026-06-20

### Removed
- **deprecated alias 2건 제거** (FID 20260620-remove-deprecated-alias, PR #94) — v1.17.0 에서 도입한 `/start-project`·`/start-batch` deprecated alias stub(commands/start-project.md·start-batch.md) 삭제. 구 슬래시는 무동작화 — 정식 진입은 `/init-project`(부트스트랩)·`/start-all`(전체 일괄). 보호테스트 AC-2 를 "alias 부재 검증"으로 전환(회귀 가드 유지), baseline commands 16→14. brainstorming-ko 스킬 토큰·test-start-project.sh T22.a 의 삭제파일 의존을 init-project 로 전환(xref·run-all 회귀 차단). 오케스트레이터 `start-project.sh`·런타임 토큰 보존.

## [1.17.0] — 2026-06-20

### Changed
- **`/start-project` → `/init-project` rename** (FID 20260619-rename-init-project, PR #92) — start- 계열 중 유일하게 lifecycle chain 을 안 도는 doc-only 부트스트랩을 init- 로 분리해 의미 명확화. built-in `/init` 충돌은 `-project` 접미로 회피. `commands/init-project.md` 신설 + `commands/start-project.md` = deprecated alias stub(동작 보존, 1~2 릴리즈 후 제거). 오케스트레이터 `start-project.sh`·런타임 토큰 무변경, 사용자 노출 26파일 치환.
- **`/start-batch` → `/start-all` rename** (FID 20260619-rename-start-all, PR #93) — "batch" 전문용어를 친숙한 "all"(전체 기능 일괄)로. `commands/start-all.md` 신설(3-Phase 오케스트레이터 본문 이관) + `commands/start-batch.md` = deprecated alias stub. **내부 분기 신호어(§batch·BATCH-*·batch-id·entry:batch) 100% 보존** — 안전 sed 로 사용자 슬래시만 치환.

### Fixed
- **문서 stale 정리** (FID 20260619-doc-stamp-sync, PR #91) — ① 테스트 suite **수 하드코딩 제거**(CLAUDE.md·README "41/42 suites" → `run-all.sh` 게이트 안내, 신규 test 마다 stale 되던 자기무효화 근본 해결) ② README §거버넌스 PreToolUse 사전차단(v1.14.0) 명시 ③ reference_upstream 멀티라인 단일라인화 3파일.

## [1.16.0] — 2026-06-19

### Added
- **start-project Phase 8a FR 표 자동 합성** (FID 20260619-start-project-fr-synth, PR #85) — `_phase_8a_requirements` 가 PRD 마일스톤(PRD_F4/F5/F6 = M1/M2/M3)을 `requirements.md` §2 FR 표 시드 + §5 마일스톤 이름에 합성(전략 C). 빈값·`<TODO>` 시 placeholder 보존(회귀). `/start-project` → `/start-batch` 워크플로 단절(FR 표 수작업) 해소.
- **진입로 7종 결정 트리** (FID 20260619-entry-decision-tree, PR #87) — README §2 에 ASCII 결정 플로차트(신규 vs 기존 / start-project→foundation→batch 순서 / start vs start-auto vs maintain 판단 기준) + `/start-auto`·`/brainstorming` 진입표 행 추가.
- **분기 라벨 생산↔소비 정합 회귀 테스트** (FID 20260619-branch-label-contract, PR #88) — `test-branch-label-contract.sh`: 소비처 §batch/§auto grep 패턴 일관성 + fixture 3-way 분기(BATCH/AUTO/SINGLE) + 생산 표기 회귀. 라벨 표기 drift 자동 탐지.
- **화면 설계 3경로 분업 문서** (FID 20260619-screen-routing-doc, PR #90) — design-screen.md 에 분업표(specifying Step 5.5 인라인 / `/design-screen` 단수 / `/design-screens` 복수 + 언제 쓰나) + design-screens.md·specifying Step 5.5 cross-ref(DRY).

### Fixed
- **verifying-evidence-ko §auto 감지 죽은 코드** (PR #88) — §auto fix_loop cap 분기의 `grep -q '**§auto**'` 가 BRE empty subexpression 으로 영구 NO MATCH → `grep -q '\*\*§auto\*\*'` 정합화. §auto(완전자동) 모드 verify 실패 시 자동 복구 로직이 작동하지 않던 잠복 버그 해소.

### Changed
- **라벨 소비처 역방향 자동 스캔** (FID 20260619-label-consumer-autoscan, PR #89) — test-branch-label-contract.sh 의 하드코딩 소비처 목록 → `grep -rlF` 역방향 스캔 + 공허 방지 + 핵심 기대치 assert. 하드코딩이 누락하던 `using-git-worktrees-ko`(§auto 소비처) 자동 포함, 신규 소비처 미포착 방지.

## [1.15.1] — 2026-06-15

### Added
- plan-reviewer 실측 의무 강화 — 검증 가능한 주장(파일·라인·bash 문법·심볼)을 추측이 아닌 명령실행(`grep`/`bash -n`/`ls`)·Read로 실측한 뒤 판정. 추측 Critical/Important 판정 금지, 실측 불가 시 `[검증 불가]` Minor 강등. plan-reviewer-ko + plan-document-reviewer-prompt 양 채널 적용. IFS false-positive류 추측 오판 근본 차단(원안 다관점 분리는 분석으로 기각 — 이미 4관점 보유). (#20260615-multilens-plan-critic)

## [1.15.0] — 2026-06-15

### Added
- mutation-score equivalent-mutant 제외 — `mut::is_equivalent`(target,line,pattern 정밀매칭) + `mutation-equivalent.conf`. governance-lib stdout-contract 함수의 관찰불가 return-code 변형 18곳을 분모 제외해 측정 31%→64% 정직화 (Stryker 표준). (#20260614-mutation-equivalent-exclude)
- ui-ux-pro-max cross-marketplace hard dependency 선언 — 화면 설계 design system 자문을 보장 동반 설치로 격상 (plugin.json dependencies + marketplace.json allowCrossMarketplaceDependenciesOn). graceful 안전망 보존. (#20260615-uiux-hard-dependency)
- 기획 단계 강화 — ① clarifying-ko 경량 모드(BLOCKING=0 자동탐지 시 DESIRABLE 1회 후 통과, F-11 보존) ② spec 성공지표(measurable target) 권장 도입(spec.md §1 서브섹션 + specifying 작성 유도 + performance learning-loop 환류). (#20260615-planning-stage-enrich)

## [1.14.0] — 2026-06-14

### Added
- **llm-eval 공통 매트릭스 러너 (eval-lib)** (FID 20260614-eval-matrix-lib, PR #69) — promptfoo 방법론(assertion 어휘 + declarative 매트릭스)을 bash 로 이식. `eval-lib.sh`(소스 전용): assertion 어휘 4종(contains/regex/cost_lt/llm_rubric) + `eval::assert` 디스패처 + `eval::run_matrix` + extract_text/cost/skip_guard. `run-matrix-eval.sh` 가 declarative 사용(기본 stub 토큰0, CLAUDE_BIN 시 실 모델). 빈 needle·비숫자 cost false-green 가드(검증 도구 자기 신뢰성). 기존 3 runner 무손상(additive, git diff 0). stub 단위 15. 검증 강화 로드맵 V5(약점 W-6 중복·표현력). 기존 러너의 lib 이관·실 provider 행별 호출은 별도 FID.
- **SKIP 형식화 강화 (skip-tracker)** (FID 20260614-skip-tracking, PR #68) — `scripts/skip-tracker.sh` 가 `.specops/*/evidence.md` 의 integration/performance 게이트 SKIP 비율을 집계(읽기 전용 advisory). awk 섹션-플래그로 evidence 2 포맷(구조형·인라인) 견고 파싱 + 비게이트 헤더 pending 리셋(오연관 차단). integration-test-ko·performance-test-ko 게이트에 §유형≠trivial SKIP 근거 spec 라인 인용 의무 명문화. 실측: integration SKIP 75%(⚠️ 임계초과)·performance 61% — 형식화 가시화. stub 단위 11. 검증 강화 로드맵 V3(약점 W-3 SKIP 형식화 + W-4 추적).
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

[Unreleased]: https://github.com/kohaedong/specops-auto-ko/compare/v1.21.2...HEAD
[1.21.2]: https://github.com/kohaedong/specops-auto-ko/compare/v1.21.1...v1.21.2
[1.21.1]: https://github.com/kohaedong/specops-auto-ko/compare/v1.21.0...v1.21.1
[1.21.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.20.0...v1.21.0
[1.20.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.19.2...v1.20.0
[1.19.2]: https://github.com/kohaedong/specops-auto-ko/compare/v1.19.1...v1.19.2
[1.19.1]: https://github.com/kohaedong/specops-auto-ko/compare/v1.19.0...v1.19.1
[1.19.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.18.0...v1.19.0
[1.18.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.17.0...v1.18.0
[1.17.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.16.0...v1.17.0
[1.16.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.15.1...v1.16.0
[1.15.1]: https://github.com/kohaedong/specops-auto-ko/compare/v1.15.0...v1.15.1
[1.15.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.14.0...v1.15.0
[1.14.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.13.0...v1.14.0
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
