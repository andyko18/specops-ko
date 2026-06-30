---
name: decomposing-ko
description: planning-ko 완료 후 호출 — plan.md를 2~5분 단위 TDD 5스텝 태스크로 분해. 모든 must AC가 최소 1 태스크에 매핑되도록 보장. bash 테스트 컨벤션 (templates/test-conventions-bash.md) 준수 점검 포함
layer: 2
reference_upstream: obra/superpowers@v5.0.7 skills/writing-plans/SKILL.md
  - github/spec-kit commands/tasks.md (specops-ko 경유)
  - specops-ko commands/tasks.md
  - specops-ko templates/tasks.md
  - obra/superpowers@v5.0.7 skills/writing-plans/SKILL.md (bite-sized task 단위)
specops_version: 1.29.0
used_by: planning-ko (chain 진입), implementing-ko (chain 출구), /start-all (BATCH-PHASE1-DONE halt 분기)
---

# Engine 스킬 — 태스크 분해 (decomposing)

`plan.md`의 카테고리·순서를 **2~5분 단위 TDD 바이트사이즈 태스크**로 분해한다. 모든 `must` AC가 **최소 1 태스크**에 매핑되도록 보장.

<HARD-GATE>
**플레이스홀더("TBD", "TODO", "similar to N", 코드 없는 스텝)**가 남은 채로 `specops-auto-ko:implementing-ko` 호출 금지. 커버리지 누락 AC가 있는 채로도 호출 금지.

**bash 테스트 파일 규약**: 생성되는 `test-*.sh` 에 shebang (`#!/usr/bin/env bash`) 또는 실행권한 (exec-bit, `chmod +x`) 이 누락된 채로 `specops-auto-ko:implementing-ko` 호출 금지. 단, 파일 첫 두 줄 내에 `# library-only` 주석 마커가 존재하면 library-only 전용 (sourced only) 으로 간주하여 exec-bit 검증 skip. shebang 은 library-only 포함 모든 bash 테스트 파일에 필수. 상세: `templates/test-conventions-bash.md`.

**Python 테스트 파일 규약**: 생성되는 `test_*.py` 에 exec-bit 및 shebang 불필요. pytest가 직접 실행. 파일명은 `test_<subject>.py` (underscore, hyphen 아님). 상세: `templates/test-conventions-python.md`.

**v0.4a 신규 — DAG 섹션 의무**: `tasks.md` 끝에 `## 의존 그래프` 섹션이 **YAML fenced block** 으로 작성되지 않은 채로 `specops-auto-ko:implementing-ko` 호출 금지. YAML 파싱 실패 (`bash scripts/dag/parse-dag.sh` 의 `dag::find_independent_batch` 가 stderr WARN 발화) 시도 차단. fallback 운영은 implementing-ko 의 sequential 분기 책임 (advisor 협의 13:00 — v0.4a 는 decomposing-ko 자동 생성은 100% YAML 정합 보장).

**foundation 재사용 게이트**: spec.md §유형이 `foundation` 이 **아니고** `.specops/memory/foundation-manifest.md` 가 존재하면, 각 task 에 다음 중 하나가 **반드시** 기재되어야 한다 — 누락 시 `specops-auto-ko:implementing-ko` 호출 금지:
- `**재사용 foundation**: <foundation-manifest.md 의 모듈명>` — foundation 모듈을 재사용하는 경우
- `**미재사용 근거**: <이유>` — 재사용하지 않는 경우 (예: 해당 task 가 foundation 범위 외)
</HARD-GATE>

## 체크리스트

1. **입력 아티팩트 확인** — `.specops/<FID>/plan.md` + `.specops/<FID>/acceptance-criteria.md`. 없으면 planning-ko 선행 요청 후 **중단**
1a. **DAG 힌트 추출 (v0.4b 신규)** — spec.md §2 포함 섹션에서 의존 구조 사전 파악:
   - `(독립 — 병렬 구현 가능)` 표기 항목 2개 이상 → DAG leaf 후보 목록 초기화
   - `(의존: X)` 표기 항목 → 해당 태스크의 `depends_on` 초기값으로 설정
   - 표기 없으면 → 기능 설명에서 독립성 추론 (공유 파일·상태 없으면 독립으로 간주)
   - 결과를 step 10 DAG 의존 그래프에 반영
2. **AC 커버리지 매핑** — 각 `must` AC → 최소 1 태스크 할당. 커버리지 표 작성
3. **파일 구조 확정** — plan.md §파일 구조의 Create/Modify/Delete 목록 고정
4. **TDD 5스텝 작성** — `specops-auto-ko:tdd-ko` 준수:
   - Step 1 RED: 실패 테스트 (실제 코드)
   - Step 2 검증: FAIL 확인
   - Step 3 GREEN: 최소 구현 (실제 코드)
   - Step 4 검증: PASS 확인
   - Step 5 COMMIT: `git add` + 한국어 커밋 메시지
5. **문지기 체크 (원칙 2)** — 파괴적 작업 태스크는 **별도 분리** + `⚠️ 사용자 승인 필요` 표기 + 확인 스텝 삽입
6. **플레이스홀더 스캔** — TBD·TODO·"similar to N" 발견 시 **구체 코드로 대체**
7. **테스트 컨벤션 점검** — 테스트 생성 태스크가 있으면 언어별 컨벤션 준수 확인:
   - bash (`test-*.sh`): `templates/test-conventions-bash.md` 준수. exec-bit·shebang 누락 시 `<HARD-GATE>` 발동
   - Python (`test_*.py`): `templates/test-conventions-python.md` 준수. exec-bit·shebang 불필요. `test_<subject>.py` 명명 위반 시 `<HARD-GATE>` 발동
8. **타입 일관성 점검** — 후속 태스크의 시그니처가 이전 태스크와 일치
9. **출력** — `templates/tasks.md` 구조로 `.specops/<FID>/tasks.md` 생성
10. **DAG 의존 그래프 작성 (v0.4a 신규, 의무)** — `tasks.md` 끝에 `## 의존 그래프` 섹션 추가:
    - **Mermaid block** (사람용 시각화): `graph TD` + 노드·edge
    - **YAML fenced block** (기계용 단일 소스 진실): `tasks:` 배열 — 각 task에 `id`·`depends_on`·`inputs`·`outputs`·`ac` 필드
    - 형식 표준: `templates/tasks.md` 끝 placeholder + `scripts/tests/dag/fixtures/tasks-md/05-diamond.md` 예시 참조
    - **자체 검증**: 작성 직후 다음 명령으로 YAML 정합 + leaf 식별 확인
      ```bash
      source scripts/dag/parse-dag.sh
      yaml=$(dag::extract_yaml .specops/<FID>/tasks.md)
      dag::list_leaves "$yaml"            # 빈 출력 시 YAML 결함 → 재작성
      dag::find_independent_batch "$yaml" # 병렬 후보 출력 (참고용)
      ```
    - YAML 파싱 실패 또는 빈 leaf 시 → 본 스킬 재작성 의무 (HARD-GATE 차단)
    - **Step 10b. emit-context.sh 자동 산출 (Wave 2 U2 — 의무)** — Step 10 의 DAG 자체 검증 통과 후:
      ```bash
      bash scripts/dag/emit-context.sh <FID>
      ```
      - tasks.md YAML 의 모든 task 에 대해 `.specops/<FID>/dispatch/<task-id>-context.md` 5섹션 자동 산출
      - fail-fast atomic — 1건이라도 검증 실패 (test_command 미기재 / ac 배열 빈 값 / AC.md 매칭 AC-id 부재 / inputs·outputs 키 부재) 시 exit 1 + stderr 출력 + 부분 잔류 0
      - 성공 시 stdout `EMIT: N files`
      - 실패 시 본 스킬 재진입 의무 (HARD GATE — tasks.md 정합성 확보 후 재호출)
      - implementing-ko 는 본 산출물의 `.specops/<FID>/dispatch/<task-id>-context.md` 를 leaf dispatch 직전에 §5 worktree 라인만 sed 갱신 (컨텍스트 수동 작성 단계 단순화)
11. **session-progress append** — `bash scripts/session-progress-append.sh <FID> /tasks 완료 "tasks.md (N 태스크)"` 호출. `specops-auto-ko:implementing-ko` 다음 단계 안내
12. **전환** — `specops-auto-ko:implementing-ko` 호출

## 태스크 크기 규약

**각 태스크 = 2~5분 작업 단위**

- 5 스텝 (RED 작성·FAIL 검증·GREEN 구현·PASS 검증·COMMIT)
- 각 스텝에 **실제 코드·명령·예상 출력** 포함
- 단일 파일 또는 밀접한 2~3 파일로 한정
- 스텝 간 의존 없음 (스텝 N+1이 스텝 N 산출 없이도 읽고 이해 가능)

**태스크가 5분을 초과한다면**: 더 작은 태스크로 분할

## 테스트 컨벤션 (bash)

plan.md 가 bash 테스트 파일 생성 태스크를 포함하는 경우, 다음 4 항목 규약을 준수하도록 태스크를 설계한다. 상세는 `templates/test-conventions-bash.md` 참조.

| 항목 | 규칙 요약 | 강도 |
|---|---|---|
| 위치 | `scripts/tests/[feature]/test-*.sh` · 전역은 `scripts/tests/test-*.sh` | 내부 예시 |
| 명명 | `test-<subject>.sh` — subject 는 대응 프로덕션 파일 basename (확장자 제거) | 내부 예시 |
| 실행권한 | `chmod +x` (755) | Universal 강제 |
| 헤더 L1 | `#!/usr/bin/env bash` shebang | Universal 강제 |
| 헤더 L2~ | `set -u`, `PASS=0; FAIL=0`, `PLUGIN=$(cd ... && pwd)`, `T<N>.<letter>` TEST ID | 내부 예시 |

**강도 해석**:
- **Universal 강제** — 위반 시 `<HARD-GATE>` 발동. `specops-auto-ko:implementing-ko` 호출 차단
- **내부 예시** — specops-auto-ko 패턴. downstream 프로젝트 기존 패턴이 있으면 그것 우선
- **단일 예외** — 실행권한 강제는 파일 L2 에 `# library-only` 마커 선언 시 skip (library-only 파일). shebang 은 예외 없음

상세 규약·예시 코드블록·회귀 금지 체크리스트: `templates/test-conventions-bash.md`.

### Python 테스트 파일 (`test_*.py`)

plan.md 가 Python 테스트 파일 생성 태스크를 포함하는 경우, 다음 규약을 준수하도록 태스크를 설계한다. 상세는 `templates/test-conventions-python.md` 참조.

| 항목 | 규칙 | 강도 |
|---|---|---|
| 위치 | `examples/tests/` 또는 downstream 프로젝트 패턴 | 내부 예시 |
| 명명 | `test_<subject>.py` — underscore | Universal 강제 |
| exec-bit | 불필요 | Universal 규약 |
| 헤더 | shebang 불필요 | Universal 규약 |

**강도 해석**:
- **Universal 강제** — `test_*.py` 명명 위반 시 `<HARD-GATE>` 발동
- **Universal 규약** — exec-bit·shebang은 불필요 (bash와 다름)
- **내부 예시** — downstream 프로젝트 기존 패턴이 있으면 그것 우선

상세: `templates/test-conventions-python.md`.

## AC 커버리지 표

```markdown
## AC → Task 매핑

| AC | must/should | Task(s) |
|---|---|---|
| AC-1 | must | Task 1, Task 3 |
| AC-2 | must | Task 2 |
| AC-3 | must | Task 4 |
| AC-4 | should | Task 5 |
| AC-5 | must | Task 6 |

**must AC 커버리지**: 5/5 (100%)
```

**미매핑 must AC가 1건이라도 있으면 → chain 중단, planning-ko 재호출**

## 태스크 포맷

`templates/tasks.md` 그대로 사용. 각 태스크는:

````markdown
### Task N: <컴포넌트명>

**AC 매핑**: AC-1, AC-3
**파일**:
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: RED — 실패 테스트 작성**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: FAIL 검증**

실행: `pytest tests/path/test.py::test_name -v`
예상: `FAIL — function not defined`

- [ ] **Step 3: GREEN — 최소 구현**

```python
def function(input):
    return expected
```

- [ ] **Step 4: PASS 검증**

실행: `pytest tests/path/test.py::test_name -v`
예상: `PASS`

- [ ] **Step 5: COMMIT**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: <기능명> 추가"
```
````

## 마이그레이션 태스크 분해 (DB 스키마 변경 시)

`data-model.md` 스키마 변경(테이블·컬럼·인덱스 신설/변경)이 있으면, 마이그레이션을 **forward+reverse 쌍**으로 분해한다 (단순 "비가역 격리"로 끝내지 말 것):

1. **forward(up) 태스크** — DDL 적용 (`CREATE/ALTER`). `data-model.md` §6 도구(Prisma Migrate/Alembic/Flyway 등)·명명 규약(`<timestamp>_<desc>`) 준수
2. **reverse(down) 태스크** — 롤백 DDL. 가역 가능하면 작성, **데이터 손실 동반(DROP 류)이면** down 으로도 복구 불가임을 명시 + 아래 "파괴적 작업 격리" + `analyzing-ko §2 expand-contract` 적용
3. **마이그레이션 테스트 태스크** — up→down→up **멱등·역가역성** + 제약(NOT NULL/CHECK/UNIQUE) 위반 경로 + 인덱스 존재 검증
4. data-model.md 의 ERD·엔티티표가 forward 와 일치하도록 갱신 (Step 5.6 design-first 산출과 정합)

DAG: down·테스트는 up 에 `depends_on`. 파괴적 forward 는 아래 격리 규칙으로 `irreversible: true`.

## 파괴적 작업 격리

데이터 삭제·프로덕션 설정 변경·마이그레이션 등 **되돌릴 수 없는 작업**은:

1. **별도 태스크**로 분리 (다른 태스크와 합치지 말 것)
2. 태스크 헤더에 `⚠️ 사용자 승인 필요` 표기
3. **Step 0 삽입**: "사용자에게 파괴적 변경 승인 요청. 승인 없으면 태스크 중단"
4. **DAG YAML 노드에 `irreversible: true` 필드 추가** — implementing-ko(부모)가 pre-dispatch에서 이 필드를 읽어 분기 처리:
   - `§batch` → 진행 (오케스트레이터 책임)
   - `§auto` → mini HARD GATE (발생 위치에서 정지): `"AUTO-HARD-GATE: <task-id> 비가역 작업 — 확인 필요 [y/n]"`
   - 단일 모드 → 기존 Step 0 확인

```markdown
### Task 7 ⚠️ 사용자 승인 필요: `.cache/` 디렉토리 정리

- [ ] **Step 0: 승인 요청**

사용자에게 다음 메시지 전달:
> "Task 7은 `.cache/` 디렉토리 전체를 삭제합니다. 진행하시겠습니까? [y/n]"

`y`가 아니면 **중단**.

> **참고 (§auto 모드)**: 서브에이전트는 사용자 채널이 없으므로 Step 0을 직접 실행할 수 없다. `irreversible: true` 필드가 있는 task는 implementing-ko 부모가 pre-dispatch 단계에서 mini HARD GATE를 발동한다. 이 Step 0은 단일 모드 전용이자 PR 게이트 가정 다이제스트의 참조 소스다.

- [ ] **Step 1: RED** ...
```

**DAG YAML `irreversible` 필드 예시**:
```yaml
tasks:
  - id: T7
    irreversible: true   # ← 파괴적/덮어쓰기 작업 표기
    depends_on: [T6]
    outputs: [.cache/]
    ac: [AC-8]
```

## 5원칙 주입 (specops-auto-ko 고유)

| 원칙 | 본 스킬 적용 |
|---|---|
| 1 **투명성** | 각 태스크에 AC 매핑 명시. "이 태스크가 어느 요구사항을 충족하는가" |
| 2 **문지기** | 파괴적 태스크는 별도 격리 + 승인 스텝. 합치지 말 것 |
| 3 **깊이** | 플레이스홀더 남기지 말 것. "similar to N"도 구체화 |
| 4 **주권 존중** | 파괴적 작업 승인은 사용자에게 직접 질문. 대신 결정 금지 |
| 5 **한계 고백** | 불확실한 태스크에 "추정 — 구현 중 확인 필요" 태그 |

## 안티패턴

- **태스크 크기 초과** — 1 태스크 = 2~5분. 더 크면 분할
- **TDD 5스텝 생략** — 특히 RED 검증 스텝 누락
- **플레이스홀더 포함** — TBD·TODO·구현 생략 금지
- **미매핑 must AC 방치** — 커버리지 100% 전 chain 진행 금지
- **파괴적 작업을 일반 태스크에 섞음** — 반드시 격리
- **Task N 참조만으로 코드 생략** — 엔지니어가 순서와 무관하게 읽을 수 있으니 코드 반복

## 참조

- `skills/planning-ko/SKILL.md` — 선행 스킬
- `skills/tdd-ko/SKILL.md` — TDD 5스텝 규약
- `templates/tasks.md` — 출력 포맷
- upstream 근거: Spec-Kit `commands/tasks.md` (specops-ko 경유) + `obra/superpowers@v5.0.7 skills/writing-plans/SKILL.md`의 bite-sized 태스크 단위 규약
- specops-ko 선례: `commands/tasks.md`, `templates/tasks.md`
- `skills/structured-artifacts-ko/SKILL.md` — .specops/<FID>/ 아티팩트 경로 규약
- `skills/karpathy-ko/SKILL.md` — Think·Simplicity·Surgical·Goal 4원칙 (cross-cutting)

## Handoff 기록 (다음 skill 진입 직전 필수)

`implementing-ko` 호출 직전 `.specops/<FID>/handoffs/decomposing.md` 작성 (structured-artifacts-ko 규약 4필드: Decided/Rejected/Risks/Remaining).

## 다음 skill

tasks.md 저장 + AC 커버리지 100% + 플레이스홀더 0 확인 + handoff.md 기록 후:

**3-way 분기 확인**:

```bash
if grep -qE '^\*\*§batch\*\*:' .specops/<FID>/spec.md; then
  echo "BATCH"
elif grep -qE '^\*\*§auto\*\*:[[:space:]]*true' .specops/<FID>/spec.md; then
  echo "AUTO"
else
  echo "SINGLE"
fi
```

- **§batch (batch 분기)** → `BATCH-PHASE1-DONE: <FID>` 출력 후 **halt** (implementing-ko 미호출). `/start-all` 오케스트레이터가 queue.md를 PLAN_DONE으로 갱신하고 다음 FR을 처리한다.
- **§auto (auto 분기)** → implementing-ko 직행. §auto 라벨이 propagate되어 각 단계에서 가역 게이트 자동 통과가 계속됨.
- **단일 분기** → 기존 동작:

```
Skill: specops-auto-ko:implementing-ko
```

implementing-ko가 각 태스크마다 fresh 서브에이전트를 dispatch한다. 본 decomposing-ko는 **batch halt 또는 implementing-ko 이외의 다음 스킬을 호출하지 않는다**.
