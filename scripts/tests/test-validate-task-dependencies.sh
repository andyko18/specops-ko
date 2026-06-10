#!/usr/bin/env bash
# specops-ko v0.2 · scripts/_internal/validate-task-dependencies.sh 검증
set -u
PASS=0; FAIL=0
SCRIPT="bash ./scripts/_internal/validate-task-dependencies.sh"

# T1 usage
err=$($SCRIPT 2>&1 >/dev/null) ; rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'usage:'; then
  PASS=$((PASS+1)); echo "PASS T1 usage"
else
  FAIL=$((FAIL+1)); echo "FAIL T1 usage (rc=$rc)"
fi

# T2 FID 디렉토리 없음
err=$($SCRIPT 20260420-ghost 2>&1 >/dev/null) ; rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'not found'; then
  PASS=$((PASS+1)); echo "PASS T2 missing FID"
else
  FAIL=$((FAIL+1)); echo "FAIL T2 missing FID (rc=$rc)"
fi

# sandbox setup: 임시 FID 디렉토리 생성
FID="test-$$-$RANDOM"
FIDDIR=".specops/$FID"
mkdir -p "$FIDDIR"

cleanup() { rm -rf "$FIDDIR"; }
trap cleanup EXIT

# T3 참조 없음 → exit 0
cat > "$FIDDIR/tasks.md" <<'EOF'
# 태스크
- 별다른 shell 의존 없음
- 그냥 Python `.py` 파일만 언급
EOF
out=$($SCRIPT "$FID") ; rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q 'no shell task dependencies'; then
  PASS=$((PASS+1)); echo "PASS T3 no refs"
else
  FAIL=$((FAIL+1)); echo "FAIL T3 no refs (rc=$rc, out=$out)"
fi

# T4 모두 존재 + exec-bit → exit 0 (실 프로젝트 내 기존 스크립트 사용)
cat > "$FIDDIR/tasks.md" <<'EOF'
# 태스크
bash scripts/_internal/count-artifacts.sh 를 실행한다.
EOF
out=$($SCRIPT "$FID") ; rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q 'all ok'; then
  PASS=$((PASS+1)); echo "PASS T4 all ok"
else
  FAIL=$((FAIL+1)); echo "FAIL T4 all ok (rc=$rc, out=$out)"
fi

# T5 누락 파일 → exit 1
cat > "$FIDDIR/tasks.md" <<'EOF'
# 태스크
scripts/nonexistent-ghost.sh 실행
EOF
err=$($SCRIPT "$FID" 2>&1 >/dev/null) ; rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'MISSING'; then
  PASS=$((PASS+1)); echo "PASS T5 missing file"
else
  FAIL=$((FAIL+1)); echo "FAIL T5 missing file (rc=$rc, err=$err)"
fi

# T6 exec-bit 없음 → exit 1
noexec_dir="$FIDDIR/fixtures"
mkdir -p "$noexec_dir"
# 임시 .sh 파일 생성 (scripts/fixtures/ 관례 회피 위해 FID 하위 경로는 detect되지 않음 — 직접 프로젝트 루트 상대경로 필요)
# 대신 실제 tests/ 경로에 noexec 파일 한 번 배치
fixture="tests/_tmp_noexec_$$_$RANDOM.sh"
mkdir -p tests
echo '#!/usr/bin/env bash' > "$fixture"
chmod -x "$fixture" 2>/dev/null || true
cat > "$FIDDIR/tasks.md" <<EOF
# 태스크
$fixture 를 확인한다
EOF
err=$($SCRIPT "$FID" 2>&1 >/dev/null) ; rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'NOT_EXEC'; then
  PASS=$((PASS+1)); echo "PASS T6 exec-bit missing"
else
  FAIL=$((FAIL+1)); echo "FAIL T6 exec-bit missing (rc=$rc, err=$err)"
fi
rm -f "$fixture"
# tests/ 디렉토리가 비어있으면 정리
rmdir tests 2>/dev/null || true

# T7 실행권한
if [ -x scripts/_internal/validate-task-dependencies.sh ]; then
  PASS=$((PASS+1)); echo "PASS T7 exec-bit"
else
  FAIL=$((FAIL+1)); echo "FAIL T7 exec-bit"
fi

echo "passed=$PASS failed=$FAIL"
exit $FAIL
