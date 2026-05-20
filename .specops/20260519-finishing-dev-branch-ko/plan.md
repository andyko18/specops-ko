<!-- FID: 20260519-finishing-dev-branch-ko -->
<!-- OWNER_COMMAND: /plan -->
<!-- layer: Lifecycle-Artifact -->

# finishing-a-development-branch-ko 구현 플랜 — 20260519-finishing-dev-branch-ko

> **에이전트 워커용**: 필수 하위 스킬 — `specops-auto-ko:implementing-ko` (권장) 또는 `specops-auto-ko:decomposing-ko` 사용. 스텝은 체크박스 `- [ ]` 문법으로 추적.

**목표**: `skills/finishing-a-development-branch-ko/SKILL.md` 신규 생성 — PR 머지 후 worktree 정리·branch 삭제·main 동기화 체크리스트를 제공하는 layer:2 Engine 스킬.

**아키텍처**: 단일 SKILL.md 문서 파일 생성 + baseline count 갱신. 기존 layer:2 스킬 패턴(frontmatter 6필드, `## 5원칙 주입`, `## 다음 skill`)을 그대로 따름. `using-git-worktrees-ko`의 짝 스킬로 등록됨.

**기술 스택**: SKILL.md (markdown 문서), bash 명령어 코드블록

**관련 AC**: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8, AC-9, AC-10, AC-R-1, AC-R-2

---

## 1. 가정 (5원칙 5번)

- Feature branch 명명은 `feat/<FID>` 패턴을 따른다
- Worktree 디렉터리는 `.worktrees/<FID>-<task-id>/` 패턴
- gh CLI가 없을 수 있으므로 `git log origin/main..feat/<FID>` fallback 제공
- SKILL.md는 실행 코드가 아닌 에이전트 행동 가이드 문서다

## 2. 파일 구조

### 생성
- `skills/finishing-a-development-branch-ko/SKILL.md` — Lifecycle 최종 정리 Engine 스킬

### 수정
- `scripts/_internal/.structure-baseline` — skills count 24→25

## 3. 태스크 개요

태스크 1개로 충분 (파일 생성 + baseline 갱신 — 강하게 결합):

1. **T1: SKILL.md 생성 + baseline 갱신** — frontmatter·체크리스트 전 절차·5원칙·다음 skill 포함

## 4. SKILL.md 전체 내용 (Task 3 구현 참조)

```markdown
---
name: finishing-a-development-branch-ko
description: feature branch 작업 완료 후 worktree 정리·branch 삭제·main 동기화를 체계적으로 수행하는 Lifecycle 최종 정리 스킬
layer: 2
reference_upstream: obra/superpowers@v5.0.7 skills/finishing-a-development-branch/SKILL.md
specops_version: 1.0.0
used_by: specops-auto-ko:using-git-worktrees-ko (짝 스킬 — 작업 완료 후 호출)
---

# Engine 스킬 — 개발 브랜치 정리 (finishing-a-development-branch)

## 개요

feature branch 작업·PR 머지가 완료된 후 **worktree 제거 → local/remote branch 삭제 → main 동기화** 순서로 저장소를 클린 상태로 복원한다.

**핵심 원칙**: 미머지 브랜치 강제 삭제 금지. remote 삭제는 반드시 사용자 확인 후.

**시작 시 선언**: "specops-auto-ko:finishing-a-development-branch-ko 스킬로 브랜치 정리를 시작합니다."

## 체크리스트

### Step 1: 현재 상태 확인

```bash
# 현재 브랜치 확인
git branch --show-current

# 미커밋 변경 확인
git status --short

# 미push 커밋 확인 (비어있어야 정상)
git log origin/$(git branch --show-current)..HEAD --oneline 2>/dev/null \
  | head -5
```

**HARD GATE**: 미커밋 변경이 있으면 중단 — "미커밋 변경이 있습니다. 커밋·stash 후 재실행하세요."

### Step 2: PR 상태 확인

**gh CLI 가용 시**:
```bash
gh pr view --json state,number,title 2>/dev/null
```
- `state: MERGED` → 계속 진행
- `state: OPEN` 또는 `CLOSED` → HARD GATE: "PR이 아직 머지되지 않았습니다. 머지 후 재실행하세요."

**gh CLI 미가용 시 (fallback)**:
```bash
# 로컬 브랜치가 origin/main 에 포함되어 있으면 머지된 것으로 간주
FEAT_BRANCH=$(git branch --show-current)
UNMERGED=$(git log origin/main.."$FEAT_BRANCH" --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNMERGED" -gt 0 ]; then
  echo "⚠️ 경고: origin/main 에 없는 커밋 ${UNMERGED}건. PR이 머지됐나요? [y/n]"
  # 사용자 응답 대기
fi
```

### Step 3: Worktree 정리

```bash
# 현재 FID 관련 worktree 탐색
git worktree list | grep ".worktrees/"

# 각 worktree 제거
# git worktree remove --force .worktrees/<FID>-<task-id>
# 예시:
git worktree list | grep ".worktrees/" | awk '{print $1}' | while read wt; do
  echo "Removing worktree: $wt"
  git worktree remove --force "$wt"
done
```

worktree가 없으면 "worktree 없음 — 스킵" 출력 후 다음 단계.

### Step 4: 로컬 feature branch 삭제

```bash
FEAT_BRANCH=$(git branch --show-current)

# main으로 먼저 이동
git checkout main

# 안전 삭제 (미머지 시 에러 발생 — 의도적)
git branch -d "$FEAT_BRANCH"
```

**HARD GATE**: `git branch -d` 가 "not fully merged" 에러 발생 시:
- `-D` 강제 삭제 **금지**
- "브랜치가 완전히 머지되지 않았습니다. PR 상태를 확인하세요." 출력 후 중단
- 사용자가 명시적으로 `-D` 를 요청해야만 실행

### Step 5: Remote branch 삭제 (사용자 확인)

```bash
echo "remote branch 'feat/<FID>'를 삭제하시겠습니까? [y/n]"
# 사용자 응답 대기
# y 시:
git push origin --delete "$FEAT_BRANCH"
# n 시: "remote branch 유지. 나중에 수동 삭제: git push origin --delete $FEAT_BRANCH"
```

### Step 6: main 동기화

```bash
git checkout main
git pull origin main
echo "✅ main 동기화 완료"
```

### Step 7: 정리 확인

```bash
echo "=== 잔류 worktree 확인 ==="
git worktree list

echo "=== 잔류 로컬 브랜치 확인 ==="
git branch

echo "=== 정리 완료 ==="
```

feat/<FID> 브랜치와 관련 worktree가 목록에 없으면 정리 성공.

## 5원칙 주입 (specops-auto-ko 고유)

| 원칙 | 본 스킬 적용 |
|---|---|
| 1 **투명성** | 각 단계 실행 전 "무엇을 하려 하는지" 1줄 출력 |
| 2 **문지기** | 미머지 상태에서 `-D` 강제 삭제 절대 금지. remote 삭제 전 반드시 확인 |
| 3 **깊이** | PR 상태를 실제 확인 — "아마 머지됐겠지" 추측 금지 |
| 4 **주권 존중** | remote branch 삭제는 사용자가 결정. 자동 삭제 금지 |
| 5 **한계 고백** | gh CLI 미가용 시 git log fallback 사용 — "머지 여부를 완전히 확인할 수 없음" 명시 |

## 참조

- 짝 스킬: `skills/using-git-worktrees-ko/SKILL.md` — worktree 생성 측
- upstream 참조: `obra/superpowers@v5.0.7 skills/finishing-a-development-branch/SKILL.md`

## 다음 skill

본 스킬은 Lifecycle의 **최종 정리 단계**다. 정리 완료 후 chain을 시작하지 않는다.

다음 기능 작업은 `/start "<기능>"` 또는 `/maintain "<대상>"` 으로 새 Lifecycle을 시작한다.
```

## 5. 위험과 완화

| 위험 | 영향 | 완화 |
|---|---|---|
| `git branch -d` 실패 시 `-D` 강제 실행 유혹 | H | Step 4 HARD GATE — 명시 금지, 사용자 명시 승인 필수 |
| gh CLI 없이 PR 미머지 감지 실패 | M | git log fallback + [y/n] 사용자 확인 |
| baseline count 미갱신 | M | validate-structure.sh 검증으로 즉시 탐지 |

## 6. 자체 검토 (5원칙 체크리스트)

- [x] **투명성**: 각 Step에 "무엇을 하는지" 명시됨
- [x] **문지기**: `-D` 강제 삭제 HARD GATE, remote 삭제 사용자 확인 Step 명시됨
- [x] **주권 존중**: remote 삭제 [y/n] 표기됨
- [x] **한계 고백**: §1 가정에 gh CLI fallback 명시됨

## 7. Advisor 협의 기록

해당 없음 — 본 plan 작성 중 불확실 지점 없음. SKILL.md 단일 파일 생성으로 구조 단순.

## 8. 다음 단계

`/tasks 20260519-finishing-dev-branch-ko` — 본 플랜을 바이트-사이즈 TDD 태스크로 분해.

---

*작성: planning-ko · 2026-05-19 · FID: 20260519-finishing-dev-branch-ko · 생성 커맨드: /plan*
