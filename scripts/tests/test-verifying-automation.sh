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
- [ ] **스텝 3**: 실행: `bash scripts/_internal/init-project.sh "<프로젝트명>"`
- [ ] **스텝 4**: 실행: `bash scripts/tests/test-real.sh`
EOF
out=$(bash "$EXTRACT" "$TMPDIR/tasks.md")
if echo "$out" | grep -q "test-real.sh" && ! echo "$out" | grep -q '<'; then
  ok "T1.b extract → placeholder <...> 명령 제외"
else
  nope "T1.b" "out='$out'"
fi
rm -rf "$TMPDIR"

# ── T1.c extract: 빈 tasks.md → exit 1 (Wave 2 U2 — AC-4 "둘 다 부재") ──
TMPDIR=$(mktemp -d)
echo "" > "$TMPDIR/tasks.md"
out=$(bash "$EXTRACT" "$TMPDIR/tasks.md" 2>/dev/null)
ec=$?
if [ -z "$out" ] && [ "$ec" -eq 1 ]; then
  ok "T1.c extract → 빈 tasks.md exit 1 (Wave 2 U2 — 명령 0건)"
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

# --- T5: 혼합 SSOT (Wave 2 U2 — FID 20260514) ---
FIXT="$PLUGIN/scripts/tests/extract-test-commands/fixtures"

# T5.a: YAML test_command 우선 — yaml-primary.md (test_command 기재)
out=$(bash "$PLUGIN/scripts/_internal/extract-test-commands.sh" "$FIXT/yaml-primary.md" 2>/dev/null)
if [[ "$out" == *"test-fromyaml.sh"* && "$out" != *"test-fromstep4.sh"* ]]; then
  PASS=$((PASS+1)); echo "PASS T5.a YAML test_command 우선"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.a (out='$out')"
fi

# T5.b: 구 FID fallback — fallback-step4.md (test_command 미기재, Step 4 라인 보유) → fallback + stderr WARN
err=$(mktemp)
out=$(bash "$PLUGIN/scripts/_internal/extract-test-commands.sh" "$FIXT/fallback-step4.md" 2>"$err")
if [[ "$out" == *"test-fromstep4.sh"* ]] && grep -q "WARN" "$err" && grep -q "falling back" "$err"; then
  PASS=$((PASS+1)); echo "PASS T5.b fallback + stderr WARN"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.b (out='$out' err=$(cat "$err"))"
fi
rm -f "$err"

# T5.c: 둘 다 부재 — empty.md → exit 1
out=$(bash "$PLUGIN/scripts/_internal/extract-test-commands.sh" "$FIXT/empty.md" 2>/dev/null; echo "exit=$?")
if echo "$out" | grep -q "exit=1"; then
  PASS=$((PASS+1)); echo "PASS T5.c 둘 다 부재 → exit 1"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.c"
fi

# ── T2.d run: whitelist 거부 명령 → WARN stderr + skip + VERIFY:PARTIAL exit 1 ──
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.specops/fid-test"
printf '%s\n' \
  '## 의존 그래프' \
  '' \
  '```yaml' \
  'tasks:' \
  '  - id: T1' \
  '    test_command: "rm -rf /"' \
  '    depends_on: []' \
  '    inputs: []' \
  '    outputs: []' \
  '    ac: [AC-1]' \
  '```' \
  > "$TMPDIR/.specops/fid-test/tasks.md"
(cd "$TMPDIR" && bash "$RUN" fid-test >/tmp/t2d-out-$$ 2>/tmp/t2d-err-$$; ec=$?
 if [ "$ec" -eq 1 ] && grep -q "WARN: SKIP" /tmp/t2d-err-$$ && grep -q "VERIFY: PARTIAL" /tmp/t2d-out-$$; then
   echo "OK"
 else
   echo "FAIL ec=$ec err='$(cat /tmp/t2d-err-$$)' out='$(cat /tmp/t2d-out-$$)'"
 fi) > "$TMPDIR/result"
rm -f /tmp/t2d-out-$$ /tmp/t2d-err-$$
if grep -q "^OK$" "$TMPDIR/result"; then
  ok "T2.d run → whitelist 거부 명령 WARN + VERIFY:PARTIAL exit 1"
else
  nope "T2.d" "$(cat "$TMPDIR/result")"
fi
rm -rf "$TMPDIR"

# ── T2.e run: .. path traversal 차단 → WARN stderr + VERIFY:PARTIAL exit 1 ──
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.specops/fid-test"
printf '%s\n' \
  '## 의존 그래프' \
  '' \
  '```yaml' \
  'tasks:' \
  '  - id: T1' \
  '    test_command: "bash scripts/../../etc/passwd.sh"' \
  '    depends_on: []' \
  '    inputs: []' \
  '    outputs: []' \
  '    ac: [AC-1]' \
  '```' \
  > "$TMPDIR/.specops/fid-test/tasks.md"
(cd "$TMPDIR" && bash "$RUN" fid-test >/tmp/t2e-out-$$ 2>/tmp/t2e-err-$$; ec=$?
 if [ "$ec" -eq 1 ] && grep -q "WARN: SKIP" /tmp/t2e-err-$$ && grep -q "VERIFY: PARTIAL" /tmp/t2e-out-$$; then
   echo "OK"
 else
   echo "FAIL ec=$ec err='$(cat /tmp/t2e-err-$$)' out='$(cat /tmp/t2e-out-$$)'"
 fi) > "$TMPDIR/result"
rm -f /tmp/t2e-out-$$ /tmp/t2e-err-$$
if grep -q "^OK$" "$TMPDIR/result"; then
  ok "T2.e run → path traversal WARN + VERIFY:PARTIAL exit 1"
else
  nope "T2.e" "$(cat "$TMPDIR/result")"
fi
rm -rf "$TMPDIR"

# ── T2.f run: 혼합(bash PASS + npm skip) → VERIFY:PARTIAL exit 1 (P0 거짓양성 방지) ──
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.specops/fid-test" "$TMPDIR/scripts/tests"
echo '#!/usr/bin/env bash
exit 0' > "$TMPDIR/scripts/tests/dummy-pass.sh"
chmod +x "$TMPDIR/scripts/tests/dummy-pass.sh"
printf '%s\n' \
  '## 의존 그래프' \
  '' \
  '```yaml' \
  'tasks:' \
  '  - id: T1' \
  '    test_command: "bash scripts/tests/dummy-pass.sh"' \
  '    depends_on: []' \
  '    inputs: []' \
  '    outputs: []' \
  '    ac: [AC-1]' \
  '  - id: T2' \
  '    test_command: "npm test"' \
  '    depends_on: []' \
  '    inputs: []' \
  '    outputs: []' \
  '    ac: [AC-2]' \
  '```' \
  > "$TMPDIR/.specops/fid-test/tasks.md"
(cd "$TMPDIR" && bash "$RUN" fid-test >/tmp/t2f-out-$$ 2>/tmp/t2f-err-$$; ec=$?
 if [ "$ec" -eq 1 ] && grep -q "VERIFY: PARTIAL" /tmp/t2f-out-$$ && grep -q "WARN: SKIP" /tmp/t2f-err-$$; then
   echo "OK"
 else
   echo "FAIL ec=$ec out='$(cat /tmp/t2f-out-$$)' err='$(cat /tmp/t2f-err-$$)'"
 fi) > "$TMPDIR/result"
rm -f /tmp/t2f-out-$$ /tmp/t2f-err-$$
if grep -q "^OK$" "$TMPDIR/result"; then
  ok "T2.f run → 혼합(bash PASS+npm skip) VERIFY:PARTIAL exit 1 (P0 거짓양성 방지)"
else
  nope "T2.f" "$(cat "$TMPDIR/result")"
fi
rm -rf "$TMPDIR"

echo ""
echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
