#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/show-fid-status.sh"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# T1 — AC-1: 잘못된 FID 형식 → stderr 오류 + exit 1
stdout_out=$("$SCRIPT" "invalid" 2>/dev/null); rc=$?
stderr_out=$("$SCRIPT" "invalid" 2>&1 1>/dev/null)
if [ "$rc" -ne 0 ] && [ -z "$stdout_out" ] && [ -n "$stderr_out" ]; then
  PASS=$((PASS+1)); echo "PASS T1 invalid-fid-format"
else
  FAIL=$((FAIL+1)); echo "FAIL T1 (rc=$rc stdout='$stdout_out' stderr='$stderr_out')"
fi

# T2 — AC-2: 올바른 FID 형식이지만 디렉토리 없음 → exit 1
stdout_out=$("$SCRIPT" "20991231-nonexistent" 2>/dev/null); rc=$?
stderr_out=$("$SCRIPT" "20991231-nonexistent" 2>&1 1>/dev/null)
if [ "$rc" -ne 0 ] && [ -z "$stdout_out" ] && [ -n "$stderr_out" ]; then
  PASS=$((PASS+1)); echo "PASS T2 fid-dir-missing"
else
  FAIL=$((FAIL+1)); echo "FAIL T2 (rc=$rc stdout='$stdout_out' stderr='$stderr_out')"
fi

# T3 — AC-3: 디렉토리 + session-progress 섹션 존재 → exit 0 + FID 헤더 + 이력
T3_FID="20260101-test-feature"
mkdir -p "$TMPDIR_TEST/.specops/$T3_FID"
T3_PROGRESS="$TMPDIR_TEST/.specops/session-progress.md"
printf '## %s · test feature\n\n- 2026-01-01T00:00:00Z /specify 완료 (spec.md)\n' "$T3_FID" > "$T3_PROGRESS"

out=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$T3_FID" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "$T3_FID" && printf '%s' "$out" | grep -q "/specify"; then
  PASS=$((PASS+1)); echo "PASS T3 lifecycle-stages-output"
else
  FAIL=$((FAIL+1)); echo "FAIL T3 (rc=$rc out='$out')"
fi

# T4 — AC-4: spec.md 있음, plan.md 없음 → ✅ / ❌ 표시
T4_FID="20260102-test-artifacts"
mkdir -p "$TMPDIR_TEST/.specops/$T4_FID"
touch "$TMPDIR_TEST/.specops/$T4_FID/spec.md"
printf '## %s\n\n- 2026-01-02T00:00:00Z /specify 완료\n' "$T4_FID" >> "$T3_PROGRESS"

out=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$T4_FID" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qF "✅ spec.md" && printf '%s' "$out" | grep -qF "❌ plan.md"; then
  PASS=$((PASS+1)); echo "PASS T4 artifact-check-display"
else
  FAIL=$((FAIL+1)); echo "FAIL T4 (rc=$rc out='$out')"
fi

# T5 — AC-5: 디렉토리 있지만 session-progress에 섹션 없음 → exit 0 + "(진행 이력 없음)"
T5_FID="20260103-no-history"
mkdir -p "$TMPDIR_TEST/.specops/$T5_FID"

out=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$T5_FID" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "진행 이력 없음"; then
  PASS=$((PASS+1)); echo "PASS T5 no-history"
else
  FAIL=$((FAIL+1)); echo "FAIL T5 (rc=$rc out='$out')"
fi

echo ""
echo "결과: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
