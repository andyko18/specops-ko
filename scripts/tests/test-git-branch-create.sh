#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/git-branch-create.sh"

cleanup() {
  cd "$PLUGIN"
  git checkout main 2>/dev/null
  git branch -D "feat/test-fid-abc" 2>/dev/null || true
}
trap cleanup EXIT

cd "$PLUGIN"

# T1: 브랜치 생성 + checkout
out=$(bash "$SCRIPT" test-fid-abc 2>&1); rc=$?
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ $rc -eq 0 ] && [ "$branch" = "feat/test-fid-abc" ] && echo "$out" | grep -q "branch: feat/test-fid-abc"; then
  PASS=$((PASS+1)); echo "PASS T1 브랜치 생성 + checkout"
else
  FAIL=$((FAIL+1)); echo "FAIL T1 (rc=$rc branch=$branch out=$out)"
fi
git checkout main 2>/dev/null

# T2: idempotent — 이미 존재할 때 exit 0
git checkout -b "feat/test-fid-abc" 2>/dev/null || true
git checkout main 2>/dev/null
out=$(bash "$SCRIPT" test-fid-abc 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q "branch: feat/test-fid-abc"; then
  PASS=$((PASS+1)); echo "PASS T2 idempotent"
else
  FAIL=$((FAIL+1)); echo "FAIL T2 (rc=$rc out=$out)"
fi
git checkout main 2>/dev/null

# T3: FID 인자 없으면 exit 1 + 에러 메시지
err=$(bash "$SCRIPT" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -qi "FID"; then
  PASS=$((PASS+1)); echo "PASS T3 FID 없음 → exit 1"
else
  FAIL=$((FAIL+1)); echo "FAIL T3 (rc=$rc err=$err)"
fi

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ]
