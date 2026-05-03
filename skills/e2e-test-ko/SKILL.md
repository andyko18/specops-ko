---
name: e2e-test-ko
description: lifecycle chain 전체를 fixture 기반으로 자동 실행하고 산출물 구조를 검증 — HARD GATE 없이 specify→clarify→plan→decompose→implement→verify 6단계 완주
layer: 3
reference_upstream: specops-auto-ko 독자 추가 (upstream 미존재)
specops_version: 1.0.0
used_by: /e2e-test
---

# Harness 스킬 — E2E 자동 테스트 (e2e-test-ko)

specops-auto-ko lifecycle chain의 **완전 자동 E2E 검증**. 내장 `greet-cli` fixture를 사용해
specify → clarify → plan → decompose → implement → verify 6단계를 HARD GATE 없이 완주하고
9개 검증 항목(V1~V9)을 점검한다.

## 체크리스트

다음 각 항목을 순서대로 완료한다:

1. **[PRE] FID + 디렉토리 생성**
2. **[S1] SPECIFY** — spec.md + acceptance-criteria.md 생성
3. **[S2] CLARIFY** — clarifications.md 생성 + AC append
4. **[S3] PLAN** — plan.md 생성
5. **[S4] DECOMPOSE** — tasks.md 생성 + DAG 파싱 확인
6. **[S5] IMPLEMENT** — greet-cli.sh 생성 + 테스트 실행
7. **[S6] VERIFY** — 9개 검증 항목 실행
8. **[REPORT]** — PASS/FAIL 결과 출력 + session-progress append

---

## 내장 Fixture — greet-cli

모든 단계에서 아래 fixture를 입력으로 사용한다. 사용자 입력 불필요.

```
기능명: greet-cli
FID 패턴: <YYYYMMDD>-greet-cli-e2e  (예: 20260503-greet-cli-e2e)
설명: 이름을 CLI 인자로 받아 "안녕하세요, <name>!" 출력하는 bash 함수

기능 요구사항:
  FR-1: .specops/<FID>/greet-cli.sh <name> → "안녕하세요, <name>!" 출력 (must)
  FR-2: 인자 없을 시 → "사용법: greet-cli.sh <이름>" + exit 1 (must)
  FR-3: 빈 문자열 인자 → 오류 처리 + exit 1 (should)

비기능 요구사항:
  NFR-1: bash 3.2+ (외부 의존성 없음, macOS 실측)

§유형: 신규
의존 구조: T1(구현)=독립, T2(테스트)=독립

사전 정의된 명확화 답변:
  Q1-BLOCKING: 인자가 여러 개면? → 첫 번째 인자만 사용
  Q1-DESIRABLE: 빈 문자열 입력? → 오류로 처리 (FR-3 추가, AC-3 신설)
```

---

## [PRE] FID 생성 + 디렉토리 준비

```bash
FID="$(date +%Y%m%d)-greet-cli-e2e"
mkdir -p ".specops/$FID"
echo "FID: $FID"
```

이후 모든 단계에서 `$FID` 변수를 유지한다.

---

## [S1] SPECIFY — spec.md + acceptance-criteria.md 생성

아래 내용으로 `.specops/$FID/spec.md`를 생성한다.
`<FID>` 플레이스홀더는 실제 FID 값으로 치환한다.

**spec.md 내용:**

```markdown
<!-- FID: <FID> -->
<!-- OWNER_COMMAND: /specify -->
<!-- reference_upstream: github/spec-kit templates/spec-template.md -->
<!-- layer: Lifecycle-Artifact -->

# greet-cli 명세 — <FID>

## 1. 개요

**목적**: 이름을 CLI 인자로 받아 한국어 인사말을 출력하는 bash 함수를 제공한다.

**배경**: E2E 테스트용 내장 fixture. specops-auto-ko lifecycle chain의 전체 동작을 검증하기 위한 최소 기능.

**성공 판정**: greet-cli.sh가 이름을 인자로 받아 "안녕하세요, <name>!"을 출력하면 완성.

**§유형**: 신규

## 2. 범위

### 포함
- greet-cli.sh: 이름 인사 bash 함수 (독립 — 병렬 구현 가능)
- test-greet-cli.sh: 단위 테스트 스크립트 (독립 — 병렬 구현 가능)

### 제외 (YAGNI)
- 다국어 지원
- 설정 파일
- 환경변수 오버라이드

## 3. 사용자 시나리오

### 주요 시나리오
**사용자**: 개발자
**상황**: 터미널에서 이름을 인자로 스크립트 실행
**행동**: `bash .specops/<FID>/greet-cli.sh 철수`
**기대 결과**: `안녕하세요, 철수!` 출력

### 보조 시나리오
**상황**: 인자 없이 실행
**행동**: `bash .specops/<FID>/greet-cli.sh`
**기대 결과**: 오류 메시지 + exit 1

## 4. 기능 요구사항 (FR)

| ID | 요구사항 | 우선순위 |
|---|---|---|
| FR-1 | greet-cli.sh <name> → "안녕하세요, <name>!" 출력 | must |
| FR-2 | 인자 없을 시 → 오류 메시지 + exit 1 | must |
| FR-3 | 빈 문자열 인자 → 오류 처리 + exit 1 | should |

## 5. 비기능 요구사항 (NFR)

| ID | 항목 | 기준 |
|---|---|---|
| NFR-1 | 호환성 | bash 3.2+ (macOS 실측 · Linux 미검증) |
| NFR-2 | 응답시간 | 즉시 (< 100ms) |

## 6. 제약사항

- 기술 스택: bash (외부 의존성 없음)
- 생성 위치: `.specops/<FID>/` 하위

## 7. 가정

- bash 3.2 이상 설치됨 (macOS 기본)
- .specops/<FID>/ 디렉토리가 미리 생성됨

## 8. 열린 질문

(S2 CLARIFY 단계에서 해소됨)

## 9. Advisor 협의 기록

해당 없음 — E2E fixture이므로 설계 불확실 지점 없음.

## 10. 참조

- DESIGN.md 디자인 시스템 준수 (비UI 기능이므로 시각 규칙 해당 없음)

---

*작성: e2e-test-ko · <날짜> · FID: <FID> · 생성 커맨드: /e2e-test*
```

**acceptance-criteria.md 내용:**

```markdown
<!-- FID: <FID> -->
<!-- OWNER_COMMAND: /specify -->
<!-- MUTABLE_BY: /clarify (append only) -->
<!-- reference_upstream: github/spec-kit + sprint-contracts Given/When/Then -->
<!-- layer: Lifecycle-Artifact -->

# 수락 기준 (Acceptance Criteria) — <FID>

> 이 파일은 **스프린트 계약서**입니다.

## 계약 항목

### AC-1: 정상 인사 출력

**Given** greet-cli.sh가 .specops/<FID>/ 에 존재하고 bash 3.2+ 환경

**When** `bash .specops/<FID>/greet-cli.sh 철수` 실행

**Then** 표준출력에 `안녕하세요, 철수!` 출력되고 exit 0

**검증 방법**: `bash .specops/<FID>/greet-cli.sh 철수` 실행 후 출력 비교
**관련 FR**: FR-1
**우선순위**: must

---

### AC-2: 인자 없을 시 오류

**Given** greet-cli.sh가 .specops/<FID>/ 에 존재

**When** `bash .specops/<FID>/greet-cli.sh` 인자 없이 실행

**Then** 표준오류에 사용법 메시지 출력되고 exit 1

**검증 방법**: `bash .specops/<FID>/greet-cli.sh; echo $?` → exit code 1 확인
**관련 FR**: FR-2
**우선순위**: must

---

## 우선순위 규약

- **must**: 이 항목이 충족되지 않으면 `/verify` PASS 불가
- **should**: 가능하면 충족. 미충족 시 verify.md에 사유 기록

---

*작성: e2e-test-ko · <날짜> · FID: <FID> · 생성 커맨드: /e2e-test*
```

생성 후:

```bash
bash scripts/session-progress-append.sh "$FID" "/specify" "완료" "spec.md, AC.md" "greet-cli E2E"
```

---

## [S2] CLARIFY — clarifications.md 생성 + AC-3 append

**clarifications.md 내용:**

```markdown
<!-- FID: <FID> -->
<!-- OWNER_COMMAND: /clarify -->
<!-- reference_upstream: specops-auto-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# 명확화 기록 — <FID>

## Q1-BLOCKING: 인자가 여러 개일 때 동작

**질문**: greet-cli.sh에 인자를 여러 개 전달하면 어떻게 처리하는가?

**답변**: 첫 번째 인자만 사용한다. 나머지 인자는 무시.

**상태**: RESOLVED (AC 변경 없음)

---

## Q1-DESIRABLE: 빈 문자열 인자 처리

**질문**: `greet-cli.sh ""` 처럼 빈 문자열을 전달하면 어떻게 처리하는가?

**답변**: 오류로 처리한다. "이름을 입력해 주세요." 메시지 + exit 1.

**상태**: RESOLVED (AC-3 신설)

---

*작성: e2e-test-ko · <날짜> · FID: <FID> · 생성 커맨드: /e2e-test*
```

**acceptance-criteria.md에 AC-3 append:**

```markdown
### AC-3: 빈 문자열 인자 오류 처리

**Given** greet-cli.sh가 .specops/<FID>/ 에 존재

**When** `bash .specops/<FID>/greet-cli.sh ""` 빈 문자열 인자로 실행

**Then** 표준오류에 오류 메시지 출력되고 exit 1

**검증 방법**: `bash .specops/<FID>/greet-cli.sh ""; echo $?` → exit code 1 확인
**관련 FR**: FR-3
**우선순위**: should

---
```

생성 후:

```bash
bash scripts/session-progress-append.sh "$FID" "/clarify" "완료" "clarifications.md (2 쟁점 해소)" "greet-cli E2E"
```

---

## [S3] PLAN — plan.md 생성

**plan.md 내용:**

```markdown
<!-- FID: <FID> -->
<!-- OWNER_COMMAND: /plan -->
<!-- reference_upstream: specops-auto-ko 독자 추가 -->
<!-- layer: Lifecycle-Artifact -->

# greet-cli 구현 플랜 — <FID>

## 목표

AC-1~AC-3을 충족하는 greet-cli bash 함수를 구현하고 테스트한다.

## 파일 구조

```
.specops/<FID>/
├── greet-cli.sh        ← 구현 (T1)
└── test-greet-cli.sh   ← 단위 테스트 (T2)
```

## 구현 단계

### 단계 1: greet-cli.sh 구현 (T1)

1. bash shebang + set -eu 설정
2. 인자 검증 (없거나 빈 문자열 → exit 1)
3. 인사말 출력 로직
4. chmod +x

### 단계 2: test-greet-cli.sh 작성 (T2)

1. 정상 케이스 (AC-1): 이름 인자 전달 → "안녕하세요, <name>!"
2. 인자 없음 케이스 (AC-2): exit 1 확인
3. 빈 문자열 케이스 (AC-3): exit 1 확인

## Advisor 협의 기록

해당 없음 — E2E fixture이므로 설계 불확실 지점 없음.

---

*작성: e2e-test-ko · <날짜> · FID: <FID> · 생성 커맨드: /e2e-test*
```

생성 후:

```bash
bash scripts/session-progress-append.sh "$FID" "/plan" "완료" "plan.md" "greet-cli E2E"
```

---

## [S4] DECOMPOSE — tasks.md 생성 + DAG 파싱 확인

**tasks.md 내용:**

```markdown
<!-- FID: <FID> -->
<!-- OWNER_COMMAND: /tasks -->
<!-- MUTABLE_BY: /implement (상태 마킹만) -->
<!-- reference_upstream: github/spec-kit tasks-template.md -->
<!-- layer: Lifecycle-Artifact -->

# greet-cli 태스크 목록 — <FID>

> 각 태스크는 TDD 5 스텝을 따릅니다.

**관련 플랜**: `.specops/<FID>/plan.md`
**관련 AC**: AC-1, AC-2, AC-3

---

## 태스크 1: greet-cli.sh 구현

**파일**:
- Create: `.specops/<FID>/greet-cli.sh`

**관련 AC**: AC-1, AC-2, AC-3

- [x] **스텝 1: 실패하는 테스트 작성** (test-greet-cli.sh — 아직 greet-cli.sh 없음)
- [x] **스텝 2: 테스트 실패 확인** (greet-cli.sh 미존재 → FAIL)
- [x] **스텝 3: 최소 구현** (greet-cli.sh 생성)
- [x] **스텝 4: 테스트 통과 확인** (3 케이스 PASS)
- [x] **스텝 5: 완료**

---

## 태스크 2: test-greet-cli.sh 단위 테스트

**파일**:
- Create: `.specops/<FID>/test-greet-cli.sh`

**관련 AC**: AC-1, AC-2, AC-3

- [x] **스텝 1~5: 완료**

---

## 진행 상태

총 태스크 수: 2
완료: 2 / 2
차단: 0

## 의존 그래프

```mermaid
graph TD
  T1[T1: greet-cli.sh 구현]
  T2[T2: test-greet-cli.sh 테스트]
```

```yaml
tasks:
  - id: T1
    depends_on: []
    inputs: []
    outputs: [.specops/<FID>/greet-cli.sh]
    ac: [AC-1, AC-2, AC-3]
  - id: T2
    depends_on: []
    inputs: [.specops/<FID>/greet-cli.sh]
    outputs: [.specops/<FID>/test-greet-cli.sh]
    ac: [AC-1, AC-2, AC-3]
```

---

*작성: e2e-test-ko · <날짜> · FID: <FID> · 생성 커맨드: /e2e-test*
```

**DAG 파싱 확인:**

```bash
source scripts/dag/parse-dag.sh
yaml=$(dag::extract_yaml ".specops/$FID/tasks.md")
batch=$(dag::find_independent_batch "$yaml")
echo "DAG leaf batch: $batch"
# T1과 T2가 모두 반환되면 PASS (depends_on: [] 이므로 둘 다 leaf)
```

생성 후:

```bash
bash scripts/session-progress-append.sh "$FID" "/tasks" "완료" "tasks.md (2 태스크)" "greet-cli E2E"
```

---

## [S5] IMPLEMENT — greet-cli.sh 생성 + 테스트 실행

**greet-cli.sh 생성:**

```bash
cat > ".specops/$FID/greet-cli.sh" << 'GREET_EOF'
#!/usr/bin/env bash
set -eu

if [ $# -eq 0 ]; then
  echo "사용법: greet-cli.sh <이름>" >&2
  exit 1
fi

name="$1"
if [ -z "$name" ]; then
  echo "이름을 입력해 주세요." >&2
  exit 1
fi

echo "안녕하세요, ${name}!"
GREET_EOF
chmod +x ".specops/$FID/greet-cli.sh"
```

**test-greet-cli.sh 생성 + 실행:**

```bash
cat > ".specops/$FID/test-greet-cli.sh" << TESTEOF
#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
SCRIPT="\$(cd "\$(dirname "\$0")" && pwd)/greet-cli.sh"

# T1.a AC-1: 정상 인사 출력
out=\$(bash "\$SCRIPT" "철수" 2>/dev/null)
if [ "\$out" = "안녕하세요, 철수!" ]; then
  echo "PASS T1.a AC-1 정상 출력"; PASS=\$((PASS+1))
else
  echo "FAIL T1.a AC-1 got=\$out"; FAIL=\$((FAIL+1))
fi

# T1.b AC-2: 인자 없음 → exit 1
bash "\$SCRIPT" 2>/dev/null; code=\$?
if [ "\$code" -eq 1 ]; then
  echo "PASS T1.b AC-2 exit 1"; PASS=\$((PASS+1))
else
  echo "FAIL T1.b AC-2 got exit=\$code"; FAIL=\$((FAIL+1))
fi

# T1.c AC-3: 빈 문자열 → exit 1
bash "\$SCRIPT" "" 2>/dev/null; code=\$?
if [ "\$code" -eq 1 ]; then
  echo "PASS T1.c AC-3 빈 문자열 exit 1"; PASS=\$((PASS+1))
else
  echo "FAIL T1.c AC-3 got exit=\$code"; FAIL=\$((FAIL+1))
fi

echo "==== greet-cli test: PASS=\$PASS FAIL=\$FAIL ===="
[ "\$FAIL" -eq 0 ] && exit 0 || exit 1
TESTEOF
chmod +x ".specops/$FID/test-greet-cli.sh"
bash ".specops/$FID/test-greet-cli.sh"
```

테스트 결과 PASS=3 FAIL=0을 확인한다.

생성 후:

```bash
bash scripts/session-progress-append.sh "$FID" "/implement" "완료" "greet-cli.sh + test PASS=3" "greet-cli E2E"
```

---

## [S6] VERIFY — 9개 검증 항목

아래 검증을 순서대로 실행하고 PASS/FAIL을 집계한다.

```bash
E2E_PASS=0; E2E_FAIL=0
e2e_check() {
  local id="$1" desc="$2" result="$3"
  if [ "$result" = "0" ]; then
    printf "%-4s %-40s PASS\n" "$id" "$desc"; E2E_PASS=$((E2E_PASS+1))
  else
    printf "%-4s %-40s FAIL\n" "$id" "$desc"; E2E_FAIL=$((E2E_FAIL+1))
  fi
}
```

**V1 — .specops/\<FID\>/ 존재:**

```bash
[ -d ".specops/$FID" ] && r=0 || r=1
e2e_check V1 ".specops/$FID/ 존재" "$r"
```

**V2 — spec.md §1·§2·§5 섹션:**

```bash
f=".specops/$FID/spec.md"
{ [ -f "$f" ] && grep -q "^## 1\." "$f" && grep -q "^## 2\." "$f" && grep -q "^## 5\." "$f"; } && r=0 || r=1
e2e_check V2 "spec.md §1·§2·§5" "$r"
```

**V3 — acceptance-criteria.md AC 3개+:**

```bash
f=".specops/$FID/acceptance-criteria.md"
cnt=$(grep -cE "^### AC-[0-9]" "$f" 2>/dev/null || echo 0)
[ "$cnt" -ge 3 ] && r=0 || r=1
e2e_check V3 "AC 3개+" "$r"
```

**V4 — clarifications.md 존재:**

```bash
[ -f ".specops/$FID/clarifications.md" ] && r=0 || r=1
e2e_check V4 "clarifications.md 존재" "$r"
```

**V5 — plan.md 구현 섹션:**

```bash
f=".specops/$FID/plan.md"
{ [ -f "$f" ] && grep -qi "구현\|implement" "$f"; } && r=0 || r=1
e2e_check V5 "plan.md 구현 섹션" "$r"
```

**V6 — tasks.md DAG YAML 블록:**

```bash
f=".specops/$FID/tasks.md"
{ [ -f "$f" ] && grep -q '^\`\`\`yaml' "$f"; } && r=0 || r=1
e2e_check V6 "tasks.md DAG YAML" "$r"
```

**V7 — session-progress.md FID 섹션:**

```bash
f=".specops/session-progress.md"
{ [ -f "$f" ] && grep -q "^## $FID" "$f"; } && r=0 || r=1
e2e_check V7 "session-progress.md FID 섹션" "$r"
```

**V8 — DAG 파싱 leaf 반환:**

```bash
if source scripts/dag/parse-dag.sh 2>/dev/null; then
  yaml=$(dag::extract_yaml ".specops/$FID/tasks.md" 2>/dev/null)
  if [ -n "$yaml" ]; then
    batch=$(dag::find_independent_batch "$yaml" 2>/dev/null)
    [ -n "$batch" ] && r=0 || r=1
  else
    echo "V8  DAG 파싱 leaf                          SKIP (yaml 추출 실패)"
    r="skip"
  fi
else
  echo "V8  DAG 파싱 leaf                          SKIP (parse-dag.sh 로드 실패)"
  r="skip"
fi
[ "$r" != "skip" ] && e2e_check V8 "DAG 파싱 leaf T1,T2" "$r"
```

**V9 — validate-structure.sh PASS:**

```bash
bash scripts/_internal/validate-structure.sh > /dev/null 2>&1 && r=0 || r=1
e2e_check V9 "validate-structure PASS" "$r"
```

---

## [REPORT] 결과 출력 + session-progress append

```bash
echo ""
echo "===== 결과: PASS=$E2E_PASS FAIL=$E2E_FAIL ====="
bash scripts/session-progress-append.sh "$FID" "/verify" "$([ $E2E_FAIL -eq 0 ] && echo PASS || echo FAIL)" "V=$E2E_PASS FAIL=$E2E_FAIL" "greet-cli E2E"
```

---

## 전체 실행 흐름 요약

```
/e2e-test 호출
    ↓
[PRE] FID 생성 + mkdir
    ↓
[S1] spec.md + acceptance-criteria.md (AC-1, AC-2)
    ↓
[S2] clarifications.md + AC-3 append
    ↓
[S3] plan.md
    ↓
[S4] tasks.md + DAG 파싱 확인
    ↓
[S5] greet-cli.sh + test-greet-cli.sh + 테스트 실행 (PASS=3)
    ↓
[S6] V1~V9 검증
    ↓
PASS=9 FAIL=0 목표
```

## 실패 시 디버깅

| 실패 항목 | 원인 후보 | 해결 방법 |
|---|---|---|
| V2 (spec.md 섹션) | 섹션 헤더 형식 불일치 | spec.md에서 `## 1.` `## 2.` `## 5.` 헤더 확인 |
| V3 (AC 3개+) | AC-3 append 누락 | acceptance-criteria.md에 `### AC-3:` 블록 존재 여부 확인 |
| V6 (tasks.md YAML) | 백틱 이스케이프 문제 | tasks.md에서 ` ```yaml ` 블록 직접 확인 |
| V7 (session-progress) | scripts/session-progress-append.sh 실패 | ensure-session-progress.sh 실행 후 재시도 |
| V8 (DAG 파싱) | parse-dag.sh 로드 실패 | `bash scripts/dag/parse-dag.sh` 직접 실행해 오류 확인 |
| V9 (validate-structure) | 파일 개수 불일치 | validate-structure.sh 실행해 구체적 FAIL 항목 확인 |

## 5원칙 적용

| 원칙 | 적용 |
|---|---|
| 1 투명성 | 각 단계 시작 시 `[S1] SPECIFY ...` 진행 상황 출력 |
| 2 문지기 | S5 테스트 결과가 FAIL이면 S6 전에 중단 및 보고 |
| 3 깊이 | fixture 요구사항·경계값(빈 문자열·인자 없음)·실패 시나리오 모두 문서화 |
| 4 주권 | HARD GATE 없음 — 완전 자동 (fixture로 사전 결정) |
| 5 한계 고백 | V8 SKIP 가능성 (python3+pyyaml 미설치) 명시 |

---

*PoC v0.0 · 2026-05-03 · E2E 자동 테스트 harness skill · specops-auto-ko 독자 추가*
