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

**HARD GATE 1**: 미커밋 변경이 있으면 중단 — "미커밋 변경이 있습니다. 커밋·stash 후 재실행하세요."

**HARD GATE 2**: 미push 커밋이 있으면 중단 — "push되지 않은 커밋이 있습니다. 브랜치 삭제 전 push하세요."

### Step 2: PR 상태 확인

**gh CLI 가용 시**:
```bash
MERGE_CONFIRMED_BY_GH=false
PR_STATE=$(gh pr view --json state --jq '.state' 2>/dev/null)
echo "PR state: $PR_STATE"
```
- `MERGED` → `MERGE_CONFIRMED_BY_GH=true` 세팅 후 계속 진행
- `OPEN` 또는 `CLOSED` → HARD GATE: "PR이 아직 머지되지 않았습니다. 머지 후 재실행하세요."
- 명령 실패 (gh 미설치 등) → fallback으로 전환

**gh CLI 미가용 시 (fallback)**:
```bash
# squash-merge 에서는 git log 가 커밋 남아있음을 정상 보고 — 완전한 확인 불가
MERGE_CONFIRMED_BY_GH=false
FEAT_BRANCH=$(git branch --show-current)
UNMERGED=$(git log origin/main.."$FEAT_BRANCH" --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNMERGED" -gt 0 ]; then
  echo "경고: origin/main 에 없는 커밋 ${UNMERGED}건. PR이 머지됐나요? [y/n]"
  # squash-merge 시 이 경고는 오탐 가능 — 사용자 응답 대기
fi
```

> **한계**: squash-merge(GitHub 기본값) 환경에서 fallback `git log` 는 오탐 경고를 출력한다. gh CLI 사용 권장.

### Step 3: Worktree 정리

```bash
# 현재 FID 관련 worktree 탐색
git worktree list | grep -F ".worktrees/"

# 각 worktree 제거 (미커밋 변경 있으면 HARD GATE)
git worktree list | grep -F ".worktrees/" | awk '{print $1}' | while read wt; do
  if [ -n "$(git -C "$wt" status --short 2>/dev/null)" ]; then
    echo "HARD GATE: $wt 에 미커밋 변경 있음 — 수동 처리 후 재실행"
    exit 1
  fi
  echo "Removing worktree: $wt"
  git worktree remove "$wt"
done
```

worktree가 없으면 "worktree 없음 — 스킵" 출력 후 다음 단계.

### Step 4: 로컬 feature branch 삭제

```bash
FEAT_BRANCH=$(git branch --show-current)

# main으로 먼저 이동
git checkout main

# 안전 삭제 시도
git branch -d "$FEAT_BRANCH" || {
  # git branch -d 실패 = "not fully merged" (squash/rebase merge 포함)
  if [ "$MERGE_CONFIRMED_BY_GH" = "true" ]; then
    echo "squash/rebase merge 감지 — gh CLI가 MERGED 확인했으므로 -D 허용"
    git branch -D "$FEAT_BRANCH"
  else
    echo "HARD GATE: 브랜치가 완전히 머지되지 않았습니다. PR 상태를 확인하세요."
    echo "  gh CLI로 'state: MERGED' 확인 후 재실행하거나, 수동으로 git branch -D 실행."
    exit 1
  fi
}
```

**HARD GATE**: `MERGE_CONFIRMED_BY_GH=false` (gh CLI 미확인) 상태에서 `-D` 는 절대 금지.
- gh CLI가 `state: MERGED` 확인한 경우에만 squash/rebase merge 대응으로 `-D` 허용 (추측 아닌 근거 기반).

### Step 5: Remote branch 삭제 (사용자 확인)

```bash
echo "remote branch '$FEAT_BRANCH'를 삭제하시겠습니까? [y/n]"
# 사용자 응답 대기
# y 시:
git push origin --delete "$FEAT_BRANCH"
# n 시: "remote branch 유지. 나중에 수동 삭제: git push origin --delete $FEAT_BRANCH"
```

### Step 6: main 동기화

```bash
git checkout main
git pull origin main
echo "main 동기화 완료"
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
