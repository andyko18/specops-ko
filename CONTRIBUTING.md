# 기여 가이드 — specops-auto-ko

Claude Code 한국어 자율 Lifecycle 플러그인에 기여 환영. 본 가이드는 PR/skill 추가 시 최소 요건을 정의한다.

## 사전 요건

- Claude Code 설치 (`claude` CLI)
- `bash 5+`, `jq`, `python3` (+ `pyyaml`)
- 플러그인을 marketplace로 등록 후 dogfood

```bash
claude plugin marketplace add ~/Project/0.Claude/specops-auto-ko
```

## 개발 워크플로

본 플러그인은 **자기 자신을 dogfood** 한다. 신규 skill·command·hook 추가는 다음 슬래시로 진입한다:

```bash
/start "<기능 설명>"          # 신규 기능
/maintain "<수정 대상>"       # 유지보수 (bug fix, refactor)
```

자율 chain: specify → clarify → plan → decompose → implement → verify → request-review → receive-review → PR.

## PR 전 필수 체크

```bash
# 1) 구조 무결성 (8/8 OK 목표)
bash scripts/_internal/validate-structure.sh

# 2) 거버넌스 규칙 38 + 신규 회귀 (45 PASS 목표)
bash scripts/tests/governance/test-rules.sh

# 3) DAG 파서 (16 PASS 목표)
bash scripts/tests/dag/test-parse-dag.sh

# 4) SKILL.md 규약
bash scripts/tests/test-skill-conventions.sh
```

전체 시간 < 10초. 1건이라도 FAIL 시 머지 금지.

## Skill 추가 규약

### frontmatter 필수 필드

```yaml
---
name: <kebab-case-ko>
description: <한 줄 — 언제 사용·무엇·결과>
layer: 1 | 2 | 3
reference_upstream: <owner/repo@version path> 또는 "specops-auto-ko 독자 추가"
specops_version: <semver>
used_by: <호출 skill 목록 (namespace 포함)>
---
```

### layer 분류

| layer | 용도 | 예시 |
|---|---|---|
| **1** | 메타 (SessionStart 자동 주입) | `using-specops-auto-ko-ko` |
| **2** | Engine — Lifecycle 단계·cross-cutting | `specifying-ko`, `karpathy-ko`, `advisor-ko` |
| **3** | Harness — 아키텍처 원칙 강제 | `sprint-contracts-ko`, `context-resets-ko` |

### 본문 필수 섹션

- `## 사용 시점` — 언제 호출되는가
- `## 절차 (Process)` — Step 1, 2, ...
- `## 다음 skill` — chain 끊김 방지 (layer 1 메타 skill 제외)
- `## 참조` — upstream 링크 + 관련 skill

## Command 추가 규약

`commands/<slug>.md` frontmatter에 `specops_layer`, `specops_version` 필수. 단순 wrapper면 process 본문은 5줄 이내 — 실제 로직은 skill에 위임.

## Hook 추가 규약

- `hooks/hooks.json` 매니페스트 등록
- `scripts/_internal/is-hook-enabled.sh` config guard 호출
- `set -uo pipefail` 강제 (또는 `safe_exit` 패턴 일관성)
- 실패 시 `exit 0` 투과 — 도구 흐름 차단 금지
- `hooks/rules.jsonl` R-* 규칙 신설 시 `test-rules.sh`에 회귀 테스트 추가

## Commit 메시지 컨벤션

```
<type>(<scope>): <subject>

<body>
```

- type: `feat`, `fix`, `chore`, `docs`, `test`, `refactor`
- scope: skill/command/hook 이름 또는 영역
- subject: 50자 이내, 명령형 한국어 가능

## PR 생성

`receiving-code-review-ko` 가 자동 안내. 수동 생성 시:

```bash
gh pr create \
  --base main \
  --head feat/<FID> \
  --title "<scope>: <subject>"
```

PR 본문: `.specops/<FID>/spec.md` + `acceptance-criteria.md` + `evidence.md` 링크 권장.

## Semver 정책

| bump | 트리거 |
|---|---|
| MAJOR | skill chain 호환성 깨짐 (예: HARD GATE 추가, 산출물 포맷 변경) |
| MINOR | 신규 skill/command/hook 추가, 기존 skill 본문 확장 |
| PATCH | bug fix, frontmatter 정합성, 테스트 보강, doc 갱신 |

`.claude-plugin/plugin.json` + `marketplace.json` 동시 갱신. `CHANGELOG.md` Unreleased → 버전 섹션 이동.

## 5원칙

| 원칙 | 의미 |
|---|---|
| 1 투명성 | skill 호출·결정 명시. 침묵 진행 금지 |
| 2 문지기 | binary 분기. 회색지대 만들지 말 것 |
| 3 회귀 보호 | 모든 AC는 테스트로 검증 |
| 4 사용자 주권 | HARD GATE는 사용자 승인. 임의 진행 금지 |
| 5 한계 고백 | 불확실 시 advisor 호출 또는 사용자 질문 |

## 참조

- `CLAUDE.md` — 프로젝트 컨텍스트 (Claude Code 전용)
- `README.md` — 사용자 진입 가이드
- `docs/case-studies/` (specops-ko 본 저장소) — 설계 근거
