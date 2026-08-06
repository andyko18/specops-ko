# Changelog

[Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 포맷. [SemVer](https://semver.org/lang/ko/) 준수.

## [Unreleased]

### Added
- **`/start-lite` · `/maintain-lite`** — clarify·plan ceremony만 생략하는 경량 Lifecycle 진입. 화면(Step 5.5)/IF(5.6)·Phase B/C·verify·AC-R-1은 풀과 동일. `/maintain-lite`는 analyzing-mini. strict 신호 시 `/start`·`/maintain` 승격. NL로 lite 추론 금지(슬래시 전용).

### Changed
- **start-all Phase 3 복구 (per-FR)** — batch-end-loaded(전 FR A 후 B/C 1회)를 되돌림. Phase 3는 다시 FR마다 `implementing`(FID end-loaded B/C) → verify → request/receive(또는 end-loaded skip). Phase 2.5·plan-reviewer defer는 유지.
- **start-all Phase 1 plan-reviewer batch defer** — FR마다 ★플랜 검사관을 빼고(`DEFERRED`), 전 `PLAN_DONE` 후 Phase 2에서 `plan-reviewer-ko` **1회** + `batch-plan-digest.sh` 짧은 표 → [y/n]. `/start`·foundation은 per-FID 리뷰 유지. per-FR 외부 critic도 batch로 이전/SKIP.
- **implementing end-loaded 리뷰 (기본, `/start`·`/start-all` FR)** — 태스크별 A→B→C를 **A만 wave → FID 말미 B 1회 + C 1회**로 전환(`review_mode: end-loaded`). 레거시 `per-task`. requesting은 B/C 산출 시 `review-skip.md` skip.

- **2단 git hook 게이트 (`.githooks/` + `install-git-hooks.sh`)** — `pre-commit` = validate-structure + check-propagation(~5s) · `pre-push` = `run-all.sh` 전체(~195s). 계기: `44cd095` revert 가 `run-all` 없이 나가 `main` 이 하루 red — **Claude Code PreToolUse 훅(R-1)은 Cursor 등 다른 도구의 커밋에 발화하지 않아** 도구 무관 게이트는 git hook 층뿐이다. 커밋마다 195s 를 걸면 `--no-verify` 관성(= 이 repo 가 BYPASS 로 겪은 실패 모드)이 생기므로 비용을 2단으로 분리했다. 게이트 스크립트 부재 repo 는 자동 면제(월권 금지), 탈출구는 `--no-verify`(5원칙 4). `core.hooksPath` 는 버전관리 대상이 아니라 clone 마다 1회 설치가 필요하다. 테스트 10건 — GH-8 은 **44cd095 파손 리비전을 실제로 복원해 pre-commit 이 차단함을 실증**한다.

### Fixed
- **`/init-project` PRD 6필드 무라벨 numbered list 오파싱 — 프로젝트 문서 전체 오염 (정밀분석 20260806)** — `_parse_numbered` 가 `[0-9]+\.[^:]*:` 를 **한 덩어리로** 요구해, 라벨 없는 `1. 사내 일정 관리` 형식이면 sub 가 통째로 실패하고 값에 `1. ` 가 그대로 남았다. 이 값은 `PRD.md §1` → `CLAUDE.md` → `README.md` → `requirements.md` FR 시드행(`| FR-1 | 4. 로그인 |`)까지 전파된다(실측 4파일). `_phase_4_count_filled` 는 "비어있지 않음"만 세므로 오파싱은 단답 fallback 도 깨우지 못하는 **silent garbage** 경로였다. 무라벨형은 Phase 0 이 stdin 으로 파이프하는 자연 형식이고 **repo 자체 테스트도 이 형식을 먹이고 있었다**(T1.a 등) — 기존 테스트가 파일 존재·개수만 검증해 값 오염을 전혀 못 봤다. 별개로, 라벨 길이가 무제한(`[^:]*:`)이라 값 중간에 콜론이 늦게 나오는 긴 문장은 콜론 앞 전체를 라벨로 오인해 잘라냈다(실측 60자 손실). ① 번호 접두는 **무조건** 제거 ② 라벨 제거는 콜론이 앞쪽(≤40바이트)일 때만 — 으로 분리했다(interval 정규식 `{1,40}` 은 구형 awk 비호환이라 `index()` 판정). 테스트: 단위 6건(T-pn.a~f) + E2E **값** 단언 4건(T24.a~d — 존재·개수가 아니라 파싱 결과를 본다), mutation 으로 구 구현 복원 시 6건 재현 확인.
- **batch 재개 키를 날짜 → `ACTIVE` 마커로 (M2 — 커맨드 전수 분석 20260806)** — `BATCH_ID = batch-<YYYYMMDD>` 는 **날짜가 곧 재개 키**여서, 같은 날 두 번째 `/start-all` 을 다른 `requirements.md` 로 돌리면 이전 batch 의 `queue.md` 를 재사용해 서로 다른 FR 집합이 한 큐에 뭉갰다(`ACTIVE` 마커는 PR 게이트 오발화만 막지 queue 혼입은 못 막는다). Phase 0 이 `.specops/batch-*/ACTIVE`(훅 `_batch_pr_gate` 와 동일 관용구)로 진행 중 batch 를 찾아 **1개면 재개 · 0개면 신규 `batch-<YYYYMMDD>-<HHMM>` 생성 · 2개 이상이면 사용자 선택 게이트**(자동 선택 금지 — 주권)로 분기한다. 같은 분 재실행은 `-2`,`-3` 접미로 회피. **하위호환**: 구 포맷 `batch-<YYYYMMDD>` 도 `ACTIVE` 가 있으면 그대로 재개되고 디렉토리명을 바꾸지 않는다 — 진행 중 batch 의 재개 경로·`feat/<BATCH_ID>` 브랜치가 갈라지지 않는다. 훅·`batch-state.sh` 는 `batch-*` 글롭과 디렉토리 인자만 쓰므로 id 포맷 비의존(게이트 동작 무변경). 테스트 6건(T12.a~f), mutation 비-vacuous, `propagation-matrix` `batch-id-active-resume` edge 락.
- **`§lite` × strict 승격 가드에 기계 teeth (H1 — 커맨드 전수 분석 20260806)** — `/start-lite`·`/maintain-lite` 의 "strict 신호면 `/start`로 승격" 은 `specifying-ko:122·131` 의 **산문(모델 키워드 판단)** 뿐이었다. lite 는 clarify·plan 을 **이미 건너뛴 뒤** decompose 에 도달하므로, 뒤늦게 strict 가 드러나도 되돌릴 게이트가 없었다(잃어버린 clarify·plan 은 스스로 돌아오지 않는다). `batch-state` 의 lite-skip 재검은 `/start-all` 경로만 지켜 단독 `/start-lite` 는 무방비였다. `risk-profile.sh compute` 가 `spec.md` 의 `**§lite**: true` 를 **스스로 감지**해(플래그 설계면 플래그 생략으로 우회되므로 self-detect) `effective=strict` 이면 `LITE-STRICT-GUARD` rc=3 을 낸다 — `decomposing-ko` Step 10c 가 이를 받아 implementing 진행을 막고 clarifying→planning 승격을 요구한다. `plan.md` 가 생기면 **자동 해제**(영구 차단 방지). 범위는 `§lite` 한정 — `§유형: trivial` 단독은 제외했다(`public_api` 가 "엔드포인트" 한 단어에 걸려 최빈 경로가 false-block 생성기가 된다). 주권 탈출구는 `SPECOPS_LITE_STRICT_OVERRIDE=1` + **사유 병기 필수**(`SPECOPS_GOVERNANCE_BYPASS` 규약 동형) — 모델이 쓸 수 있는 마커 파일은 자기발급 면제표가 되므로 채택하지 않았다. 강도는 `emit-context.sh` fail-fast 와 동급(**기계 탐지 + 체인 레벨 강제**이지 하드 차단 아님). 테스트 8건(T14~T20), mutation 비-vacuous, `propagation-matrix` `lite-strict-guard` edge 4자 락.
- **R-5 자기발급 면제표 봉합 — advisor 협의에 실호출 증거 요구** — 종전 R-5 는 `## N. Advisor 협의 기록` 에 data row 가 **있기만 하면** PASS 했다. 그 표는 모델이 스스로 쓰는 것이라, "advisor 와 협의했다" 자기보고를 검증하는 층이 0 이었다(R-1/R-2 가 verify 자기보고에 대해 이미 봉합한 것과 동일 클래스의 구멍). `governance-lib.sh:_advisor_exec_evidence` 신설 — 협의를 **주장**하면(data row 1+, `해당 없음` 아님) transcript 의 실호출 증거를 요구한다. advisor 는 서버사이드 도구라 일반 `tool_use`/`tool_result` 가 아니라 **`server_tool_use`(name=advisor) ↔ `advisor_tool_result`** 로 기록되므로(실측 확인 — 일반 tool_use 만 보는 검사는 영원히 0건) 이 형태를 `tool_use_id` 로 직접 join 하고, `is_error` 결과는 불인정한다. advisor 미연결 시의 **공식 fallback 인 `critic-ask.sh` 실행도 인정** — 불인정하면 정직한 미연결 세션이 위반으로 찍힌다. `해당 없음` 정직 선언(원칙 5 한계 고백)은 증거 불요로 통과. 판정 불가(transcript 부재·jq 실패·content 블록 0건)는 fail-open. 강도는 기존과 동일한 `Stop` 훅 warn — advisor 는 비용·latency 트레이드오프가 있어 hard block 대상이 아니다. 테스트 6건(T10.i~T10.n) 추가 + 의미가 바뀐 T10.a 갱신(구 픽스처는 실호출 없는 data row 였다), mutation 으로 비-vacuous 확인, 실제 세션 transcript 대조로 블록 형태 검증.
- **RELEASE_READY `crit_high` 오탐 — end-loaded 기본 흐름 PR 하드 차단 봉합** — `release-ready.sh`가 `reviews/`를 `grep -RqlE 'NEEDS_FIX|## 🔴 Critical'`로 스캔했는데, `code-reviewer-ko` 출력 템플릿은 **발견 0건이어도** `## 🔴 Critical` 헤딩과 `## 종합 판정` 3종 메뉴(READY_TO_MERGE·NEEDS_FIX·NEEDS_DISCUSSION)를 항상 찍는다 → 무조건 매치. 구제 조건은 session-progress 의 `/receive-review`·`수용` 토큰뿐인데 08-04에 기본값이 된 end-loaded 는 requesting 을 `review-skip.md`로 건너뛰어 그 줄이 생기지 않는다. 결과: 전 축 PASS 인데 `crit_high=UNRESOLVED_REVIEW` → strict FID·ACTIVE batch 브랜치에서 `gh pr create` hard deny(BYPASS 강요 → 관성 재발 경로). 모든 진입점이 `decomposing-ko:10c`를 지나 `risk-profile.json`을 갖고, spec 에 "엔드포인트" 한 단어만 있어도 `effective=strict`라 예외가 아닌 **일반 케이스**였다. 판정기를 (a) 🔴 절의 **실제 항목**(플레이스홀더 `<file>:<line>`·`없음` 제외) (b) `READY_TO_MERGE` 없이 `NEEDS_FIX`만 남은 **선택된 판정** 두 신호로 교체하고, 스캔 대상을 최종 판정물 `*-report.md`로 한정(해소된 과거 라운드가 남는 `-feedback.md` 제외). teeth 보존 — 실제 Critical 항목이 있으면 여전히 수용 흔적을 요구한다. 회귀 테스트 8건(RR-14·14b·15·16·17·18·19·20, RED 3 → GREEN 22) — 그중 **RR-20 은 훅 레벨 증상 실증**(strict risk-profile + end-loaded 산출물 → `gh pr create` allow, 구 grep 복원 mutation 시 보고된 deny 그대로 재현). `propagation-matrix` `review-verdict-contract` edge 로 템플릿↔판정기 드리프트 락.
- **계약 전파 edge 보강 — 토큰이 아니라 소비 문자열까지 락** — `batch-review-skip` edge 가 토큰만 요구해, 44cd095 revert 가 `start-all.md`에서 `risk-profile.json` 경로만 떨어뜨렸을 때 전파 스캔은 통과하고 T1.e 만 red 로 남았다. 해당 id 에 `commands/start-all.md`·`scripts/batch-state.sh` ~ `risk-profile.json` edge 를 추가(파손 리비전 대조로 FAIL 재현 확인)하고, 신규 `end-loaded-skip` id 로 end-loaded 리뷰 계약 4자(implementing `review_mode` → requesting Step 0 사유 → start-all Phase 3 축소 조건 → batch-state 재검) 전파를 락했다. 테스트 P7·P8 추가(mutation 비-vacuous), 35 edges. README 에 "소비처가 읽는 경로·필드명을 edge 에 포함" 규약 명문화.
- **`start-all` lite review-skip 조건의 `risk-profile.json` 경로 복원** — batch-end-loaded revert 가 명시 경로까지 함께 걷어내 `batch-state.sh`(그 파일을 계속 읽음)와 문서가 어긋났고 `test-screen-generation-gate` T1.e 가 FAIL(run-all 112 중 1)로 하루 방치됐다.

## [1.60.0] — 2026-08-04

### Added
- **검증 상태 머신 + 비용·수율 계측 (P0)** — `verification-state.sh`가 `NOT_RUN|PASS|PARTIAL|FAIL|WAIVED`(+조회 시 `STALE`)를 FID별 SoT로 기록한다. `record-metric.sh`가 `.specops/<FID>/metrics.jsonl`에 토큰·wall·retry·fallback·판정 식별자만 append(원문 거부). `run-verification`·BYPASS·risk-profile이 자동 계측한다.
- **태스크 receipt R-1 게이트 (P0)** — implement 중간 커밋은 FID 전체 verify 대신 `record-task-receipt.sh`/`check-task-receipt.sh`(staged⊆outputs·tree 신선·test_command hash·커밋 메시지 T#)로 연다. R-2(PR)는 receipt로 열리지 않는다.
- **RELEASE_READY 합성 판정 (P0→Wave B)** — verify·review-audit·security/integration/performance·reconcile·Critical/High를 AND 합성. Wave B에서 **strict FID 또는 ACTIVE batch 브랜치 PR**은 NOT_READY 시 hard deny, 그 외 warn-only. UNKNOWN(rc=2) fail-open.
- **위험 프로파일 limited-live (P1→Wave B)** — `risk-profile.sh`가 lite/standard/strict를 기록(`mode=live`). lite만 `reductions_allowed: ["batch-review-skip"]`(requesting/receiving skip). Phase B·TDD·verify·receipt 축소는 금지. `batch-state`가 allowlist·단일 태스크·사유를 재검.
- **Phase 2.5 화면→IF→design-reviewer (#243 계열)** — `/start-all` batch가 화면·인터페이스를 통합한 뒤 `design-reviewer-ko`(evaluator)로 무거운 설계 리뷰. Critical≥1은 §auto여도 정지, Important-only만 §auto 자동통과.
- **Wave C 관측·DX** — (1) R-1 deny 시 `git add&&git commit` compound 분리 안내 (2) `propagation-matrix.jsonl`+`check-propagation.sh` 계약 드리프트 스캔(run-all) (3) `phase=evaluator-degradation` 메트릭 배선 + Phase 2.5 수동 dogfood 체크리스트.

### Changed
- **init-project·start-all 프로세스 축소 + 결정 원장** — 온보딩/batch 중복 질문·단계를 줄이고 `.specops/memory/project-context.md`·`decisions.md`로 확정 스택을 전달한다.
- **review-skip lite 메타 검증** — skip 경로에 `risk-profile.json`·`batch-review-skip` allowlist·단일 태스크·비어 있지 않은 사유를 요구(남용 차단).

### Fixed
- **Wave A 거짓 안심 제거** — `check-review-audit`가 산문 tid만으로 PASS하던 구멍 봉쇄(경로·`B:tid`/`C:tid`·`## task-<tid>` 구조화만 인정). reconcile review=70은 `review-request.md`/`review-skip.md`만 인정(bare `reviews/` 제거). R-1 implement 창에서 FID-wide exec-evidence fallthrough 제거 → receipt 필수.
- **enrich 스캔 LC_ALL=C 가-힣 collation false-FAIL** — locale 고정 환경에서 한글 클래스 오류로 placeholder 스캔이 깨지던 문제 수정.
- **validate-structure evaluator 마킹 기대 6→7** — `design-reviewer-ko` 추가로 T15.a 기대값 정합.

### Removed
- **죽은 파일·디렉토리 30건 제거 (Tier 1)** — `examples/` 24 파일(실행 러너 0곳·바이트 동일 복제·상시 FAIL 방치) · `scripts/tests/v0.4-pre/`·`v0.4a/` · `screens/main.{md,html}`. 문서 dead-ref 정리. FID 20260728-dead-file-cleanup.

## [1.59.0] — 2026-07-24

### Fixed
- **false-block 9호 — run-verification whitelist subdir 러너 인식 (#238)** — `run-verification.sh` whitelist 가 monorepo 테스트 호출 `cd <subdir> && npx|pnpm|yarn exec <runner>` 형태를 미인식(→`PARTIAL`→실행-근거 게이트 불인정→커밋 deny)해, 외부 완주 1건이 `SPECOPS_GOVERNANCE_BYPASS` 를 9회(67% 동일 사유) 우회하던 실측 단일 병목을 봉합(감사 plugin-evaluation-20260723 처방 #1). `_WHITELIST_PAT` 에 선택적 `cd <상대subdir> &&` 접두 + `npx <bin>`·`pnpm|yarn exec <bin>` 러너형 편입(단일라인 단일따옴표 유지), exec 루프에 `( cd "$dir" && "${rest[@]}" )` 서브셸 직접-exec 분기(no-shell·부모 cwd 비오염·`ec=$?` 불변식 보존). 절대경로(`npx /abs`·`cd /abs`)·트래버설(`../`)·임의 `&&` 체인·옵션주입(`npx --yes`)·bare `pnpm vitest` 는 차단(bin 선두 문자 `[A-Za-z0-9_@]` 제한). 부가: subdir 명령이 PASS 되어 evidence `RUN-VERIFICATION-RESULT` PARTIAL→PASS → #236 implement-면제 경로 도달가능.
- **세션-env BYPASS 감사추적 + fail-open rc=2 문서화 (#239)** — `pretool-governance.sh` 의 세션-env `SPECOPS_GOVERNANCE_BYPASS` 우회가 friction-log **무기록**으로 allow 되던 감사 공백(상한 3호)을 봉합: `log_friction "BYPASS-ENV" 1 <snippet> 0` 기록 후 allow — **막지 않고 기록만**(공식 탈출구 유지, 5원칙 4 주권), `.specops` 관할 가드로 비-specops repo 월권 방지, `|| true` 로 allow 불변식 보존(`principle`·`offset` 은 `--argjson` 유효 JSON 필수 — 숫자). `CLAUDE.md` fail-open 열거에 `tool_use 이벤트 0건(rc=2)` 케이스 추가(`governance-lib.sh:142 return 2` 실코드 정합, 상한 2호). 테스트 자기오염(기존 T3 가 격리 없이 세션-env BYPASS 실행 → run-all 시 실제 감사로그 오염) 격리 + suite-wide 무오염 회귀 락(`T-no-selfcontam`, flip-test 로 비-vacuous 실증).

## [1.58.0] — 2026-07-23

### Changed
- **plan-reviewer 단일화 — general-purpose Plan Document Reviewer 흡수 (#237)** — planning-ko 가 같은 plan.md 를 두 서브에이전트(general-purpose Plan Document Reviewer + plan-reviewer-ko)로 이중 검증하던 구조를 전용 Evaluator 로 단일화. 두 리뷰어는 순수 중복이 아니라 spec준수(Completeness·Spec Alignment) ↔ eng품질(TDD·타입·경계) 상보 관계였으므로, plan-reviewer-ko 를 4관점 → **6관점**(스펙 커버리지·스펙 정합 흡수)으로 확장하고 spec.md 도 읽도록 검증절차를 수정한 뒤 general dispatch 를 제거했다 — plan 단계 dispatch 1회↓ + **커버리지 무손실**. `plan-document-reviewer-prompt.md` 는 `run-plan-ab.sh` LLM A/B eval 픽스처로 유지(lifecycle 경로만 분리).

### Removed
- **규범문서 미구현 스캐폴딩 2건 제거 (#237)** — `file-based-communication-ko` 의 페이로드 로깅 절(`log-subagent-calls.sh` — 미구현 dangling)과 `structured-artifacts-ko` 의 session-start handoff 요약 주입 "구현 예정" 줄을 제거. 규범 문서에서 미완 로드맵 항목을 정리(session-start.sh 미구현 실측 확인 후).

## [1.57.0] — 2026-07-23

### Fixed
- **R-1 거버넌스가 implement 단계 커밋을 구조적으로 차단하던 문제 (FID 20260723-lifecycle-robustness)** — implement 단계의 태스크별 TDD 커밋은 R-1 면제 조건 ②(`/verify PASS` 앵커 · evidence stamp)를 **구조적으로 충족할 수 없다** — `/verify` 는 후속 단계라 커밋 시점엔 앵커가 존재하지 않는다. 그래서 정직한 흐름도 매 커밋 `SPECOPS_GOVERNANCE_BYPASS` 로 몰렸다(20260722 screen-design FID 실측 5+회 — BYPASS 관성의 시작점). `hooks/governance-lib.sh` `apply_lookback_rule` 에 R-1 한정 면제 경로 신설: transcript 에 러너 `VERIFY: PASS` **실행증거**(`_exec_rc=0`, 엄격 — fail-open `rc=2` 불인정)가 있고 FID 가 implement 창(`tasks.md` 존재 ∧ `evidence.md` 부재)에 있으면 커밋을 면제한다.
  - **자기보고 아닌 실행증거 기반** — 위조 불가. `_verify_exec_evidence` 의 `lasthit > lastedit`(마지막 편집 이후 실행 요구)가 "run-all 통과 후 임의 코드 편집→커밋" 우회를 봉쇄한다(편집 시 `exec_rc=1` 로 무효화).
  - **evidence.md 생기는 즉시 경로 닫힘** — post-verify 는 기존 앵커로 판정. R-2(PR)는 verify 이후라 미대상.
  - 회귀 테스트 3건: T6.B1(면제) · T6.B2(실행증거 없으면 deny — 위조방지) · T6.B3(evidence.md 존재 시 닫힘).
- **emit-context 소프트 실패가 exit 0 으로 통과하던 문제 (FID 20260723-lifecycle-robustness)** — `scripts/dag/emit-context.sh` 의 `ac_summary()` 가 AC 요약 텍스트 추출에 실패해도 WARN 만 내고 빈 요약으로 `EMIT: N files` exit 0 통과했다(20260722 실측: `## AC-N` h2 헤더가 추출 패턴 밖 → 빈 요약 17건, 무인 모드면 빈 컨텍스트로 dispatch). ① `ac_summary` 패턴을 `###` → `#{2,3}` 로 넓혀 `##`(h2) 헤더도 추출(#209 bullet 겸용 완화 철학 연장). ② 그래도 추출 실패(AC-id 토큰은 존재하나 헤더/불릿 전무 = 진짜 drift)면 write **전** 원자적 `exit 1`(부분 잔류 0) — 빈 AC dispatch 차단. 회귀 테스트 2건(h2 구제 · fail-closed).

## [1.56.0] — 2026-07-23

### Added
- **화면설계 껍데기 방지 — 마커 계약 + 판정 헬퍼 (#235, FID 20260722-screen-design-quality)** — `/start-all` batch 경로에서 화면설계서가 템플릿 껍데기로 남던 문제를 기계적 판정으로 종결. `#203`·`#204` 가 산문 지시로 대응했다 2회 재발한 실패 클래스를 마커 1줄로 이진 판정한다.
  - **마커 단일 출처** — `templates/screen.md`·`screen.html` 에 공유 마커 주석 1줄, `scripts/_internal/design-screen.sh` 에 `SCREEN_PLACEHOLDER_MARKER` 상수 + `screen_is_placeholder()` 함수 + `--check` CLI 진입점. 판정은 템플릿 **본문 리터럴이 아니라 마커에만** 의존해 본문 drift 에 면역이다(뮤테이션 쌍 테스트로 리터럴 grep 회귀 상시 차단).
  - **템플릿 상세화** — `templates/screen.md` 필수 코어 5→8섹션(필드 정의표·데이터 소스·에러 메시지 신설) + 조건부 4섹션(RBAC·반응형·접근성·진입/이탈, 미해당 시 섹션 자체 생략 — `—` 채우기 금지로 batch 토큰 선형 유지). 데이터 소스는 `api-spec.md`·`data-model.md`(Step 5.6) 참조로 연계.
  - 신규 bash 회귀 4스위트 47단언 + `run-all` baseline 99→103.

### Changed
- **화면 생성 3경로 껍데기 판정 대칭화 (#235)** — `commands/start-all.md` Phase 2.5 · `skills/specifying-ko/SKILL.md` Step 5.5 의 재사용 판정을 "경로 존재" → "마커 부재"로 교정하고, `.md` 필수 8섹션 완성 요건을 `design-screen(s).md` 와 대칭화(lifecycle 안/밖 비대칭 해소). `skills/verifying-evidence-ko/SKILL.md` 역방향 net 에 화면 껍데기 backstop(비차단 경고 + 차기 버전 승급 조건) 추가.

### Fixed
- **Phase 2.5 부재 파일 오판 + 혼합 상태 데이터 손실 (#235, 외부 critic 3중 수렴)** — `start-all.md` 재사용 판정이 무조건 적용돼, 실파일 없는 화면이 `--check` exit 1(FILLED)로 "재사용, 재생성 안 함"으로 오판돼 **영영 생성 안 되던** 침묵 버그. `specifying-ko` 와 동일한 "파일이 없으면 생성" 존재 가드를 미러링. 아울러 껍데기 짝 덮어쓰기 시 `PLACEHOLDER:` 로 지목된 파일만 선별 덮어쓰고 이미 채워진 짝은 보존(혼합 상태 손실 방지).

## [1.55.0] — 2026-07-22

### Changed
- **플러그인명 `specops-auto-ko` → `specops-ko` (BREAKING)** — 플러그인 식별자·skill 네임스페이스·로컬 마켓플레이스명이 모두 바뀐다. Skill 호출은 `specops-auto-ko:<name>` → `specops-ko:<name>`, 마켓플레이스 키는 `specops-auto-ko-local` → `specops-ko-local`, 활성화 키는 `specops-ko@specops-ko-local`. 사용자는 `~/.claude/settings.json` 의 `enabledPlugins`·`extraKnownMarketplaces` 키를 갱신하고 Claude Code 를 재시작해야 한다.
  - 메타 skill 디렉토리 `skills/using-specops-auto-ko-ko/` → `skills/using-specops-ko/` (기계적 치환 시 발생하는 `-ko` 중복 제거).
  - 거버넌스 규칙(`hooks/rules.jsonl`)의 `negative_skill_pattern`·`trigger_skill_pattern` 도 새 네임스페이스로 갱신 — 구 네임스페이스로 호출된 skill 은 verify 크레딧을 받지 못한다.
  - `validate-structure.sh` `XREF_ALLOW` 에 구 플러그인명(`specops-auto-ko`)을 케이스 스터디 파일명 참조용으로 유지.
  - GitHub 저장소도 `andyko18/specops-ko` 로 rename (구 URL 은 GitHub 리다이렉트).

## [1.54.0] — 2026-07-21

### Fixed
- **리뷰 감사 역방향 대조 — 리포트를 아예 안 남긴 경우 봉합 (dogfood 20260721 HIGH-4)** — 기존 `check-review-audit.sh` 는 `reviews/ → dispatch-log` **한 방향**만 봤다. 그래서 리뷰 판정을 **파일로 아예 안 남기면** `reviews/ 부재 = SKIP` 으로 통째로 비껴갔다 — Generator↔Evaluator 분리가 조용히 0 이 되는데 `VERIFY: PASS` 는 그대로 났다. 실물(전수 스캔 적발): `.specops/20260713-llm-eval-nrun/dispatch-log.md` 가 `reviews/all-B-report.md`·`all-C-report.md` 를 기록해 놓고 **그 파일이 없다** — 판정을 대화로만 흘린 것이다. dispatch-log 가 참조하는 `reviews/*.md` 의 실재를 대조하는 역방향 검사를 추가했다.
  - **판별자 = dispatch-log 존재** (false-block 회피). "tasks.md 있는데 reviews/ 없으면 FAIL" 은 **기각**했다 — 실측상 그 조건에 걸리는 기존 FID 가 16건 중 5건(31%)이고, 그중 4건은 e2e fixture·플러그인 self-maintenance 처럼 dispatch 루프를 돌지 않는 정당한 직접 작업이다(이 PR 을 만든 FID 자신도 포함). dispatch-log 가 있다 = 루프를 돌았다 = 판정 산출물이 있어야 한다. 로그 부재는 SKIP.
  - **템플릿 placeholder 제외** — dispatch-log 템플릿의 꺾쇠 자리표시자(`reviews/<task-id>-B-feedback.md`)를 실재 요구하면 템플릿을 복사한 모든 FID 가 즉시 FAIL 한다.
  - 전수 검증: 기존 FID 전체에 돌려 **새로 FAIL 나는 것은 2건뿐이고 둘 다 진짜 누락**이다(`20260713-llm-eval-nrun`·`20260709-tpl-session-progress-design`). false-block 0건.
- **batch PR 뭉개짐 teeth 를 산문에서 훅으로 이동 (dogfood 20260721 test1)** — `/start-all-auto` 실전 감사에서, 무인 batch 가 7개 per-FR FID 를 BATCH_ID 하나(`.specops/batch-20260721/`)로 뭉갠 채 PR 을 냈다. 뭉개짐을 막는 `batch-state.sh` 하드 스캔은 `commands/start-all.md:114` **산문 지시**에만 있었고 R-2 훅은 verify 만 보므로, 아무도 호출하지 않은 채 통과했다(실측 재현: 사후에 돌리니 `MISMATCH` — 돌렸다면 PR 전 차단됐다). `hooks/pretool-governance.sh` 가 `gh pr create` 시 최신 `.specops/batch-*/queue.md` 에 신규 `batch-state.sh --gate` 를 자동 실행한다.
  - **`--gate` 는 기본 모드와 판정 기준이 다르다** — 뭉개짐 신호(per-FR 산출물 3종 부재·진행기록 `/verify PASS` 줄 부재·라벨 오염)만 차단하고, 드리프트·미완·중복은 차단하지 않는다. 후자는 batch 운영 판단이고(M1 batch → M2·M3 batch 분할은 정당), 그것으로 PR 을 막으면 정당한 부분 batch 를 차단하는 **false-block 재생산**이 된다.
  - **라벨 화이트리스트 동반이 필수였다** — 산출물·진행기록 teeth 는 `IMPL_DONE` 행만 수집하므로(`batch-state.sh:87`), test1 처럼 `DONE` 으로 쓰면 **검사 대상 0건 → 조용히 통과**한다. 라벨 검증 없이 teeth 만 훅에 붙였다면 실물 케이스를 여전히 못 잡았다. 미인식 라벨은 차단 사유로 승격(gate 모드 한정 — 기본 모드 판정 불변).
  - **인라인 BYPASS 불인정** — batch PR 은 비가역이라 security Critical/High 와 동급으로 다룬다(`start-all-auto.md:56` 선례). 없으면 test1 이 한 그대로 사유 한 줄로 우회된다. 세션 env BYPASS(사용자 주권, 5원칙 4)는 보존. 중간 커밋은 대상 아님(chain 상 verify 앞이 정상).
  - **판정 범위 = 진행 중(ACTIVE 마커) batch 한정** — 첫 구현은 `ls -t .specops/batch-*/queue.md | head -1` 로 최신 batch 를 집었는데, 이것이 **새 false-block(6호)을 만들었다**. `.specops/*` 는 gitignore 라 뭉개진 batch 디렉토리가 디스크에 무기한 남고, 그 batch 와 **무관한** 단일 FID 작업의 PR 이 과거 라벨 오염으로 차단된다(실측 재현: specops-test1 의 무관한 PR 이 `batch-20260721b` 의 `DONE` 때문에 deny). 게다가 이 게이트는 인라인 BYPASS 앞이라 탈출구가 "세션 전체 거버넌스 해제"뿐이 된다 — false-block 의 유일한 출구가 보호 장치 무력화라는 최악의 형태다. `start-all` Phase 0 이 `.specops/$BATCH_ID/ACTIVE` 를 남기고 Step D 가 PR 성공 후 지우며, 게이트는 마커 있는 batch 만 판정한다. **한계(5원칙 5)**: 마커는 오케스트레이터가 쓰는 것이라 안 만들면 게이트도 안 열린다 — 그럼에도 이 설계를 택한 건 놓치는 비용(기존 상태 복귀) < 오차단 비용(완주율 킬러)이기 때문이다.
  - **판정 조건 = 마커 ∧ 브랜치 일치** — 마커만으로는 부족하다. 마커는 "batch 가 진행 중인가"에 답할 뿐, 게이트가 필요한 답은 "**이 PR 이 그 batch 의 PR 인가**"다. 특히 **중단된 batch** 가 치명적이다: 마커는 PR 성공(Step D)에서만 지워지는데 이 게이트의 목적이 뭉개진 batch 를 막는 것이라, 막힌 batch 는 Step D 에 도달하지 못하고 마커가 영구히 남아 이후 **모든** 무관한 PR 을 차단한다 — 게이트가 잘 막을수록 오염 마커가 쌓이는 역설. 판별자는 브랜치다(batch PR 은 `feat/<BATCH_ID>` 에서 난다 — `start-all.md` Phase 0). 불일치·판정 불가는 skip 하여 false-block 회피 방향으로 오류를 낸다. 브랜치 조회는 `symbolic-ref`(unborn HEAD 에서도 동작) — `rev-parse` 는 첫 커밋 전 batch 에서 실패해 게이트가 가장 필요한 시점에 침묵한다.
- **R-1/R-2 deny 메시지가 실제 면제 조건과 불일치 (false-block 5호)** — 면제는 **두 겹**이다: ① transcript 의 러너 실행 증거(필요조건) ② FID-scoped 앵커(session-progress `/verify PASS` 줄·evidence 스탬프·Skill 호출). 구 문안은 ①만 안내해, 지시대로 러너를 재실행하고도 ②가 없어 또 막힌 모델을 BYPASS 로 몰았다. test1 transcript 실측: `#418` deny(정당 — verify 후 코드 수정으로 stale) → `#419` 안내대로 러너 재실행 `VERIFY: PASS` → `#420` **동일 메시지로 재차단** → `#421` BYPASS. `detect_fid` 가 빈값(session-progress 에 `## <FID>` 섹션 부재)이면 그 사실을 진단으로 표시하도록 메시지 분기 추가.
  - **기각한 오답**: 최초 진단은 "`session-progress-append.sh` 정규식이 `batch-` FID 를 거부하는 것이 결함"이었다. 틀렸다 — `batch-YYYYMMDD` 는 BATCH_ID(브랜치·큐 디렉토리)이고 verify·append·detect_fid 에 넘어가야 할 것은 per-FR FID 다(`start-all.md:93,103,107,122`). 정규식은 옳게 동작했고, 수용하도록 고쳤다면 뭉개짐을 제도화하는 역행이었다.

### Added
- **입력 프로브(fixture-외) 의무 — Phase C 리뷰어 (test1·test2 델타 감사 F4)** — 리뷰어 3종 어디에도 "fixture 밖 입력을 직접 만들어 던지는" 의무가 없었다(실측: `agents/*-reviewer-ko.md` 에 프로브·스트레스 문구 0건). 있는 건 `code-reviewer-ko` 의 "**작성자 테스트가** 경계값을 커버했나" 수동 점검뿐이라, 작성자가 상상하지 못한 입력 클래스는 내부 리뷰를 통과한다. 실측 대가(test2): 블록주석 마스킹 봉합이 내부 Phase C 통과 후 **외부 리뷰의 fixture-외 스트레스 프로브에 4라운드 연속 Critical**(문자열 오열림·라인주석 누출·text block phantom)을 맞고 8커밋을 썼다. `code-reviewer-ko` 프로세스에 4단계 신설: 변경이 입력을 파싱·검증·변환·매칭하면 **fixture 미커버 입력 클래스 최소 1종을 지목·합성·실행**하고 **명령과 출력을 원문 인용**(요약 주장은 프로브 불인정), **fixture·expected 파일 수정 금지**(판정 근거 오염), 표면 없으면 `해당 없음 + 사유`(침묵 skip 금지). 보고서 `## 입력 프로브` 섹션 추가. `test-gate-presence` 3-패턴 회귀(프로세스 단계·fixture 수정 금지·보고서 섹션 — 각각 다른 소실을 잡도록 mutation 3/3 검증).
  - **등급 한계(5원칙 5)**: **guidance-level** 이다(#226 P4 넛지와 동급). 프로브는 행동이라 파일 대조로 검증 가능한 객관 신호가 없어, 회귀 테스트는 **문구 존재**만 본다 — 실제 프로브 수행 여부는 검증하지 않는다. 같은 PR 계열의 F1(누락 검사)이 teeth 인 것과 지점이 다르며, 그 천장을 알고 넣는다.
- **적용 범위**: `code-reviewer-ko`(Phase C) 한정. `spec-reviewer-ko` 는 스펙 준수 판정, `plan-reviewer-ko` 는 실행 전 설계 단계라 프로브 표면이 없다 — 근거가 있는 곳에만 배선(과잉 전파 금지).
- **리뷰 감사 추적 기계 검사 — Evaluator 규칙에 teeth (test1·test2 델타 감사 F1)** — `#224`(v1.51.0)가 "부모 self-review 금지 / 모델 override 재dispatch / dispatch-log degradation 기록"을 명문화했으나, teeth 는 `test-gate-presence`(스킬 본문 섹션 존재 mutation)뿐이라 **산출물이 그 규칙을 지켰는지 검사하는 층이 0** 이었다. 실측: test1 `20260717-approval-rbac` 이 `reviews/T10-B-report.md` 만 남기고 `dispatch-log.md` 에 T10 행을 누락 → 아무 게이트도 반응 없음. 신규 `scripts/_internal/check-review-audit.sh` 가 `reviews/<task-id>-[BC]-{report,feedback}.md` ↔ dispatch-log 행을 경계매칭(T1 이 T10 을 덮지 않음)으로 대조하고, `run-verification.sh` 가 이를 호출해 미기록 시 `VERIFY: PASS` 를 거부 — 실행-근거 게이트(R-1/R-2)와 직결이라 커밋도 열리지 않는다. 테스트 명령 0건 FID 도 감사 대상(`NO COMMANDS` 우회 구멍 봉합). 산출물 부재는 SKIP(fail-open)이라 무관 repo·초기 FID 월권 0. `implementing-ko`·`verifying-evidence-ko` 본문 배선. 신규 테스트 11건(T1.a~T3.c, RED 10 → GREEN 11).
  - **스코프 한계(5원칙 5)**: **누락 전용**이다. dispatch-log 행이 존재하되 내용이 거짓인 falsification(부모 인라인 판정을 서브에이전트로 기재)은 자기보고라 파일 대조로 판별 불가 — transcript join 은 `context-resets-ko` 의 implement↔verify 리셋 경계 때문에 대부분 fail-open 이라 실효가 낮다(#120 자기보고 구조적 한계 동일 클래스).

## [1.53.0] — 2026-07-19

### Fixed
- **전수 감사 구체 버그 4건** (커맨드·스킬·에이전트 58 유닛 평가 산출):
  - **skip-tracker.sh security 게이트 死문** — `skip-tracker.sh` 는 헤더 `^## /${gate}-test` 하드코딩이라 security(헤더 `## /security-review`)를 못 잡아, `security-review-ko` 의 SKIP 관측 지시가 死문이었다. 게이트→헤더 매핑(`skip::header`) 추가로 integration/performance/security 3게이트 정합(하위호환 유지). 신규 테스트 T17~T20 + mutation 검증.
  - **`dispatching-parallel-agents-ko` used_by 허위 역참조** — `systematic-debugging-ko` 를 호출자로 주장하나 실측 grep=0 → 제거.
  - **`using-git-worktrees-ko` `~` 따옴표 내 미확장** — `path="~/.config/..."` 는 리터럴 `~` 디렉토리 생성 → `"$HOME/.config/..."` 수정.
  - **`finishing-a-development-branch-ko` used_by 과소기재** — 실제 호출자 `performance-test-ko`·`e2e-test-ko` 추가.

## [1.52.0] — 2026-07-19

### Added
- **유지보수 오분류 백스톱 (specifying-ko [신규 분기])** — 커맨드 감사 20260719 [MED]: entry 라벨(`<!-- entry: maintain -->`)은 모델-prepend 프로즈라 훅 강제가 없어, 메타스킬 유지보수 분류·라벨이 누락되면 유지보수 요청이 [신규 분기]로 새어 analyzing-ko HARD GATE(current-state·impact-analysis)를 통째 skip → 회귀 AC-R 미적용. specifying-ko [신규 분기] 진입점에 soft 백스톱 추가: 요청이 **기존 코드·동작 수정**이면 신규 진행 전 1회 확인(유지보수 전환 시 analyzing-ko 선행). 하드강제 아님(5원칙4 주권)·오탐 방지(신규 창작이 "개선/변경" 어휘 포함은 흔하므로 기존 산출물 실제 수정 시에만 확인). 관찰 실패 0의 백스톱 — 아키텍처상 라벨은 프로즈라 완전 기계강제는 불가.
- **재개 desync 자동표면화 (SessionStart)** — 완주율 레버: 정체 후 재개 시 session-progress breadcrumb 이 git·dispatch 보다 뒤처져 재개 모델이 "미구현" 오판·방치(dogfood test1 FR-3, 24h 정체). `/status` reconcile(#220)은 탐지하나 수동 실행 필요였다. SessionStart 훅이 진행 중 FID 에 `reconcile-check.sh --hook` 을 자동 실행 → 증거 frontier > 기록 frontier 일 때만 DESYNC 경고+재개점을 `<session-progress-reconcile>` 로 주입(정합 시 무출력, 노이즈 0). session-progress 자동 덮어쓰기는 하지 않음(표면화만 — breadcrumb 오염 방지). frontier 사다리·reconcile 로직을 `scripts/_internal/reconcile-check.sh` 로 추출해 show-fid-status·SessionStart 단일 SoT(drift 방지). 신규 테스트 9건(reconcile-check 6 + session-start-reconcile 3), mutation 검증.

### Fixed
- **외부 신규진입 블로커 — 번들 스크립트 상대경로 → `${CLAUDE_PLUGIN_ROOT}` 정식형** (funnel dogfood 적발): 26개 커맨드/스킬 본문이 `bash scripts/...` **상대경로**로 번들 스크립트를 호출해, 사용자 프로젝트 cwd(≠plugin)에서 `No such file or directory` 로 lifecycle 전 단계가 깨졌다. 모든 dogfood/e2e 가 plugin repo 내부(cwd=plugin)서 돌아 상대경로가 우연 해소돼 여태 미적발(자기repo 편향). 공식 docs 확인: Skill·agent 본문의 `${CLAUDE_PLUGIN_ROOT}` 는 로드 시점 절대경로 치환 → 정식형 `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/...` 로 전면 전환. 예외: 자기유지보수 전용(release·e2e-test-ko, cwd=plugin) + 라이브 호출 아닌 산문·PR템플릿.

### Added
- **`validate-structure.sh` `plugin_root_paths` 회귀 검사**: 사용자 프로젝트서 실행되는 커맨드/스킬 본문에 상대 `bash scripts/` 재발 시 FAIL (예외 allowlist 반영). red-green 검증.

## [1.51.0] — 2026-07-18

### Added
- **공유 유틸 창발 중복 경고 (P2) + implement 전환 선언 넛지 (P4) — test2 회고** — **P2**: foundation-manifest 는 사전 선언된 공통부 재사용만 게이트하지, 형제 FID 가 각자 만드는 유틸의 **창발 중복**은 못 잡는다(전방 계약≠후방 탐지). test2 실측: `mask_block_comments`·`PRUNE`/`ANALYZE_EXT` 가 4~5 FID 복제 → "sysprobe-lib 승격" backlog 반복. planning-ko 에 판별 가이드(재사용 유틸 → 공통 lib 배치·manifest 등재 후보, 애매 시 `공유후보:` 1줄+advisor) 추가 — 하드게이트 아님. **P4**: R-3 warn 12건이 전부 `implementing-ko`(자동 체인이 선언 없이 직접 호출). decomposing-ko 의 implement 전환에 "호출 직전 한 줄 선언" 넛지 추가(근본=전환 지점). teeth: test-gate-presence(mutation 2/2). ※ P4 는 guidance-level(자동 체인이라 완전 제거는 미보장)이고 R-3 은 audit-only 라 잔여 warn 은 benign.

- **detection-proof — 테스트 전용 태스크의 RED 대체 (P5, test2 정주행 회고)** — RED-first 는 새 동작 구현을 가정하는데, **이미 정상 동작하는 로직에 테스트를 추가**하는 태스크(커버리지·스캐너 탐지 테스트·회귀 락인)는 자연 RED 가 없다. tdd-ko 의 "테스트가 통과? → 테스트 수정"은 이 경우 오처방(테스트가 옳다). `tdd-ko` 에 detection-proof 성문화: **변이(규칙 뒤집기·유령 주입)로 테스트가 FAIL 하는지 확인**해 탐지력 증명 — "변이해도 통과=tautology=RED 미충족". RED 의 본질은 "실패 테스트를 먼저"가 아니라 "**fail 할 수 있음을 관찰**"이라는 원칙 명문화(변이본 FAIL 원문 인용 = RED 인용 규약 대칭). test2 run 이 스스로 발명한 패턴을 성문화 — decomposing-ko 는 tdd-ko 준수라 자동 전파. teeth: test-gate-presence(섹션 삭제 mutation).

### Fixed
- **Evaluator fable 하드고정이 크레딧 소진 시 Generator↔Evaluator 붕괴 (P1 — test2 정주행 회고)** — `plan-reviewer-ko`·`spec-reviewer-ko`·`code-reviewer-ko` 가 `model: fable` 고정이라, fable 크레딧 소진 시 **3 Evaluator 전부 dispatch 불가** → 부모(생성자) self-review 로 후퇴 = **Evaluator=Generator 편향**(specops 핵심 가치인 독립 리뷰 붕괴). test2 완결 run 의 실측 근거: 부모 self-review 가 놓친 Critical(I-1 self-gate exit 마스킹)을 **독립 비-fable 리뷰어가 잡았다**(독립-약한 모델 ≫ 편향-강한 모델). fix: fable 불가 시 **같은 Evaluator 를 독립 서브에이전트로 가용 모델 override 재dispatch**(컨텍스트 분리로 불변식 보존), **부모 self-review 후퇴 명시 금지**, dispatch-log degradation 기록 + 고위험 FID 크레딧 복구 후 재리뷰 권고. fable 고정(강한 리뷰어 보장)은 가용 시 유지 — graceful floor. implementing-ko(B/C) + planning-ko(plan-reviewer) 배선. teeth: test-gate-presence(mutation 2/2, cross-ref 오매칭 조임 포함).


### Changed
- **E2 최종 리뷰 right-size — 단일 태스크 중복 제거 (경제성)** — `implementing-ko` 의 wave-loop 후 "최종 코드 리뷰어(전체 구현)"는 태스크 간 통합을 보는 단계인데, **태스크가 1개**면 "전체 구현"="그 1 태스크"라 이미 Phase C 가 리뷰한 것과 **literal 중복**이었다. 태스크 수==1 일 때만 최종 리뷰 skip(기계적 게이트, 품질 손실 0 — 동일 산출물의 두 번째 리뷰 제거). **멀티태스크 Phase B/C 는 무변경** — 그 리뷰가 실 Critical(RBAC 권한상승 등)을 잡는 품질의 원천이라 명시적 축소 금지 가드 추가. dispatch-log 투명성 기록(F-12 규약). teeth: test-gate-presence(mutation 3/3). ※ 경제성의 대부분은 이런 코드 레버가 아니라 "자기수리 나선 중단"(행동)에 있음 — 본 변경은 안전한 중복 제거 한 건으로 한정.

### Fixed
- **`/status` reconcile — 유지보수 흐름 `/analyze` 단계 누락 (#220 자기결함)** — reconcile 단계 사다리가 `specify` 부터 시작해 유지보수 진입 단계 `/analyze` 를 몰랐다. `/analyze 완료` 가 기록돼도 recorded=0 오라벨 + current-state.md·impact-analysis.md 가 증거 사다리에 부재 → 모든 유지보수 FID 를 오판(cry-wolf 리스크). dogfood 로 test2 `scanner-blockcomment-fix`(유지보수 FID) 를 실제 조회하다 발견 — "shipped 도구를 실사용 중 나온 자기결함" 이라는 개선 명분 기준의 실례. 사다리에 `analyze`(rank 5, specify 앞) + analyze 산출물 증거 추가, 비균일 간격 위해 `_stage_next` 명시 매핑. teeth: test-show-fid-status T9(정합)·T10(analyze→specify desync). ★ T9/T10 초안이 상단 이력 echo 의 `analyze` 로 tautology-PASS → reconcile 섹션 스코프로 정정(grep 앵커 교훈 자체적용).

### Added
- **FID 크기 규약 — per-FID 태스크 수 완성율 소프트 신호 (`decomposing-ko`)** — per-태스크 크기(2~5분)는 있었으나 **per-FID 크기(총 태스크 수)** 가이드가 전무했다. dogfood 실측: test2 3-태스크 FID **6/6 완주** vs test1 10-태스크 FID **24h+ 정체**(태스크 각각은 정상, FID 전체가 7.5h 마라톤 → 세션 경계 이탈). 권장 스코프 ≤6 태스크, 7+ 이면 `⚠️ FID-SIZE` 소프트 신호 + 예방(다음 FID 는 수직 슬라이스로 작게)·완화(태스크별 checkpoint→`/status` reconcile 재개) 택1. 하드 게이트 아님(리스크 인지용). teeth: test-gate-presence(silent drift 방어). #220 reconcile(정체 복구)의 짝 — 이건 정체 예방.
- **`/status` reconcile — 기록↔증거 frontier 대조로 정체 재개점 제시** — session-progress 단독은 정체 후 현실을 **과소보고**한다(dogfood test1 FR-3 실측: `/tasks` 기록 상태에서 12커밋+dispatch T7까지 존재했으나 주 breadcrumb 만 읽어 "구현 안 됨"으로 오판 → **24h+ 방치, 실제 잔여 작업은 5분**. 완성율 킬러의 실물). `show-fid-status.sh` 가 **기록 frontier(session-progress 최고 단계) ↔ 증거 frontier(spec/plan/tasks·dispatch-log DONE·feat/<FID> 브랜치 커밋·evidence.md·reviews/)**를 8단계 rank 로 대조 — 증거가 앞서면 `⚠️ DESYNC` + **진짜 재개점**(증거+1 단계) + **기록 보정 구간**(recorded+1~evidence) 제시. 정합 시 경고 0(오탐 방지). 실 FR-3 정체 상태 재현 검증: "재개점 review 부터, implement~verify 기록 보정" 정확 산출. teeth: test-show-fid-status T6~T8.

## [1.50.0] — 2026-07-18

### Fixed
- **posttool R-1/R-2 감사 침묵 봉합 — 감사 스코프를 "방금 액션의 범위"로** — posttool 이 working-tree 기준 `is_docs_only_change` 를 쓰는데, 커밋 직후 잔여 dirty 는 거의 항상 tracked `.specops/session-progress.md` 뿐이라 `.specops/*` 면제(#214)에 걸려 **감사가 통째로 skip** — #214 이후 R-1 posttool warn 이 전 repo 0건이던 실물 원인(pretool block 만 남는 절반 가시성. 기존 T8.a 는 git repo 부재 fixture 라 빈 diff fail-safe 로 위장 통과). 신설 `is_docs_only_audit_scope`: R-1 = `HEAD~1..HEAD`(방금 커밋), R-2 = `base...HEAD`(PR 범위) — whitelist 는 `_files_all_docs` 로 공유(drift 방지). pretool(액션 前 = working-tree 가 곧 커밋 범위)은 무변경. range 실패(최초 커밋·base 미검출)는 비면제 fail-safe(감사는 기록이라 과잉 방향이 안전). teeth: test-hooks T8.e/f·test-lib T-scope.a~d.
- **실행증거 신선도 게이트 — 세션 전역 만능 면제표 봉합** — `_verify_exec_evidence` 가 윈도우·FID 스코프 없이 transcript 전체를 스캔해, 세션 초반 **다른 FID 의** `VERIFY: PASS` 1회가 세션 끝까지 모든 커밋을 여는 만능 면제표였다(dogfood test1 실측: FR-2 verify 가 FR-3 미검증 implement 커밋 8+개를 전부 면제 → friction 무흔적. 계측 probe 로 서브에이전트 훅도 main transcript 로 평가됨을 확정 — "서브에이전트 게이트 갭" 가설은 기각, 실물은 staleness). 규칙: **마지막 실행증거 이후 비-`.specops` Edit/Write/NotebookEdit 가 있으면 stale**(수정→재검증 후 커밋이 정직 순서 — `_verify_passed_in_progress` vts>cts 와 동형). `.specops/` 아티팩트 Write(evidence.md 마무리)는 제외. 한계: Bash 경유 파일수정(sed -i)은 미탐(F-1 동류 heuristic). teeth: test-exec-evidence T-fresh.a~d.
- **인용 문자열 프로즈 false-block — `_strip_quoted_strings`** — printf/echo 인용 인자 속 프로즈("배포 후 (git commit 으로 기록)"·"build | git commit")의 `(`·`|` 선행자가 R-1/R-2 트리거와 오매칭돼 정직한 문서·코드 텍스트 작성이 차단됐다(dogfood 20260717 test2 모델 backlog "R-1 블록주석 내부 오검출" — probe 로 실재 확정. heredoc 경로는 기처리, 인라인 인용 인자가 잔여 표면). 인용 본문을 트리거 검사 입력에서 제거하되 **차단 우세 불변식** 유지: 더블쿼트 내 `$( )`·백틱은 실제 실행되므로 보존(deny 보존), 백슬래시는 bash 인용 의미대로 처리(blanket-bail 은 `printf "%s\n"` 주 형태를 전부 죽여 fix 무력화), `$'…'`·미종결 인용·awk 실패는 원본 후퇴. pretool prefilter + `apply_lookback_rule`(posttool 대칭) 양쪽 배선. teeth: test-pretool T-qs.1~6·4b.
- **커밋 메시지 BYPASS 표식 오염 가드** — 우회 커밋 메시지를 `BYPASS fix: …` 로 시작하는 오염(dogfood test2 `61f9e0d` — conventional commit 훼손, 릴리즈 노트·검색 오염)이 실측됨. bypass 경로에서 `-m "BYPASS…"` 를 deny + 정상 메시지 재작성 안내(우회 기록은 `SPECOPS_BYPASS_REASON`+friction-log 담당). teeth: test-pretool T-mp.a~c.

## [1.49.0] — 2026-07-17

### Added
- **batch 진행기록 teeth — batch-state check 5** (#214) — `/start-all` dogfood(specops-test1 재주행)에서 batch 가 skill 미호출 인라인 진행으로 session-progress 0줄 → R-1/R-2 면제 신호(`_verify_passed_in_progress`) 부재 → 게이트 차단 → 무사유 BYPASS 관성(커밋 3회+PR)이 실측됨. IMPL_DONE FID 마다 session-progress FID 섹션의 `- YYYY-MM-DD HH:MM /verify PASS` 줄(행 선두 앵커)을 batch PR 직전 하드 재검 — 부재 시 `[진행기록 누락]` + exit 1. start-all.md Phase 3 배선(재검 3종→4항목) + 안티패턴 2건(인라인 뭉개기·무사유 BYPASS 정면 돌파) 신설. teeth: test-batch-state T2.f/g.
- **인라인 BYPASS 사유 강제 — `SPECOPS_BYPASS_REASON`** (#214) — `SPECOPS_GOVERNANCE_BYPASS=1` 인라인 prefix 는 사유 병기 필수(무사유 deny + 형식 안내). 사유가 friction-log evidence_snippet 에 명령 원문째 남아 감사 가능한 우회가 된다. 세션 env 탈출구(사용자 주권)는 불변. teeth: test-pretool T36 계약 뒤집기 + T36b/c.
- **critic provider preflight·cascade — `_usable`** (#215) — specops-test2 정주행에서 claude 감지(`command -v` 통과) 후 실행 rc=127(stale shim/PATH 클래스) → 외부 critic 전 구간 실효 0 이 `FAIL (provider rc=127)` 로 위장됐다. `--version` preflight 로 실행 불가 provider 를 부재로 강등 → 다음 provider cascade(claude→codex→gemini→ollama) 또는 정직한 SKIP + stderr 진단. `CRITIC_BIN`(사용자 강제)은 계약상 preflight 제외. teeth: test-critic-ask T1.h/i.

### Fixed
- **design 산출물 커밋 false-block 5호** (#214) — Phase 2.5 design 커밋(`screens/*.html`)이 `.md` 한정 docs-only whitelist 에 걸려 차단 → BYPASS 남발 유인. `is_docs_only_change` 에 `screens/*.html`(루트 screens/ 한정 — `src/**/*.html` 은 비면제 유지)·`.specops/*`(아티팩트 도메인) 면제 추가. teeth: test-lib T-docs.n~q.
- **인용 공백값 prefix 트리거 우회 차단 + prefilter 동적 로드** (#214) — `FOO='a b' git commit` 처럼 인용 공백값이 VAR=val prefix 체인을 끊어 R-1/R-2 트리거를 통째로 비껴가던 기존 우회를 인용값 클래스 지원(deny-superset widening)으로 차단. 인용값 도입으로 pretool literal 에 quote-splice 가 생겨 T-H1(literal 복제 비교)이 구조적으로 깨짐 → prefilter 를 rules.jsonl `trigger_pattern` 동적 로드로 전환(T-R8 동형, drift 원천 제거). teeth: test-pretool T21b/T22b·test-rules T-H1/H1b.
- **정직한 BYPASS false-deny — 선행자 클래스 비대칭** (#215) — 사유까지 병기한 compound(`git add x && BYPASS=1 REASON=... git commit`)·함수 wrapper(`B() { ... }`) 우회가 `^줄시작` 앵커에 걸려 deny 되던 것(specops-test2 실측, 재시도 2회+ 낭비)을 트리거와 동일 선행자 클래스 `(^|[;&|({\`])` 로 정합. 메시지 내 토큰 언급(공백 선행)은 여전히 불인정(T37 보존). teeth: test-pretool T36d/e/f.

## [1.48.0] — 2026-07-16

### Added
- **`/init-project` Phase 0 기존 기획 문서 auto-discovery (3단 탐색)** — 실무는 PRD·기획서가 **이미 파일로 존재**하는 게 보통인데, 종전 감지는 `.specops/memory/brainstorming-*.md`(플러그인 자기 관습 파일명)뿐이라 repo 에 `prd.md` 를 두는 자연스러운 흐름이 안 먹혔다(온보딩 마찰 — 사용자 실지적). 3단 우선순위 신설: **0-a** args 명시 경로(`/init-project 쇼핑몰 docs/기획서.md`) → **0-b** 브레인스토밍 메모(기존) → **0-c** auto-discovery(`PRD*.md·prd*.md·기획*.md·요구사항*.md·requirements*.md` + `docs/` 변형 — 발견 시 **사용자 확인 필수**, 자동 소비 금지). 확보 문서로 PRD 6필드 초안 합성(없는 필드는 창작 금지·질문). Phase 11 근거 4원의 ① 을 "사전 문서"로 동기 확장. FR 표 보유 requirements 는 Phase 8a 보존 정책과 연계. teeth: `test-init-project` T23.a.

## [1.47.3] — 2026-07-16

### Fixed
- **advisor-ko 진단표 실측 정정** — `/advisor` 유효 옵션은 opus·sonnet·off 뿐(fable 미지원 실측). ∴ main=Fable 5 면 advisor 는 구조적 불가 — 진단표 안내를 "/advisor off + critic-ask 공식 대체 또는 main 하향 중 사용자 선택"으로 정정 (구 안내 "main 과 동급 이상 모델 재설정"은 Fable main 에서 실행 불가한 지시였음).
- **DB lifecycle 잔여 gap 3건 종결** (#152 보류분 — 코드 backlog 제로화): **gap3** 마이그레이션 테스트 정책 — `test-strategy.md` §4.5 신설(up→down→up 멱등·제약 위반 경로·인덱스 존재·expand-contract 데이터 보존, 도구 표 행 추가) + `tdd-ko` "마이그레이션(DDL)도 TDD"(멱등 테스트 먼저 RED). **gap5** verify 스키마 추출 heuristic 명세 — 도구별 위치(prisma/alembic/db/supabase migrations·ORM 스키마·raw DDL grep) + **ERD(mermaid) 수기 한계 고백**(자동 대조 기준은 §3 엔티티 표, ERD 는 권고만). **gap6** `data-model.md` PostgreSQL 편향 조건부화 — §1 에 비-PG 주의 노트(GIN→FULLTEXT/FTS5 치환·MongoDB document 모델 §3 대체·localStorage 축소 적용) + PK 생성 함수·at-rest 암호화 DB별 병기. teeth: `test-interface-routing-doc` AC-17~19.

## [1.47.2] — 2026-07-16

### Fixed
- **감사 P2/P3 + dogfood 관찰 2건 + 빈틈2 일괄 종결** (7건):
  - **R-4 러너 패턴 downstream 확장 (#209 전파)** — `test_runner_pattern` 의 `scripts/tests/` 하드코딩 2형(bash·`./` 직접)이 외부 repo 의 `bash tests/test-x.sh` 실행을 러너로 미인식 → 정직한 성공 주장이 R-4 false-warn. `(scripts/tests|tests?)/` 확장 + `test-rules` T9.f 회귀(RED→GREEN). verifying-evidence 러너 목록 prose 도 동기 정정.
  - **dogfood 관찰 A — trivial 스펙승인 중복 게이트 통합** — 설계승인+축약승인 직후 동일 내용 스펙의 3번째 승인 요구는 중복(4연속 게이트 실측). specifying-ko 에 [trivial 게이트 통합]: 내용 동일 시 1줄 고지 통과, 신규 논점·범위 변화 시 게이트 유지(주권 불변). teeth: `test-trivial-new-shortcut` AC-GATE-MERGE.
  - **dogfood 관찰 B — Phase B/C 판정 file-based 감사 추적** — PASS 가 부모 선언으로만 흘러 Phase C 가 B 통과 자격을 검증 불가(file-based-communication 위반, Phase C 리뷰어 실지적). implementing-ko 에 `reviews/<task-id>-B(-C)-report.md` 저장 + C dispatch 에 경로 포함 규약. teeth: AC-B-REPORT.
  - **TDD 감사 P2-① — plan-reviewer TDD 렌즈 오조준 정정** — "RED 스텝 누락=Critical" 은 tasks.md 기준인데 리뷰 대상 plan.md §5 는 설계상 카테고리만 담음 → 모든 정상 plan 이 Critical 나는 렌즈. "TDD 가능성"(§2 테스트 파일 계획·§5 테스트 가능 단위) 기준으로 재정의.
  - **TDD 감사 P2-② — 5스텝↔Red-Green-Refactor 명칭 관계 명문화** — tdd-ko 에 "5스텝=RGR 의 태스크 실행형, REFACTOR 는 별도 리팩터링 태스크로 분해가 의도" 주석 (drift 가 아니라 단위 차이임을 고정).
  - **테스트영역 감사 P3 — macOS CI 차단 승격** — `test.yml` run-all-macos 의 `continue-on-error: true` 제거 (관찰 기간 green + darwin 이 주 개발 환경).
  - **빈틈2 — verify 테스트=spec 커버 점검** — api-spec 에 추가·변경된 제공 엔드포인트별 테스트 케이스 존재 대조, 미커버는 evidence.md `## 미커버 엔드포인트` 권고(비차단·graceful).
  - 기각 기록: TDD P3-① whitelist 협소(=#195·#209 로 기해소, memory stale)·R-4 무관 러너 면제(F-3 self-report 클래스 WON'T-FIX 정합)·e2e staleness stamp·init-project phases 직접 유닛(e2e 가 커버, 투자 대비 낮음).
- **trivial 단축경로 외부 실주행 dogfood — 완주 차단 결함 3건 적발·해소** (완주율 레버, 평가 6.7 도달-14% 공략) — 외부 fixture repo(todo.sh CLI)에 신규 소형 기능(stats 명령)을 실제 lifecycle 로 진입시켜 spec→trivial 제안·승인→(clarify·plan SKIP)→decompose→implement(Phase B PASS·C READY_TO_MERGE)→verify **완주 실증**. 발견 3건 전부 fix:
  - **★ 발견 #3 (핵심 — false-block 4호)**: `run-verification.sh` whitelist·`extract-test-commands.sh` fallback 정규식이 `bash scripts/` **접두 하드코딩** — 플러그인 자기 repo 레이아웃 편향. downstream 표준 `bash tests/test-x.sh` 가 추출 0건(NO COMMANDS) 또는 SKIP(PARTIAL) → **실행-근거 게이트 불인정 → 정직한 외부 완주가 커밋 deny → BYPASS 강요**. 외부 완주를 게이트가 직접 막던 문. 두 곳 `(scripts|tests?)/` 확장(anti-footgun 성격이라 상대경로 테스트 디렉토리 확장 안전 — 절대경로·`lib/` 여전히 차단). 회귀: `test-verifying-automation` T2.g(extract 층, RED→GREEN)·T2.h(whitelist 층 YAML 주입 잠금). **fixture red-green 실증**: fix 전 `VERIFY: PARTIAL` → fix 후 `VERIFY: PASS`.
  - **발견 #1**: decomposing trivial 오판 안전망 기준 "AC ≥ 3 또는 파일 ≥ 2" 가 TDD 최소 구성(코드1+테스트1=2파일·회귀 AC 포함 must 3건)에 **항상 걸리는 false-trigger** — 전 trivial 재확인 유발로 단축 이득 상쇄. "must AC ≥ 4 또는 구현 파일 ≥ 2(테스트 제외)" 로 보정.
  - **발견 #2**: acceptance-criteria.md 를 bullet(`- **AC-1**:`) 포맷으로 쓰면(템플릿은 `### AC-1:` 헤더 — LLM 흔한 위반, 실주행에서 재현) `emit-context` AC 요약이 **빈 문자열로 조용히 degrade** + validate-context 도 통과. bullet 겸용 파싱 + 추출 실패 시 stderr WARN. 회귀: `test-emit-context` T1.j(bullet 추출)·T1.k(WARN 발화).

## [1.47.1] — 2026-07-16

### Fixed
- **소비 IF(api-spec-consumer) 정·역 쌍 복원 + advisor 연결 진단 신설** — ① **C2 소비 축**: 재실측 결과 memory 의 "빈틈1" 은 대부분 stale(8g consumer 생성·frontend-architecture 참조 정정 기완료, 8f KIND 2·4 한정은 정당 — UI/Mobile 은 제공 API 없음)이었고, 진짜 잔여는 **소비 IF 축만 정방향(Step 5.6·design-interface) 설계뿐 역방향·계약 미배선** — verify 역방향 안전망 추출 대상에 외부 API 소비 호출 없음 · emit-context §6 계약 · implementing 계약 목록 전부 consumer 0건. UI/Mobile 프로젝트에서 신규 외부 API 호출이 추가돼도 `api-spec-consumer.md` 대조 없이 통과하는 반쪽 안전망이었다. verify(추출 대상 "외부 API 소비 호출" + 대조 대상 consumer)·emit-context contract·implementing 계약 3곳 대칭 복원. teeth: `test-interface-routing-doc` AC-15(verify 소비 축, grep `-c`≥2)·AC-16(계약 대칭) + `test-emit-context` T1.f2(consumer §6 emit, RED→GREEN). ② **C3 advisor 연결 진단**: advisor() 미연결이 2세션 연속 "자체검토만" 무음 fallback — 협의 의무 체계가 도구 부재로 조용히 공회전. 공식 문서 조사(advisor=서버사이드 도구) 기반으로 `advisor-ko` 에 **연결 진단 §**(4원인: pairing 무효(advisor 는 main 과 동급 이상 — main 상향 시 조용히 깨지는 함정)·main 미지원·비-Anthropic API·`CLAUDE_CODE_DISABLE_ADVISOR_TOOL`) + 사용자 재연결 안내 1회 의무 신설. teeth: `test-auto-advisor` AC-6.
- **verify-exec-gate 잔여 backlog 4건 일괄 종결** (PR #195 알려진 잔여 — [`project_verify_exec_gate`] §잔여):
  - **B4 inject-evaluator-timestamp 개행 융합 fix** — BSD sed `a\` 가 삽입 텍스트 뒤 개행을 안 붙여 `**timestamp**: ...Zbody` 로 다음 줄이 흡수됐다(실측 재현 — 기존 T2.e 는 status 가 마지막 줄이라 미검출). awk print 전환(BSD/GNU 무차이) + 회귀 T2.e2(중간 삽입 융합) 신설.
  - **B2 심층 필터 통합 잠금** — is_error·PASS/PARTIAL 혼재는 단위(T9·T10 인라인)만 있었고 pretool 훅 전체 파이프는 미잠금. 파일 fixture 2종(`pretool-verify-exec-error`·`-partial-mixed`) + test-pretool T2c·T2d 신설 — 둘 다 deny 실증.
  - **B1 스코프 이관 규약 명문화** — NEEDS_CONTEXT 트리거 5(whitelist 외 파일) 처리가 dispatch context 수기 보강으로 새면 ① tasks.md(SoT) drift ② emit-context 재실행 시 증발 ③ 후속 wave outputs-disjoint 판정이 낡은 outputs 로 계산 → R11 git race. implementing-ko 에 4스텝 규약(tasks.md 먼저 갱신 → emit-context 재실행+worktree 라인 재갱신 → 미완 wave disjoint 재판정 → `SCOPE-MOVED:` 기록) 신설. teeth: test-emit-context T1.h(규약 배선 grep, `-c`=1)·T1.i(재실행 멱등 — 수기 편집 증발 cksum 실증).
  - **B3 roadmap §auto stale 서술 정정** — V1 의 "§auto 차단 면제" 서술에 후속 정정 인용(무조건 면제는 v1.45.0 에서 제거 — 자기발급 면제표, 실행-근거 동반 시에만 통과) 각주.

## [1.47.0] — 2026-07-16

### Fixed
- **R-1/R-2 실행-근거 게이트 run-all.sh 미인식 false-block 해소** — 플러그인 자기 repo self-maintenance 의 정식 검증 러너는 전체 스위트 `run-all.sh` 인데, `_verify_exec_evidence` 러너 클래스가 `run-verification.sh`·pytest 류만 인식해 **run-all 95/95 통과 세션이 커밋·PR 에서 deny** 됐다(20260716 dogfooding 실전 적발 — false-block 은 BYPASS 남발을 유발해 게이트 신호 자체를 희석, heredoc false-block #199 와 동일 클래스). 해소(토큰 계약 단일 유지): ① `run-all.sh` 가 성공 시 `VERIFY: PASS`·실패 시 `VERIFY: FAIL` 을 마지막 줄로 출력(소비자 전부 exit-code 기반 + 기존 출력에 `VERIFY:` 혼입 0 실측 — 안전) ② 러너 클래스에 `bash \S*tests/run-all\.sh` 추가 — **좁은 앵커**(downstream 무관 `./run-all.sh` 불인정, 위조 표면은 기존 run-verification.sh 와 동일 클래스로 비확대) ③ pretool deny 메시지에 self-maintenance 대안 안내 1줄. 게이트 출력검사 로직(jq negative check) 무변경. 회귀: `test-exec-evidence.sh` T14(인식)·T15(좁은 앵커 잠금)·T16(FAIL 토큰 negative) + 신규 `test-run-all-verify-token.sh` 3건(sandbox 실행 기반 토큰 계약 + 앵커 배선 grep, `-c`=1 실측). advisor 미연결 — 자체검토만 명시(원칙 5).
- **batch Phase 3 per-FR verify·code-review 뭉개짐 3층 해소 (개별 산출물 강제)** — `/start-all` Phase 3 는 FR 마다 verify·code-review 를 돌리지만 **개별 산출물이 뭉개졌다**. 3층 원인: **(1) 지시** — Phase 3 스텝 2~4 에 "(FID 기준)" 명시가 없어, 바로 아래 Step A/B/C 의 "batch 전체 대표 FID 로 **1회** 통합" 패턴을 verify·review 에까지 일반화(테스트는 suite-global 하게 느껴져 특히 유혹)하기 쉬웠다. **(2) 내용** — `requesting-code-review-ko` 의 `BASE_SHA=git log|grep "Task 1"|head -1` 이 공유 `feat/<BATCH_ID>` 브랜치에서 **가장 오래된** Task 1 커밋을 잡아, FR-2 의 `review.diff` 가 FR-1 변경까지 포함 → **이름만 per-FID, 내용은 blended**. **(3) teeth 부재** — `batch-state.sh` 가 queue Status parity(IMPL_DONE 토큰)만 검사하고 per-FID `evidence.md`·`review-request.md` **존재는 미검증** → 뭉개진 채 batch PR 통과. 해소: `start-all.md` Phase 3 에 **per-FR≠batch-level 경계 박스** + 스텝 1a(`git rev-parse HEAD > .specops/<FID>/review-base.sha` — 각 FR 구현 직전 base 고정) + 스텝 2~4 **(FID 기준)** 명시 + 스텝 6 산출물 존재 확인 후 IMPL_DONE. `requesting-code-review-ko` 에 **§batch base 격리 분기**(review.diff base = `review-base.sha`, 부재 시 `HEAD~1` fallback). **teeth(3층 대칭)**: `batch-state.sh` 가 IMPL_DONE FID 마다 `review-base.sha`(layer 2 내용 격리) **AND** `evidence.md` **AND** `review-request.md`(layer 3 존재) **3종** 존재를 하드 요구, 부재 시 `[산출물 누락]` + exit 1 로 batch PR 차단. ★ **layer 2 대칭화**(adversarial 적발): review-base.sha 를 teeth 에 안 걸면 step 1a 누락 시 `HEAD~1` silent fallback 인데 review-request.md 는 생성되니 존재-teeth 통과 → **내용 뭉개짐이 조용히 재발**. IMPL_DONE 한정(MERGED=타 사이클 shipped, batch 전용 review-base.sha 미보유 → legacy false-block 방지). 전파: `e2e-test-ko` V24·`test-batch-orchestration` T5 에 3종 시뮬 seed. 회귀: `test-batch-state.sh` T2.b(review-request 부재 차단·완전 FID 미보고)·T2.c(FID 디렉토리 부재)·**T2.d(review-base.sha 만 부재로 차단 — layer 2)**·**T2.e(§batch spec+review-base.sha → 문서화 BASE_SHA 스니펫이 파일 내용으로 resolve, HEAD~1 미사용 실행검증)** 신설. GNU/BSD(gawk·mawk·ggrep) 이식성 확인.

### Added
- **신규 trivial 단축 경로 — 소작업 탈출구 신설 (완주율 레버)** — 2026-07-14 평가(6.7/10)가 지목한 **완주율 14%의 지배 원인**: `trivial` 축약이 유지보수 분기 전용이라, 1파일 소규모 **신규** 작업도 spec→clarify→plan→decompose→implement→verify 6단계 의식을 강제당했다(실측 이탈: CouponWake 1라인 픽스가 6분 의식 후 수동 커밋 · IKEN spec 15초 후 마찰 맞고 Excel 이탈). 이제 `specifying-ko` 가 신규 분기에서 설계 승인 직후 예상 산출이 **단일 파일·소규모**면 사용자에게 축약을 **명시 제안**하고, **사용자 승인 시에만** `§유형: trivial` 부여 → **clarify·plan ceremony 만** 건너뛰고 `decomposing-ko` 직행한다. `decomposing-ko` 는 `plan.md` 부재를 trivial 로 감지해 spec+AC 로 **단일 태스크 tasks.md** 를 경량 합성(implementing 무변경 — DAG 계약 유지). ★ **teeth 불변**: decompose·implement·**verify 실행-근거 게이트·TDD·security 는 정상과 동일** — 사용자가 규모를 오판해도 검증 teeth 가 안전망이다. 축약되는 것은 오직 설계 ceremony 뿐. **경제성-안전 설계**: 새 훅·게이트·chain edge·사용자 개념 0개 신설 — `specifying`/`decomposing` body 조건 분기 + 기존 R-5 trivial-skip·AC-R 면제 **재사용**(primary edge 불변이라 chain.yaml·메타목록 무변경). SKIP 은 session-progress 에 `완료` 위장 없이 정직 기록. 회귀: `test-trivial-new-shortcut.sh` 14건 — form 검사 + **실행 어서션 3건**(실제 파이프라인에서 clarify·plan provably SKIP · ceremony 산출물 실제 부재 · R-5 거버넌스 미발화). FID 20260714-trivial-new-shortcut

## [1.46.0] — 2026-07-14

### Fixed
- **LLM eval 이 유지보수 신호를 측정하도록 fixture 정확화** — `#198`(sandbox 파일 시드) 후에도 `maint-2`·`docs-1`·`new-4` 가 FAIL 이던 것을 stream-json 진단으로 원인 규명. `new-4`("기존 도구 업그레이드")는 모델이 `analyzing-ko`(유지보수)를 정확히 호출 — 구 `expect_skill`(specifying-ko)이 버그였다. `maint-2`(작으면 스킵/크면 timeout)·`docs-1`(자문 후 스킵)은 eval 로 안정적 PASS 가 어려운 **경계 케이스**로 `note` 에 정직히 기록(억지 green 안 만듦). 성과: `maint-1`·`maint-3`·`new-4` 가 `analyzing-ko` 감지 — 전엔 파일 부재로 **100% `none`**(측정 자체가 안 됐다). `judge()` FAIL 사유 구분(`FAIL:skill`/`FAIL:flag`)으로 "skill 정답·약속어 누락"이 드러난다. FID 20260713-eval-sandbox-seed

### Added
- **mutation 커버리지 게이트 강제화 + governance-lib 측정 정확화** — mutation testing 인프라(`mutation-score.sh`)가 있으나 (a) run-all 미포함=수동 (b) 타겟 명령이 stale 해 governance-lib 를 **32%** 로 오측정했다(`test-lib && test-rules` 만 돌려 `_verify_exec_evidence`·`_strip_heredoc_bodies` 미커버). 전체 governance 스위트로 정정 → **55%**(15개 false rot 제거). `MUTATION_MIN_SCORE` threshold 추가(미설정 시 기존 동작 — 하위호환)하고 `llm-smoke.yml` 주간 cron 에 mutation job 배선(secret 불요·항상 실행, MIN=55) — run-all 은 ~6분 부담이라 cron. `test-conventions-bash.md` §5 에 grep 앵커 tautology 규약(`grep -c '<앵커>' == 1`) + 실측 함정 3건 문서화(리뷰 규율, 자동 linter 는 정적 불가). ★ 리뷰가 이 게이트 자체의 hollow verification 2건 적발(testcmd 파손 시 100% 거짓 통과 → baseline sanity self-check, threshold 무테스트 → T15·16·17 추가). FID 20260714-mutation-ci-gate

## [1.45.0] — 2026-07-14

### Added
- **실행-근거 gate — 자기보고 면제 3경로 균일 조임** — R-1/R-2(commit·PR 전 verify) 게이트가 **자기보고만으로 열리던** 구멍을 막았다. 기존엔 session-progress 에 수기로 쓴 `/verify PASS` 줄 · evidence.md 스탬프 · Skill 호출 중 **하나만 있으면** 면제됐고, 셋 다 모델이 스스로 쓰는 텍스트라 사실상 자기발급 면제표였다. `governance-lib.sh` 에 `_verify_exec_evidence` 신설 — transcript 의 `tool_use` ↔ `tool_result` 를 `tool_use_id` 로 join 해 **검증 러너가 실제 실행되어 `VERIFY: PASS` 를 출력했는지** 확인하고, 3경로 **전부** 이 실행 증거를 요구한다. `VERIFY: PARTIAL`·`FAIL`·`is_error` 결과와 command-only 위조(`echo pytest`)는 불인정. 판정 불가(transcript 부재·jq 실패)는 fail-open 으로 기존 동작 유지. FID 20260713-verify-exec-gate
- **`run-verification.sh` 다언어 러너 확장** — 화이트리스트가 `bash scripts/*.sh` 만 실행하던 탓에 pytest·npm 프로젝트는 **항상 `VERIFY: PARTIAL`** 이었고, 실행-근거 gate 가 요구하는 PASS 증거를 구조적으로 낼 수 없었다. `pytest`(`python -m pytest` 포함) · `npm|pnpm|yarn (run) test` · `go test` · `cargo test` 를 **선두 앵커(`^`) 고정** 패턴으로 추가 — `echo pytest`·`foo && pytest`·`rm -rf / # pytest` 류 위장은 계속 SKIP. 한계 고백: `go test ./...`(`..` 가드) · `npm run test:unit`(`:`) 은 여전히 미지원. 실패 경로(`VERIFY: FAIL`)도 회귀 테스트로 영구 고정.
- **LLM eval sandbox 파일 시드 (`seed_files`)** — `maint-*`·`docs-1`·`new-4` fixture 가 실재하지 않는 파일(`scripts/slug.sh`·`README.md`)을 참조해, 모델이 파일 부재를 확인하고 정직하게 중단한 것을 eval 이 `got=none` → FAIL 로 오판했다. **PR #57 이래 "신호 감지 eval" 이 유지보수 신호를 한 번도 측정한 적이 없었다** (baseline 대조로 선재 결함 확정). `setup_sandbox` 에 `seed_files`(선택 필드) → sandbox 생성 + **git tracked**(모델이 `git ls-files` 로 확인) 추가. `test-llm-eval.sh` 에 fixture↔seed 정합 정적 검사(T16) 신설. `judge()` FAIL 사유 구분(`FAIL:skill`/`FAIL:flag`/…) — skill 을 맞혔는데 flag 로 떨어진 것을 skill 오답처럼 보이던 문제 해소. FID 20260713-eval-sandbox-seed

### Removed
- **`§auto` 무조건 면제 제거 (⚠️ 행동 변경 — 거버넌스 조임)** — `pretool-governance.sh` 가 spec.md 의 `**§auto**: true` 라벨만 보고 실행-근거 검사에 **도달하기도 전에** allow 하던 블록을 삭제했다. 그 라벨은 모델이 spec.md 에 쓰는 것이라, 무인 진입(`/start-auto`·`/start-all-auto`)이면 게이트가 통째로 무효화됐다. `§auto` 의 의미는 "가역 게이트 자동 통과"(사용자 확인 생략)이지 "검증 면제"가 아니다. 무인 모드도 chain 에 `verifying-evidence-ko` 가 있어 verify 를 실제 실행하므로 **정직한 무인 흐름은 실행 증거를 남기고 그대로 통과**한다(e2e·batch 회귀 PASS). 남는 면제 4종: `SPECOPS_GOVERNANCE_BYPASS=1` · docs-only · `.specops/` 부재(관할 한정) · fail-open.

### Changed
- **비-소프트웨어 요청은 lifecycle 에 진입하지 않는다 (⚠️ 행동 변경 — 진입 게이팅)** — "신제품 소개 PPT 12장 만들어줘"·"요구사항 정의서 작성해줘" 처럼 **repo 밖 산출물**만 만드는 자연어 요청이, 그동안 메타 skill 의 신호 감지("만들어줘")에 걸려 chain(spec→clarify→plan→implement→verify)에 통째로 포획됐다. **테스트할 코드가 없으니 후속 단계가 전부 공회전**했고, 실측 이탈 2건(`sales-ppt` PPT 12장 · `iken-webapp` 요구사항 133건)은 둘 다 spec 에서 사망 — 후자는 사용자가 Excel 로 이탈했다. 이제 이런 요청엔 **1줄 고지**("코딩 작업이 아니라 판단해 lifecycle 을 진입하지 않았습니다")와 **`/start <설명>` 강제 진입** 안내가 나간다 — 판정이 틀렸다면 슬래시로 즉시 뒤집을 수 있다(`/start` 는 무조건 직행. `commands/` 무변경 — slash SoT 불침범).
  - **무손상 — repo 내 파일은 진입 유지**: 코드·설정·스크립트·스키마는 물론 **README·CLAUDE.md 등 문서 수정도 그대로 chain 에 들어간다**("README 설치 안내 업데이트해줘" → 유지보수 진입). 문서만 고치려다 코드까지 건드리는 일이 흔해서다. 배제는 **명백할 때만**이고 **애매하면 호출**한다 — 진짜 코딩 작업을 놓치는 쪽(false-negative)이 과잉 발동보다 훨씬 나쁘다. "1% 가능성이라도 호출" 정신은 유지(**블랙리스트** — 화이트리스트 전환 아님). `specifying-ko` 의 "인지된 단순성과 무관하게 전부 프로세스를 거친다" 원칙도 무변경(chain 단축 없음).
  - **⚠️ 한계 고백 — 정적 통과는 실효 증명이 아니다**: 이 게이팅은 **산문이 LLM 을 설득하는 구조**다. 자동 테스트(`run-all` 94/94 · `test-meta-skill.sh` T6.a~d)가 증명하는 것은 **배제 문구가 존재한다**는 사실뿐이고, LLM 이 실제로 그렇게 행동하는지(**실효**)는 `bash scripts/tests/llm-eval/run-evals.sh` 로만 관찰된다 — **토큰 비용 때문에 run-all 비포함·수동 실행**이다. 신규 fixture 3건(`nonsw-1`·`nonsw-2` 배제 / `docs-1` 진입 유지 가드)을 그 수동 계층에 추가했다. 비결정론이 의심되면 `LLM_EVAL_RUNS=5` 로 성공률을 본다. FID 20260713-signal-coding-gate
- **문서 drift 화해 (3곳)** — (a) `CLAUDE.md` 거버넌스 엔진: 면제 서술을 4종으로 정정 + 실행-근거 gate 문단 신설. (b) `verifying-evidence-ko/SKILL.md`: "whitelist 미통과 (npm/pytest 등)" · "`bash scripts/...` 외 명령만 쓰면 **항상** PARTIAL" 이 다언어 확장 이후 **거짓**이 되어 실제 러너 목록·잔여 SKIP 형태·gate 연동으로 갱신. (c) `pretool-governance.sh` 근거 주석: `/implement` 의 **태스크별 중간 커밋은 verify 이전이라 실행 증거가 없어** 정직한 흐름이어도 deny→BYPASS 경로를 탄다는 설계된 비용을 명시(다음 독자 오도 방지).

### Fixed
- **유령 에이전트 서술 정정 + `xref_resolve` bare 토큰 확장** — harness skill 4종(`generator-evaluator-ko`·`sprint-contracts-ko`·`context-resets-ko`·`file-based-communication-ko`) + `advisor-ko` + `templates/` 가 **존재하지 않는 에이전트 6종**(`specifier`·`clarifier`·`planner`·`analyzer`·`task-decomposer`·`verifier`-ko)을 서술했다. `generator-evaluator-ko` 의 "Generator 4 / Evaluator 4" 는 **이름이 아니라 구조가 허구** — 명세·설계·분해·검증은 에이전트가 아니라 skill 이 메인 세션에서 수행한다. 실재 `agents/` 7종(Generator: `implementer-ko` / Evaluator: `spec-reviewer`·`code-reviewer`·`plan-reviewer` / self-config: `red-team`·`blue-team`·`auditor`)으로 교체. **근본 원인**: `xref_resolve` 가 `specops-ko:` prefix 토큰만 수집한 탓에 bare 로 서술된 유령이 검사망 밖이었다(93개 테스트 전량 통과의 원인). bare `-ko` 토큰 + `templates/` 스캔으로 확장하고 플러그인명·upstream 참조 4종 allowlist 로 오탐 차단. 원칙(Gen↔Eval 분리 — `role: evaluator` Write/Edit 박탈)은 무변경. FID 20260713-ghost-agent-drift
- **heredoc 본문의 git 예시를 실제 명령으로 오인하던 false-block 제거** — `grep -E` 가 줄 단위라 멀티라인 Bash command 의 heredoc 본문 줄(`cat > spec.md <<EOF ... git commit ... EOF`)도 R-1/R-2 트리거에 매칭됐다 → skill·plan·spec 에 git 예시를 쓰는 정직한 작업이 차단되고 BYPASS 남발을 유발해 실행-근거 gate 의 신호를 희석했다. `_strip_heredoc_bodies()` 로 트리거 검사 **입력만** 전처리(정규식 무변경 — evasion 방어 불변, 리터럴 바이트 동일). 셸 실행자(`bash`·`sh`·`eval`) heredoc 본문은 실제 실행되므로 제외하지 않아 **F-3 표면 불변**(우회 표면 19종 탐침·strip 이 진짜 커밋 숨긴 케이스 0건). 미종료·판정불가 시 원본 반환(fail-safe — 차단 우세). FID 20260713-heredoc-false-block

## [1.44.0] — 2026-07-13

### Changed
- **implementing-ko 모델 라우팅 섹션 drift 화해** — 커밋 97c672b("서브에이전트 모델 라우팅 고정 — 리뷰=fable·개발=opus") 이후 stale 했던 `## 모델 티어 라우팅` 섹션(tasks.md `tier:` 필드→부모가 model 파라미터 동적 결정, 미배선 dead spec)을 실제 고정모델 현실로 화해. `## 모델 라우팅 (역할별 고정)` 로 재작성 — implementer=opus·evaluator=fable·self-config=inherit frontmatter 단일 소스, 품질 편향(비용 다운그레이드 미채택) 명시, L231 오기(implementer inherit↔실제 opus)·BLOCKED "더 강한 모델" 모순 제거. wshobson/agents PluginEval 흡수 분석의 model-tier 항목이 이미 완료(97c672b)였고 doc drift 만 잔여였음을 반영. (#194)

## [1.43.0] — 2026-07-13

### Added
- **LLM eval N-run 신뢰성 측정 (`LLM_EVAL_RUNS`)** — wshobson/agents PluginEval Layer3(Monte Carlo) 아이디어를 bash 로 이식. 기존 `run-evals.sh` 는 fixture별 1회 실행(+retry cap=1)이라 확률적 LLM 동작의 flakiness 를 못 잡고 retry 가 오히려 은폐했다. `LLM_EVAL_RUNS=N`(N>1) 시 retry 없이 N회 반복 → per-fixture 성공률·FLAKY(<80%)·총괄 평균활성률 리포트(비차단 exit 0). 기본 N=1 은 기존 단발 동작 완전 무변경, 경계 케이스(`expect_any`)는 집계 제외. FID 20260713-llm-eval-nrun (#192)
- **SKILL.md 정적 밀도/bloat lint (T10)** — wshobson/agents PluginEval Layer1(BLOATED_SKILL·OVER_CONSTRAINED) 이식. `test-skill-conventions.sh` 에 (a) bloat(>800줄, specops "800 max" norm — e2e-test-ko 문서화 예외) 예외 밖 FAIL 회귀가드, (b) 디렉티브 밀도(`discipline: true` 제외, 임계 25) 초과 시 INFO(FAIL 아님) 추가. 임계를 현 최댓값(22) 위로 두어 현재 0건 flag·미래 폭증만 포착 — OVER_CONSTRAINED 판단은 `discipline: true` marker 를 통해 사용자에게 남긴다. FID 20260713-skill-density-lint (#193)

### Changed
- **CLAUDE.md 서브시스템 3영역 반영** — 최근 대형 서브시스템(self-config 적대감사 red/blue/auditor·design-first 대칭 Step 5.5/5.6·학습 루프 gbrain/freelog)을 CLAUDE.md 에 문서화 (#191)

## [1.42.0] — 2026-07-12

### Added
- **화면(UI) E2E 검증 루프 폐합 — DB lifecycle 대칭 (감사 P1+P2)** — 화면(screens)이 design-first(Step 5.5)로 그려지고 구현자 전달까지만 닫히고 사후 검증(분해·리뷰·verify·게이트)이 비어 UI 웹앱이 브라우저 무검증으로 PR 통과하던 3중 비대칭을 DB lifecycle(#152) 패턴으로 대칭 복제해 폐합. verifying-evidence 역방향 net 에 screens/ 대조, code-reviewer UI/화면 관점(조건부), integration-test UI/사용자흐름 detection 신호(기존 백엔드 OR 유지), performance-test Web Vitals(LCP/CLS/FCP) 신호 추가. UI 표면 검출 시 downstream 스택(Playwright/Cypress) E2E 위임(e2e-runner 선택적·Step 2 env-check 재사용). **detection·delegation 은 플러그인 강제, 브라우저 E2E execution 은 downstream/manual**(플러그인 인프라 부재 — advisor: e2e-runner 하드 dispatch 기각, 사용자 전역 에이전트라 aspirational). 4 신호를 계약 테스트 `test-ui-e2e-signals.sh`(앵커 리터럴 + reverse-observe)로 잠금(aspirational 방지). FID 20260712-ui-e2e-loop-closure (#189)

## [1.41.0] — 2026-07-12

### Fixed
- **테스트 인프라 false-PASS/silent-skip 봉쇄 (테스트 영역 감사 P1·P2)** — 3각도 테스트 감사가 되돌려-관찰로 실증한 "조용한 거짓 통과" 표면 3건 근본 봉쇄:
  - **gbrain tautology + harness canary (P1, #185)** — `test-gbrain.sh` T2.b·T2.c 가 `bash -c` 블록 마지막 `rm`(항상 exit 0)에 grep 판정을 삼켜 프로덕션을 망가뜨려도 통과하던 tautology 를 판정-캡처(rc→rm→exit rc)로 정정. `harness.sh:5` 오파일명 canary(복붙 시 source-실패 false-PASS 유발) 정정. FID 20260711-test-gbrain-tautology
  - **harness 로드 가드 (P2-①, #186)** — harness source test 가 함수 로드 실패 시 카운터 미증가로 0 assertion 인데 조용히 exit 0 하던 구멍을, source 다음 줄 로드 가드(`command -v finish || exit 1`) 34개 삽입으로 봉쇄. finish 표준화(감사 원안) 대신 로드 가드 채택(advisor 협의 — tail 무접촉·계약 테스트 강제력). 계약 테스트 `test-harness-load-guard.sh`. FID 20260711-harness-load-guard
  - **run-all glob 완결성 계약 (P2-②, #187)** — run-all aggregator 가 test 서브디렉토리를 for 루프에 하드코딩 편입해 미등록 subdir 에 test 추가 시 조용히 스킵하던 구멍을, 완결성 계약 테스트(find 실제집합 ⊆ run-all for-루프 grep 커버, run-all 단일 SoT)로 봉쇄. run-all 실행 경로 무접촉(advisor 협의 — 릴리즈 게이트 불안정화 방지) + L4 stale 주석 정정. `test-run-all-glob-completeness.sh`. FID 20260712-runall-glob-completeness

## [1.40.0] — 2026-07-11

### Added
- **batch 오케스트레이터 런타임 커버리지 (G0 해소)** — `/start-all` batch 상태기계를 2층으로 검증: ① 무료·상시 결정적 시뮬 `scripts/tests/test-batch-orchestration.sh`(queue 초기화·PLAN_DONE 전이·재진입 보존·batch-state 게이트 통합, start-all.md 근거 라인 주석 의무) ② 유료·수동 e2e `[S8] BATCH`(격리 repo Phase 0~1 실주행·§batch halt·완료 게이트 실증, V22~V24). e2e V 개수 21→24 동기. start-all 감사 G0 해소. FID 20260711-g0-batch-e2e (#182)

### Fixed
- **TDD RED 증거 규약 강화 (감사 P1 3건)** — TDD 3각도 감사에서 RED 관찰이 카운트 요약 주장에만 의존(실증 7 FID 중 raw 출력 인용 0, GREEN 과 비대칭)함을 확인. 앵커 규약 `RED 실측 출력`·`FAIL 라인 ≤10줄` 을 5소비처(tdd-ko 합리화 차단표·implementer-ko·verifying-evidence·dispatch-context 의무표·tasks.md 스텝2)에 배선하고 문구 계약 테스트 `test-tdd-red-evidence.sh`(15케이스)로 상시 잠금. templates/tasks.md test_command "optional" 모순 정정(emit-context 게이트 SSOT) + implementer-ko 죽은 "git log 증명" self-check 교체. FID 20260711-tdd-red-evidence (#183)

## [1.39.1] — 2026-07-11

### Fixed
- **전체 점검 P3 Low 10건** — 분석 단계 advisor 계약 실배선(impact-analysis §4 신설 + R-5 죽은 타깃 impact-analysis.md 교체) · init 종료 안내 이음새(/start-foundation·/design-screens·/design-interfaces·/status) · Phase 8e 클라이언트 스토리지 안내 · design-interfaces 커밋 참조 · agents drift 3건 · generator-evaluator 잔재 · start-all 문서 3건 · README R-6 정정 (#181)

## [1.39.0] — 2026-07-11

### Added
- **`scripts/batch-state.sh` — 첫 batch 인프라** — `/start-all` queue↔requirements parity read-only 감지(미완·드리프트·FR-ID 중복, 2-테이블 분할 queue 견딤). Phase 3 완료 하드 스캔 게이트 배선: exit 1 → "그래도 batch PR? [y/n]"(의도적 부분 진행 허용 — 주권), §auto 무인 정지점. 실물 batch 산출물에서 드리프트 5건+미완 3건 검출 실증. start-all 감사 F-4·F-5 해소. FID 20260710-p2-batch-state (#180)

### Fixed
- **전체 점검 P1 — 경계면 전파 누락 5건** — ① DESIGN.md 템플릿 Border 행(9색 헬퍼 no-op 해소) ② Phase 7 html `{{화면 제목}}` 치환 ③ 가정 다이제스트 "자동 결정 인터페이스" 3소비처 수집 ④ verify 역방향 안전망 클라이언트 스토리지 커버 ⑤ README `/design-interface(s)` 반영+footer 3커맨드 (#178)
- **P2 규약 3건** — Phase 11 그룹③ 팔레트 재주입(미편집 단서) · data-model §1 하이브리드 복수 표기 · Step 5.6 인터페이스 dedup (#180)

## [1.38.0] — 2026-07-10

### Added
- **인터페이스 설계 클라이언트 스토리지 축** — Step 5.6(=start-all batch·단일 /start 공용) + `/design-interface(s)` 독립 슬래시에 "클라이언트 영속 데이터(localStorage·IndexedDB)" 축 추가. 기존 2축(제공 HTTP API / 외부 소비 API)만으로 skip 되던 서버 없는 프론트 앱(예: weekflow)도 화면 Interactions·requirements FR 이중 근거로 `data-model.md` 자동 도출. HTTP api-spec 무변경(혼입 금지), 순수 UI·CLI 로직은 skip 유지(비확대). 라우팅 정합 15케이스. weekflow dogfooding 실결함 발견→수정. FID 20260710-if-client-storage-axis (#177)

## [1.37.0] — 2026-07-10

### Added
- **`/design-interface(s)` 인터페이스 설계 독립 슬래시** — 화면 `/design-screen(s)` 대칭. 무스크립트 대화 루프로 `api-spec.md`·`data-model.md` 마스터 섹션 갱신(덮어쓰기 금지), 화면 `Interactions`→API 도출(design-first 결합), 제공/소비 API 구분, 3경로 분업 cross-ref + `test-interface-routing-doc.sh` 정합 검증. FID 20260710-design-interface-slash (#176)
- **Phase 11 v2 — 인터뷰·가정 다이제스트·깊이 기준** — 그룹별 사전 인터뷰(상한·결정급 우선·"모름/나중에"·질문 스킵)로 비약(미질문 가정) 차단, 가정 전건 번호 목록+★ 게이트·PRD 말미 다이제스트 기록으로 투명화, 최소 깊이 기준 v2(must 빈 셀 금지·M1 FR 분해 / should NFR 수치)로 허접 차단, 무인 degrade(e2e·§auto). enrich 스위트 44케이스. FID 20260710-init-p11-quality (#174)

### Fixed
- **init-project 화면 스캐폴딩 DESIGN.md 팔레트 미반영** — Phase 7·`design-screen.sh` 가 DESIGN.md 색상을 반영 안 하던 것(Phase 7=0색, design-screen=Primary만)을 공유 `_inject_design_palette` 9색 매핑 헬퍼로 해소(미확정 색은 skip→기본값 유지). FID 20260710-init-p11-quality 계열 (#175)
- **session-progress 첫 append 오염** — 신규 프로젝트 첫 lifecycle 커맨드 시 rehydrate 블록에 템플릿 예시가 딸려 들어가던 잔여 결함(#172 후속)을 안내문·예시를 삽입 anchor 위로 이동해 해소. 회귀 테스트는 실 파이프라인으로 생성 (#173)
- **V21 placeholder 스캔 규약 표기 allowlist** — `.specops/<FID>`·`screens/<name>` 류 규약 표기를 placeholder 로 오검출하던 것을 스캔 SoT(`scan-enrich-placeholders.sh`) allowlist 로 해소 — 정직 보강과 양립 (#171)

## [1.36.0] — 2026-07-09

### Added
- **init-project Phase 11 LLM 보강 패스** — bash 10 Phase 종료 후 LLM 이 13종 산출물을 개발 기준 문서 수준으로 보강 (그룹 3묶음 승인 + 사실성 계약 + 재커밋). 브레인스토밍 메모 존재 시 PRD 6필드 초안 합성. `--enrich` 소급 경로 (placeholder 잔존 문서만 — 멱등). e2e V21 placeholder 스캔. 계약 스캔 테스트 `test-init-project-enrich.sh` 신규. bash 레이어 0 diff. FID 20260709-init-project-llm-enrich

## [1.35.0] — 2026-07-06

### Added
- **서브에이전트 모델 라우팅 고정** — 서브에이전트 단계의 모델을 명시 고정(메인루프 스킬은 `/model`이 지배하므로 대상 밖). `implementer-ko`(개발+TDD 5스텝) `inherit → opus`, `code-reviewer-ko`·`spec-reviewer-ko`·`plan-reviewer-ko`(리뷰) `inherit → fable`. 메인루프(브레인스토밍·specifying·analyzing·planning·verify)는 세션 `/model` 따름. `red/blue/auditor`(security-scan 감사)는 스코프 밖 inherit 유지. PR #169

## [1.34.1] — 2026-07-03

### Fixed
- **init-project 생성 문서의 오인 예시·자기모순·유령행 정리** — 라이브 부트스트랩 산출물 내용 검토에서 발견한 3결함. **A**: `data-model`(`users`/`orders`/`products`)·`api-spec`(`/v1/users`)이 프로젝트 무관 e-commerce 예시인데 placeholder 마커 없어 실제 설계로 오인 소지 → "예시 — 실제 도메인으로 교체" 경고 배너(architecture/front/back은 `<Redux/Zustand>` choice-placeholder라 이미 자명, 미대상). **B**: `requirements` FR 표·§5 마일스톤 매핑이 seed(FR-N↔M-N 1:1)와 어긋나 FR-4 유령행·§5 오매핑(M2→FR-3) → seed 1:1 모델 정합 + FR-4 제거. **C**: `screens-overview` §2 전이도·§5 인증표가 fence 밖이라 입력 안 한 `dashboard`(미존재 화면) 고착 → §1 실측과 자기모순·dangling 링크 → 예시 배너 + 화면명 placeholder화. 데모 재생성 실측 검증, test-init-project 31 PASS. PR #168

## [1.34.0] — 2026-07-03

### Added
- **skill-body 게이트 결정적 회귀 인프라** — 유료 llm-smoke CI(secret 미등록 도먼트)에 의존하지 않고 recurring 결함 클래스(teeth in body, 강제 인프라 소실)의 **구조적 절반**을 무료·결정적으로 봉쇄. ① `validate-structure.sh` 신규 검사 `contract_consistency`(#15): cross-skill `BATCH-*-DONE` halt signal 의 방출(skill)↔감시(orchestrator) 정합 + suffix 일치 검사 — `<BATCH_ID>`↔`<FID>` drift·고아 signal 을 LLM 없이 CI 차단. ② `scripts/tests/test-gate-presence.sh`(9 assertion, run-all 자동편입): skill-body HARD GATE 문구 소실 회귀 — foundation 3-지점 계약(verify 생산 게이트·decomposing 소비 게이트·planning 강제 cross-ref)·경로 정합·BATCH 5신호 방출측. red-green 검증. PR #167

### Fixed
- **lifecycle 단계별 실측 결함 7건** — 신규 프로젝트 lifecycle 6단계 검증에서 발견·수정. **brainstorming**: Q0 라우팅↔자가점검 고정참조 역설(유료고객 경로가 항상 반려)·한글 slug `tr -cd` 전삭제→`scripts/slug.sh`(국립국어원 로마자) 교체. **init-project**: `api-spec-consumer.md` 가 배열 밖이라 git add 누락(고아화)→`git add .specops/memory`·constitution skip placeholder 누출 가드(T1.b 회귀). **start-foundation**: `foundation-manifest.md` 생산이 산문 지시뿐이라(강제 evaluator 부재) 후속 `/start` 재사용 게이트가 침묵 no-op 되던 구조 결함 → `verifying-evidence-ko` HARD GATE 신설(Mode1 태스크누락·Mode2 파일미작성 동시 차단). **start-all**: batch-level halt signal suffix drift(`<BATCH_ID>`↔`<FID>`) 정합. **release**: 문서가 실제 자동 push+GitHub Release 동작을 오도하던 것 정합. **specifying-ko**: Q5+ 명확화 위임을 spec.md §8 구체 기재로 명시(clarifying 경량분기 오판 차단). PR #165·#166

## [1.33.0] — 2026-07-03

### Added
- **LLM chain 저비용 CI (A층+B층)** — `.github/workflows/llm-smoke.yml` 주 1회 cron + workflow_dispatch 로 신호감지 대표 6 fixture smoke (~$3/회, `ANTHROPIC_API_KEY` secret 부재 시 graceful skip, 실패 시 issue 자동 통보 + FAIL 요약·redaction). `run-evals.sh` 완주 스탬프(`.specops-cache/llm-eval-last-run`, `LLM_EVAL_STAMP_DIR` 테스트 격리) + `release.sh` pre-flight staleness soft 경고(7일). red-green T8.a~d·T18.a~c. C층(월간 e2e cron)은 설계 기록만 — 사용자 후속 결정. FID `20260702-llm-smoke-ci`
- **chain 단일 source + 정합 게이트** — `hooks/chain.yaml` 이 lifecycle primary edge 의 Source of Truth 로 신설. `validate-structure.sh` 신규 검사 `chain_consistency`(#14) 가 21개 SKILL.md `## 다음 skill` 코드블록·메타 skill 화살표 목록과의 drift 를 양방향 적발 (edge 좌표 명시 FAIL). #150~153 전파 누락 4회 재발 클래스 차단. red-green T14.a~f (drift 4방향 + pyyaml SKIP + yaml 파손). FID `20260702-chain-single-source`

### Changed
- **critic-ask advisor 백엔드에 claude 최우선 추가** — `critic-ask.sh` provider 감지에 `claude` CLI 를 최우선(CRITIC_BIN 다음)으로 배선. 모델은 `fable` 우선·`opus` fallback(`--fallback-model`, `CRITIC_CLAUDE_MODEL`/`CRITIC_CLAUDE_FALLBACK` override). 기존 ollama 기본 모델(`qwen2.5:7b`) 불일치로 advisor fallback 이 사실상 죽어있던 문제 해소 — claude code 사용자는 claude CLI 를 항상 보유하므로 advisory critic 이 실동작. red-green T-claude 1~3.
- **하드코딩 목록 → frontmatter marker 역방향 스캔** — `validate-structure.sh` agent_tools 가 reviewer 3종 리터럴에서 `role: evaluator` marker 스캔으로 전환 (red/blue/auditor 편입 — 6종, `*reviewer*` 미마킹 2차 방어 + 마킹 0건 공회전 방지). `test-skill-conventions.sh` T9 가 discipline 3종 리터럴에서 `discipline: true` marker 스캔 + 하한 3 으로 전환. 신규 evaluator/discipline 항목은 marker 만 달면 자동 검사 편입 (T9 completeness Known-Limited 해소). red-green T15.a~d·T9.r/s. FID `20260702-marker-reverse-scan`

## [1.32.3] — 2026-07-02

### Changed
- **Superpowers 코멘트성 언급 제거 (21파일 29건)** — skill 본문 산문·`## 참조` upstream 링크 라인·footer stamp·메타 skill description 괄호·템플릿 예시 경로(`docs/superpowers/...`)·템플릿 HTML 주석에서 Superpowers 표기 제거. **인프라 데이터는 유지**: frontmatter `reference_upstream:`(validate-structure·diff-upstream 소비), `docs/upstream-drift-log.md` 자동 생성 기록, CHANGELOG 과거 릴리즈 노트, `.specops-cache/upstream/`. 기능 무변경 — 사용 중 노출 표면만 정리.

## [1.32.2] — 2026-07-02

### Fixed
- **2026-07-02 전체 감사 잔여 LOW 5건 일괄 처리** — ① `test-shellcheck-lint.sh` 신설: CI 전용이던 `shellcheck -S error` 게이트의 로컬 run-all parity(미설치 시 graceful SKIP) — 로컬 green 후 push 에서 최초 발각되던 비대칭 해소. ② `_replace_token` 토큰(LHS) BRE 메타문자 escape — `.` any-char 오매치·`*[]` 미매치·`|` 구분자 파손 차단, `test-init-lib-token.sh` 5케이스 red-green. ③ `diff-upstream.sh` trap EXIT — 중단 시 임시파일 6종 잔류 방지. ④ used_by frontmatter 정합 2건 — `systematic-debugging-ko` 에 security-review-ko FAIL 분기 추가, `advisor-ko` 를 실배선 기준(ambient + planning-ko 실호출)으로 정확화. ⑤ 훅 표기 정밀화 — CLAUDE.md·README "훅 4종" → 거버넌스 4종 + Notification 보조 1종.
- **Stop 훅 `.specops` symlink 가드 대칭화 (#144 잔여)** — `log_friction` 계열에만 적용됐던 write-through path-escape 가드를 같은 Stop 계층의 나머지 `.specops` writer 2곳에 전파. `freecomment-capture.sh`: `.specops` 디렉토리·`pending-capture.jsonl` 파일 symlink 시 append 거부(safe_exit). `ensure-session-progress.sh`: `.specops` 디렉토리·`session-progress.md` dangling symlink 시 write 거부(조용히 exit 0). 악성 repo 가 symlink 를 심어 repo 밖 파일에 쓰게 만드는 벡터 차단 — 한 세션 안에서 log_friction 은 거부하는데 다른 writer 는 관통하던 자기모순 해소. 회귀 테스트 4케이스(T5.a/T5.b, T1.f/T1.g) red-green.
- **`validate-context.sh` §3 fence 상태 추적 결함** — 닫는 ``` 가 `(bash|sh)?` 빈 매치로 여는 패턴에 걸려 `in_b=0` 규칙이 죽은 코드였음. 빈 코드블록 뒤 산문이 테스트 명령으로 오인돼 실제 명령 없는 dispatch context 를 거짓 PASS 하는 검증기 soundness 결함. fence 상태 토글 + bash/sh/bare 여는 fence 만 캡처로 교체. 회귀 테스트 T5.a(산문 누출 차단)·T5.b(비-bash fence 미인식) red-green.

### Docs
- **2026-07-02 전체 감사 문서 drift 4건 정정** — README 커맨드 자산 트리에 `promote.md`·`status.md` 누락 2건 추가(헤더 19건 ↔ 열거 17건 불일치 해소). README 템플릿 분해 산문에 v1.32 신설 `api-spec-consumer`(init-project 12→13)·`freework`(Lifecycle 18→19) 반영(합계 32 유지). CONTRIBUTING 테스트 카운트 stale 정정 — 구조검증 `12/12 OK`→`전 항목 ✅`(실제 14항목·N/N 총계 미출력), 거버넌스 `PASS=72`→`FAIL=0` 표기(실측 74, brittle 고정숫자 회피). `docs/upstream-drift-log.md` validate-structure 경로 `scripts/`→`scripts/_internal/` 정정.

## [1.32.1] — 2026-07-02

### Fixed
- **`emit-context.sh` §6에서 `api-spec-consumer.md` 제거** — 소비자 IF는 init-time·KIND-gated 1회 생성 문서(per-feature 아님). §6 per-feature 계약 목록에 포함 시 specifying-ko Step 5.6·verifying 역방향 안전망과 3-way 불일치 발생. `frontend-architecture.md`와 동일 패턴으로 §6 제외.

## [1.32.0] — 2026-07-01

### Added
- **`/init-project` Phase 8g — 소비자 IF 템플릿(`api-spec-consumer.md`) 신설** — KIND 1(UI)·5(Mobile)에서 외부 API 소비 계약 문서를 y/N 프롬프트로 조건부 생성. `templates/api-spec-consumer.md` 신설(소비 서비스 목록·의존 엔드포인트·실패 처리 전략). `specifying-ko` 부재 가드에 소비자 분기 명시. `templates/CLAUDE.md`·`frontend-architecture.md` 인덱스 업데이트. `test-init-project.sh` T1.a 수정 + T15.a(consumer=y 케이스) 추가.

### Changed
- **commands frontmatter 스키마 위생** — `log.md`·`release.md`·`statusline-install.md` 3개 파일에 누락 필드 추가. `log.md`: `triggers·mode·specops_version·specops_layer·reference_upstream·footer` 신설. `release.md`: `specops_layer·reference_upstream` 추가. `statusline-install.md`: skills 포맷(`layer·used_by`) → commands 포맷(`triggers·mode·specops_layer`) 변환·footer 추가. 런타임 무영향.

## [1.31.0] — 2026-07-01

### Fixed
- **`_verify_passed_in_progress` 타임스탬프 비교 전환 — prepend 불변식 의존 제거** — 기존 줄 번호(`vline < cline`) 비교가 session-progress 작성자가 내림차순(prepend) 대신 오름차순으로 기록할 경우 false-allow를 유발하는 구조적 취약점. `YYYY-MM-DD HH:MM` 전체 타임스탬프 추출 + `sort -r | head -1`(max) 비교로 교체. 날짜경계(23:59→00:00) 자동 처리. 동률(same-minute) → 안전측 `return 2`(deny). 행 선두 앵커(`^- YYYY-MM-DD HH:MM /command`)로 memo 자유텍스트 날짜 오염 차단. `test-verify-progress.sh` T-H2a/T-H2b/T-H2c 3케이스 추가(줄순서↔타임스탬프 불일치 시 타임스탬프 기준 판정 검증). 기존 T1~T13 전체 회귀 없음.

## [1.30.0] — 2026-07-01

### Fixed
- **`diff-upstream.sh` plugin_root 경로 계산 오류** — `scripts/_internal/` 하위에서 실행 시 `dirname` 1회 적용으로 `scripts/`를 repo root로 오인하던 버그. `cd "$script_dir/../.."` 2단계 상위로 수정. struct=0→21, manual=0→26 정상 산출. 테스트 sandbox 경로도 동일하게 수정 (T2~T7 PASS). (#155)

### Added
- **`writing-skills` 방법론 흡수 — failure-first + rationalization table 3 인프라 동시 전파** — superpowers upstream drift 점검에서 rationalization 섹션 대거 추가 확인(실증 근거). 신규 skill 추가 없이 기존 3 인프라에 teeth 동시 전파(aspirational-without-enforcement 방지): `CONTRIBUTING.md` Skill 작성 방법론 신설, `templates/SKILL.md` 합리화 차단표 섹션 양식 추가, `test-skill-conventions.sh` T7/T8 형식 게이트. `using-git-worktrees-ko` 적색 플래그 누락 항목 보강(EnterWorktree native tool 우선, upstream v5.1.0). (#156)

### Refactored
- **discipline-class skill 합리화 차단표 헤딩 통일 + T9 gate** — `## 흔한 합리화`(systematic-debugging-ko, tdd-ko), `## 합리화 방지`(verifying-evidence-ko) → `## 합리화 차단표` 통일. `test-skill-conventions.sh` T9: 3종 discipline-class skill 합리화 차단표 섹션 존재 강제 게이트. T1~T9 10개 체계 완성. (#157)

## [1.29.0] — 2026-06-30

### Added
- **인터페이스 design-first 대칭 — `specifying-ko` Step 5.6 신설** — 화면(Step 5.5)처럼 인터페이스(API 엔드포인트·DB 스키마)도 구현 전 `api-spec.md`·`data-model.md` 에 **먼저 설계 반영**한다. 그간 화면만 design-first(Step 5.5)이고 인터페이스는 설계 단계 없이 구현→방치되던 비대칭 해소. 보조로 `verifying-evidence-ko` 에 **역방향 안전망**("memory 설계 동기화 점검") 추가 — 구현(`git diff`)을 inspect-first 로 읽어 memory 문서와 괴리 감지 시 evidence.md 에 권고 기록(자동수정 금지, chain 비차단). 산출물이 init 골격 후 stale 되던 lifecycle 단절 해소. (ecc inspect-first 메커니즘 차용, SI design-first 철학 유지) (#150)
- **self-config 적대감사 번들 범위 확대** — `self-config-collect.sh` 가 `agents/*.md`·`scripts/_internal/**` 표면까지 흡수(44→90 표면). 1차 감사 미수집 4종(kill-switch·agents·statusline·init-project) 수집. TDD 회귀 `T1.e2~e6`. (#141)

### Fixed
- **3 진입점 검증 잔여 7건** — #153 후속 마무리(MED 2 + LOW 5): ① CLAUDE.md 템플릿 `frontend-architecture`·`screens-overview` 가 `(UI/풀스택만)` → 실제 게이트 Mobile(5) 포함 정정 `(UI/풀스택/모바일)` ② `decomposing-ko` 마이그레이션 트리거를 `data-model.md` 존재 → **plan.md DDL 표면**으로 확장(미부트스트랩 `/start-auto` DB 기능서 reverse/test 없이 진행되던 구멍 차단) ③ data-model.md 헤더 `## N` → `## §N`(api-spec·인용처 §N 정합) ④ init Phase 8e/8f `_should_skip` 선검사(resume 시 불필요 프롬프트 회피, 타 phase 와 정합) ⑤ foundation 흐름도 노드에 Step 5.6 명시 ⑥ 유지보수 분기에 스키마/API 수정 시 Step 5.6 + AC-R-2 연계 명시 ⑦ `maintain.md` 사용 예에 analyzing-ko 단계 삽입(stale 정정). (#154)

- **3 진입점 검증 — design-first 인프라 전파 결손 4건** — init/start/maintain chain 병렬 검증으로 발견: #150~152 가 skill body 만 강화하고 의존 인프라(템플릿·자동생성기·게이트)에 전파를 누락해 teeth 가 aspirational 이던 것 실배선: ① **trivial 게이트 데이터손실 우회** — `analyzing-ko` trivial 판정(≤5줄)이 파괴적 스키마(`ALTER DROP`)를 우회해 §2 롤백분석·AC-R 면제하던 것에 **스키마 override**(스키마 변경 시 라인수 무관 비trivial) ② **impact-analysis 템플릿 전파** — expand-contract·코드롤백≠데이터롤백·data-down 보존 필드를 §2 템플릿에 영속(고아 inline 해소) ③ **회귀 AC-R-2** — 데이터 보존·역가역성(up→down→up 멱등) 회귀 AC 스텁(스키마 변경·override 시 강제) ④ **implementing 계약 dispatch 실배선** — `emit-context.sh` 가 설계 산출물 존재 시 dispatch 컨텍스트 **§6 설계 계약**에 경로 자동 emit(부재 시 graceful), `implementing-ko` 후진 teeth 가 병렬/자동 경로서 실제 도달(TDD `T1.f/g`). (#153)

- **DB 테이블 설계→구현 lifecycle 결손 3건** — 독립 분석으로 발견: 설계(data-model design-first)는 #150/#151 로 됐으나 "설계 이후"가 비어 있던 것 보강. ① **마이그레이션 흐름 부재** — `decomposing-ko` 에 마이그레이션 **forward+reverse 태스크 쌍** 분해 패턴 추가(up/down·멱등 테스트·DDL 도구 규약, 단순 "비가역 격리"에서 격상) ② **DB 전문 리뷰 부재** — `code-reviewer-ko`(Phase C) 에 조건부 **DB 스키마 관점**(인덱스·FK ON DELETE·N+1·정규화·data-model↔DDL 정합) 추가 ③ **데이터 손실 롤백** — `analyzing-ko` §2 가 스키마 변경 롤백을 `git revert`(코드만)로 답하던 것을 **코드 롤백 vs 데이터 마이그레이션 down 구분** + expand-contract 안전 패턴 명시(`ALTER DROP` 데이터 복원 불가 경고). (#152)

- **인터페이스 design-first 배선 결함 7건 (#150 follow-up)** — 적대 검토(Generator↔Evaluator 분리)로 #150 의 미완성 배선 발견·수정: ① **verify 안전망 무력화** — `/implement` 태스크별 커밋으로 working-tree 클린 → bare `git diff` 빈출력 → 항상 통과하던 것을 `git diff base...HEAD`(R-2 동일 패턴)로 수정 ② **foundation 분기 Step 5.6 미배선** — DB 스키마 본진이 design-first 미적용이던 것 배선 + §2 DAG/data-model 역할 경계 명시 ③ **design-first 강제력** — `implementing-ko` 에 "설계 계약 준수"(screens·api-spec·data-model 화면·인터페이스 대칭) 후진 teeth 추가 ④ **§auto·흐름도가 Step 5.6 우회** — §auto 화면 블록 Step 6 직행 수정 + 프로세스 흐름도에 5.6 노드 추가 ⑤ **§auto 부재 가드** — 무인 마스터 문서 임의생성 금지 + batch append-only ⑥⑦ 추출 기준·섹션 표현 통일. (#151)

- **self-config 감사 잔여 backlog 처리** — 2026-06-30 `/security-scan --self-config` 실전 감사(등급 D) 후속 fix 묶음:
  - SessionStart rehydrate 신뢰경계 펜스 — untrusted-repo `session-progress.md` 자동주입을 `<untrusted-repo-content>` 태그로 래핑(R5). (#142)
  - `log_friction_sev` 디렉토리 symlink 가드 대칭화 + verify-stamp 면제 불변식(vp=1 전용·vp=2 불가침) characterization 잠금(R6·N1). (#143)
  - `friction-log.jsonl` **파일** 자체 symlink append 가드 — 디렉토리만 검사하던 사각 보강, 양 함수 `[ ! -L ]` 대칭. (#144)
  - untrusted-repo 출력 위생 — statusline `step`/`status` 제어문자 strip(ANSI escape injection 차단) + `phases-artifacts.sh` raw sed→`_replace_token`(N5·N6). (#145)
  - posttool R-3 trigger 패턴 `rules.jsonl` 단일소스화(하드코딩 drift 제거) + 감사 에이전트 Bash 행동계약 명문화·auditor description 정직 정정(R8·N2·N3). (#146)

## [1.28.0] — 2026-06-29

### Added
- **gbrain confidence scoring — ecc instinct 흡수** — `gbrain-append --confidence low|medium|high` enum 옵션으로 learnings 레코드에 조건부 `confidence` 필드(미지정 시 생략 — 기존 ~120 레코드 graceful). `gbrain-recall` score 동점 시 confidence 가중(high=3/medium=2/low=1/미지정=0) tiebreak + 표시, `gbrain-ko` 조회 출력 렌더. confidence 는 **표시·정렬 보조만** — `/evolve` skill 자동생성·임계 자동승격은 흡수 금지(메타플러그인 무결성). 회귀: recall 탭 평탄화(jq `$txt|gsub`) + 테스트 mktemp 가드. (#139, #140)
- **`SPECOPS_GOVERNANCE_PROFILE` 프리셋 (minimal/standard/strict) — ecc #4 흡수** — `is-hook-enabled.sh` 에 ENV 프리셋 분기. minimal(pretool+session-start)·standard(4 훅)·strict(6 훅). **minimal 도 R-1/R-2 hard-block 유지**(거버넌스 해자 보존). pyyaml 독립 bash case. (#137)

### Changed
- **advisor-ko 이종 백엔드 자동 fallback 확대 — omc #2 경량 흡수** — `critic-ask` 연결지점 2→5곳 + 미연결 시 자동 fallback 트리거. advisor 미연결 환경에서도 graceful. (#136)

### Fixed
- **R-1/R-2 verify 면제 방어 보강** — R-1 면제가 verifying-evidence-ko skill transcript 패턴에 강결합돼 직접 verify(skill 우회) 시 false-block 하던 결함 수정. `run-verification.sh` 의 `RUN-VERIFICATION-RESULT` evidence stamp 를 보조 면제 신호로 추가 + `_verify_passed_in_progress` **3-state**(0 유효/1 inconclusive/2 affirmative-stale). stamp 면제는 vp=1 만, vp=2(stale)는 stamp 무시 차단(거짓면제 0, T39 보존). (#138)

## [1.27.0] — 2026-06-29

### Added
- **`/security-scan --self-config` 모드 — ecc AgentShield 흡수** — 플러그인 **자기 설정**(`hooks/*.sh`·`skills/*/SKILL.md`·`rules.jsonl`·`plugin.json`·`settings`)을 red/blue/auditor 3 서브에이전트 적대추론으로 on-demand 보안감사. `collect → red → blue → auditor` CHAIN, risk 등급(A~F). 그간 수동 심층감사(PR #129/#130/#134)로 메우던 사각지대 자동화. (#135)
- **`scripts/self-config-collect.sh`** — 자기 설정 표면 read-only 번들. 공백 경로 안전(`-print0` + process substitution), `.claude-plugin/plugin.json` 마커 부재 시 거부(임의 경로 차단).
- **`agents/red-team-ko`·`blue-team-ko`·`auditor-ko`** — 적대감사 3종. `tools: Read/Grep/Glob/Bash` read-only 불변식(Write/Edit 미보유 → 거버넌스 훅 충돌 0). 회귀 테스트 `test-self-config-collect`(공백경로 포함)·`test-self-config-agents`.

### Design
- ecc AgentShield 의 red/blue/auditor 적대 파이프라인은 specops 의 **Generator↔Evaluator 분리 철학과 동형**이라 자연 흡수. on-demand 전용(토큰 비용 관리), 기존 `/security-scan` SAST/DAST 무변경.

## [1.26.5] — 2026-06-27

### Security
- **`.specops` symlink path-escape 차단** — `.specops` 가 symlink 면 `mkdir -p .specops` 가 OS 따라 외부 dir 타겟에 friction-log·session-progress 를 write-through(악성 repo clone 시 정보 누출·파일 clobber)하던 표면 차단. `governance-lib` 의 `log_friction`·`log_friction_sev` + `session-progress-append.sh` 진입에 symlink 거부 가드(`_specops_dir_safe`). 정상 dir 영향 0. 회귀 테스트 `test-lib` T-symlink 추가. (심층감사 보안 M-A)
- **ui-ux-pro-max 의존 상한 핀** — `>=2.0.0` → `>=2.0.0 <3.0.0`. cross-marketplace hard dependency 의 major breaking 릴리즈 자동 신뢰 표면 축소(공급망). (심층감사 보안 S-1)

### Changed
- **테스트 헬퍼 공통화 (DRY) — `scripts/tests/harness.sh` 신설** — `ok`/`fail`/`nope`/`run` 헬퍼를 26+파일에 인라인 재정의하던 중복(변종 4종 + 출력포맷 드리프트 `PASS:`/`FAIL -`/`FAIL —`)을 단일 하네스로 통합. `ok/fail/nope/run/finish` 표준 시그니처 + 통일 출력. ok/nope/fail/run 클러스터 **28파일**을 `source` 로 교체. check/ck 클러스터(소문자 `pass/fail` 카운터·grep 매칭 시그니처)는 별도 체계라 범위 외. 회귀: run-all 79/79. (심층감사 중복/DRY)

## [1.26.4] — 2026-06-27

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
- **미완 lifecycle 재개 통보 규칙** — `using-specops-ko` 메타skill 에 SessionStart rehydrate 데이터를 사용자에게 통보하는 규칙 신설. 미완 FID 의 최신 단계·다음 단계를 점검해, 새 신호 시 1줄 참고·신호 없을 시 능동 재개 제안(완료 FID 는 침묵). rehydrate 데이터는 있으나 통보 규칙이 없던 가시화 공백 해소. (심층감사 H2 — 5원칙 4 주권: 새 신호 우선)

## [1.26.2] — 2026-06-27

### Fixed
- **pretool 거버넌스 R-1/R-2 관할 한정 — `.specops` 부재 repo 월권 차단 제거** — 플러그인 훅이 전역 발화하므로 specops 미사용 repo(`.specops/` 디렉토리 부재)의 `git commit`·`gh pr create` 까지 verify 누락으로 하드차단하던 결함(5원칙 4 주권 위반). `[ -d .specops ] || allow` 가드 추가 — lifecycle 진행 중(`.specops` 존재) repo 는 그대로 강제(보호 손실 0). `test-pretool` deny sandbox 3종 `.specops` 보정 + T40 신규(red-green). (PR #129, 재감사 M2)
- **`using-specops-ko` 유지보수 분기 ASCII 자기모순 정정** — 진입 다이어그램이 `analyzing-ko ★HARD GATE` 선행을 건너뛰고 `specifying-ko 직행`으로 표기(Phase A 잔재)해 권위 테이블과 모순. `analyzing-ko 먼저 → specifying-ko` 로 정합화. (PR #129, 재감사 M1)
- **`session-progress-append.sh` partial clobber 차단** — `awk > TMP` 후 `mv` 무조건 실행 → `&&` 결합(awk 중간실패 시 손상 TMP 가 TARGET 덮어쓰기 차단, 2곳). (PR #129)
- **`freework-resolve-fid.sh` FID 포맷 가드** — 진입부 정규식 검증 추가로 메타문자 유입 시 awk 동적정규식 오판정·오귀속 방지(타 스크립트와 일관). (PR #129)

### Changed
- **문서 정합 2건** — `using-specops-ko` 참조 섹션 폐기된 `engine/*·harness/*` 중첩구조 표기 → 플랫 구조 갱신, `analyzing-ko` `used_by` 에 `/promote` 누락 추가. (PR #129)

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

[Unreleased]: https://github.com/andyko18/specops-ko/compare/v1.60.0...HEAD
[1.60.0]: https://github.com/andyko18/specops-ko/compare/v1.59.0...v1.60.0
[1.59.0]: https://github.com/andyko18/specops-ko/compare/v1.58.0...v1.59.0
[1.58.0]: https://github.com/andyko18/specops-ko/compare/v1.57.0...v1.58.0
[1.57.0]: https://github.com/andyko18/specops-ko/compare/v1.56.0...v1.57.0
[1.56.0]: https://github.com/andyko18/specops-ko/compare/v1.55.0...v1.56.0
[1.55.0]: https://github.com/andyko18/specops-ko/compare/v1.54.0...v1.55.0
[1.54.0]: https://github.com/andyko18/specops-ko/compare/v1.53.0...v1.54.0
[1.53.0]: https://github.com/andyko18/specops-ko/compare/v1.52.0...v1.53.0
[1.52.0]: https://github.com/andyko18/specops-ko/compare/v1.51.0...v1.52.0
[1.51.0]: https://github.com/andyko18/specops-ko/compare/v1.50.0...v1.51.0
[1.50.0]: https://github.com/andyko18/specops-ko/compare/v1.49.0...v1.50.0
[1.49.0]: https://github.com/andyko18/specops-ko/compare/v1.48.0...v1.49.0
[1.48.0]: https://github.com/andyko18/specops-ko/compare/v1.47.3...v1.48.0
[1.47.3]: https://github.com/andyko18/specops-ko/compare/v1.47.2...v1.47.3
[1.47.2]: https://github.com/andyko18/specops-ko/compare/v1.47.1...v1.47.2
[1.47.1]: https://github.com/andyko18/specops-ko/compare/v1.47.0...v1.47.1
[1.47.0]: https://github.com/andyko18/specops-ko/compare/v1.46.0...v1.47.0
[1.46.0]: https://github.com/andyko18/specops-ko/compare/v1.45.0...v1.46.0
[1.45.0]: https://github.com/andyko18/specops-ko/compare/v1.44.0...v1.45.0
[1.44.0]: https://github.com/andyko18/specops-ko/compare/v1.43.0...v1.44.0
[1.43.0]: https://github.com/andyko18/specops-ko/compare/v1.42.0...v1.43.0
[1.42.0]: https://github.com/andyko18/specops-ko/compare/v1.41.0...v1.42.0
[1.41.0]: https://github.com/andyko18/specops-ko/compare/v1.40.0...v1.41.0
[1.40.0]: https://github.com/andyko18/specops-ko/compare/v1.39.1...v1.40.0
[1.39.1]: https://github.com/andyko18/specops-ko/compare/v1.39.0...v1.39.1
[1.39.0]: https://github.com/andyko18/specops-ko/compare/v1.38.0...v1.39.0
[1.38.0]: https://github.com/andyko18/specops-ko/compare/v1.37.0...v1.38.0
[1.37.0]: https://github.com/andyko18/specops-ko/compare/v1.36.0...v1.37.0
[1.36.0]: https://github.com/andyko18/specops-ko/compare/v1.35.0...v1.36.0
[1.35.0]: https://github.com/andyko18/specops-ko/compare/v1.34.1...v1.35.0
[1.34.1]: https://github.com/andyko18/specops-ko/compare/v1.34.0...v1.34.1
[1.34.0]: https://github.com/andyko18/specops-ko/compare/v1.33.0...v1.34.0
[1.33.0]: https://github.com/andyko18/specops-ko/compare/v1.32.3...v1.33.0
[1.32.3]: https://github.com/andyko18/specops-ko/compare/v1.32.2...v1.32.3
[1.32.2]: https://github.com/andyko18/specops-ko/compare/v1.32.1...v1.32.2
[1.32.1]: https://github.com/andyko18/specops-ko/compare/v1.32.0...v1.32.1
[1.32.0]: https://github.com/andyko18/specops-ko/compare/v1.31.0...v1.32.0
[1.31.0]: https://github.com/andyko18/specops-ko/compare/v1.30.0...v1.31.0
[1.30.0]: https://github.com/andyko18/specops-ko/compare/v1.29.0...v1.30.0
[1.29.0]: https://github.com/andyko18/specops-ko/compare/v1.28.0...v1.29.0
[1.28.0]: https://github.com/andyko18/specops-ko/compare/v1.27.0...v1.28.0
[1.27.0]: https://github.com/andyko18/specops-ko/compare/v1.26.5...v1.27.0
[1.26.5]: https://github.com/andyko18/specops-ko/compare/v1.26.4...v1.26.5
[1.26.4]: https://github.com/andyko18/specops-ko/compare/v1.26.3...v1.26.4
[1.26.3]: https://github.com/andyko18/specops-ko/compare/v1.26.2...v1.26.3
[1.26.2]: https://github.com/andyko18/specops-ko/compare/v1.26.1...v1.26.2
[1.26.1]: https://github.com/andyko18/specops-ko/compare/v1.26.0...v1.26.1
[1.26.0]: https://github.com/andyko18/specops-ko/compare/v1.25.0...v1.26.0
[1.25.0]: https://github.com/andyko18/specops-ko/compare/v1.24.0...v1.25.0
[1.24.0]: https://github.com/andyko18/specops-ko/compare/v1.23.0...v1.24.0
[1.23.0]: https://github.com/andyko18/specops-ko/compare/v1.22.1...v1.23.0
[1.22.1]: https://github.com/andyko18/specops-ko/compare/v1.22.0...v1.22.1
[1.22.0]: https://github.com/andyko18/specops-ko/compare/v1.21.3...v1.22.0
[1.21.3]: https://github.com/andyko18/specops-ko/compare/v1.21.2...v1.21.3
[1.21.2]: https://github.com/andyko18/specops-ko/compare/v1.21.1...v1.21.2
[1.21.1]: https://github.com/andyko18/specops-ko/compare/v1.21.0...v1.21.1
[1.21.0]: https://github.com/andyko18/specops-ko/compare/v1.20.0...v1.21.0
[1.20.0]: https://github.com/andyko18/specops-ko/compare/v1.19.2...v1.20.0
[1.19.2]: https://github.com/andyko18/specops-ko/compare/v1.19.1...v1.19.2
[1.19.1]: https://github.com/andyko18/specops-ko/compare/v1.19.0...v1.19.1
[1.19.0]: https://github.com/andyko18/specops-ko/compare/v1.18.0...v1.19.0
[1.18.0]: https://github.com/andyko18/specops-ko/compare/v1.17.0...v1.18.0
[1.17.0]: https://github.com/andyko18/specops-ko/compare/v1.16.0...v1.17.0
[1.16.0]: https://github.com/andyko18/specops-ko/compare/v1.15.1...v1.16.0
[1.15.1]: https://github.com/andyko18/specops-ko/compare/v1.15.0...v1.15.1
[1.15.0]: https://github.com/andyko18/specops-ko/compare/v1.14.0...v1.15.0
[1.14.0]: https://github.com/andyko18/specops-ko/compare/v1.13.0...v1.14.0
[1.13.0]: https://github.com/andyko18/specops-ko/compare/v1.12.0...v1.13.0
[1.12.0]: https://github.com/andyko18/specops-ko/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/andyko18/specops-ko/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/andyko18/specops-ko/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/andyko18/specops-ko/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/andyko18/specops-ko/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/andyko18/specops-ko/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/andyko18/specops-ko/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/andyko18/specops-ko/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/andyko18/specops-ko/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/andyko18/specops-ko/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/andyko18/specops-ko/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/andyko18/specops-ko/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/andyko18/specops-ko/releases/tag/v1.0.0
