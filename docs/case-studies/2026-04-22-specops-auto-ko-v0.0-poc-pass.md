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

## Lifecycle 완주 결과 (2026-04-22 09:45 ~ 09:55)

dogfood-demo 에서 **9 단계 엔드투엔드 완주**. 추가 관찰:

| 단계 | Skill 박스 | 산출물 | 커밋 |
|---|---|---|---|
| verifying-evidence-ko | `Skill(specops-auto-ko:verifying-evidence-ko)` | `evidence.md` (166 라인) — 테스트 9/9 · must 5/5 · should 2/2 · spec §4 표 12/12 · shellcheck 미설치 한계 고백 | `4bf74ce` |
| requesting-code-review-ko | `Skill(specops-auto-ko:requesting-code-review-ko)` + `Task(code-reviewer)` 외부 리뷰 (65.8k 토큰 · 1m 27s) | `review-request.md` + 판정 `READY_TO_MERGE` (Critical/Important 0, Minor 3) | `f4ece5d` |
| receiving-code-review-ko | `Skill(specops-auto-ko:receiving-code-review-ko)` | Minor 1 수용 (FRICTION-LOG append) · 2/3 기각 (YAGNI · sprint-contracts 읽기 전용) | `2f03034` |

**Skill 박스 총 7회** · **Task 박스 총 5회** (backend-dev × 1, code-reviewer Phase B/C · external × 3, 기타 × 1) · **총 12 커밋** · **실측 코드 107 라인 / 아티팩트 ~1160 라인**.

### 원칙 5 한계 고백 실측 적용

`receiving-code-review-ko` 단계에서 Claude 가 FRICTION-LOG 실행 증거 섹션을 추정값(`78 줄`, `stdin 미지원 확인`) 으로 작성한 후 **직접 실측 재확인**:

```bash
./csv-lines .specops/20260422-csv-lines/spec.md     # → 102
printf '"a\nb",1\nc,2\n' | ./csv-lines /dev/stdin   # → error: /dev/stdin not found or not a regular file
```

추정값 `78` → 실측값 `102` 로 Update, stdin 거부 메시지 원문으로 정정. `verifying-evidence-ko` skill body 의 "주장 전에 증거, 출력 원문 캡처 · 요약 금지" 원칙이 다음 단계(`receiving-code-review-ko`) 까지 reasoning 에 지속 유지됨을 보여주는 primary source.

## FRICTION-LOG 수확 — Phase 3 v0.1 P0/P1 근거

PoC 본 가설은 예상대로 PASS. 더 가치있는 결과물은 dogfood 가 도출한 **Phase 3 백로그 구체 숫자**:

### F-11 · clarify 생략 정책 반례 (**P0**)

- **증상**: specifying-ko 가 Q1~Q4 4건 질문 후에도 clarifying-ko 가 3건 DESIRABLE 추가 발굴. spec §9 열린 질문 3건 → 전부 RESOLVED + AC-6/AC-7 신규 append
- **영향**: specifying-ko 단독으로는 AC 계약 완결 불가. lite profile 도입 시 "clarify 생략" 기본값이면 암묵 가정으로 구현 진입 → 계약 공백
- **Phase 3 태스크**: skill body 에 "clarify 는 기본 필수. `/start` 에서 spec §열린질문 카운트 0 이 아니면 clarify 강제" 조항 추가

### F-12 · implementing-ko ESCAPE HATCH 부재 (**P0**)

- **증상**: skill 본문은 "각 태스크마다 fresh 서브에이전트 + 2단계 리뷰" 명시. 실제 dogfood 에서는 5 태스크 전부 동일 파일 쌍 순차 수정이라 **1 구현자 + 2 리뷰어 = 3 dispatch 집약**. 에이전트가 `dispatch-log.md` 에 해석 근거 명시 후 진행 (원칙 4 주권 판단)
- **영향**: skill 원문과 실제 효율 판단 간 **암묵 트레이드오프를 에이전트가 단독 결정**. 5원칙 4(주권) vs 2(문지기) 충돌
- **Phase 3 태스크**: implementing-ko skill 에 "태스크가 동일 파일 쌍을 순차 수정하는 TDD 체인이면 구현자 1회 dispatch 로 집약 가능. 2단계 리뷰는 유지. dispatch-log 해석 근거 명시 의무" 조항 추가. 현 PoC 의 `dispatch-log.md` Phase A/B/C 기록 패턴을 사례로 박아둠

### F-13 · spec NFR 실측 괴리 (**P1**)

- **증상**: spec.md §6 NFR-2 "bash 4+" 기재, 실측 bash 3.2.57 (macOS 기본) 에서 9/9 PASS. 구현 자체가 bash 4+ 전용 문법 미사용 — specifying-ko 가 wc-lines 의 NFR-2 를 맹목 복제
- **영향**: spec 이 실측보다 엄격 → 배포 판단 오도. sprint-contracts 상 spec 읽기 전용이라 후속 Lifecycle 재진입 전까지 수정 불가
- **Phase 3 태스크**: specifying-ko skill 에 "NFR 호환성은 실측 최저 버전 우선 기재. 확신 없으면 `<ver>+ (실측 미확인)` 형식으로 한계 고백" 가이드 추가. 또는 verifying-evidence-ko 가 실측↔spec NFR 불일치 발견 시 경고 출력

### F-14 · 짝 아티팩트 교차 리뷰 부수효과 (**P2**, 긍정 마찰)

- **증상**: csv-lines 외부 리뷰가 일관성 점검 중 기존 `wc-lines:11 f=$1` (비인용) 식별. 공백 포함 파일명에서 실제 버그. csv-lines 는 `f="$1"` (인용) 로 회피
- **영향**: **dogfood 가치의 구체 증거** — 단일 FID 리뷰에선 안 보이는 버그를 교차 비교로 포착
- **Phase 3 태스크**: "짝 아티팩트 · 교차 비교 리뷰 패턴" 을 권장 사례로 문서화. 후속 Lifecycle 진입 시 wc-lines unquoted 버그를 첫 태스크로 처리 권장 (F-14 를 spec 입력으로)

## 알려진 제한 / 후속 이슈

- **SKILL.md L90-100 "PoC v0.0 검증 체크리스트" 섹션** — 1차 재시도에서 "NO 케이스 응답 템플릿" 으로 오해석됐던 흔적. B-1 커밋 후 재발 안 함. 향후 PoC 종료 시 섹션 자체를 `docs/` 로 이관해 skill body 부피 감축 필요.
- **specifying-ko 질문 반복 상한 미명세** — 이번 dogfood 에서는 Q1~Q4 + 설계 초안 에서 자연 수렴했으나, 복잡한 요구일 때 무한 루프 위험. 후속 fix 후보.
- **세션 1 미실측** — Fallback 경로는 문서 수준으로만 남음. 다음 regression 세션에서 "안녕" 단독 입력 샘플 수집 필요.

## 다음 단계

- **Phase 2 (dogfood) 완료 확정** — csv-lines Lifecycle 9 단계 전부 통과. READY_TO_MERGE.
- **Phase 3 (v0.1) 백로그 — dogfood 실측 근거 우선**:
  - **P0** F-11 clarify 기본 필수 고정 (lite 분기 도입 시에도 생략 금지)
  - **P0** F-12 implementing-ko "TDD 체인 집약 dispatch" ESCAPE HATCH 조항 추가
  - **P1** F-13 specifying-ko NFR 가이드 — 실측 우선 + 한계 고백 태그
  - **P2** F-14 짝 아티팩트 교차 리뷰 패턴 문서화
  - (기존 예정) ECC `autonomous-loops` 흡수 (Sequential Pipeline · De-Sloppify)
  - (기존 예정) `pre:governance-capture` hook — 5 원칙 위반 자동 기록
  - (기존 예정) Superpowers `writing-skills` · `executing-plans` · `finishing-a-development-branch` 선별 흡수
  - (기존 예정) `github/spec-kit` 직접 clone

## 참조

- 설계 case study: `~/Project/0.Claude/specops-ko/docs/case-studies/2026-04-21-specops-auto-ko-design.md §15`
- P1 커밋: `433a624`
- B-1 커밋: `b664592`
- dogfood 산출물: `~/Project/0.Claude/dogfood-demo/.specops/20260422-csv-lines/`
- Plan 파일: `~/.claude/plans/specops-auto-ko-start-zazzy-church.md`
