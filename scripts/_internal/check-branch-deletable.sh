#!/usr/bin/env bash
# check-branch-deletable.sh — feature branch 삭제 안전 판정 (20260806)
# Usage: check-branch-deletable.sh <branch> [base]     (base 기본 main)
# Exit: 0 = 삭제 허용(근거 stdout) · 1 = 금지 · 2 = 사용 오류·판정 대상 아님
#
# 왜 스크립트인가: `finishing-a-development-branch-ko` 의 핵심 HARD GATE 가
#   `[ "$MERGE_CONFIRMED_BY_GH" = "true" ]` 인데 이 변수를 **모델이 스스로 세팅**한다.
#   gh 가 실제로 MERGED 를 반환했는지 검증하는 층이 0곳이고, `git branch -D`·
#   `git worktree remove`·`git push --delete` 는 pretool 훅 관할 밖이다(R-1/R-2 는
#   commit·PR 만 본다). 미머지 브랜치를 `-D` 하면 **커밋이 소실**된다 — 비가역.
#
# 판정 근거 2종:
#   ① git 조상 — `merge-base --is-ancestor <branch> <base>` (일반 merge)
#   ② gh MERGED  — squash/rebase merge 는 조상이 아니므로 PR 상태로만 확인 가능
# **fail-CLOSED**: 판정 불가(gh 미설치·응답 불가)면 **금지**. 다른 게이트의 fail-open 과
#   반대인 이유는 결과가 비가역 데이터 손실이기 때문이다(안전 쪽이 "안 지움").
# 테스트·비대화 주입: SPECOPS_BRANCH_GH_STATE 로 gh 조회를 대체(실 네트워크 의존 제거).
set -u

BRANCH="${1:-}"
BASE="${2:-main}"
[ -n "$BRANCH" ] || { echo "usage: $0 <branch> [base]" >&2; exit 2; }

git rev-parse --git-dir >/dev/null 2>&1 || { echo "BRANCH-DELETE: git repo 아님" >&2; exit 2; }

# 자기 발등 방지 — base·현재 체크아웃 브랜치는 대상 아님
cur=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [ "$BRANCH" = "$BASE" ]; then
  echo "BRANCH-DELETE: 거부 — base 브랜치($BASE)는 삭제 대상이 아닙니다" >&2
  exit 2
fi
if [ -n "$cur" ] && [ "$BRANCH" = "$cur" ]; then
  echo "BRANCH-DELETE: 거부 — 현재 체크아웃된 브랜치입니다 ($BRANCH). $BASE 로 이동 후 재실행" >&2
  exit 2
fi

git show-ref --verify --quiet "refs/heads/$BRANCH" || {
  echo "BRANCH-DELETE: 브랜치 없음 — $BRANCH" >&2; exit 2
}
git show-ref --verify --quiet "refs/heads/$BASE" || {
  echo "BRANCH-DELETE: base 브랜치 없음 — $BASE" >&2; exit 2
}

# ① git 조상 — 일반 merge 는 여기서 통과 (git branch -d 와 동일 기준)
if git merge-base --is-ancestor "$BRANCH" "$BASE" 2>/dev/null; then
  echo "BRANCH-DELETE: OK — $BRANCH 는 $BASE 에 fully merged (git 조상 확인). 안전 삭제(-d) 가능"
  exit 0
fi

# ② gh MERGED — squash/rebase merge 대응. 자기세팅 변수가 아니라 실제 조회 결과를 본다.
gh_state="${SPECOPS_BRANCH_GH_STATE-}"
if [ -z "${gh_state}" ] && [ "${SPECOPS_BRANCH_GH_STATE+set}" != "set" ]; then
  if command -v gh >/dev/null 2>&1; then
    gh_state=$(gh pr list --head "$BRANCH" --state all --limit 1 --json state \
      --jq '.[0].state // empty' 2>/dev/null || echo "")
  fi
fi

case "$gh_state" in
  MERGED)
    echo "BRANCH-DELETE: OK — 조상은 아니나 gh 가 PR state=MERGED 확인 (squash/rebase merge). -D 허용"
    exit 0 ;;
  "")
    cat >&2 <<EOF
BRANCH-DELETE: 금지 — $BRANCH 가 $BASE 에 미머지이고 머지 증거도 없습니다.
  git 조상 아님 + gh PR 상태 확인 불가(미설치·PR 없음·조회 실패).
  삭제는 비가역이므로 판정 불가 시 **금지**합니다(fail-CLOSED).
  해법: PR 을 머지한 뒤 재실행하거나, 의도적 폐기라면 수동으로 git branch -D 하세요.
EOF
    exit 1 ;;
  *)
    cat >&2 <<EOF
BRANCH-DELETE: 금지 — $BRANCH 미머지 (gh PR state=$gh_state).
  MERGED 가 아닌 상태에서 삭제하면 커밋이 소실됩니다.
EOF
    exit 1 ;;
esac
