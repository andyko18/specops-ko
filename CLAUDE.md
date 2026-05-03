# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

specops-auto-ko는 **Claude Code 전용 한국어 자율 Lifecycle 플러그인**이다. 슬래시 1회(`/start`, `/maintain`) 또는 자연어 진입 후 메타 스킬이 spec → clarify → plan → TDD implement → verify → review 전 단계를 자동 chain한다. Conductor 에이전트 없이 각 SKILL.md 본문의 `## 다음 skill` 섹션이 다음 단계를 강제한다.

## 테스트 명령

```bash
# 거버넌스 규칙 테스트 (R-1~R-5, 38건)
bash scripts/tests/governance/test-rules.sh

# DAG 파서 테스트 (13건)
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
- **layer: 2** — Engine Skills: Lifecycle 체인의 각 단계 (specifying → clarifying → planning → decomposing → implementing → verifying → reviewing)
- **layer: 2** — `karpathy-ko`: cross-cutting 행동 원칙 (Think·Simplicity·Surgical·Goal), 구현 단계 자동 활성
- **layer: 3** — Harness Skills: 아키텍처 원칙 강제 (sprint-contracts, structured-artifacts, generator-evaluator, context-resets, file-based-communication)

### 거버넌스 엔진

훅 3종이 자동 실행되며, `hooks/rules.jsonl`에 정의된 5개 규칙(R-1~R-5)을 검사한다:

- `SessionStart` → `session-start.sh`: 메타 스킬 주입 + session-progress rehydrate
- `PostToolUse` → `posttool-governance.sh`: R-1(commit 전 verify), R-2(PR 전 verify), R-3(스킬 선언 투명성)
- `Stop` → `stop-governance.sh`: R-4(성공 주장 + 테스트 미실행), R-5(plan 수정 + Advisor 협의 누락)

위반은 `.specops/<FID>/friction-log.jsonl`에 Soft Warn으로 기록된다.

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
specops_version: <semver>
used_by: <호출 스킬 목록>
---
```

### tasks.md DAG 포맷

`decomposing-ko`가 생성하는 `tasks.md`에는 YAML DAG가 포함된다. `scripts/dag/parse-dag.sh`가 파싱하여 독립 batch를 추출하고, `implementing-ko`가 병렬 dispatch에 활용한다.

### maintenance flag

유지보수 진입 시 args 첫 줄에 `<!-- entry: maintain -->` HTML 주석을 prepend하여 신규/유지보수 분기를 구분한다. `specifying-ko`의 `[유지보수 분기]`가 이 약속어를 감지한다.

## 구조 검증이 FAIL나면

```bash
bash scripts/_internal/validate-structure.sh
```

- `file_counts FAIL` → 파일 추가/삭제 시 스크립트 내 기대값(commands, skills, templates 개수) 업데이트
- `frontmatter FAIL` → YAML `{{placeholder}}`는 따옴표로 감싸야 함
- `ref_upstream_fmt` → `owner/repo@version path` 포맷 또는 `specops-auto-ko 독자 추가` 명시 필요
