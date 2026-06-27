# Changelog

[Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 포맷. [SemVer](https://semver.org/lang/ko/) 준수.

## [Unreleased]

### Added
- **`/status [<FID>]` 슬래시 신설 — 재개 조회 수단** — 오펀이던 `show-fid-status.sh`(Lifecycle 단계·아티팩트 ✅/❌ 현황)를 슬래시로 연결. 인자 없으면 session-progress 최신 FID 자동. 메타skill "미완 lifecycle 재개 통보"(자동 1줄)와 짝을 이루는 능동 상세 조회. (심층감사 UX backlog)

### Changed
- **start 계열 5종 description 직교 태그** — 동일 prefix 로 슬래시 메뉴 구분이 약하던 것에 `[단일·대화형]`·`[단일·무인]`·`[전체·대화형]`·`[전체·무인]`·`[공통부·대화형]` 선두 태그 부여. (심층감사 UX M2)
- **FID 슬러그 생성 가드** — `specifying-ko` Step 0 에 슬러그 규칙 명시(소문자 kebab·최대 40자·빈값 시 `feature-<HHMM>` fallback·trailing dash 금지) + `git-branch-create.sh` 2차 방어(빈 슬러그 `YYYYMMDD-`·60자 초과 거부). LLM 생성 FID 가 기형/과길이 되던 표면 차단. (심층감사 UX M1)

## [1.26.3] — 2026-06-27

### Fixed
- **session-start `escape_for_json` 잔여 C0 제어문자 누출 — 거버넌스 침묵 무력화 차단** — `\t\n\r` 외 제어문자(BS·ESC·NUL 등)를 미escape 해 raw 제어문자가 `additionalContext` JSON 을 invalid 화 → Claude Code 가 메타skill+거버넌스 스캐폴드를 통째 drop 하던 침묵 무력화. `tr -d` 로 잔여 C0 제거. (PR #130, 심층감사 M-B — gbrain escape fix 와 동일 클래스 잔존분)
- **`git-branch-create.sh` 기존 브랜치 무경고 재사용 — 가시화** — `-b` 실패 시 기존 브랜치로 침묵 전환하던 것을 WARN 출력. 같은날 동일 기능명 재실행 시 산출물 덮어쓰기 경고. (PR #130, 심층감사 H1)
- **`security-scan.sh` self-check only 미표기 — full SAST 오인 방지** — semgrep·gitleaks 미설치 시 self-check 만 실행됐는데 `crit=0` 만 출력해 전체 SAST 통과로 오인되던 것에 `(self-check only — semgrep·gitleaks 미설치)` 병기. (PR #130, 심층감사 M6)
- **거버넌스 훅 한/영 메시지 불일치** — posttool·stop 의 영어 `stdin JSON parse failed` → 한국어 통일(pretool 과 정합). (PR #130, 심층감사 M5)

### Added
- **미완 lifecycle 재개 통보 규칙** — `using-specops-auto-ko-ko` 메타skill 에 SessionStart rehydrate 데이터를 사용자에게 통보하는 규칙 신설. 미완 FID 의 최신 단계·다음 단계를 점검해, 새 신호 시 1줄 참고·신호 없을 시 능동 재개 제안(완료 FID 는 침묵). rehydrate 데이터는 있으나 통보 규칙이 없던 가시화 공백 해소. (심층감사 H2 — 5원칙 4 주권: 새 신호 우선)

## [1.26.2] — 2026-06-27

### Fixed
- **pretool 거버넌스 R-1/R-2 관할 한정 — `.specops` 부재 repo 월권 차단 제거** — 플러그인 훅이 전역 발화하므로 specops 미사용 repo(`.specops/` 디렉토리 부재)의 `git commit`·`gh pr create` 까지 verify 누락으로 하드차단하던 결함(5원칙 4 주권 위반). `[ -d .specops ] || allow` 가드 추가 — lifecycle 진행 중(`.specops` 존재) repo 는 그대로 강제(보호 손실 0). `test-pretool` deny sandbox 3종 `.specops` 보정 + T40 신규(red-green). (PR #129, 재감사 M2)
- **`using-specops-auto-ko-ko` 유지보수 분기 ASCII 자기모순 정정** — 진입 다이어그램이 `analyzing-ko ★HARD GATE` 선행을 건너뛰고 `specifying-ko 직행`으로 표기(Phase A 잔재)해 권위 테이블과 모순. `analyzing-ko 먼저 → specifying-ko` 로 정합화. (PR #129, 재감사 M1)
- **`session-progress-append.sh` partial clobber 차단** — `awk > TMP` 후 `mv` 무조건 실행 → `&&` 결합(awk 중간실패 시 손상 TMP 가 TARGET 덮어쓰기 차단, 2곳). (PR #129)
- **`freework-resolve-fid.sh` FID 포맷 가드** — 진입부 정규식 검증 추가로 메타문자 유입 시 awk 동적정규식 오판정·오귀속 방지(타 스크립트와 일관). (PR #129)

### Changed
- **문서 정합 2건** — `using-specops-auto-ko-ko` 참조 섹션 폐기된 `engine/*·harness/*` 중첩구조 표기 → 플랫 구조 갱신, `analyzing-ko` `used_by` 에 `/promote` 누락 추가. (PR #129)

## [1.26.1] — 2026-06-26

### Changed
- **`init-project.sh` 책임 분할 (705→78줄) — deep module 리팩터링** — improve-arch shallow 판정(705줄·37함수·비율18)을 받아 공용 헬퍼 + phase 그룹을 `scripts/_internal/init-project/{lib,phases-early,phases-design,phases-artifacts}.sh` 4개 모듈로 분리. 본체는 전역 선언 + `_DIR`(BASH_SOURCE 기준) 4 source + `main()` + source 가드만 보유. 순수 이동 — 36/36 함수 byte-identical, 함수 총합 37 불변, 동작·CLI 인터페이스 무변경. (PR #127)
- **`init-project.sh` PLUGIN 경로 `$0` → `${BASH_SOURCE[0]}` 통일** — split 도입한 `_DIR` 와 동일 기준으로 통일해 source 컨텍스트에서도 PLUGIN(템플릿 복사 베이스) 정확 해석. 직접 실행 시 `$0==BASH_SOURCE[0]` 라 동작 동일. (PR #128)

### Added (내부 — 회귀 검사)
- `test-init-project-split.sh` 신설 — 임의 cwd source 시 헬퍼+phase 함수 로드 + source 가드(main 미자동실행) 검증 (AC-R-2). (PR #127)

## [1.26.0] — 2026-06-26

### Fixed
- **`gbrain-append.sh` 제어문자 escape — 인사이트 영구 유실 차단** — `json_esc`(수동 `\`·`"` 2종 치환)가 개행·탭(U+0000~U+001F)을 미처리해 `learnings.jsonl` 에 무효 JSON 줄 + recall 유실되던 결함. insight/fid 도 tags 와 동일하게 `jq -cn --arg/--argjson` 전체 객체 생성으로 전환. (PR #123, 감사 H1)
- **R-1 commit trigger over-match — `git commit-tree` 오차단 해소** — trigger `commit\b` → `commit($|[^-[:alnum:]])`. `git commit`/`-m`/`;` 차단은 유지하며 plumbing(`commit-tree`)만 허용. `rules.jsonl`+pretool prefilter 동시 변경(H-1 single-source 정합 유지). (PR #126, 감사 low L2)
- **`session-progress-append.sh` mktemp 무방어** — 2곳 `|| exit 1` 추가(침묵 실패→false success 차단). (PR #126, low L3)

### Changed
- **verify-lookback 줄순서 불변식 정합 (거버넌스 우회 방지)** — `_verify_passed_in_progress` 의 `vline<cline` 비교가 "session-progress 줄 최신=상단(prepend)" 에 보안 의존하나 `context-resets-ko` 예시가 오름차순으로 모순 → writer 가 따라 쓰면 R-1/R-2 false-allow. 문서 정합(`context-resets-ko`·`structured-artifacts-ko`)+불변식 주석 명문화. (PR #123, 감사 H2)
- **metadata drift 정정** — security-review-ko chain 서술 누락 4곳, `used_by` full-prefix→short name 16개, `implementing-ko` 진입 표기 planning→decomposing. (PR #124, 감사 M1~M3)
- **agent tools 하드강제 + file-based 정합** — reviewer 3개 frontmatter `tools:`(Read/Grep/Glob/Bash, Write/Edit 박탈)로 Generator-Evaluator 분리 구조 강제. `implementing-ko` payload 잔재→path-only 정정, Phase B→C PASS 보고서 경로 규약 신설. (PR #125, 감사 M5~M7)
- **dead-ref 정정** — `verdict-board.sh` README 등재(발견성), `log-subagent-calls.sh` dangling 참조 "미구현" 명확화. (PR #126, 감사 M4)
- R-3 하드코딩 패턴 ↔ `rules.jsonl` 동기 NOTE(dead config drift 경고), `validate-structure` 헤더주석 수치 제거(드리프트 방지). (PR #126, low L1·L4)

### Added (내부 — 회귀 검사)
- 구조 검증 회귀 검사 3종 신설: `used_by_fmt`(used_by short name 규약), `agent_tools`(reviewer read-only 하드강제), `test-pretool` T15b(commit-tree allow). (PR #124·#125·#126)

## [1.25.0] — 2026-06-26

### Fixed
- **거버넌스 R-1/R-2 verify lookback false-block 수정** — 긴 lifecycle(도구 20+ 호출) 후 commit/PR 시 verify Skill 이 transcript `negative_lookback=20` 밖으로 밀려 false-block 되던 결함 해소. `_verify_passed_in_progress(fid)` 헬퍼가 `session-progress.md` 의 `/verify PASS` 를 윈도우 밖 보조 면제 신호로 사용(R-1/R-2 공용). `SPECOPS_GOVERNANCE_BYPASS=1` inline prefix 면제도 추가(메시지 내 토큰 언급은 미면제). (PR #118, FID `20260625-governance-lookback-fix`)
- **docs-only 면제 rename 우회 차단** — `is_docs_only_change` 의 git diff 호출에 `--no-renames` 추가. 코드파일을 `.md` 로 rename(`tool.sh`→`tool.md`)해 docs-only 오인 면제되던 표면 차단(rename→delete+add 분해로 원본 노출). (PR #122, FID `20260626-r2-docs-edge`)

### Added
- **`/promote` baseline 시드 구현 완성 (G5)** — `analyzing-ko` Step 0 promote-fid 분기 선언이 Step 1 시드 로직에 미연결되던 갭 해소. `freework.md` files 1차 → `git diff`/`log` 보조 → 둘다 빈손 시 한계고백(빈 §1 금지). (PR #121, FID `20260626-diagnostic-residual`)

### Changed (내부 — 테스트·문서)
- 거버넌스 통합 wiring 회귀 픽스처 T38/T39 + sandbox `mktemp -d || exit 1` guard 5곳. (PR #119)
- `rules.jsonl` trigger ≡ pretool L31 prefilter single-source 정합성 테스트 T-H1(H-1). docs 면제 rename 회귀 T-docs.j~m. (PR #121·#122)
- WON'T-FIX 한계 문서화: verify staleness(self-report 2차방어), F-3 wrapper 우회(honest-mistake 경로 부재), G1 freecomment 멱등(truncate 자동화 본질불가). e2e-test 수동전용 CLAUDE.md 명시. (PR #120·#121)

## [1.24.0] — 2026-06-25

### Added
- **`/promote` 승격 커맨드 — 자유작업 mini-FID → lifecycle in-place 승격** — 자유작업이 만든 mini-FID(`freework.md` 마커만 있는 경량 트랙)를 lifecycle full 트리로 in-place 승격한다. `freework.md` 를 시드로 `spec.md`+AC 를 역작성하고 이미 된 변경을 보존(회귀 테스트 보강)해, 자유작업에서 시작한 일을 정식 lifecycle(specify→…→PR)로 끊김 없이 이어받는다. v1.23.0(PR #116)이 남긴 "자유작업→lifecycle 승격" 갭을 메움.
- 진입 검증을 `scripts/promote-validate.sh` 헬퍼로 추출(`OK`|`REJECT:<사유>` 7케이스 — bash 단위테스트 가능). `commands/promote.md` 가 거부 5케이스를 표준 문구로 매핑 + args 합성(`entry:maintain`+`promote-fid` 신호) → `analyzing-ko` 진입. `analyzing-ko` Step 0 promote-fid 분기가 mini-FID 를 in-place 재사용(새 FID 생성 skip, 기존 `/maintain` 동작 무손상). FID 포맷 검증(`[0-9]{8}-[a-z0-9-]+`)으로 경로 traversal(`fid=.`·`../x`) 차단. (PR #117, FID `20260625-promote-command`)

## [1.23.0] — 2026-06-25

### Added
- **자유작업 lifecycle 완전 통합 (freecomment mini-lifecycle 편입)** — 자유작업(freecomment-capture)에 FID를 부여해 `.specops/<FID>/` 트리·session-progress·learnings(`--fid`)에 양방향 추적 편입. Stop훅 `detect_fid()`로 활성 FID 후보를 pending stub `fid` 필드에 기록 → 다음 턴 메타skill이 `scripts/freework-resolve-fid.sh`(종결마커 판정)로 **귀속(ATTACH)** / **신규(NEW mini-FID)** 분기. mini-FID는 경량 `templates/freework.md` 마커(spec.md 없는 트랙)로 편입.
- **종결마커 false-positive 방어** — 종결 판정 정규식을 command 슬래시 앵커(`/lifecycle DONE`)+`PR #N 생성` 인접으로 협소화해 진행중 줄("PR #999 참조")의 오귀속 차단. `test-resolve-fid.sh` 7케이스 회귀 고정. (PR #116, FID `20260625-freecomment-lifecycle-integ`)

## [1.22.1] — 2026-06-25

### Fixed
- **문서 drift 정정 (commands 16→17 + `/log` 누락)** — v1.22.0 `/log` 추가 시 사람 읽는 문서가 갱신 누락. README(슬래시 진입로 `(16건)`→`(17건)` + `log.md` 항목 추가)·scripts/README(`commands=16`→`17`) 정합화. `file_counts` 게이트는 `.structure-baseline` JSON 단일소스 기준이라 검증엔 무영향이었음(사람 문서만 drift). `specifying-ko` frontmatter `reference_upstream` bullet 글자그대로 중복 첫 줄에 부연 추가(clarifying-ko lineage 표기 규약 정합). validate-structure 13/13 OK 실측.

## [1.22.0] — 2026-06-25

### Added
- **자유 코멘트 작업 자동 캡처** (FID 20260625-freecomment-capture, PR #113) — lifecycle 밖 자연어 코멘트로 처리한 작업(오류수정·질문·설계변경)을 specops 기억 산출물에 자동 기록. Stop 훅(`hooks/freecomment-capture.sh`)이 메인 transcript 직접 Edit/Write ∩ `git diff HEAD` 교차로 자유작업 감지(서브에이전트 `Task` 경유 lifecycle 작업과 자동 구분) → `.specops/pending-capture.jsonl` stub(3유형 fix/question/design-change 키워드 분류). SessionStart 훅이 다음 세션에 `<freecomment-pending>` 안내 주입 → 메인 LLM 이 요약·`type` 재분류 → `.specops/freelog.md`(전용 영속 기록, session-progress 와 격리해 rehydrate 회귀 차단) + `learnings.jsonl` 기록 → pending 비움(멱등) → 1줄 보고. `/log` 수동 보강 커맨드(`commands/log.md`). 변경 0 세션 skip(노이즈 차단)·fail-open(세션 종료 무차단). 메타 skill 처리 규약 7단계 문서화. 회귀: `scripts/tests/freecomment/test-*.sh` 5스위트 10케이스.
- **requirements 자동 연결 강화** (FID 20260625-requirements-autolink, PR #114) — 자유작업 `design-change` 유형을 `requirements.md` FR 표에 **반자동(승인형)** 연결. `scripts/requirements-append-fr.sh` 신설(FR 채번 수치정렬 max+1·`|`→`\|` escape·개행 정규화·멱등(중복 desc skip)·atomic mv·FR 표 미발견 가드). 메타 skill 처리 규약: design-change 시 LLM 이 FR 초안 생성 → 사용자 `[y/n]` 승인 → 헬퍼 호출. **AC-6(자동변경 금지) 유지** — 오탐(단순수정→FR 표 오염)은 LLM 1차 판단 + 승인 게이트로 이중 차단. `requirements.md` 는 이전까지 읽기 전용(자동 쓰기 0)이었음. 재사용: `_replace_line_prefix`(init-project.sh) ENVIRON escape 패턴. 회귀: `test-requirements-append.sh` 6케이스(채번·NFR무손상·멱등·escape·FR10→11 수치정렬·부재).

### Fixed
- **freecomment test-capture CI(ubuntu) git ident 실패** (PR #113) — CI ubuntu runner 의 git user ident 미설정으로 테스트 격리 repo `git commit --allow-empty` 가 "Author identity unknown" 실패 → HEAD 없음 → hook `git diff HEAD` 빈 → 자유작업 미감지. macOS 로컬은 ident fallback 으로 가려졌던 환경 의존 버그. 격리 repo commit 3곳에 `-c user.email/-c user.name` 명시로 ident 자급.
- **Stop 훅 회귀 가드 + run-all 글롭** (PR #113) — `test-notify.sh` Stop 훅 개수 단언 `length==2→3`(freecomment-capture 추가 반영, 기존 2종 무손상 검증 유지), `run-all.sh` 글롭에 `freecomment/test-*.sh` 추가(릴리즈 게이트 연결).

## [1.21.3] — 2026-06-24

### Added
- **`release.sh` 원격 push + GitHub Release 자동 발행** (FID 20260623-release-gh-publish) — 기존 로컬 commit+tag 후 사용자가 수동 `git push`하던 마지막 단계를 자동화. release.sh가 commit·tag 완료 후 `origin` 존재 시 `git push` + `git push origin v<VER>` → `gh release create v<VER> --verify-tag --latest` 까지 수행. release 노트는 CHANGELOG `[<VER>]` 섹션 본문을 `awk` 추출 + compare 링크 append(`--notes-file`), 본문 부재 시 `--generate-notes` fallback. `--latest` 명시로 backfill 시 관측된 Latest 배지 오염 차단. **fail-safe**: `origin` 부재(테스트 임시 repo) → push/release skip(기존 테스트 무손상), `gh` 미설치 → release만 graceful skip(push는 보존)·수동 명령 안내. dry-run 안내에 7·8단계 추가. 회귀: test-release T14(bare origin + `gh` stub로 push·태그·`--verify-tag/--latest/--notes-file` 호출 검증, 실 GitHub 호출 0) + T15(origin 부재 skip + 로컬 태그 보존), PASS 18→24.

### Changed
- **문서 현행화** — 사용자 문서를 실제 구조·수치와 정합화. README(commands 16건 `statusline-install`·hooks 4종 PreToolUse/pretool·templates 30건 `critic-prompt-*`)·scripts/README(검증항목 6→12·suites 42→68·v1.21.2·경로 `_internal/`)·CONTRIBUTING(테스트 목표 12/12·PASS=72·PASS=24·run-all·ui-ux 선행등록)·CHANGELOG/docs(Superpowers 외부 출처 서술 제거). validate-structure 12/12 OK 실측 기반.

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
- **plan 리뷰 A/B 측정 하니스** (FID 20260613-plan-review-ab, PR #65) — `run-plan-ab.sh` 가 결함 심은 plan fixture 에 inline self-review(A) vs 2중 dispatch(B) 를 적용해 검출률·토큰 비교. `count_detected` 이중 가드 (plan 본문 등장 locator 무효화 — claude 입력 인용 over-count 차단), 결함 fixture 2종 (커버리지·플레이스홀더·타입), stub 단위 9 (토큰 0). 격차 분석 P2-1(subagent-리뷰 폐지 측정)의 코드베이스 재현. 실 baseline 은 모델 가용 시 수동 측정 (한계 고백).

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

[Unreleased]: https://github.com/kohaedong/specops-auto-ko/compare/v1.26.3...HEAD
[1.26.3]: https://github.com/kohaedong/specops-auto-ko/compare/v1.26.2...v1.26.3
[1.26.2]: https://github.com/kohaedong/specops-auto-ko/compare/v1.26.1...v1.26.2
[1.26.1]: https://github.com/kohaedong/specops-auto-ko/compare/v1.26.0...v1.26.1
[1.26.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.25.0...v1.26.0
[1.25.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.24.0...v1.25.0
[1.24.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.23.0...v1.24.0
[1.23.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.22.1...v1.23.0
[1.22.1]: https://github.com/kohaedong/specops-auto-ko/compare/v1.22.0...v1.22.1
[1.22.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.21.3...v1.22.0
[1.21.3]: https://github.com/kohaedong/specops-auto-ko/compare/v1.21.2...v1.21.3
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
