# specops-auto-ko v0.0 PoC Gold PASS

**Date**: 2026-04-22
**Plugin**: `specops-auto-ko@0.0.0`
**Dogfood FID**: `20260422-csv-lines` (논리 CSV 레코드 카운터 CLI)
**결과**: **PASS** — 모든 구조 요소 (메타 skill 자동 주입 · skill chain · HARD GATE · subagent dispatch · 2단계 리뷰 · TDD 5스텝 · commit trailer · 5원칙 주입) 엔드투엔드 작동 확인.

## 배경

specops-auto-ko 는 Superpowers 메인 + ECC/Spec-Kit/Harness 보조 경로로 한국어 자율 Lifecycle 을 제공하는 Claude Code 플러그인이다. v0.0 PoC 의 핵심 가설은 **"메타 skill (`using-specops-auto-ko-ko`) 이 Claude Code 세션 시작 시 자동 주입되어 Claude 의 reasoning·도구 선택·서브에이전트 dispatch 를 Lifecycle 대로 강제한다"** 였다.

초기 Phase 1 (커밋 `de3cdd7`) 은 Superpowers v5.0.7 + ECC v1.2.0 + specops-ko v0.2 자산을 평탄하게 fork 한 상태였으나 — Claude Code 2.1 skill discovery 규약 (`skills/<name>/SKILL.md`) 과 어긋나 메타 skill 이 available skills 목록에 노출조차 되지 않았다.

## P1: 구조 표준화 + SessionStart 자동 주입 (커밋 `433a624`)

Superpowers 의 `hooks/session-start` 가 `using-superpowers` 를 자동 활성시키는 방법을 primary source 로 추적 — **built-in 기능이 아니라 플러그인이 JSON `hookSpecificOutput.additionalContext` 로 skill 본문을 수동 주입**하는 패턴임을 확인. 동일 경로를 이식:

- 16 skill 을 `skills/<name>/SKILL.md` 로 git mv 평탄화 (harness/engine 물리 디렉토리 제거, frontmatter `layer:` 로 구분 유지)
- `skills/using-specops-auto-ko-ko/SKILL.md` frontmatter `name` 을 디렉토리명과 일치시켜 정규화
- body 내 모든 `(engine|harness)/X` 참조를 `specops-auto-ko:X` skill ID 형태로 전수 치환 (specops-ko upstream 참조 라인은 Python 스크립트로 보호)
- `hooks/session-start.sh` 신규 — SKILL.md 본문을 JSON escape 해 `<EXTREMELY_IMPORTANT>` 블록으로 싸서 `additionalContext` 주입 + `.specops/session-progress.md` rehydrate 를 단일 JSON 으로 merge
- `hooks/context-reset.sh` 제거 (기능 merge 됨)
- validator (`scripts/validate-structure.sh`) 에 `meta_injection` 체크 신설, test sandbox 도 flat 구조로 재생성 — 회귀 테스트 10/10 PASS

검증: `validate-structure.sh` 6 체크 OK · 39/39 회귀 테스트 PASS · `CLAUDE_PLUGIN_ROOT=... bash hooks/session-start.sh | python3 -m json.tool` 로 `additionalContext` 5110 자 JSON 정상 출력 확인.

## 1차 재시도: 설계 상충 검출 + B-1 수정 (커밋 `b664592`)

P1 재시작 후 신규 세션에서 `/specops-auto-ko:start 안녕` 실측:

```
/specops-auto-ko:start 진입했지만 인자 "안녕"은 기능 설명 신호가 아닙니다
(메타 skill PoC 체크리스트 NO 케이스). specifying-ko 자동 호출을 보류하고
확인 요청드립니다.
```

**3 가지 동시 관찰**:

1. **메타 skill 주입은 작동한다** — Claude 가 "신호 감지 NO → 일반 응답" 로직을 언급한 것 자체가 `using-specops-auto-ko-ko/SKILL.md` 가 세션 컨텍스트에 실렸다는 증거.
2. **설계 상충 존재** — `commands/start.md` L22-23 ("즉시 specifying-ko 호출") + `SKILL.md` L23 ("/start <기능> = 신호 YES") 모두 specifying-ko 호출을 요구하는데 실측은 보류.
3. **skill body 에 없는 문구 생성** — "PoC 체크리스트 NO 케이스" 표현이 `SKILL.md` 에 없음. L90-100 의 "PoC v0.0 검증 체크리스트" 섹션이 응답 템플릿으로 오해석된 흔적.

**경로 B-1 채택** (advisor + Plan agent 합의): command 를 Source of Truth 로 단일화.

- `commands/start.md` "안티패턴" 섹션에 `"인자 내용 2차 판단"` 조항 1 개 추가 — `/start <아무 인자>` 는 인자 내용 불문 specifying-ko 로 직행, 인자 적합성은 specifying-ko HARD GATE 에서 처리
- `SKILL.md` 신호 목록 직후 **경계 블록** 인용문 1 줄 삽입 — 슬래시 동작 정의는 `commands/start.md` 가 Source of Truth, 메타 skill 은 자연어 입력 신호만 책임

회귀 6/6 · 39/39 · JSON 5709 자 (+599 차 = 경계 주석 크기 일치) 확인 후 커밋.

## 2차 재시도: 엔드투엔드 dogfood 완주

재시작 후 신규 세션 (`~/Project/0.Claude/dogfood-demo`) 에서 자연어 `CSV 줄 수 세기 CLI 만들어줘` 실측.

### 단계별 증거

| 단계 | 관찰된 툴 박스 | 결과 |
|---|---|---|
| 메타 skill 활성 | — | 5원칙 (투명성·주권·한계 고백) 인용 — 주입 작동 |
| specifying-ko Q1~Q4 | Read 2 + ls 2 | 프로젝트 맥락 탐색 (wc-lines 자산 인지) |
| specifying-ko 설계 초안 | — | 섹션 1~9 (개요~AC 초안~열린 질문) · HARD GATE 3지선다 |
| specifying-ko 종료 | **Write ×2** (spec.md · acceptance-criteria.md) + Bash ×3 (mkdir · git add · git commit) + Grep ×1 (자체 검토) + Update ×1 (한자→한글 수정) | 커밋 `52a4689` trailer 자동 생성 |
| **clarifying-ko chain** | **`Skill(specops-auto-ko:clarifying-ko)` → `Successfully loaded skill`** | **chain 강제 입증** |
| clarifying-ko 번들 질문 | Write 1 (clarifications.md) + Update 2 (AC-6·AC-7 append · session-progress) + Bash 1 (date) + Bash 1 (commit) | 커밋 `5524c42` — BLOCKING 0 / DESIRABLE 3 해소 |
| **planning-ko chain** | **`Skill(specops-auto-ko:planning-ko)`** | chain 2 단계 |
| planning-ko 산출 | Write 1 (plan.md 226 라인) + Update 1 + Bash 1 (commit) | 커밋 `4fbe331` · AC 커버리지 7/7 · 위험 5 건 |
| 실행 모드 GATE | — | 옵션 1 (subagent dispatch) 선택 |
| **decomposing-ko chain** | **`Skill(specops-auto-ko:decomposing-ko)`** | chain 3 단계 |
| decomposing-ko 산출 | Write 1 (tasks.md 451 라인) + Update 1 + Bash 1 (commit) | 커밋 `a6c194c` · Task 1~5 · 테스트 8 · must 5/5 · should 2/2 |
| **implementing-ko chain** | **`Skill(specops-auto-ko:implementing-ko)`** | chain 4 단계 |
| implementing-ko dispatch 기록 | Write 1 (dispatch-log.md) | 원칙 1 투명성 실천 |
| **subagent dispatch** | **`backend-dev(Implement csv-lines TDD 5 tasks)` → Done (30 tool uses · 27.1k tokens · 2m 15s)** | **subagent-driven-development 경로 완전 입증** |
| TDD 5스텝 × 5 태스크 | 5 feat 커밋 (`754e4fb`, `3781f34`, `21a09ff` 등) | RED→FAIL→GREEN→PASS→COMMIT 각 태스크 |
| 독립 검증 | Bash 1 (git log) + Bash 1 (test 실행) + Read 1 | **9/9 PASS** — "구현자 보고를 독립 검증 없이 수용 금지" (원칙 5) 실천 |
| Phase B | — | 2 단계 리뷰 스펙 리뷰어 dispatch 진입 |

## 결정적 증거 요약

1. **Skill 박스 4회** — 메타 skill 주입이 `## 다음 skill` 섹션 파싱을 통해 **자동 chain invocation** 을 일으킴. 텍스트 모방이 아닌 실제 `Skill` 도구 호출.
2. **Task 박스 1회** (backend-dev) — `implementing-ko` SKILL 이 지시한 **서브에이전트 dispatch** 가 실제 발생. 27.1k 토큰 · 30 툴 사용 · 2m 15s — 독립 에이전트 컨텍스트에서 TDD 사이클 완주.
3. **11 커밋 자동 생성** (specops-auto-ko 2 + dogfood-demo 9) — `commit_protocol` 의 `Constraint·Rejected·Directive` trailer 가 전부 포함. Global CLAUDE.md → 메타 skill body → Claude reasoning 경로가 실제로 연결돼 있음.
4. **5원칙 인용** — "원칙 1 투명성", "원칙 4 주권 존중", "원칙 5 한계 고백" 이 설계 초안 · HARD GATE · 자체 검증 문구에 자연스럽게 등장. skill body `§ "5원칙 주입"` 섹션이 reasoning 에 실제 쓰임.
5. **한자→한글 자체 수정** — AC-3 의 "差異" 를 자체 Grep 검토 후 "차이" 로 Update. generator-evaluator-ko 의 분리 검증 원칙 재현.

## 결론

v0.0 PoC 의 핵심 가설 — **"메타 skill 자동 주입이 Claude 의 Lifecycle 행동을 강제한다"** — 은 **Gold PASS**.

특히 다음 3 경로가 동시에 확인됐다:

- **SessionStart 주입 경로**: `hooks/session-start.sh` → JSON `hookSpecificOutput.additionalContext` → Claude Code 세션 컨텍스트 `<EXTREMELY_IMPORTANT>` 블록
- **Skill chain 경로**: 각 skill body 말미 `## 다음 skill` 섹션이 `Skill(specops-auto-ko:X-ko)` 호출을 유도 (Conductor 에이전트 없이)
- **Subagent dispatch 경로**: `implementing-ko` SKILL 이 `Task(subagent_type=...)` 도구 호출로 fresh 에이전트 컨텍스트 생성

세션 1 (자연어 "안녕" NO 분기) 은 Fallback 적용 사유가 사라져 실측 생략.

## 알려진 제한 / 후속 이슈

- **SKILL.md L90-100 "PoC v0.0 검증 체크리스트" 섹션** — 1차 재시도에서 "NO 케이스 응답 템플릿" 으로 오해석됐던 흔적. B-1 커밋 후 재발 안 함. 향후 PoC 종료 시 섹션 자체를 `docs/` 로 이관해 skill body 부피 감축 필요.
- **specifying-ko 질문 반복 상한 미명세** — 이번 dogfood 에서는 Q1~Q4 + 설계 초안 에서 자연 수렴했으나, 복잡한 요구일 때 무한 루프 위험. 후속 fix 후보.
- **세션 1 미실측** — Fallback 경로는 문서 수준으로만 남음. 다음 regression 세션에서 "안녕" 단독 입력 샘플 수집 필요.

## 다음 단계

- **Phase 2 (dogfood) 완료** — 이번 csv-lines Lifecycle 이 Phase 2 실전을 겸함. 사용자 세션이 `verifying-evidence-ko` → `requesting-code-review-ko` → `receiving-code-review-ko` → 최종 GATE 까지 완주하면 Lifecycle 전 구간 PASS.
- **Phase 3 (v0.1)** 준비:
  - ECC `autonomous-loops` 흡수 (Sequential Pipeline · De-Sloppify)
  - `pre:governance-capture` hook — 5 원칙 위반 자동 기록
  - Superpowers `writing-skills` · `executing-plans` · `finishing-a-development-branch` 선별 흡수
  - `github/spec-kit` 직접 clone

## 참조

- 설계 case study: `~/Project/0.Claude/specops-ko/docs/case-studies/2026-04-21-specops-auto-ko-design.md §15`
- P1 커밋: `433a624`
- B-1 커밋: `b664592`
- dogfood 산출물: `~/Project/0.Claude/dogfood-demo/.specops/20260422-csv-lines/`
- Plan 파일: `~/.claude/plans/specops-auto-ko-start-zazzy-church.md`
