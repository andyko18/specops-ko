# scripts/ — 구조 검증·drift 감지·config guard 유틸리티

> v0.1 `count-artifacts.sh`, v0.2 세션 4 `validate-task-dependencies.sh`, 세션 5 `validate-structure.sh`, 세션 5.5 `diff-upstream.sh`(프로토타입), 세션 6 `is-hook-enabled.sh`까지 누적 5개. drift 감지는 v0.3 완성 예정.

## v0.1 — 기존

### `count-artifacts.sh`

지정 디렉토리 최상위의 `.md` 아티팩트 파일 수를 stdout에 출력. FID 디렉토리 아티팩트 카운트·smoke test에 사용.

```bash
scripts/count-artifacts.sh .specops/20260420-rss-cache
# → 7
```

## v0.2 — 세션 4

### `validate-task-dependencies.sh`

`.specops/<FID>/tasks.md`에서 `scripts/·hooks/·tests/` 하위 `.sh` 파일 참조를 추출하여 **실제 파일 존재**와 **실행권한(exec-bit)** 을 검증. `/analyze` Process 스텝 9에서 자동 호출되며 실패 시 BLOCK 사유로 편입.

```bash
scripts/validate-task-dependencies.sh 20260420-rss-cache
# 정상:
#   OK: scripts/count-artifacts.sh
#   all ok: 1 refs validated
# 실패:
#   MISSING: scripts/ghost.sh   (exit 1)
#   NOT_EXEC: scripts/new-util.sh (fix: chmod +x scripts/new-util.sh)  (exit 1)
```

## v0.2 — 세션 5 🆕

### `validate-structure.sh`

플러그인 구조 무결성 정적 검증 Gate. 리팩토링·실수로 구조가 깨졌을 때 빨리 감지.

```bash
scripts/validate-structure.sh         # 사람이 읽는 출력
scripts/validate-structure.sh --json  # CI 통합용 JSON
```

**검증 항목 6개**:
| # | 항목 | 실패 조건 |
|---|---|---|
| 1 | 디렉토리 존재 | 12개 필수 디렉토리 중 하나라도 부재 |
| 2 | 파일 개수 | commands=8, agents=8, harness=5, engine≥4, templates=6 |
| 3 | frontmatter YAML 유효 | 첫 `---` 블록 파싱 실패 |
| 4 | superpowers 런타임 참조 | `commands/`·`agents/` 에 매칭 발견 |
| 5 | 매니페스트 일관성 | `plugin.json.version ≠ marketplace.json.plugins[0].version` |
| 6 | ref_upstream 포맷 | 구조화 비율 정보성 보고만 (FAIL 아님) |

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
scripts/diff-upstream.sh               # 캐시 우선, miss 시 fetch
scripts/diff-upstream.sh --cached      # 네트워크 금지, 캐시만
scripts/diff-upstream.sh --no-fetch    # 캐시 miss 시 skip (offline 테스트)
scripts/diff-upstream.sh --file skills/engine/tdd-ko.md   # 단일 파일
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

훅 guard 유틸리티 — 각 훅 첫 줄에서 `bash scripts/is-hook-enabled.sh <hook-name> || exit 0` 형태로 호출. `.specops/config.yaml`을 읽어 활성/비활성을 결정합니다. config 부재 시 default enabled (v0.1 동작 보존). pyyaml 부재 시 stderr 1회 경고 + default enabled.

```bash
bash scripts/is-hook-enabled.sh ensure-session-progress; echo $?  # 0 = ON, 1 = OFF
SPECOPS_CONFIG=/path/to/alt.yaml bash scripts/is-hook-enabled.sh context-reset
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

## 참조

- `docs/OSS-ATTRIBUTION.md` — drift 관리 프로토콜
- `docs/ARCHITECTURE.md` §7
- `docs/case-studies/2026-04-21-session-5-design.md` §3.1 — validate-structure 상세 설계
- `hooks/README.md` — v0.2 evaluator 메타 훅 + post-implement·pre-commit
