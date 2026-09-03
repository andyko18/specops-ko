# scripts/ — 구조 검증·릴리즈·DAG·eval 유틸리티

> 구성 (v1.72.0 기준): `_internal/` (validate-structure·init-project·run-verification 등 내부 유틸) ·
> `dag/` (parse-dag·emit-context·validate-context) · `tests/` (run-all aggregator ≈ **142** suites + llm-eval) ·
> 루트 (release.sh·gbrain-append.sh·session-progress-append.sh·git-branch-create.sh·show-fid-status.sh·slug.sh 등).
> baseline: commands=24 · skills=30 · templates=33 · agents=8 (README templates 34는 screen.html 포함).
> 아래 절들은 초기 (v0.1~v0.2) 스크립트의 상세 설명 — 경로는 현행 (`_internal/`) 기준으로 갱신됨.

## v0.1 — 기존

### `count-artifacts.sh`

지정 디렉토리 최상위의 `.md` 아티팩트 파일 수를 stdout에 출력. FID 디렉토리 아티팩트 카운트·smoke test에 사용.

```bash
scripts/_internal/count-artifacts.sh .specops/20260420-rss-cache
# → 7
```

## v0.2 — 세션 4

### `validate-task-dependencies.sh`

`.specops/<FID>/tasks.md`에서 `scripts/·hooks/·tests/` 하위 `.sh` 파일 참조를 추출하여 **실제 파일 존재**와 **실행권한(exec-bit)** 을 검증. `/analyze` Process 스텝 9에서 자동 호출되며 실패 시 BLOCK 사유로 편입.

```bash
scripts/_internal/validate-task-dependencies.sh 20260420-rss-cache
# 정상:
#   OK: scripts/_internal/count-artifacts.sh
#   all ok: 1 refs validated
# 실패:
#   MISSING: scripts/ghost.sh   (exit 1)
#   NOT_EXEC: scripts/new-util.sh (fix: chmod +x scripts/new-util.sh)  (exit 1)
```

## v0.2 — 세션 5 🆕

### `validate-structure.sh`

플러그인 구조 무결성 정적 검증 Gate. 리팩토링·실수로 구조가 깨졌을 때 빨리 감지.

```bash
scripts/_internal/validate-structure.sh         # 사람이 읽는 출력
scripts/_internal/validate-structure.sh --json   # CI 통합용 JSON
```

**검증 항목 12개** (`.structure-baseline` jsonl 카운트 기준):
| 항목 | 실패 조건 |
|---|---|
| `directories` | 필수 디렉토리 부재 |
| `file_counts` | `.structure-baseline` glob 카운트 불일치 (commands=24·skills=30·templates=33·agents=8) |
| `meta_injection` | `session-start.sh` 메타 skill 주입 누락 |
| `frontmatter` | YAML 파싱 실패 (pyyaml 부재 시 SKIP — 한계 고백) |
| `no_superpowers` | `commands/`·`agents/` 에 superpowers 런타임 참조 발견 |
| `manifest` | `plugin.json` ≠ `marketplace.json` 버전 |
| `ref_upstream_fmt` | 구조화 비율 정보성 보고 (FAIL 아님) |
| `skill_conventions` | SKILL.md 필수 필드·섹션 누락 |
| `version_sync` | 버전 문자열 불일치 |
| `readme_counts` | README 자산 카운트 불일치 |
| `changelog_body` | CHANGELOG 최신 버전 섹션 부재 |
| `xref_resolve` | 문서 상호참조 깨짐 |

**의존성**:
- Python 3 (필수) — JSON 파싱
- `pyyaml` (선택) — frontmatter 파싱. 없으면 항목 3은 SKIP 처리(원칙 5 한계 고백)

**출력 예**:
```
✅ directories: OK
✅ file_counts: OK
⚠️  frontmatter: SKIP — python3+pyyaml 미설치 — 한계 고백
✅ no_superpowers: OK
✅ manifest: OK (both=0.1.0)
ℹ️  ref_upstream_fmt: struct=8/23
```

exit code: `0` 전체 통과, `1` 하나 이상 FAIL.

## v0.2 — 세션 5.5 🆕

### `diff-upstream.sh`

상류 OSS 원본과 내재화본 간 drift 감지 프로토타입. 엄격 정규식
(`<owner>/<repo>@<tag> <path.ext>` + 라인 끝 앵커)으로 struct 분류
후 `##`·`###` 섹션 헤더 집합만 비교(한국어 재창작이라 본문 diff
무의미). 차이 결과를 `docs/upstream-drift-log.md`에 run 블록으로
prepend.

```bash
scripts/_internal/diff-upstream.sh               # 캐시 우선, miss 시 fetch
scripts/_internal/diff-upstream.sh --cached      # 네트워크 금지, 캐시만
scripts/_internal/diff-upstream.sh --no-fetch    # 캐시 miss 시 skip (offline 테스트)
scripts/_internal/diff-upstream.sh --file skills/tdd-ko/SKILL.md   # 단일 파일
```

**분류**:
- `struct` (auto): 엄격 매칭 (현재 — `skills/*/SKILL.md` 플랫 경로)
- `manual`: 다중·서술형·확장자 없음 (현재 17건) — v0.3 primary/secondary 필드 split 예정

**캐시**: `.specops-cache/upstream/${owner}__${repo}__${tag}__<path>` (gitignored)

**카운트 차이 (정상)**:
- `validate-structure.sh`의 `ref_upstream_fmt: struct=8/23` — 덜 엄격 (확장자 없어도 매칭)
- `diff-upstream.sh` 의 `struct=4` — 엄격 매칭
- 상세 배경: `docs/OSS-ATTRIBUTION.md §3.5`

## v0.2 — 세션 6 🆕

### `is-hook-enabled.sh`

훅 guard 유틸리티 — 각 훅 첫 줄에서 `bash scripts/_internal/is-hook-enabled.sh <hook-name> || exit 0` 형태로 호출. `.specops/config.yaml`을 읽어 활성/비활성을 결정합니다. config 부재 시 default enabled (v0.1 동작 보존). pyyaml 부재 시 stderr 1회 경고 + default enabled.

```bash
bash scripts/_internal/is-hook-enabled.sh ensure-session-progress; echo $?  # 0 = ON, 1 = OFF
SPECOPS_CONFIG=/path/to/alt.yaml bash scripts/_internal/is-hook-enabled.sh session-start
```

**스키마·profile 우선순위**: `hooks/README.md` "config" 섹션 참조.

## v0.2+ 도입 예정 (v0.3)

### `lint-five-principles.sh` (v0.3)

정규식 기반 5원칙 위반 정적 스캔:
- `except: pass` → 원칙 5
- 매직 넘버 3회 이상 → 원칙 3
- 주석 없는 복잡 조건문 → 원칙 1

## 테스트

```bash
bash scripts/tests/test-count-artifacts.sh              # 7건 (v0.1)
bash scripts/tests/test-validate-task-dependencies.sh   # 7건 (v0.2 세션 4)
bash scripts/tests/test-validate-structure.sh           # 7건 (v0.2 세션 5)
bash scripts/tests/test-diff-upstream.sh                # 8건 (v0.2 세션 5.5)
bash scripts/tests/test-is-hook-enabled.sh              # 7건 (v0.2 세션 6)
```

## 수동 검증 (v0.1 잔존 — validate-structure.sh 등장 후 사용 줄어듦)

```bash
[ $(ls commands/*.md | wc -l | tr -d ' ') -eq 24 ] && echo commands:OK
[ $(ls agents/*.md | wc -l | tr -d ' ') -eq 8 ] && echo agents:OK
! grep -rE "^[^#<-]*superpowers:" commands/ agents/
# ↑ validate-structure.sh 가 이 모두를 자동화 — 직접 실행 불필요
```

## llm-eval — LLM 동작 smoke eval (수동 전용)

메타 skill 의 신호 감지 + 체인 진입을 headless `claude -p` 로 검증합니다.

⚠️ 실 claude 호출은 토큰 비용 발생 (~$0.5/fixture, 총 10 fixture) — run-all/CI **비포함**. 릴리즈 전 수동 실행 권장.

```bash
bash scripts/tests/llm-eval/run-evals.sh            # 실 eval (claude CLI 필요, 비용 발생)
bash scripts/tests/llm-eval/test-llm-eval.sh        # runner 단위 테스트 (stub, 토큰 0 — run-all 포함)
```

- `LLM_EVAL_RUNS=N` (N>1): 각 fixture N회 반복 → 성공률/FLAKY 신뢰성 리포트 (비차단). 기본 1=단발.

- `bash scripts/tests/llm-eval/run-pressure-evals.sh` — **압박 테스트** (HARD GATE 우회 거부 검증, 실 claude 비용·수동 전용). `test-pressure-evals.sh` 는 stub 단위 (토큰 0, run-all 포함).
- `bash scripts/tests/llm-eval/run-pressure-evals.sh scripts/tests/llm-eval/verify-gate-fixtures.jsonl` — **verify-gate 압박** (R-1/R-2 commit·PR 전 verify 우회 거부 검증, bash-command 차원, sandbox 격리, 실 claude 비용·수동 전용).
- `bash scripts/tests/llm-eval/run-plan-ab.sh` — **plan 리뷰 A/B 측정** (inline self-review vs 2중 dispatch 검출률·토큰, 실 claude 비용·수동·예비 측정). `test-plan-ab.sh` 는 stub 집계 단위 (토큰 0).
- `bash scripts/tests/llm-eval/run-chain-stage.sh` — **chain 중간단계 eval** (decompose 단계 미커버 must AC 탐지율, plan-ab 패턴 확대, 실 claude 비용·수동 전용). `test-chain-stage.sh` 는 stub 단위(토큰 0, run-all 포함).
- `tests/mutation-score.sh` — 간이 뮤테이션 하니스 (수동 — bash 스크립트 변형 주입 후 테스트 검출률 측정). run-all 비포함. config: `tests/mutation-targets.conf`.
  - `mutation-equivalent.conf` — 알려진 equivalent mutant(`<target>|<line>|<pattern>|<reason>`) 분모 제외. return-code/관찰불가 변형만(남용 금지). `MUT_EQUIV_CONF` 로 오버라이드.
- `tests/llm-eval/eval-lib.sh` — llm-eval 공통 lib (소스 전용): assertion 어휘 4종(contains/regex/cost_lt/llm_rubric) + 매트릭스 평가. promptfoo 방법론 bash 이식. `run-matrix-eval.sh` 가 declarative 사용 (기본 stub, `CLAUDE_BIN` 시 실 모델). run-all 비포함(test-eval-matrix.sh 만).
- signal eval은 `sandbox_seed`(both/none/specops-only) + `expect_bootstrap` fixture 필드로 **프로젝트 최초 진입 부트스트랩 안내**(/init-project 권장 발화) 감지를 커버한다.

## 참조

- `docs/OSS-ATTRIBUTION.md` — drift 관리 프로토콜
- `docs/ARCHITECTURE.md` §7
- `hooks/README.md` — v0.2 evaluator 메타 훅 + post-implement·pre-commit

## skip-tracker.sh — SKIP 비율 관측 (advisory)

- `skip-tracker.sh` — integration/performance 게이트 SKIP 비율 관측 (읽기 전용, advisory). `.specops/*/evidence.md` 집계. 임계: `SKIP_TRACKER_THRESHOLD` (기본 70).

```bash
bash scripts/skip-tracker.sh
# 출력 예 (게이트별 1줄, SKIP 비율 정수):
# integration: total=12 PASS=3 SKIP=9 FAIL=0 (SKIP 75%)  ⚠️ 형식화 의심 (>70%)
# performance: total=13 PASS=4 SKIP=8 FAIL=1 (SKIP 61%)
```

---

## critic-ask.sh — 외부 모델 critic 위탁 (advisory)

plan.md·diff 를 Codex/Gemini CLI 에 위탁해 이종 모델 의견을 받습니다. CLI 부재 시 `CRITIC: SKIP` (chain 비차단).

```bash
bash scripts/critic-ask.sh templates/critic-prompt-plan.md --files .specops/<FID>/plan.md
CRITIC_BIN=/path/to/cli bash scripts/critic-ask.sh ...   # provider 강제 (테스트 stub 포함)
```

---

## verdict-board.sh — FID별 게이트 결과 매트릭스 (advisory, 읽기 전용)

검증 단일 상태(`verification-state.json`)와 evidence의 integration·performance 판정을 FID별 매트릭스로 표시하는 **수동 관측 유틸**입니다. 검증 상태는 `NOT_RUN | PASS | PARTIAL | FAIL | WAIVED`이며, PASS 이후 코드가 바뀌면 조회 시 `STALE`로 계산됩니다. 구조화 상태가 없는 기존 FID만 evidence stamp를 읽습니다.

```bash
bash scripts/verdict-board.sh [.specops 경로]
```

## verification-state.sh — 검증 상태 단일 SoT

```bash
bash scripts/_internal/verification-state.sh current <FID>
bash scripts/_internal/verification-state.sh record <FID> PASS --executed 3 --failed 0
```

`run-verification.sh`가 자동 기록합니다. 명령 0건은 `NOT_RUN`과 non-zero로 종료하며 PASS로 취급하지 않습니다. `WAIVED` 기록에는 `--waiver-reason`, `--waiver-approved-by`, `--waiver-expires-at`이 모두 필요합니다. 만료된 `WAIVED`는 저장값을 덮지 않고 조회 시 `NOT_RUN`으로 계산됩니다. STALE 판정은 HEAD 문자열이 아니라 임시 인덱스 `write-tree` 내용 지문을 쓰므로, 검증된 내용의 순수 커밋만으로는 STALE이 되지 않습니다.

## risk-profile.sh — 위험 프로파일 limited-live 분류 (P1)

```bash
bash scripts/_internal/risk-profile.sh compute <FID> [--floor standard|strict]
bash scripts/_internal/risk-profile.sh show <FID>
```

`.specops/<FID>/risk-profile.json`에 `lite|standard|strict`를 기록합니다 (`mode=live`). strict 신호(인증·migration·삭제·결제/PII·public API·인프라·외부실행·병렬 batch·cross-service)가 있으면 라인 수와 무관하게 strict입니다. `effective=lite`일 때만 `reductions_allowed: ["batch-review-skip"]`(requesting/receiving skip). Phase B·TDD·verify·receipt 축소는 금지입니다. 사용자/ENV floor는 상향만 가능합니다.

## release-ready.sh — PR 직전 RELEASE_READY 합성 판정 (P0-3)

```bash
bash scripts/_internal/release-ready.sh <FID>
# 0=READY · 1=NOT_READY · 2=UNKNOWN(legacy/fail-open)
```

verify(`verification-state` PASS) · review-audit · security/integration/performance(evidence PASS|SKIP) · reconcile(DESYNC 없음) · Critical/High 휴리스틱을 AND로 합성합니다. `pretool-governance`는 `gh pr create` 시 **strict FID 또는 ACTIVE batch 브랜치 PR**에서 NOT_READY면 hard deny하고, 그 외는 stderr + friction-log warn만 남깁니다. UNKNOWN(rc=2)은 fail-open입니다.

## record-task-receipt.sh / check-task-receipt.sh — 태스크 단위 커밋 게이트 (P0-2)

```bash
bash scripts/_internal/record-task-receipt.sh <FID> <task-id>   # test_command PASS 시 receipt 기록
bash scripts/_internal/check-task-receipt.sh <FID> <task-id>    # 0=면제 · 1=무효 · 2=부재
```

`.specops/<FID>/receipts/<task>.json`에 `tree_hash`·`outputs`·`test_command_hash`를 저장합니다. R-1은 receipt가 유효하고 staged ⊆ outputs이며 커밋 메시지에 `T#`가 있으면 FID 전체 verify 없이 커밋을 허용합니다. R-2(PR)는 receipt로 열리지 않습니다. receipt 부재 FID는 기존 implement/verify 면제 경로를 유지합니다.

## record-metric.sh — 비용·수율 메타데이터 기록

```bash
bash scripts/_internal/record-metric.sh \
  --fid <FID> --task T1 --phase implement --model <model> \
  --wall-ms 1200 --retry-count 0 --fallback false --verdict PASS
```

`.specops/<FID>/metrics.jsonl`에 고정 스키마만 기록합니다(`schema_version: 2`).

> **v2 에서 제거된 필드** (FID `20260903-metrics-dead-fields`): `tokens.{input,output,cache_read,cache_write}` · `timeout` · `fixed`. 실측 150 레코드에서 토큰 4필드와 `fixed` 는 **전부 null**, `timeout` 은 **전부 상수 `false`** 였고 넘기는 프로덕션 호출자가 0곳이었다 — bash 는 Claude 토큰을 관측할 수 없다. 빈 칸은 "측정하고 있다"는 착시를 준다. 제거된 플래그를 넘기면 **비0 종료**한다(조용히 무시하지 않는다). 기존 v1 레코드는 그대로 남는다. 프롬프트·응답 원문을 받는 옵션은 제공하지 않으며, 미등록 필드는 거부합니다. `run-verification.sh`는 `phase=verify`를, 거버넌스 BYPASS 경로는 `phase=governance-bypass`를 자동 append합니다(사유 원문은 friction-log에만 남김). Evaluator `fable` 불가 재dispatch는 `phase=evaluator-degradation --fallback true --model <override>`를 남깁니다(`implementing-ko` · `start-all` Phase 2.5-D).

## install-git-hooks.sh — 2단 git hook 게이트 (도구 무관)

```bash
bash scripts/_internal/install-git-hooks.sh            # 설치 (clone 마다 1회)
bash scripts/_internal/install-git-hooks.sh --uninstall
```

| 훅 | 게이트 | 소요 |
|---|---|---|
| `pre-commit` | `validate-structure` + `check-propagation` | ~5s |
| `pre-push` | `check-ci-status`(경고, ~1s) + `run-all.sh` 전체 스위트 | ~330s |

훅 본문은 `.githooks/` 로 버전관리되지만 `core.hooksPath` 는 `.git/config` 로컬 설정이라 **clone 마다 1회 설치**가 필요합니다. Claude Code PreToolUse 훅(R-1)은 Cursor 등 다른 도구의 커밋에 발화하지 않으므로, 도구 무관하게 걸리는 층은 git hook 뿐입니다 — 계기는 `44cd095` 가 `run-all` 없이 나가 `main` 이 하루 red 였던 사고입니다. 커밋마다 5분 넘게 걸면 `--no-verify` 관성이 생겨 게이트가 무력화되므로 비용을 2단으로 나눴습니다. 탈출구(주권): `git commit --no-verify` · `git push --no-verify`. 게이트 스크립트가 없는 repo 에서는 자동 면제됩니다(월권 금지).

`check-ci-status.sh` 는 `git push` 직전 origin main 의 **최근 완료 CI 결론**을 조회해 red 면 경고합니다 — ~330s 스위트를 돌기 전에 알리는 것이 목적이라 면제 4종 뒤·`run-all` 앞에 옵니다. **차단하지 않습니다**(항상 `exit 0`). `gh`·`jq` 는 **선택 의존**이라 미설치·미인증·오프라인·타임아웃에서는 조용히 넘어갑니다. 타임아웃 상한은 `SPECOPS_CI_CHECK_TIMEOUT`(기본 5초, 실측 왕복 ~1.0초)로 조정합니다. 계기: 2026-08-07 `main` 이 3커밋 연속 Linux CI red 였는데 로컬 게이트가 전부 macOS 라 아무도 몰랐습니다.

## check-propagation.sh — 계약 경계 전파 스캔 (Wave C)

```bash
bash scripts/_internal/check-propagation.sh
# 매트릭스: scripts/_internal/propagation-matrix.jsonl
```

신규 게이트·allowlist·Critical cap 등 **소비처가 있는 계약**을 추가·변경할 때 `propagation-matrix.jsonl`에 edge 행을 함께 갱신합니다. `scripts/tests/test-propagation.sh`가 run-all에 포함됩니다.

**edge 는 계약 토큰이 아니라 소비 문자열까지 잡아야 합니다.** 실측(44cd095): `batch-review-skip` edge 가 토큰만 요구해, revert 가 `commands/start-all.md`에서 `risk-profile.json` 경로만 떨어뜨렸을 때 스캔은 통과하고 `test-screen-generation-gate` T1.e 만 하루 red 로 남았습니다. 소비처가 **읽는 파일 경로·필드명**을 edge 에 포함하세요.

**`SPECOPS_PROPAGATION_MATRIX`** — 매트릭스 경로를 덮는 env 입니다. **테스트가 픽스처를 물려 체커의 FAIL 경로를 실제로 실행**하려고 열어 뒀습니다(`test-propagation.sh` P4·P5·P9). 그래서 **소비측은 반드시 빈 값으로 핀해야 합니다** — 셸에 이 env 가 잔류하면 전량 매트릭스 대신 1-edge 픽스처를 보게 되고, `pre-commit` 은 rc=0 경로에서 체커 출력을 삼키므로 **게이트가 무음으로 축소**됩니다.

```bash
# 소비측 의무 — 빈 대입으로 핀한다. `:-` 가 unset 과 empty 를 같게 취급하므로 기본 매트릭스로 fallback 한다.
cp_out=$(SPECOPS_PROPAGATION_MATRIX= bash "$CP" 2>&1)
```

이 핀 계약 자체는 `propagation-env-pin` 레코드가 잠급니다 — 핀 2곳과 그 이빨(`test-propagation.sh` P10)과 판별력 스위트(`test-propagation-teeth.sh`)와 이 문단까지 5 edge. 패턴은 **행두 앵커**입니다: 비앵커면 `cp_out=` 이 `out=` 패턴을 뚫고, 평문 토큰은 이 문단 같은 **산문에 false-match** 해 잠금이 무음 사망합니다.

## check-matrix-patterns.sh — 원장 패턴 판별력 lint

```bash
bash scripts/_internal/check-matrix-patterns.sh
# 위반 0 → exit 0 · 위반 존재 → exit 1
```

`must_match` 가 대상 파일의 **주석 줄에서만** 매치하면 그 edge 는 **실제 배선을 지우고 주석만
남겨도 통과**합니다 — 태어날 때부터 무음입니다. gbrain `20260814` 가 이 클래스를 기록했으나
강제층이 없어 원장에 2건이 살아남았고(실측), 이 lint 가 그 강제층입니다.

**게이팅 3분류** — 방향이 **산문 allowlist** 입니다:
1. **산문**(`.md`·`.txt`·`.rst`) → skip. 주석 문법이 없어 "주석 전용"이 정의되지 않습니다.
2. **`#` 주석 계열**(`.sh`·`.bash`·`.zsh`·`.py`·`.rb`·`.yaml`·`.yml`·`.toml`·`.githooks/*`) → 검사.
3. **그 외** → **미분류 카운터로 표면화**. FAIL 이 아닙니다 — 새 확장자는 정당할 수 있어 차단하면 false-block 입니다.

출력은 **세 숫자를 모두** 냅니다: `검사 N · 산문 skip M · 미분류 K`. 조용히 빼지 않습니다.

> 방향이 왜 중요한가: 초기 구현은 **코드 allowlist**(`.sh`+훅만 검사, 나머지 skip)였는데,
> 그러면 새 확장자가 원장에 오를 때 "산문 skip" 으로 **무음 분류**되고 skip 카운터만 오른다 —
> `검사+skip=전체` 항등조차 성립해 **어떤 어서션도 깨지지 않는다**. 무음을 잡으러 온 lint 가
> 자기 게이팅에서 무음을 만드는 구조였다(Phase C 지적). 실측으로도 확인된다: 주석 계열에서
> `.githooks/*` 를 빼는 변이는 `검사 111 · skip 68 · 미분류 2` 로 **항등은 성립하는데 분류는
> 틀린** 상태가 되고, 이를 잡는 것은 항등이 아니라 **미분류 카운터 노출**이다.

**의도적으로 주석을 잠그려면** 패턴을 주석 앵커로 씁니다 — `^[[:space:]]*#.*<문구>`.
면제 필드가 아니라 **패턴 자체가 선언**이라 `git diff` 에 남고 리뷰어가 봅니다.
(들여쓴 주석이 흔하므로 `^#` 이 아니라 `^[[:space:]]*#` 여야 합니다.)

**실행 위치**: `run-all`·pre-push 가 수집하는 스위트(`test-matrix-patterns.sh`)에서만 돕니다.
`check-propagation.sh` 나 `pre-commit` 에는 **넣지 않습니다** — 원장은 드물게 변하는데 매 커밋
전량 린트는 비용만 냅니다.

**한계 3종** — "이 클래스는 기계가 본다"이지 "이제 안전하다"가 아닙니다:
1. **코드 안 문자열 리터럴** 매치는 못 잡습니다(변이 테스트가 쓴 문자열이 패턴에 매치하는 자기참조 클래스).
2. **몸통을 도려낸 패턴**은 못 잡습니다 — `^cp_out=` 는 코드 줄에 매치하므로 통과합니다.
3. **줄끝 주석**(`cmd  # 설명`)에만 있으면 통과합니다. `#` 시작 위치를 정확히 가르려면 문자열 안 `#` 을 구분해야 해 파서가 필요하고, 단순 휴리스틱은 정상 edge 를 차단합니다.
