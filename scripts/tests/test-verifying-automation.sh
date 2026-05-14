#!/usr/bin/env bash
# U3 (wobbly §U3) — extract-test-commands.sh + run-verification.sh 검증
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
EXTRACT="$PLUGIN/scripts/_internal/extract-test-commands.sh"
RUN="$PLUGIN/scripts/_internal/run-verification.sh"

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
nope() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }

# ── T1.a extract: bash scripts/ 패턴 추출 ─────
TMPDIR=$(mktemp -d)
cat > "$TMPDIR/tasks.md" <<'EOF'
# tasks
- [ ] **스텝 4**: 실행: `bash scripts/tests/test-foo.sh`
- [ ] **스텝 4**: 실행: `bash scripts/_internal/validate-structure.sh`
EOF
out=$(bash "$EXTRACT" "$TMPDIR/tasks.md")
if echo "$out" | grep -q "test-foo.sh" && echo "$out" | grep -q "validate-structure.sh"; then
  ok "T1.a extract → bash scripts/ 패턴 2건 추출"
else
  nope "T1.a" "out='$out'"
fi
rm -rf "$TMPDIR"

# ── T1.b extract: placeholder (<...>) 제외 ─────
TMPDIR=$(mktemp -d)
cat > "$TMPDIR/tasks.md" <<'EOF'
- [ ] **스텝 3**: 실행: `bash scripts/_internal/start-project.sh "<프로젝트명>"`
- [ ] **스텝 4**: 실행: `bash scripts/tests/test-real.sh`
EOF
out=$(bash "$EXTRACT" "$TMPDIR/tasks.md")
if echo "$out" | grep -q "test-real.sh" && ! echo "$out" | grep -q '<'; then
  ok "T1.b extract → placeholder <...> 명령 제외"
else
  nope "T1.b" "out='$out'"
fi
rm -rf "$TMPDIR"

# ── T1.c extract: 빈 tasks.md → 빈 결과 (exit 0) ──
TMPDIR=$(mktemp -d)
echo "" > "$TMPDIR/tasks.md"
out=$(bash "$EXTRACT" "$TMPDIR/tasks.md")
ec=$?
if [ -z "$out" ] && [ "$ec" -eq 0 ]; then
  ok "T1.c extract → 빈 tasks.md 빈 결과 exit 0"
else
  nope "T1.c" "ec=$ec out='$out'"
fi
rm -rf "$TMPDIR"

# ── T1.d extract: tasks.md 부재 → exit 1 + stderr ──
out=$(bash "$EXTRACT" /tmp/nonexistent-$$.md 2>&1)
ec=$?
if [ "$ec" -eq 1 ] && echo "$out" | grep -q "not found"; then
  ok "T1.d extract → tasks.md 부재 exit 1 + stderr 'not found'"
else
  nope "T1.d" "ec=$ec out='$out'"
fi

# ── T2.a run: 모든 명령 PASS → exit 0 + 'VERIFY: PASS' ──
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.specops/fid-test"
cat > "$TMPDIR/.specops/fid-test/tasks.md" <<'EOF'
- [ ] **스텝 4**: 실행: `bash scripts/tests/dummy-pass.sh`
EOF
mkdir -p "$TMPDIR/scripts/tests"
echo '#!/usr/bin/env bash
exit 0' > "$TMPDIR/scripts/tests/dummy-pass.sh"
chmod +x "$TMPDIR/scripts/tests/dummy-pass.sh"
(cd "$TMPDIR" && out=$(bash "$RUN" fid-test 2>&1); ec=$?
 if [ "$ec" -eq 0 ] && echo "$out" | grep -q "VERIFY: PASS"; then
   echo "OK"
 else
   echo "FAIL ec=$ec out='$out'"
 fi) > "$TMPDIR/result"
if grep -q "^OK$" "$TMPDIR/result"; then
  ok "T2.a run → 모든 PASS exit 0 + 'VERIFY: PASS'"
else
  nope "T2.a" "$(cat "$TMPDIR/result")"
fi
rm -rf "$TMPDIR"

# ── T2.b run: 1건 FAIL → exit 1 + 'VERIFY: FAIL' stderr ──
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.specops/fid-test" "$TMPDIR/scripts/tests"
cat > "$TMPDIR/.specops/fid-test/tasks.md" <<'EOF'
- [ ] **스텝 4**: 실행: `bash scripts/tests/dummy-fail.sh`
EOF
echo '#!/usr/bin/env bash
exit 1' > "$TMPDIR/scripts/tests/dummy-fail.sh"
chmod +x "$TMPDIR/scripts/tests/dummy-fail.sh"
(cd "$TMPDIR" && bash "$RUN" fid-test >/tmp/run-stdout-$$ 2>/tmp/run-stderr-$$; ec=$?
 if [ "$ec" -eq 1 ] && grep -q "VERIFY: FAIL" /tmp/run-stderr-$$; then
   echo "OK"
 else
   echo "FAIL ec=$ec stderr='$(cat /tmp/run-stderr-$$)'"
 fi) > "$TMPDIR/result"
rm -f /tmp/run-stdout-$$ /tmp/run-stderr-$$
if grep -q "^OK$" "$TMPDIR/result"; then
  ok "T2.b run → 1건 FAIL exit 1 + 'VERIFY: FAIL' stderr"
else
  nope "T2.b" "$(cat "$TMPDIR/result")"
fi
rm -rf "$TMPDIR"

# ── T2.c run: 명령 추출 0건 → 'VERIFY: NO COMMANDS' exit 0 ──
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.specops/fid-test"
echo "no commands here" > "$TMPDIR/.specops/fid-test/tasks.md"
(cd "$TMPDIR" && out=$(bash "$RUN" fid-test 2>&1); ec=$?
 if [ "$ec" -eq 0 ] && echo "$out" | grep -q "VERIFY: NO COMMANDS"; then
   echo "OK"
 else
   echo "FAIL ec=$ec out='$out'"
 fi) > "$TMPDIR/result"
if grep -q "^OK$" "$TMPDIR/result"; then
  ok "T2.c run → 명령 0건 'VERIFY: NO COMMANDS' exit 0"
else
  nope "T2.c" "$(cat "$TMPDIR/result")"
fi
rm -rf "$TMPDIR"

echo ""
echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
