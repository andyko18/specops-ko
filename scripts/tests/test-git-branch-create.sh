#!/usr/bin/env bash
# scripts/git-branch-create.sh 검증 — 격리 sandbox (실 repo 변이 금지, LOW 정리 2026-06-11)
# set -u only (no -e): rc=$? 캡처를 위해 -e 의도적으로 생략
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/git-branch-create.sh"

# sandbox: throwaway git repo — 실 repo 브랜치/체크아웃 상태 무변이
SB=$(mktemp -d)
trap 'rm -rf "$SB"' EXIT
git -C "$SB" init -q -b main
git -C "$SB" config user.email "t@t.com"
git -C "$SB" config user.name "T"
( cd "$SB" && git commit -q --allow-empty -m init )
cd "$SB"

# T1: 브랜치 생성 + checkout
out=$(bash "$SCRIPT" test-fid-abc 2>&1); rc=$?
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ $rc -eq 0 ] && [ "$branch" = "feat/test-fid-abc" ] && echo "$out" | grep -q "branch: feat/test-fid-abc"; then
  PASS=$((PASS+1)); echo "PASS T1 브랜치 생성 + checkout"
else
  FAIL=$((FAIL+1)); echo "FAIL T1 (rc=$rc branch=$branch out=$out)"
fi

# T2: idempotent — 이미 존재할 때 exit 0 + 브랜치 checkout 확인 (AC-2)
git checkout -q main 2>/dev/null
out=$(bash "$SCRIPT" test-fid-abc 2>&1); rc=$?
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ $rc -eq 0 ] && [ "$branch" = "feat/test-fid-abc" ] && echo "$out" | grep -q "branch: feat/test-fid-abc"; then
  PASS=$((PASS+1)); echo "PASS T2 idempotent"
else
  FAIL=$((FAIL+1)); echo "FAIL T2 (rc=$rc branch=$branch out=$out)"
fi

# T3: FID 인자 없으면 exit 1 + 에러 메시지
err=$(bash "$SCRIPT" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -qi "FID"; then
  PASS=$((PASS+1)); echo "PASS T3 FID 없음 → exit 1"
else
  FAIL=$((FAIL+1)); echo "FAIL T3 (rc=$rc err=$err)"
fi

# T4: invalid FID — 공백·연속 점·ref 금지문자 차단 (가드 회귀)
for bad in "a b" "a..b" 'x~y'; do
  err=$(bash "$SCRIPT" "$bad" 2>&1); rc=$?
  if [ $rc -eq 1 ] && echo "$err" | grep -q "invalid FID"; then
    PASS=$((PASS+1)); echo "PASS T4 invalid FID '$bad' → exit 1"
  else
    FAIL=$((FAIL+1)); echo "FAIL T4 '$bad' (rc=$rc err=$err)"
  fi
done

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ]
