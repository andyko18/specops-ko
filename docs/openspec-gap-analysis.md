# OpenSpec 대비 개선 분석 (20260807)

> 대상: `Fission-AI/OpenSpec` @ `d57889664cab4f2f061d236ec3ff82a5578701bb` (2026-08-05) · specops-ko v1.62.0
> 방법: 소스 실측 대조. 인용 코드는 이 커밋 기준.

---

## 요약

OpenSpec 은 **"스펙 문서 자체를 기계가 검증한다"**. specops-ko 는 **"프로세스를 기계가 강제한다"**.
두 축은 직교하고, specops-ko 는 전자가 거의 비어 있다.

| | OpenSpec | specops-ko |
|---|---|---|
| 프로세스 강제 (verify·리뷰·TDD) | 약함 (`verify` 는 archive 를 막지 않음) | **강함** (훅 deny) |
| 스펙 **내용** 검증 | **773줄 validator · 규칙 ~30** | 구조·참조 무결성은 있음, **필드 수준은 없음** |
| 살아있는 정본 | capability spec 36개 (자기 dogfood) | FID 디렉터리 누적, 정본 없음 |

---

## G1. 수락 기준(AC)의 형식·내용이 미검증 — **최대 갭**

### OpenSpec 이 하는 것

`src/core/validation/validator.ts` (773줄) 가 스펙 파일을 파싱해 판정한다:

| 규칙 | 수준 |
|---|---|
| 요구사항에 `SHALL`/`MUST` 없음 | ERROR (strict) / WARNING |
| 요구사항에 시나리오 0건 | **ERROR** |
| `#### Scenario` 가 3해시·불릿이면 **조용히 실패** → 전용 경고 + 변환 가이드 | ERROR |
| ADDED/MODIFIED/REMOVED 내 중복 요구사항 | ERROR |
| 같은 요구사항이 MODIFIED ∧ REMOVED / MODIFIED ∧ ADDED / ADDED ∧ REMOVED | ERROR |
| RENAMED 후 옛 이름을 MODIFIED 가 참조 | ERROR |
| `Why` 50~1000자 · `Purpose` ≥50자 · 요구사항 ≤500자 | ERROR/WARNING |
| 델타 0건 (면제 마커 없이) | ERROR |

### specops-ko 의 실상 — 이미 있는 것과 없는 것

`acceptance-criteria.md` 는 스스로를 "스프린트 계약서 … Evaluator 는 이 계약만을 판정 기준으로 삼는다"고 규정한다. 실측하면 그 범위는 좁다:

| 에이전트 | `acceptance-criteria` 참조 |
|---|---:|
| `spec-reviewer-ko` (Phase B) | **4건** — 실질 유일 소비자 |
| `code-reviewer-ko` (Phase C) | 1건 |
| `plan-reviewer-ko` | **0건** |

즉 "Evaluator 3종의 유일 판정 기준"이 아니라 **`spec-reviewer-ko` 의 유일 판정 기준**이다.

**이미 기계 검증되는 것** — `scripts/dag/emit-context.sh` (247줄, dispatch 전 원자 fail-fast):

- `acceptance-criteria.md` 파일 존재 (부재 → exit 1)
- task 마다 `ac` 배열 비면 error → **모든 task 가 AC 를 참조해야 한다**
- task 가 참조한 `AC-N` 이 파일에 실재하는지 (정방향 무결성)
- **모든 `must` AC 가 ≥1 task 에 매핑됐는지** (역방향 커버리지)
- `### AC-N:` 헤더에서 요약 추출 실패 시 파일 미작성 + exit 1

**여전히 미검증인 것** — 전부 **필드 수준**이다:

| 항목 | 현황 |
|---|---|
| `**Given**`/`**When**`/`**Then**` 형식 | **회귀 AC(`AC-R-*`)에만** 적용 — `check-regression-ac.sh:77` |
| `**검증 방법**` · `**관련 FR**` | 검사 없음 |
| AC 본문 placeholder(`<기능 이름>`, `...`) 잔존 | 검사 없음 |
| AC → FR 역참조 무결성 | 검사 없음 (emit-context 는 task↔AC 만 본다) |

### 진짜 구멍 — 역방향 커버리지가 조용히 꺼진다

`emit-context.sh` 의 must AC 역방향 검사에는 **명시적 fail-open** 이 박혀 있다:

```python
#   must 판정: h2/h3 AC 헤더 섹션 안에 `**우선순위**: must` 가 있는 id 만 —
#   우선순위 필드가 아예 없는 구식/픽스처 AC 문서는 자연히 대상 0건(하위호환 fail-open).
```

**`**우선순위**` 필드를 안 쓰면 `must_ids = []` 가 되어 역방향 커버리지 검사 전체가 무음으로 꺼진다.** 그런데 그 필드의 존재를 강제하는 층은 없다 — 위 표대로 미검증이다.

이게 클래스 A(선언은 HARD, 구현은 0곳)의 잔재다. 형태는 다르다 — 게이트가 아예 없는 게 아니라, **게이트를 끄는 스위치가 무검증 상태로 노출돼 있다.**

### 개선안

`scripts/_internal/check-ac-format.sh` (신규) — AC 블록(`### AC-<n>:`)마다:

```
필수 필드: **Given** · **When** · **Then** · **검증 방법** · **관련 FR** · **우선순위**
placeholder 잔존 → FAIL (scan-enrich-placeholders 재사용)
```

`**우선순위**` 를 필수로 만들면 위 fail-open 이 닫힌다 — **이 항목 하나가 기존 최강 검사를 되살린다.**

배선: `scripts/dag/emit-context.sh` (기존 게이트 4종과 같은 자리).

### 구현 완료 (20260807)

`scripts/_internal/check-ac-format.sh` 신설 + `scripts/dag/emit-context.sh` 배선.

| 판정 | 항목 | 비고 |
|---|---|---|
| **HARD** | `**우선순위**` 필수 + 값 `must`·`should`·`nice-to-have` | 스위치 잠금 — 본 수정의 목적 |
| **HARD** | `**Given**`·`**When**`·`**Then**` 각 1건 | 존재 판정은 행 어디서든(한 줄 병기 실사용 형태 수용) |
| **HARD** | 템플릿 골격 잔존(`<...>` · 값이 `...`) 없음 | |
| **HARD** | AC 토큰 자체가 0건 | 계약이 빈 문서 |
| WARN | `**검증 방법**` 부재 | `test_command` 가 이미 hard (중복) |
| WARN | `**관련 FR**` 부재 | FR 대조 SoT 미결 (아래) |
| WARN | 헤더형 AC 0건(불릿·표·산문) | ↓ |
| 대상 밖 | `AC-R-*` | SoT = `check-regression-ac.sh`. 이중 방어로 배제 |

**잔여 구멍 1건 — 불릿 형식 문서.** `emit-context` 는 `- **AC-1**: …` 불릿 요약 추출을 의도적으로 구제한다(#209 · 20260716 dogfood). 그런데 불릿 형식엔 `**우선순위**` 를 둘 자리가 없어 **must 커버리지가 그 문서에서 영구히 0건**이다. 그 완화 계약을 일방적으로 깨지 않기로 하고 **WARN 으로 드러내기만 했다** — 완전 봉합은 "불릿 형식 지원 폐기" 결정이 선행돼야 한다(별도 판단 사항).

**픽스처 4건 승격** — `ok-fid`·`h2-header`·`missing-tc`·`bad-ac` 에 `**우선순위**` 추가. 이 4건이 우선순위 0건이었다는 사실 자체가 결함의 증거였다.

**저작 지점까지 배선** — 게이트만 만들고 `specifying-ko`·`clarifying-ko` 에 지시를 안 넣으면, 모델은 AC 를 쓴 뒤 **여러 단계 지나 dispatch 직전에야** hard block 을 만난다(클래스 A 의 거울상). 두 skill 에 필수 필드 지시를 추가하고 `ac-format-switch` edge(7개)로 잠갔다.

**부수 발견 2건**
- `AC-R` 만 있는 유지보수 문서가 **"AC 0건" 으로 오차단**됐다. T8/T8b 가 미채운 골격을 막으므로 유지보수 FID 에서 `AC-1..3` 템플릿을 지우는 것이 정상 대응인데, 그때 정확히 이 경로에 닿는다. 수정 + T10b 로 잠금.
- `hardgate_classified` 는 분류 토큰을 **파일 전체**에서 찾는다(블록 스코프 아님). specifying-ko 에 AC 게이트 SoT 를 추가하자 기존 변이 테스트가 vacuous 로 전환됐다. 테스트는 고쳤으나 **규칙 자체의 느슨함은 남아 있다** — 별건.

**변이 검증** — 8개 변이 중 3개가 처음에 생존했고 전부 원인이 달랐다: ① `AC-R` 배제가 이중 구현이라 한 줄만 지우면 통과 ② T7 이 `grep 'WARN'` 로 **PASS 요약줄의 "WARN N건"** 을 오매칭 ③ 변이 정규식 미적용(가짜 생존). ①은 주석 명시, ②는 WARN 행 자체를 검사하도록 수정, ③은 재측정.

> **미결 — FR SoT 를 먼저 정해야 한다.** `**관련 FR**` 을 무엇과 대조할 것인가:
> `spec.md §4 FR 표` 인가, `check-fr-table.sh` 가 읽는 `.specops/memory/requirements.md` 인가.
> 둘은 다른 표다. `/start-all` batch 경로에서 FR ID 소유자가 누구인지 명시하지 않으면
> 새 checker 가 `check-fr-table.sh` 와 **batch 경로에서 정확히 어긋난다** (그 경로는 이미 FR 파싱 결함 이력이 있다).
> 이 항목만 결정 전까지 보류하고, 나머지 5개 필드부터 닫는 것이 안전하다.

---

## G2. 범위 팽창의 정량 상한이 없다

OpenSpec `src/core/validation/constants.ts`:

```ts
export const MAX_DELTAS_PER_CHANGE = 10;         // "Consider splitting changes with more than 10 deltas"
export const MAX_REQUIREMENT_TEXT_LENGTH = 500;  // "Consider breaking it down"
export const MIN_WHY_SECTION_LENGTH = 50;
export const MAX_WHY_SECTION_LENGTH = 1000;
```

specops-ko 에는 **FR 개수·AC 개수·spec 길이 상한이 하나도 없다.** `/start-all` 은 `requirements.md` FR 표 **전량**을 batch 로 돈다 — 표에 FR 이 40개면 40개를 돈다. `check-fr-table.sh` 는 하한(실 FR ≥1)만 본다.

**개선안**: `check-fr-table.sh` 에 상한 warn 추가(예: batch 진입 FR > 12 → 분할 권고 + `/start-all` 에 경고 출력). 차단이 아니라 경고 — 이 프로젝트의 warn-first 전환 관행대로.

---

## G3. 면제 마커가 본문에 있고, 충돌 검사가 없다

### OpenSpec

면제(`skip_specs`)를 **본문이 아니라 별도 메타데이터 파일**(`.openspec.yaml`)에 두고, validator 가 3-way 로 판정한다:

| 마커 | 델타 | 판정 |
|---|---|---|
| 있음 | 있음 | **ERROR** — `skip_specs is set … but spec files exist. Remove skip_specs or delete the delta spec files` |
| 있음 | 없음 | INFO — 수용 |
| 없음 | 없음 | **ERROR** — `Change must have at least one delta` |
| 마커는 있으나 메타데이터가 무효 | — | **ERROR** — 마커 불인정 |

즉 **선언과 산출물의 불일치를 양방향으로 잡는다.**

### specops-ko

`§auto` 자기발급 면제는 v1.45.0 에 제거했으나, **분기 라벨은 여전히 모델이 `spec.md` 본문에 쓴다** — `**§유형**` · `**§lite**` · `<!-- entry: ... -->`.

충돌 검사는 **한 방향뿐**이다:

- `risk-profile.sh` LITE-STRICT-GUARD: `§lite: true` ∧ `effective=strict` ∧ `plan.md 부재` → rc=3
- 역방향(`§lite: true` 인데 `plan.md`·`clarifications.md` 가 **존재**) → 검사 없음
- `§유형: 유지보수` 인데 `current-state.md` 부재 → `check-maintain-baseline.sh` 가 잡음 ✅
- 역방향(`§유형: 신규` 인데 기존 파일 대량 수정) → 검사 없음

**개선안**: `check-label-consistency.sh` — 라벨 ↔ 산출물 존재의 3-way 판정.

> 단서: `§lite` 게이트(LITE-STRICT-GUARD)는 이번 세션에 hard 로 올렸지만 **실측 §lite FID 수가 0이었다.**
> 실입력이 0인 게이트는 검증된 배선점이 아니다 — 확장 시 기존 경로가 함께 흔들릴 수 있다.

---

## G4. 살아있는 capability spec 이 없다 (delta 모델 — 직전 턴 지적 보강)

OpenSpec 은 **자기 자신을 자기 도구로 운영한다**:

```
openspec/specs/     36개 capability spec (cli-validate, schema-resolution, context-injection …)
openspec/changes/archive/   83개 완료 change
```

change 가 archive 될 때 델타가 `specs/` 정본으로 접힌다 → **시스템의 현재 계약이 항상 한곳에 존재한다.**

specops-ko 는 `.specops/<FID>/` 가 쌓이기만 하고 정본이 생기지 않는다. 정본에 가장 가까운 건 `.specops/memory/api-spec.md`·`data-model.md` 인데 **API·DB 만 커버**한다 — CLI·라이브러리·배치 기능은 정본이 없다.

**증상 3개가 같은 원인이다**:
- `/maintain` 이 매번 `current-state.md` 를 새로 뜬다 (baseline 을 코드에서 재발굴)
- `api-spec.md` 가 append 라 계약 드리프트가 쌓인다
- FID 가 무엇을 추가/변경/삭제했는지 기계가 못 읽는다

**개선안**(직전 턴과 동일, 근거만 보강): FID 산출물에 `specs-delta.md`(ADDED/MODIFIED/REMOVED) 추가 + verify PASS 시 `.specops/memory/specs/<capability>.md` 로 접는 `sync` 단계.

---

## G5. 사용자 프로젝트를 진단하는 `doctor` 가 없다

OpenSpec: `commands/doctor.ts`(219) + `core/relationship-health.ts`(166) + `core/profile-sync-drift.ts`(255) — 설치·설정·동기화 상태를 진단하고 **`fix` 문구까지 제시**한다.

specops-ko 의 `validate-structure.sh` 는 **플러그인 개발자용**이다(파일 개수·frontmatter·chain 정합). **사용자 프로젝트의 `.specops/` 건강**을 보는 건 없다:

- git hook 설치됐나 (`install-git-hooks.sh` 는 clone 마다 수동 1회 — 미실행 시 조용히 무방비)
- `.specops/memory/*` 가 채워졌나
- 고아 FID(spec 만 있고 진행 없음)
- `session-progress.md` 와 실제 산출물의 불일치

**개선안**: `/status` 를 확장하거나 `scripts/doctor.sh` 신설. 이번 세션에 만든 checker 16개를 read-only 로 일괄 실행하고 요약하는 얇은 층이면 충분하다.

---

## G6. 워크플로가 데이터가 아니다

OpenSpec `schemas/spec-driven/schema.yaml` — **워크플로 전체가 한 YAML 파일**이다:

```yaml
artifacts:
  - id: proposal
    generates: proposal.md
    template: proposal.md
    instruction: |  ...전체 작성 지침...
    requires: []
  - id: specs
    requires: [proposal]
  - id: tasks
    requires: [specs, design]
apply:
  requires: [tasks]
  tracks: tasks.md
```

의존 DAG·산출물·템플릿·지침이 한곳에 있다. 새 `schema.yaml` 을 넣으면 워크플로가 통째로 바뀐다.

specops-ko 는 `hooks/chain.yaml`(16줄, edge 만) + 각 SKILL.md 본문에 흩어진 지침 + **3곳 동기화를 `validate-structure` 가 감시**하는 구조다. 커스터마이징 지점이 없다.

이건 Spec-Kit 검토에서 나온 "커스터마이징 층 0" 과 **같은 결론에 다른 근거**다 — 두 경쟁 프로젝트가 각자 다른 방식으로 해결한 문제를 specops-ko 만 안 풀었다.

---

## 우선순위

| | 항목 | 비용 | 근거 |
|---|---|---|---|
| **1** | **G1 AC 필드 검증** | 낮음 | `**우선순위**` 필수화 하나가 기존 최강 검사(must AC 역방향 커버리지)의 fail-open 을 닫는다 |
| 2 | G3 라벨↔산출물 3-way | 낮음 | 배선점 존재(risk-profile). 자기발급 면제의 마지막 잔재 |
| 3 | G5 doctor | 낮음 | 기존 checker 재사용. git hook 미설치가 **조용한 무방비**라 실사용 전 필요 |
| 4 | G2 범위 상한 warn | 낮음 | `/start-all` 폭주 방지 |
| 5 | G4 delta 정본 | **높음** | 효과 최대지만 산출물 규약 변경. 실사용 검증 후 |
| 6 | G6 워크플로 데이터화 | **높음** | Spec-Kit 재포지셔닝 검토와 묶어서 판단 |

**추천 1순위 — G1.** 근거: `emit-context.sh` 의 must AC 역방향 커버리지 검사가 **`**우선순위**` 필드 부재 시 무음으로 꺼지는데**, 그 필드를 강제하는 층이 없다. 게이트를 끄는 스위치가 무검증 상태다. 필드 5개(FR 대조 제외) 필수화는 기존 `check-*.sh` 패턴 그대로라 비용이 낮고, 효과는 이미 있는 최강 검사를 되살리는 것이다.

---

## 부록: 이 분석이 쓰지 않은 것

- OpenSpec 의 `Stores`(cross-repo 스펙 공유, beta) — specops-ko 에 대응 수요 없음
- `bulk-archive` 의 병렬 change 충돌 해소 — FID 동시 진행이 드물어 후순위
- OpenSpec `verify` 의 3차원(Completeness/Correctness/Coherence) 리포트 — specops-ko 는 `verifying-evidence-ko` + Phase B/C 로 이미 더 두껍게 덮는다
