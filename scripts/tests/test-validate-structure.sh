#!/usr/bin/env bash
# specops-auto-ko v0.0 PoC · scripts/validate-structure.sh 검증
# baseline: P1 flat — commands=1, skills/<name>/SKILL.md=16, templates=6
# (meta skill 필수: skills/using-specops-auto-ko-ko/SKILL.md + hooks/session-start.sh exec-bit)
set -u
PASS=0; FAIL=0
PLUGIN=$(pwd)
SCRIPT="$PLUGIN/scripts/validate-structure.sh"

# T1 현재 플러그인 실행 — 모든 항목 OK 또는 INFO/SKIP, FAILS=0
out=$(bash "$SCRIPT" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '✅ directories: OK' && echo "$out" | grep -q '✅ file_counts: OK'; then
  PASS=$((PASS+1)); echo "PASS T1 current plugin passes"
else
  FAIL=$((FAIL+1)); echo "FAIL T1 current plugin (rc=$rc)"
  echo "$out" | sed 's/^/    /'
fi

# T2 --json 출력 파싱 가능
out=$(bash "$SCRIPT" --json 2>&1); rc=$?
if [ $rc -eq 0 ] && printf '%s' "$out" | python3 -c "import sys,json; j=json.load(sys.stdin); assert 'fails' in j and 'checks' in j" 2>/dev/null; then
  PASS=$((PASS+1)); echo "PASS T2 --json parseable"
else
  FAIL=$((FAIL+1)); echo "FAIL T2 --json (rc=$rc)"
fi

# 샌드박스 공통: P1 flat baseline 미니 플러그인 복제
# (commands=1, skills/<name>/SKILL.md=16, templates=6 + 메타 skill/hook 필수)
SKILL_NAMES=(
  using-specops-auto-ko-ko
  context-resets-ko file-based-communication-ko generator-evaluator-ko
  sprint-contracts-ko structured-artifacts-ko
  specifying-ko clarifying-ko planning-ko decomposing-ko implementing-ko
  tdd-ko verifying-evidence-ko requesting-code-review-ko receiving-code-review-ko
  systematic-debugging-ko
)
make_sandbox() {
  local sb=$1
  mkdir -p "$sb"/{commands,skills,templates,docs,hooks,scripts,.claude-plugin}
  printf -- '---\nname: start\n---\n' > "$sb/commands/start.md"
  for name in "${SKILL_NAMES[@]}"; do
    mkdir -p "$sb/skills/$name"
    printf -- '---\nname: %s\n---\n' "$name" > "$sb/skills/$name/SKILL.md"
  done
  for i in 1 2 3 4 5 6; do printf -- '---\nname: t%s\n---\n' "$i" > "$sb/templates/t$i.md"; done
  # 메타 skill 주입 경로 (validator 의 meta_injection 체크 대상)
  printf '#!/usr/bin/env bash\necho "{}"\n' > "$sb/hooks/session-start.sh"
  chmod +x "$sb/hooks/session-start.sh"
  echo '{"version":"0.1.0"}' > "$sb/.claude-plugin/plugin.json"
  echo '{"plugins":[{"version":"0.1.0"}]}' > "$sb/.claude-plugin/marketplace.json"
  cp "$SCRIPT" "$sb/scripts/validate-structure.sh"
  chmod +x "$sb/scripts/validate-structure.sh"
}

# T3a 정상 baseline sandbox — OK
sb=$(mktemp -d); make_sandbox "$sb"
out=$(bash "$sb/scripts/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '✅ file_counts: OK' && echo "$out" | grep -q '✅ meta_injection: OK'; then
  PASS=$((PASS+1)); echo "PASS T3a baseline sandbox passes"
else
  FAIL=$((FAIL+1)); echo "FAIL T3a baseline sandbox (rc=$rc)"
  echo "$out" | sed 's/^/    /'
fi
rm -rf "$sb"

# T3b skills 15개(baseline 16에서 -1) — FAIL
sb=$(mktemp -d); make_sandbox "$sb"; rm -rf "$sb/skills/context-resets-ko"
err=$(bash "$sb/scripts/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'file_counts: FAIL'; then
  PASS=$((PASS+1)); echo "PASS T3b skills 15개 FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T3b (rc=$rc)"
fi
rm -rf "$sb"

# T3c 메타 skill 누락 — FAIL (P1 핵심 가설 위반)
sb=$(mktemp -d); make_sandbox "$sb"; rm -rf "$sb/skills/using-specops-auto-ko-ko"
err=$(bash "$sb/scripts/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'meta_injection: FAIL'; then
  PASS=$((PASS+1)); echo "PASS T3c 메타 skill 누락 FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T3c (rc=$rc)"
fi
rm -rf "$sb"

# T3d session-start.sh exec-bit 없음 — FAIL
sb=$(mktemp -d); make_sandbox "$sb"; chmod -x "$sb/hooks/session-start.sh"
err=$(bash "$sb/scripts/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'meta_injection: FAIL'; then
  PASS=$((PASS+1)); echo "PASS T3d session-start exec-bit 없음 FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T3d (rc=$rc)"
fi
rm -rf "$sb"

# T4 commands/start.md 에 superpowers 런타임 참조 삽입 — FAIL
sb=$(mktemp -d); make_sandbox "$sb"
printf -- '---\nname: bad\n---\nsuperpowers: call-this-at-runtime\n' > "$sb/commands/start.md"
err=$(bash "$sb/scripts/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'no_superpowers: FAIL'; then
  PASS=$((PASS+1)); echo "PASS T4 superpowers runtime ref FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T4 (rc=$rc, out=$(echo "$err" | head -10))"
fi
rm -rf "$sb"

# T5 manifest version 불일치 — FAIL
sb=$(mktemp -d); make_sandbox "$sb"
echo '{"version":"0.2.0"}' > "$sb/.claude-plugin/plugin.json"
err=$(bash "$sb/scripts/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'manifest: FAIL'; then
  PASS=$((PASS+1)); echo "PASS T5 version mismatch FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T5 (rc=$rc)"
fi
rm -rf "$sb"

# T6 frontmatter 손상 — FAIL (python3+pyyaml 가정)
if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" 2>/dev/null; then
  sb=$(mktemp -d); make_sandbox "$sb"
  printf -- '---\nname: { unclosed\n  - bad\n---\n' > "$sb/commands/start.md"
  err=$(bash "$sb/scripts/validate-structure.sh" 2>&1); rc=$?
  if [ $rc -eq 1 ] && echo "$err" | grep -q 'frontmatter: FAIL'; then
    PASS=$((PASS+1)); echo "PASS T6 broken frontmatter FAIL"
  else
    FAIL=$((FAIL+1)); echo "FAIL T6 (rc=$rc)"
  fi
  rm -rf "$sb"
else
  PASS=$((PASS+1)); echo "PASS T6 skipped (pyyaml 미설치)"
fi

# T7 실행권한
if [ -x "$SCRIPT" ]; then
  PASS=$((PASS+1)); echo "PASS T7 exec-bit"
else
  FAIL=$((FAIL+1)); echo "FAIL T7 exec-bit"
fi

echo "passed=$PASS failed=$FAIL"
exit $FAIL
