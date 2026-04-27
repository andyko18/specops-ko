<!-- FID: 20260427-analyzing-gh-fallback-refactor -->
<!-- OWNER_COMMAND: /maintain → analyzing-ko -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: specops-auto-ko 독자 추가 (본가 obra/superpowers@v5.0.7 미존재) -->
<!-- layer: Lifecycle-Artifact -->

# 현재 시스템 분석 (Current State) — 20260427-analyzing-gh-fallback-refactor

> 유지보수 진입 (`/maintain skills/analyzing-ko/SKILL.md 의 gh CLI fallback 로직 리팩터링`) → analyzing-ko 가 본 산출물 작성. 변경 대상 = analyzing-ko 자기 자신 (self-modifying skill — meta-circular).

## 1. 변경 대상 식별

- 파일: `skills/analyzing-ko/SKILL.md` (Lines: **32–34, 3 줄** — `## 체크리스트` Step 4 본문)
  - `32:4. **gh CLI 가용성 점검** (clarify Q-C 결정):`
  - `33:   - \`gh --version\` 성공 → \`gh pr list\`, \`gh issue list\` 사용`
  - `34:   - 실패 → \`git log --merges --grep='Merge pull'\` fallback + impact-analysis.md §3 에 "데이터 출처: git log (gh CLI 미가용 — 한계 고백)" 메타 명시 (5 원칙 5)`
- 진입점 (skill body 관점): `## 체크리스트` Step 4 텍스트 룰 — 분기 조건 = `gh --version` exit code
- **라인 범위 합산 = 3 ≤ 5 → analyzing-ko Step 5 자동 판정 → spec.md §유형 = `trivial` 후보**
  - 단, "리팩터링" 키워드가 본문 구조 개편 (예: 3 줄 → 5 줄 +1 자리수) 의도를 시사 → specifying-ko Step 1 [유지보수 분기] 가 사용자 의도 재확인 권장. trivial 자동 부여는 사용자 명시 거부 시 미부여.
- 관련 모듈:
  - `templates/impact-analysis.md` Lines 25–27 (`§3 데이터 출처` 메타 — Step 4 룰의 mirror)
  - `commands/maintain.md` (analyzing-ko 호출 진입로)
  - `skills/using-specops-auto-ko-ko/SKILL.md` (메타 skill — maintenance flag 신호 매칭)

## 2. 호출자/의존 매핑

### 2.1 분석 대상 (analyzing-ko Step 4) 호출자
- **direct caller**: 본 SKILL 본문 Step 4 는 LLM 이 SKILL 호출 시 순차 실행 — 코드 호출자 없음 (skill-as-prompt)
- **상위 진입로 (analyzing-ko 자체 호출자)**:
  - `commands/maintain.md` (`## Process` Step 2 — args 첫 줄 `<!-- entry: maintain -->` prepend 후 호출)
  - `skills/using-specops-auto-ko-ko/SKILL.md` (자연어 입력 maintenance flag = true 시 호출)

### 2.2 의존 매핑

| 의존 대상 | 종류 | 결합도 | 위치 |
|---|---|---|---|
| `gh` CLI 바이너리 | external tool | **soft** (fallback 존재) | shell PATH (`/opt/homebrew/bin/gh` 본 환경) |
| `git log` | external tool | hard (필수 fallback) | shell PATH |
| `templates/impact-analysis.md` §3 | mirror text | **strong** (본 SKILL Step 4 의 fallback 메타 문자열을 template 도 그대로 인용 — Lines 25–27) | `templates/` |
| `acceptance-criteria.md` AC-15 | spec assertion | **strong** (본 SKILL Step 4 의 동작 룰을 Given/When/Then 으로 검증 — Lines 202–213, FID `20260427-maintenance-lifecycle`) | `.specops/20260427-maintenance-lifecycle/` |
| `behavioral-verification-protocol.md` B-V4 | verbatim 검증 시나리오 | medium (fresh 세션 dogfood) | `.specops/20260427-maintenance-lifecycle/` Lines 174–199 |

### 2.3 grep 근거 (5 원칙 1 투명성)
- `grep -rn "gh CLI\|gh --version\|gh pr list\|git log --merges" skills/ commands/ templates/` 결과 (위 검증 시 수집):
  - `skills/analyzing-ko/SKILL.md:31–34` (자체)
  - `templates/impact-analysis.md:25–27` (mirror)
  - 그 외 0 건 (분석 대상 외 직접 caller 없음)

## 3. 기존 테스트 커버리지

| 검증 종류 | 위치 | 자동화 여부 | 본 변경의 회귀 영향 |
|---|---|---|---|
| **자동화 단위 테스트** | `scripts/tests/` 하위 | **없음** (analyzing-ko 자기 자신을 검증하는 자동화 테스트 부재) | — |
| **spec assertion (AC)** | `.specops/20260427-maintenance-lifecycle/acceptance-criteria.md` AC-15 | structural (grep 기반) | **AC-15 검증 방법이 SKILL Step 4 본문의 동작 의미와 mirror — 룰 의미가 깨지면 AC-15 PASS 불가** |
| **behavioral verbatim 검증** | `.specops/20260427-maintenance-lifecycle/behavioral-verification-protocol.md` B-V4 (Lines 174–199) | manual (fresh 세션 사용자 dogfood) | gh CLI 미가용 시 fallback 동작 — Step 4 룰 변경 시 B-V4 시나리오 재검증 필요 |
| **template mirror 정합성** | `templates/impact-analysis.md` Lines 25–27 | **자동화 검증 없음** (수동 mirror 유지) | Step 4 본문 표현 변경 시 template 도 동시 갱신 필요 |

**커버되지 않는 경로**:
- gh CLI 가 설치됐으나 인증 실패 (`gh auth status` non-zero) 또는 repo 미식별 (`gh pr list` GraphQL Could not resolve) 인 중간 상태 — 본 환경에서 실측됨 (`gh pr list --repo andyko/specops-auto-ko` → `GraphQL: Could not resolve to a Repository`). 현재 Step 4 는 `gh --version` 만 분기 조건으로 사용 → 이 중간 상태는 fallback 미발동 → impact-analysis.md §3 빈 결과 위험.

## 4. 관찰 가능 동작 (Baseline)

| # | 입력 / 환경 | 현재 동작 (Baseline) | 비고 |
|---|---|---|---|
| 1 | `gh --version` 성공 + repo push 됨 | `gh pr list`, `gh issue list` 사용 → §3 채움 | 정상 happy path |
| 2 | `gh --version` 실패 (gh 미설치) | `git log --merges --grep='Merge pull'` fallback + §3 메타 "데이터 출처: git log (gh CLI 미가용 — 한계 고백)" 명시 | AC-15 검증 대상 |
| 3 | `gh --version` 성공 + repo 미push (로컬 전용) | **현재 룰 미정의** — Step 4 분기는 `gh --version` 만 본다 → §3 빈 결과 또는 LLM 임의 처리 | **본 환경 실측 — 회귀 위험 H** |
| 4 | `gh --version` 성공 + 인증 실패 (`gh auth status` non-zero) | **현재 룰 미정의** — 동상 | 회귀 위험 M |
| 5 | self-modifying 호출 (analyzing-ko 가 자기 자신을 분석 — 본 세션) | **사용 가능** — meta-circular 진입에 대한 안전장치 부재 | edge case (현재 세션이 첫 사례) |

## 5. 회귀 위험 메모

| 위험 | 대상 | 강도 | 완화책 |
|---|---|---|---|
| **R1: AC-15 grep 깨짐** | `.specops/20260427-maintenance-lifecycle/acceptance-criteria.md` AC-15 | **H** | 리팩터링 시 AC-15 의 `git log (gh CLI 미가용` substring 검색 가능성 유지 — 메타 문자열 동등 의미 보존 |
| **R2: template mirror 분기** | `templates/impact-analysis.md` Lines 25–27 | **H** | Step 4 본문 변경 시 template §3 도 동일 PR 에서 동시 갱신 (별도 PR 분리 금지) |
| **R3: B-V4 behavioral protocol 깨짐** | `.specops/20260427-maintenance-lifecycle/behavioral-verification-protocol.md` Lines 174–199 | M | 룰 동작 의미 동등성 유지 (텍스트 표현은 변해도 fresh 세션 검증 결과 PASS) |
| **R4: gh 인증 실패 / repo 미push 중간 상태 미커버** | 본 SKILL Step 4 분기 조건 (`gh --version` 단일 조건) | **H** (본 세션에서 실측됨) | 리팩터링 범위에 포함시킬지 사용자 결정 — specifying-ko Step 1 [유지보수 분기] 의 의도 재확인 시 명시적으로 묻기 |
| **R5: meta-circular 안전성** | analyzing-ko 가 자기 자신 SKILL.md 를 분석 — Step 4 텍스트 변경이 다음 호출 동작에 즉시 영향 | M | 리팩터링 PR 머지 후 fresh 세션에서 B-V4 재검증 필수. 사전 dogfood (본 FID) 보존. |
| **R6: trivial 자동 판정 vs 리팩터링 의도 충돌** | analyzing-ko Step 5 (3 줄 → trivial) vs "리팩터링" 키워드 (구조 변경 의도) | L | spec.md §유형 자동 부여 시 사용자 명시 거부 옵션 사용 |

## 6. Advisor 협의 메모 (2026-04-27)

`feedback_advisor_analysis_design.md` 에 따른 의무 협의 결과:

- **R4 는 회귀 위험이 아니라 리팩터링 범위 binary fork** — HARD GATE 단계에서 사용자에게 명시 분기 1 문항으로 처리해야 함 (specifying-ko Step 1 까지 미루지 말 것). 분기 결과가 spec.md §유형 / 회귀 AC 모양까지 결정.
- **R5 (meta-circular), R6 (trivial vs refactoring 충돌) 은 차단 사유 아님** — R5 mitigation (머지 후 fresh 세션 B-V4 재검증) 은 §5 본문에 이미 명시. R6 은 spec.md 유형 라벨 단계에서 결정.
- **산출물 길이 적정** — trivial 후보지만 mirror 3 건 (template, AC-15, B-V4) + meta-circular 라 §1·§2 작성 판단은 올바름.

---

*작성: analyzing-ko · 2026-04-27 · FID: 20260427-analyzing-gh-fallback-refactor · 변경 규모: 3 줄 (trivial 후보 — 리팩터링 의도 재확인 필요)*
