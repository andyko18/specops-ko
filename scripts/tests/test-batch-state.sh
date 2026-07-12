#!/usr/bin/env bash
# test-batch-state.sh — scripts/batch-state.sh 검증 (FID 20260710-p2-batch-state)
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SCRIPT="$PLUGIN/scripts/batch-state.sh"
PASS=0; FAIL=0
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

# ── fixture A: 실물 batch-20260624 재현 (미완 3 + 드리프트 5 + 2-테이블 분할) ──
mkdir -p "$TMP/a/.specops/batch-x"
cat > "$TMP/a/.specops/batch-x/queue.md" <<'EOF'
# Batch Queue — batch-x

| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
| FR-1 | 20260624-vercel-pr | 어댑터 | MERGED |
| FR-2 | — | 확장 | HELD (자격증명 준비 후) |
| FR-3 | — | 머지 | HELD (자격증명 준비 후) |
| FR-4 | — | placeholder | SKIP |

| FR-5 | 20260624-dashboard-ui | 대시보드 | MERGED |
EOF
cat > "$TMP/a/req.md" <<'EOF'
| FR-1 | a | M1 | must | s | f |
| FR-2 | b | M2 | should | s | f |
| FR-3 | c | M3 | nice | s | f |
| FR-4 | d | M3 | nice | s | f |
| FR-5 | e | M1 | should | s | f |
| FR-6 | f | M1 | must | s | f |
| FR-7 | g | M1 | must | s | f |
| FR-8 | h | M1 | should | s | f |
| FR-9 | i | M1 | must | s | f |
| FR-3b | j | M3 | should | s | f |
EOF
out=$(bash "$SCRIPT" "$TMP/a/.specops/batch-x" "$TMP/a/req.md" 2>&1); code=$?
if [ "$code" -eq 1 ] && echo "$out" | grep -q "미완" && echo "$out" | grep -q "드리프트" \
   && echo "$out" | grep -q "FR-6" && echo "$out" | grep -q "FR-3b" && echo "$out" | grep -q "FR-2"; then
  ok "T1.a 실물 fixture — exit 1 + 미완·드리프트 검출 (2-테이블 견딤)"
else
  nope "T1.a 실물 fixture" "exit=$code out=$(echo "$out" | head -3 | tr '\n' ' ')"
fi

# ── fixture B: clean (전 행 IMPL_DONE, parity 일치) ──
mkdir -p "$TMP/b/.specops/batch-y"
cat > "$TMP/b/.specops/batch-y/queue.md" <<'EOF'
| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
| FR-1 | 20260101-a | one | IMPL_DONE |
| FR-2 | 20260101-b | two | MERGED |
EOF
printf '| FR-1 | a | M1 | must | s | f |\n| FR-2 | b | M1 | must | s | f |\n' > "$TMP/b/req.md"
bash "$SCRIPT" "$TMP/b/.specops/batch-y" "$TMP/b/req.md" >/dev/null 2>&1; code=$?
[ "$code" -eq 0 ] && ok "T2.a clean fixture — exit 0" || nope "T2.a clean" "exit=$code (기대 0)"

# ── fixture C: FR-ID 중복 + read-only 검증 ──
mkdir -p "$TMP/c/.specops/batch-z"
cat > "$TMP/c/.specops/batch-z/queue.md" <<'EOF'
| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
| FR-3 | x | dup1 | IMPL_DONE |
| FR-3 | y | dup2 | IMPL_DONE |
EOF
printf '| FR-3 | a | M1 | must | s | f |\n' > "$TMP/c/req.md"
sum_before=$(cksum "$TMP/c/.specops/batch-z/queue.md" "$TMP/c/req.md")
out=$(bash "$SCRIPT" "$TMP/c/.specops/batch-z" "$TMP/c/req.md" 2>&1); code=$?
sum_after=$(cksum "$TMP/c/.specops/batch-z/queue.md" "$TMP/c/req.md")
if [ "$code" -eq 1 ] && echo "$out" | grep -q "중복" && [ "$sum_before" = "$sum_after" ]; then
  ok "T3.a 중복 감지 + read-only (cksum 불변)"
else
  nope "T3.a 중복/read-only" "exit=$code"
fi

# ── 사용 오류: 인자 없음 → exit 2 ──
bash "$SCRIPT" 2>/dev/null; code=$?
[ "$code" -eq 2 ] && ok "T4.a 인자 없음 → exit 2" || nope "T4.a usage" "exit=$code"

# ── 배선·규약 grep 계약 (AC-4·AC-5) ──
grep -q 'batch-state.sh' "$PLUGIN/commands/start-all.md" && grep -q '그래도 batch PR' "$PLUGIN/commands/start-all.md" \
  && ok "T5.a start-all 게이트 배선" || nope "T5.a 배선" "batch-state 호출/[y/n] 없음"
grep -q '_inject_design_palette' "$PLUGIN/commands/init-project.md" \
  && ok "T5.b Phase11 재주입 지시" || nope "T5.b 재주입" "없음"
grep -q '복수 표기' "$PLUGIN/templates/data-model.md" \
  && ok "T5.c 하이브리드 복수 표기" || nope "T5.c 복수표기" "없음"
grep -q '해당 행 갱신' "$PLUGIN/skills/specifying-ko/SKILL.md" \
  && ok "T5.d Step5.6 dedup" || nope "T5.d dedup" "없음"

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
