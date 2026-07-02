# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

specops-auto-ko는 **Claude Code 전용 한국어 자율 Lifecycle 플러그인**이다. 슬래시 1회(`/start`, `/maintain`) 또는 자연어 진입 후 메타 스킬이 spec → clarify → plan → TDD implement → verify → review → security → integration-test → performance-test → PR 전 단계를 자동 chain한다. Conductor 에이전트 없이 각 SKILL.md 본문의 `## 다음 skill` 섹션이 다음 단계를 강제한다.

## 테스트 명령

```bash
# 전체 테스트 (run-all.sh — 릴리즈 pre-flight 게이트와 동일)
bash scripts/tests/run-all.sh

# LLM 동작 smoke eval (수동 전용 — 토큰 비용 발생, run-all 비포함)
bash scripts/tests/llm-eval/run-evals.sh

# lifecycle E2E 자동 검증 (수동 전용 — 토큰 비용 발생, run-all 비포함)
# e2e-test-ko skill 이 greet-cli fixture 로 9단계 chain 완주 + 산출물 구조 검증
/e2e-test

# 거버넌스 규칙 테스트 (R-1~R-6, 전 항목 PASS 목표)
bash scripts/tests/governance/test-rules.sh

# DAG 파서 테스트 (전 항목 PASS 목표)
bash scripts/tests/dag/test-parse-dag.sh

# 플러그인 구조 무결성 검증 (전 항목 ✅ 목표)
bash scripts/_internal/validate-structure.sh
```

## 아키텍처

### Skill 계층 구조

```
skills/<name>/SKILL.md   ← 플랫 구조, layer 필드로 계층 구분
```

- **layer: 1** — 메타 스킬 (`using-specops-auto-ko-ko`): SessionStart 훅으로 자동 주입, 신호 감지 후 chain 진입
- **layer: 2** — Engine Skills: Lifecycle 체인의 각 단계 (specifying → clarifying → planning → decomposing → implementing → verifying → reviewing → security-review → integration-test → performance-test → PR)
- **layer: 2** — `karpathy-ko`: cross-cutting 행동 원칙 (Think·Simplicity·Surgical·Goal), 구현 단계 자동 활성
- **layer: 3** — Harness Skills: 아키텍처 원칙 강제 (sprint-contracts, structured-artifacts, generator-evaluator, context-resets, file-based-communication) + e2e-test-ko (lifecycle E2E 자동 검증)

chain 의 primary edge 는 `hooks/chain.yaml` 이 단일 Source of Truth 다 — 각 SKILL.md `## 다음 skill` 코드블록·메타 skill chain 목록과의 drift 는 `validate-structure.sh` `chain_consistency` 검사가 적발한다 (edge 변경 시 세 곳 동기 수정).

### 거버넌스 엔진

거버넌스 훅 이벤트 4종(+ `Notification` → `notify.sh` 보조 1종)이 자동 실행되며, `hooks/rules.jsonl`에 정의된 6개 규칙 중 R-1~R-5 를 검사한다 (R-6 은 `enabled: false` — gbrain-ko manual-only 설계):

- `SessionStart` → `session-start.sh`: 메타 스킬 주입 + session-progress rehydrate
- `PreToolUse` → `pretool-governance.sh` (v1.14.0 신설): R-1(commit 전 verify)·R-2(PR 전 verify) **사전 차단(Hard block)** — verify 누락 시 `git commit`·`gh pr create` 실행 전 deny. **관할 한정**: cwd 에 `.specops/` 부재 시(specops 미사용 repo) 면제 — 플러그인은 자기 관할 repo 만 통제(5원칙 4 주권). `§auto`·`SPECOPS_GOVERNANCE_BYPASS=1` 면제, fail-open
- `PostToolUse` → `posttool-governance.sh`: R-1(commit 전 verify), R-2(PR 전 verify) **감사 기록(Soft Warn)**, R-3(스킬 선언 투명성)
- `Stop` → 3 훅 발화: `ensure-session-progress.sh`(session-progress.md 보장) + `stop-governance.sh`(거버넌스: R-4 성공 주장 + 테스트 미실행, R-5 plan 수정 + Advisor 협의 누락, R-6 `/verify` + evidence.md 후 gbrain-append 호출 부재 — 비활성) + `freecomment-capture.sh`(자유 코멘트 자동 캡처 — pending 적재, SessionStart 에서 LLM 요약→freelog.md)

R-1/R-2 는 **pretool=강제 차단 / posttool=감사** 로 역할이 분리된다(면제·fail-open 시 posttool audit trail 보존). 그 외 위반은 `.specops/<FID>/friction-log.jsonl`에 Soft Warn으로 기록된다.

### 서브에이전트 2단계 리뷰 패턴

`implementing-ko`가 태스크별 fresh 서브에이전트를 dispatch하며, 각 태스크 완료 후:
- **Phase B** `spec-reviewer-ko` (스펙 준수만 판정) → PASS 후
- **Phase C** `code-reviewer-ko` (코드 품질·보안·커버리지)

Generator와 Evaluator를 엄격히 분리해 자기평가 편향을 차단한다.

### 아티팩트 규약

모든 작업 산출물은 `.specops/<FID>/`에 보관된다. FID 포맷: `YYYYMMDD-kebab-slug`.

```
.specops/<FID>/
├── spec.md + acceptance-criteria.md   ← /specify 산출
├── clarifications.md                  ← /clarify 산출
├── plan.md                            ← /plan 산출
├── tasks.md                           ← /decompose 산출 (YAML DAG 포함)
├── dispatch/<task-id>-context.md      ← 서브에이전트 입력
├── evidence.md                        ← /verify 산출
└── friction-log.jsonl                 ← 거버넌스 위반 기록
```

## 주요 규약

### SKILL.md frontmatter 필수 필드

```yaml
---
name: <스킬명>
description: <한 줄 설명>
layer: <1|2|3>
reference_upstream: <owner/repo@version path>  # 포맷 필수 (독자 추가 시 "specops-auto-ko 독자 추가" 허용)
specops_version: <semver>  # 본 skill 본문이 마지막으로 substantive 변경된 플러그인 버전 (자동 갱신 아님)
used_by: <호출자 목록>  # 표기 규약 — command 는 /<name>, skill 은 short name (<skill>-ko)
---
```

### tasks.md DAG 포맷

`decomposing-ko`가 생성하는 `tasks.md`에는 YAML DAG가 포함된다. `scripts/dag/parse-dag.sh`가 파싱하여 독립 batch를 추출하고, `implementing-ko`가 병렬 dispatch에 활용한다.

### maintenance flag

진입 분기 약속어 — args 첫 줄에 HTML 주석을 prepend하여 분기를 구분한다:

- `<!-- entry: maintain -->` — 유지보수 진입. `specifying-ko`의 `[유지보수 분기]`가 감지.
- `<!-- entry: foundation -->` — 공통부 먼저 개발 진입. `specifying-ko`의 `[foundation 분기]`가 감지. Step 5.5(화면 루프) skip, §유형=`foundation` 자동 라벨.

## 구조 검증이 FAIL나면

```bash
bash scripts/_internal/validate-structure.sh
```

- `file_counts FAIL` → 파일 추가/삭제 시 스크립트 내 기대값(commands, skills, templates 개수) 업데이트
- `frontmatter FAIL` → YAML `{{placeholder}}`는 따옴표로 감싸야 함
- `ref_upstream_fmt` → `owner/repo@version path` 포맷 또는 `specops-auto-ko 독자 추가` 명시 필요
