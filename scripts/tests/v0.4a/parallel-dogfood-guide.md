# v0.4a 병렬 dogfood 가이드 — 3 독립 leaf 검증

**목적**: v0.4a #26 (🚀 DAG 자동 라우팅) 본 차별화 자산을 dogfood로 실측 검증.

**예상 시간**: 30-60분 (cvt-cli 직전 dogfood와 비슷한 규모, 단 3 독립 leaf 의도 설계).

---

## ⚠️ cvt-cli 학습 사항 (chain DAG 한계)

직전 cvt-cli dogfood (FID 20260426-cvt-cli)는 lifecycle 완주했지만 **DAG 가 chain 구조** (`T1→T2→T3→T4→T5`) 라 절대 leaf 1개 (T1) 만 → 병렬 라우팅 미트리거.

W7 PASS 기준 (`phase=parallel batch_size=N (N≥2)`) 충족하려면 **의도적으로 3 독립 leaf** 가 나오는 기능 설계 필요.

---

## ⭐ 추천 기능: `encode-decode-validate` 3 독립 leaf

**기능**: Base64 인코더 + 디코더 + 검증기 — 3 독립 도구, 각자 독립 파일.

### 의도된 DAG 구조 (병렬 후보 명백)

```
T1: encode-base64 (src/encode.sh + tests/test-encode.sh)
T2: decode-base64 (src/decode.sh + tests/test-decode.sh)  
T3: validate-base64 (src/validate.sh + tests/test-validate.sh)

depends_on: 모두 [] (절대 leaf)
outputs: 완전 disjoint (서로 다른 파일)
```

**기대 DAG-AWARE PARALLEL 트리거**:
- `dag::find_independent_batch` → T1, T2, T3 (3 leaf)
- `dispatching-parallel-agents-ko` 호출 → batch_size=3
- 각 leaf별 worktree (`.worktrees/<FID>-T1/`, `-T2/`, `-T3/`)
- AC injection 3 context.md 파일 작성

### 자연어 진입 예시

```
Base64 인코더, 디코더, 검증기 3개 독립 bash CLI 만들고 싶어. 각자 다른 파일에 분리.
```

또는

```
다음 3개 독립 도구를 한 번에 구현해줘 (서로 의존성 없음):
1. base64 encode CLI
2. base64 decode CLI  
3. base64 검증 CLI (입력이 valid base64인지 확인)
```

---

## 사전 점검

```bash
# 1. v0.4a 인프라 commits 확인
git log --oneline | grep "v0.4a" | head -7
# 기대: W1·W2·W3·W4·W5·W6 6개 commit

# 2. 기존 dogfood 자산 확인
ls .specops/
# 기대: 20260425-slug-cli, 20260426-epoch-iso-cli, 20260426-cvt-cli (cvt 는 chain 한계 사례)

# 3. archive 태그 확인
git tag --list 'archive/*'

# 4. governance 회귀 0
bash scripts/tests/governance/test-rules.sh 2>&1 | tail -3
# 기대: PASS=36 FAIL=0

# 5. DAG 파서 회귀 0
bash scripts/tests/dag/test-parse-dag.sh 2>&1 | tail -2
# 기대: PASS=13 FAIL=0
```

---

## dogfood 진행 단계

### Step 1: Claude Code 재시작 + 새 conversation
- Claude Code 종료 → 재실행 → 새 대화 시작

### Step 2: 첫 입력 (위 자연어 진입 예시 중 선택)
- 메타 skill 자동 활성 → specifying-ko 진입

### Step 3: lifecycle 자동 진행 관찰
- `specifying-ko` (mode=Standard 추천) → spec.md 작성
- `clarifying-ko` → clarifications.md
- `planning-ko` → plan.md (반드시 §9 Advisor 협의 기록 포함 — R-5 false positive 차단)
- `decomposing-ko` → tasks.md + **DAG YAML** (T1·T2·T3 절대 leaf 의도)
- `implementing-ko` → **DAG-AWARE PARALLEL 분기** 트리거
  - `.specops/<FID>/dispatch/T1-context.md`, `T2-context.md`, `T3-context.md` 작성
  - `validate-context.sh` 검증
  - `using-git-worktrees-ko` 3 worktree 생성
  - `dispatching-parallel-agents-ko` 호출 → 3 leaf 병렬 dispatch
  - 각 leaf: `implementer-ko` agent in worktree
  - Phase B/C 리뷰 (각 leaf별)
  - 부모 머지 + commit
- `verifying-evidence-ko` → evidence.md
- 종료

### Step 4: PASS 기준 검증

dogfood 종료 후:

```bash
# FID 자동 감지
FID=$(grep -E '^## [0-9]{8}-' .specops/session-progress.md | head -1 | sed -E 's/## ([0-9]{8}-[a-z0-9-]+).*/\1/')
echo "FID: $FID"

# v0.4a W7 PASS 기준 자동 검증
bash scripts/tests/v0.4a/verify-parallel-dispatch.sh "$FID"
```

**기대 출력**:
```
=== 검증 1: tasks.md DAG 절대 leaf ≥ 2 ===
✅ tasks.md 절대 leaf 수: 3 (≥2 필요)

=== 검증 2: dispatch-log.md 병렬 dispatch 증거 ===
✅ dispatch-log 병렬 마커 수: 1 (≥1 필요)

=== 검증 3: dispatch 디렉터리 leaf별 context.md ≥ 2 ===
✅ dispatch/ context.md 파일 수: 3 (≥2 필요)
✅ context 파일 5 컨텍스트 모두 충족: 3/3

=== 검증 4: friction-log false positive (R-3 + R-4 + R-5) ≤ 4 ===
✅ false positive 후보: ≤4

==== Results: PASS=4 FAIL=0 ====
✅ v0.4a W7 PASS 기준 모두 충족
```

---

## 발생 가능 문제 + fallback

| 증상 | 진단 | 해결 |
|---|---|---|
| `decomposing-ko` 가 chain DAG 작성 (cvt-cli 같은 한계) | 사용자 입력이 의존성 있는 기능으로 해석 | 자연어 진입 시 "**서로 의존성 없음**" 명시 |
| DAG-AWARE PARALLEL 분기 미트리거 | `dag::find_independent_batch` 빈 출력 | tasks.md DAG YAML 수동 검증: `bash scripts/dag/parse-dag.sh` source 후 `dag::list_leaves` 호출 |
| AC injection context 파일 부재 | implementing-ko 가 W5 분기 미실행 | implementing-ko SKILL.md DAG-AWARE PARALLEL 분기 (line 39-96) 따라가는지 확인 |
| R-3·R-5 false positive 재발 | v0.4-pre 매처 정정 미커버 동사·plan §9 부재 | (별건) v0.4-pre 보강 plan 진입 — R-3 추가 동사 + plan §9 자동 placeholder |

---

## 결과 보고 (다음 conversation)

dogfood 종료 후:
```
v0.4a 병렬 dogfood 완료 (FID: <new-FID>). verify-parallel-dispatch.sh 결과 확인 후 case-study 작성해줘.
```

→ assistant가 자동으로 분석 + `docs/case-studies/2026-XX-XX-v0.4a-parallel-dispatch-validation.md` 작성 (W10 작업).

---

*v0.4a W7 가이드 · 2026-04-26 · cvt-cli chain 한계 학습 반영*
