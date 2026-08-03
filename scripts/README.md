# scripts/ — 구조 검증·릴리즈·DAG·eval 유틸리티

> 구성 (v1.21.2 기준): `_internal/` (validate-structure·init-project·run-verification 등 내부 유틸) ·
> `dag/` (parse-dag·emit-context·validate-context) · `tests/` (run-all aggregator + 68 suites + llm-eval) ·
> 루트 (release.sh·gbrain-append.sh·session-progress-append.sh·git-branch-create.sh·show-fid-status.sh·slug.sh 등).
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
| `file_counts` | `.structure-baseline` glob 카운트 불일치 (commands=17·skills=30·templates=29·agents=4) |
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
- `struct` (auto): 엄격 매칭 (현재 4건 — skills/engine/*-ko.md)
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
[ $(ls commands/ | wc -l) -eq 8 ] && echo commands:OK
[ $(ls agents/ | wc -l) -eq 8 ] && echo agents:OK
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

## record-metric.sh — 비용·수율 메타데이터 기록

```bash
bash scripts/_internal/record-metric.sh \
  --fid <FID> --task T1 --phase implement --model <model> \
  --input-tokens 100 --output-tokens 20 --wall-ms 1200 \
  --retry-count 0 --timeout false --fallback false --verdict PASS
```

`.specops/<FID>/metrics.jsonl`에 고정 스키마만 기록합니다. 프롬프트·응답 원문을 받는 옵션은 제공하지 않으며, 미등록 필드는 거부합니다. `run-verification.sh`는 `phase=verify`를, 거버넌스 BYPASS 경로는 `phase=governance-bypass`를 자동 append합니다(사유 원문은 friction-log에만 남김).
