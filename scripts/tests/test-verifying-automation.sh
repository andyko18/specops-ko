#!/usr/bin/env bash
# U3 (wobbly §U3) — extract-test-commands.sh + run-verification.sh 검증
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
EXTRACT="$PLUGIN/scripts/_internal/extract-test-commands.sh"
RUN="$PLUGIN/scripts/_internal/run-verification.sh"


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

# ── T2.g run: downstream 표준 배치 bash tests/*.sh → 실행 + VERIFY: PASS ──
#   (20260716 trivial dogfood 발견 #3: whitelist 가 scripts/ 접두 하드코딩 — 플러그인 자기 repo
#    레이아웃 편향. 외부 프로젝트 표준 tests/·test/ 가 PARTIAL 로 떨어져 실행-근거 게이트 불인정
#    → 정직한 외부 완주가 커밋 deny → BYPASS 강요. 완주율 문(도달 14%)을 게이트가 직접 막던 결함)
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.specops/fid-test" "$TMPDIR/tests"
cat > "$TMPDIR/.specops/fid-test/tasks.md" <<'EOF'
- [ ] **스텝 4**: 실행: `bash tests/test-downstream.sh`
EOF
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMPDIR/tests/test-downstream.sh"
chmod +x "$TMPDIR/tests/test-downstream.sh"
(cd "$TMPDIR" && out=$(bash "$RUN" fid-test 2>&1); ec=$?
 if [ "$ec" -eq 0 ] && echo "$out" | grep -q "VERIFY: PASS"; then echo "OK"; else echo "FAIL ec=$ec out='$out'"; fi) > "$TMPDIR/result"
if grep -q "^OK$" "$TMPDIR/result"; then
  ok "T2.g run → downstream bash tests/*.sh 인정 (VERIFY: PASS)"
else
  nope "T2.g" "$(cat "$TMPDIR/result")"
fi
rm -rf "$TMPDIR"

# ── T2.h run: 앵커 잠금 — 절대경로·비테스트 디렉토리 bash 는 여전히 SKIP(PARTIAL) ──
#   YAML test_command 로 주입 — Step 4 fallback 은 extract 층에서 걸러져 whitelist 층이 안 돌므로
#   (T2.g 는 extract 층, 본 케이스는 whitelist 층을 각각 잠근다)
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.specops/fid-test" "$TMPDIR/lib"
cat > "$TMPDIR/.specops/fid-test/tasks.md" <<'EOF'
## 의존 그래프

```yaml
tasks:
  - id: T1
    depends_on: []
    inputs: []
    outputs: []
    ac: [AC-1]
    test_command: bash /tmp/evil.sh
  - id: T2
    depends_on: [T1]
    inputs: []
    outputs: []
    ac: [AC-1]
    test_command: bash lib/helper.sh
```
EOF
(cd "$TMPDIR" && out=$(bash "$RUN" fid-test 2>&1); ec=$?
 if [ "$ec" -eq 1 ] && echo "$out" | grep -q "VERIFY: PARTIAL" && ! echo "$out" | grep -q "VERIFY: PASS"; then echo "OK"; else echo "FAIL ec=$ec out='$out'"; fi) > "$TMPDIR/result"
if grep -q "^OK$" "$TMPDIR/result"; then
  ok "T2.h run → 절대경로·lib/ bash 여전히 SKIP (앵커 잠금)"
else
  nope "T2.h" "$(cat "$TMPDIR/result")"
fi
rm -rf "$TMPDIR"

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

# ── T2.f run: 혼합(bash PASS + make skip) → VERIFY:PARTIAL exit 1 (P0 거짓양성 방지) ──
#   20260713-verify-exec-gate: npm 이 화이트리스트에 편입되어 더 이상 skip 되지 않음 → skip 러너를 make 로 교체.
#   (make/gradle/mvn 은 의도적 미포함 — clarify D-1 YAGNI)
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
  '    test_command: "make test"' \
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
  ok "T2.f run → 혼합(bash PASS+make skip) VERIFY:PARTIAL exit 1 (P0 거짓양성 방지)"
else
  nope "T2.f" "$(cat "$TMPDIR/result")"
fi
rm -rf "$TMPDIR"

# ── T-multi: 다언어 러너 화이트리스트 (20260713-verify-exec-gate AC-1·AC-2·AC-3) ──
# 가짜 러너를 PATH 선점으로 주입 — 실제 pytest/npm 없이 exit 0 재현
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.specops/fid-multi" "$TMPDIR/bin"
printf '#!/bin/sh\necho "3 passed"\nexit 0\n' > "$TMPDIR/bin/pytest"
printf '#!/bin/sh\necho "ok"\nexit 0\n' > "$TMPDIR/bin/npm"
chmod +x "$TMPDIR/bin/pytest" "$TMPDIR/bin/npm"

# T-multi.a: pytest 실행 → VERIFY: PASS (AC-1·AC-3)
printf '%s\n' \
  '## 의존 그래프' \
  '' \
  '```yaml' \
  'tasks:' \
  '  - id: T1' \
  '    test_command: "pytest tests/"' \
  '```' \
  > "$TMPDIR/.specops/fid-multi/tasks.md"
out=$(cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$RUN" fid-multi 2>&1)
if printf '%s' "$out" | grep -q 'VERIFY: PASS'; then
  ok "T-multi.a pytest 러너 실행 → VERIFY: PASS"
else
  nope "T-multi.a" "expected 'VERIFY: PASS', got: $out"
fi

# T-multi.b: npm test 실행 → VERIFY: PASS (AC-1 — 실행부 일반화가 bash 외 러너에도 동작하는지)
rm -f "$TMPDIR/.specops/fid-multi/evidence.md"
printf '%s\n' \
  '## 의존 그래프' '' '```yaml' 'tasks:' '  - id: T1' \
  '    test_command: "npm test"' '```' \
  > "$TMPDIR/.specops/fid-multi/tasks.md"
out=$(cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$RUN" fid-multi 2>&1)
if printf '%s' "$out" | grep -q 'VERIFY: PASS'; then
  ok "T-multi.b npm test 실행 → VERIFY: PASS"
else
  nope "T-multi.b" "expected 'VERIFY: PASS', got: $out"
fi

# T-multi.c: 앵커 검증 — echo 위장 SKIP (AC-2)
rm -f "$TMPDIR/.specops/fid-multi/evidence.md"
printf '%s\n' \
  '## 의존 그래프' '' '```yaml' 'tasks:' '  - id: T1' \
  '    test_command: "echo pytest fake"' '```' \
  > "$TMPDIR/.specops/fid-multi/tasks.md"
out=$(cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$RUN" fid-multi 2>&1)
if printf '%s' "$out" | grep -q 'PARTIAL'; then
  ok "T-multi.c echo 위장 → SKIP(PARTIAL)"
else
  nope "T-multi.c" "expected PARTIAL, got: $out"
fi

# T-multi.d: 앵커 검증 — 체이닝 위장 SKIP (AC-2)
rm -f "$TMPDIR/.specops/fid-multi/evidence.md"
printf '%s\n' \
  '## 의존 그래프' '' '```yaml' 'tasks:' '  - id: T1' \
  '    test_command: "pytest; rm -rf /tmp/x"' '```' \
  > "$TMPDIR/.specops/fid-multi/tasks.md"
out=$(cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$RUN" fid-multi 2>&1)
if printf '%s' "$out" | grep -q 'PARTIAL'; then
  ok "T-multi.d 체이닝 위장 → SKIP(PARTIAL)"
else
  nope "T-multi.d" "expected PARTIAL, got: $out"
fi

# ── T-multi.e: 실패하는 non-bash 러너 → VERIFY: FAIL (else 분기 실패 경로 고정) ──
#   왜 필요한가: T-multi.a/b 는 else 분기(비-bash 러너)의 성공 경로만 고정한다.
#   run-verification.sh 의 `ec=$?` 가 실행 분기 밖 한 줄이라, 분기 안에 명령이 하나만 끼어들어도
#   그 status(0)를 캡처해 **실패한 러너가 VERIFY: PASS 로 샌다** (plan I-4 — 출하 직전까지 간 실증 함정).
#   후속 거버넌스 게이트가 'VERIFY: PASS' 문자열을 앵커하므로, 무증상 false green 은 실패 테스트를 통과로 연다.
#   → stdout·exit code·evidence 3중 단언으로 고정한다 (하나만 보면 회귀를 놓친다).
rm -f "$TMPDIR/.specops/fid-multi/evidence.md"
printf '#!/bin/sh\necho "1 failed"\nexit 1\n' > "$TMPDIR/bin/pytest"   # a/b 완료 후이므로 덮어써도 안전
chmod +x "$TMPDIR/bin/pytest"
printf '%s\n' \
  '## 의존 그래프' '' '```yaml' 'tasks:' '  - id: T1' \
  '    test_command: "pytest tests/"' '```' \
  > "$TMPDIR/.specops/fid-multi/tasks.md"
out=$(cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$RUN" fid-multi 2>&1); ec=$?
if [ "$ec" -eq 1 ] \
   && printf '%s' "$out" | grep -q 'VERIFY: FAIL' \
   && grep -q 'RUN-VERIFICATION-RESULT: FAIL' "$TMPDIR/.specops/fid-multi/evidence.md" 2>/dev/null; then
  ok "T-multi.e 실패 러너(pytest exit 1) → VERIFY: FAIL + exit 1 + evidence FAIL"
else
  nope "T-multi.e" "expected exit 1 + 'VERIFY: FAIL' + evidence 'RUN-VERIFICATION-RESULT: FAIL'; got ec=$ec out: $out"
fi

# ── T-multi.f: 러너 미설치(exit 127) → VERIFY: FAIL (exit code 원문 전달) ──
#   한계 고백: 실제 미설치 대신 exit 127 을 내는 가짜 cargo 로 결정론적 재현.
#   (PATH 에서 실 러너만 골라 지울 수 없고, PATH 를 비우면 스크립트가 쓰는 기본 유틸까지 사라져 환경 의존이 된다.
#    bash 의 command-not-found 도 동일하게 ec=127 을 내므로 run-verification.sh 관점에서 두 경로는 같다.)
rm -f "$TMPDIR/.specops/fid-multi/evidence.md"
printf '#!/bin/sh\necho "cargo: command not found" >&2\nexit 127\n' > "$TMPDIR/bin/cargo"
chmod +x "$TMPDIR/bin/cargo"
printf '%s\n' \
  '## 의존 그래프' '' '```yaml' 'tasks:' '  - id: T1' \
  '    test_command: "cargo test"' '```' \
  > "$TMPDIR/.specops/fid-multi/tasks.md"
out=$(cd "$TMPDIR" && PATH="$TMPDIR/bin:$PATH" bash "$RUN" fid-multi 2>&1); ec=$?
if [ "$ec" -eq 1 ] \
   && printf '%s' "$out" | grep -q 'VERIFY: FAIL cargo test (exit=127)' \
   && grep -q 'RUN-VERIFICATION-RESULT: FAIL' "$TMPDIR/.specops/fid-multi/evidence.md" 2>/dev/null; then
  ok "T-multi.f 러너 미설치(exit 127) → VERIFY: FAIL (exit=127 원문)"
else
  nope "T-multi.f" "expected exit 1 + 'VERIFY: FAIL cargo test (exit=127)' + evidence FAIL; got ec=$ec out: $out"
fi
rm -rf "$TMPDIR"

echo ""
echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
