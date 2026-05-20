#!/usr/bin/env bash
# v0.4a W1 — parse-dag.sh 단위 테스트
# 6 fixture × 4 함수 검증 + malformed fallback
# 컨벤션: templates/test-conventions-bash.md (PASS=N FAIL=N 카운터)

set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
FIXTURES="$PLUGIN/scripts/tests/dag/fixtures/tasks-md"

# shellcheck disable=SC1091
source "$PLUGIN/scripts/dag/parse-dag.sh"

# --- T1: extract_yaml ---
# T1.a — fixture 01에서 yaml block 추출 시 'tasks:' 라인 포함
yaml=$(dag::extract_yaml "$FIXTURES/01-two-leaves-disjoint.md")
if echo "$yaml" | grep -q "^tasks:"; then
  PASS=$((PASS+1)); echo "PASS T1.a extract_yaml fixture 01 → tasks: 라인 포함"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a — yaml=$yaml"
fi

# T1.b — fixture 03 (single leaf)
yaml=$(dag::extract_yaml "$FIXTURES/03-single-leaf.md")
if echo "$yaml" | grep -q "id: T1"; then
  PASS=$((PASS+1)); echo "PASS T1.b extract_yaml fixture 03 → id: T1 포함"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.b"
fi

# --- T2: list_leaves ---
# T2.a — fixture 01 두 leaf
yaml=$(dag::extract_yaml "$FIXTURES/01-two-leaves-disjoint.md")
out=$(dag::list_leaves "$yaml" | sort | tr '\n' ',')
if [ "$out" = "T1,T2," ]; then
  PASS=$((PASS+1)); echo "PASS T2.a list_leaves fixture 01 → T1,T2"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.a (out=$out)"
fi

# T2.b — fixture 04 chain (T1만 절대 leaf)
yaml=$(dag::extract_yaml "$FIXTURES/04-chain.md")
out=$(dag::list_leaves "$yaml" | sort | tr '\n' ',')
if [ "$out" = "T1," ]; then
  PASS=$((PASS+1)); echo "PASS T2.b list_leaves fixture 04 → T1만"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.b (out=$out)"
fi

# T2.c — fixture 05 diamond (T1·T2 절대 leaf)
yaml=$(dag::extract_yaml "$FIXTURES/05-diamond.md")
out=$(dag::list_leaves "$yaml" | sort | tr '\n' ',')
if [ "$out" = "T1,T2," ]; then
  PASS=$((PASS+1)); echo "PASS T2.c list_leaves fixture 05 → T1,T2"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.c (out=$out)"
fi

# --- T3: outputs_disjoint ---
# T3.a — fixture 01 T1·T2 disjoint
yaml=$(dag::extract_yaml "$FIXTURES/01-two-leaves-disjoint.md")
if dag::outputs_disjoint "$yaml" T1 T2; then
  PASS=$((PASS+1)); echo "PASS T3.a outputs_disjoint fixture 01 T1·T2 → disjoint (exit 0)"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.a (exit $?)"
fi

# T3.b — fixture 02 T1·T2 overlap (같은 src/shared.sh 수정)
yaml=$(dag::extract_yaml "$FIXTURES/02-two-leaves-overlap.md")
if ! dag::outputs_disjoint "$yaml" T1 T2; then
  PASS=$((PASS+1)); echo "PASS T3.b outputs_disjoint fixture 02 T1·T2 → overlap (exit 1)"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.b — overlap 인데 disjoint 판정"
fi

# --- T4: find_independent_batch ---
# T4.a — fixture 01 → batch [T1, T2]
yaml=$(dag::extract_yaml "$FIXTURES/01-two-leaves-disjoint.md")
out=$(dag::find_independent_batch "$yaml" | sort | tr '\n' ',')
if [ "$out" = "T1,T2," ]; then
  PASS=$((PASS+1)); echo "PASS T4.a find_independent_batch fixture 01 → T1,T2"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.a (out=$out)"
fi

# T4.b — fixture 02 overlap → batch 빈
yaml=$(dag::extract_yaml "$FIXTURES/02-two-leaves-overlap.md")
out=$(dag::find_independent_batch "$yaml")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T4.b find_independent_batch fixture 02 → 빈 batch (overlap)"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.b (out=$out)"
fi

# T4.c — fixture 03 single leaf → batch 빈
yaml=$(dag::extract_yaml "$FIXTURES/03-single-leaf.md")
out=$(dag::find_independent_batch "$yaml")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T4.c find_independent_batch fixture 03 → 빈 batch (leaf 1개)"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.c (out=$out)"
fi

# T4.d — fixture 04 chain → batch 빈 (T1만 leaf)
yaml=$(dag::extract_yaml "$FIXTURES/04-chain.md")
out=$(dag::find_independent_batch "$yaml")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T4.d find_independent_batch fixture 04 → 빈 batch (chain)"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.d (out=$out)"
fi

# T4.e — fixture 05 diamond → batch [T1, T2]
yaml=$(dag::extract_yaml "$FIXTURES/05-diamond.md")
out=$(dag::find_independent_batch "$yaml" | sort | tr '\n' ',')
if [ "$out" = "T1,T2," ]; then
  PASS=$((PASS+1)); echo "PASS T4.e find_independent_batch fixture 05 → T1,T2"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.e (out=$out)"
fi

# T4.f — fixture 06 malformed YAML → 빈 batch + stderr WARN (fallback)
yaml=$(dag::extract_yaml "$FIXTURES/06-malformed-yaml.md")
out=$(dag::find_independent_batch "$yaml" 2>/dev/null)
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T4.f find_independent_batch fixture 06 malformed → 빈 batch (fallback)"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.f (out=$out)"
fi

# --- T5: get_task_test_command (Wave 2 U2 — FID 20260514) ---
# 인라인 yaml string (dag::extract_yaml 호출 없이 직접 dag::get_task_test_command 검증)
yaml='tasks:
  - id: T1
    test_command: "bash scripts/tests/test-foo.sh"
    depends_on: []
    inputs: []
    outputs: [src/foo.sh]
    ac: [AC-1]
  - id: T2
    depends_on: []
    inputs: []
    outputs: [src/bar.sh]
    ac: [AC-2]
'

# T5.a — T1 test_command 추출 (기재된 경우) + stderr 0줄
dag::get_task_test_command "$yaml" "T1" >/tmp/b1_stdout 2>/tmp/b1_stderr
out=$(cat /tmp/b1_stdout)
err_lines=$(grep -c . /tmp/b1_stderr || true)
if [ "$out" = "bash scripts/tests/test-foo.sh" ] && [ "$err_lines" -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS T5.a get_task_test_command T1 → stdout 정상 + stderr 0줄"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.a (out='$out' err_lines=$err_lines)"
fi

# T5.b — test_command 미기재 task → stdout 빈 + stderr warn 1줄 + exit 0
out=$(dag::get_task_test_command "$yaml" "T2" 2>/tmp/b1_stderr)
exit_code=$?
err_lines=$(grep -c . /tmp/b1_stderr || true)
if [ -z "$out" ] && [ "$err_lines" -eq 1 ] && [ "$exit_code" -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS T5.b get_task_test_command T2 → stdout 빈 + stderr 1줄 + exit 0"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.b (out='$out' err_lines=$err_lines exit=$exit_code)"
fi

# T5.c — 존재하지 않는 task → stdout 빈 + stderr warn 1줄 + exit 0 (graceful)
out=$(dag::get_task_test_command "$yaml" "Tnoexist" 2>/tmp/b1_stderr)
exit_code=$?
err_lines=$(grep -c . /tmp/b1_stderr || true)
if [ -z "$out" ] && [ "$err_lines" -eq 1 ] && [ "$exit_code" -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS T5.c get_task_test_command Tnoexist → stdout 빈 + stderr 1줄 + exit 0"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.c (out='$out' err_lines=$err_lines exit=$exit_code)"
fi

# cleanup
rm -f /tmp/b1_stdout /tmp/b1_stderr

echo ""
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
