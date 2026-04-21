#!/usr/bin/env bash
# specops-ko v0.2 · scripts/validate-structure.sh 검증
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

# 샌드박스 공통: 미니 플러그인 복제
make_sandbox() {
  local sb=$1
  mkdir -p "$sb"/{commands,agents,skills/harness,skills/engine,templates,knowledge/constitution,knowledge/checklists,knowledge/anti-patterns,knowledge/patterns,docs,hooks,scripts,.claude-plugin}
  for i in 1 2 3 4 5 6 7 8; do
    printf -- '---\nname: cmd%s\n---\n' "$i" > "$sb/commands/c$i.md"
    printf -- '---\nname: ag%s\n---\n' "$i" > "$sb/agents/a$i.md"
  done
  for i in 1 2 3 4 5; do printf -- '---\nname: h%s\n---\n' "$i" > "$sb/skills/harness/h$i.md"; done
  for i in 1 2 3 4; do printf -- '---\nname: e%s\n---\n' "$i" > "$sb/skills/engine/e$i.md"; done
  for i in 1 2 3 4 5 6; do printf -- '---\nname: t%s\n---\n' "$i" > "$sb/templates/t$i.md"; done
  echo '{"version":"0.1.0"}' > "$sb/.claude-plugin/plugin.json"
  echo '{"plugins":[{"version":"0.1.0"}]}' > "$sb/.claude-plugin/marketplace.json"
  # validate-structure.sh 는 plugin_root 를 scripts/.. 로 잡으므로 샌드박스에도 scripts/validate-structure.sh 심볼릭링크 필요
  cp "$SCRIPT" "$sb/scripts/validate-structure.sh"
  chmod +x "$sb/scripts/validate-structure.sh"
}

# T3 commands 7개 — FAIL
sb=$(mktemp -d); make_sandbox "$sb"; rm "$sb/commands/c8.md"
err=$(bash "$sb/scripts/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'file_counts: FAIL'; then
  PASS=$((PASS+1)); echo "PASS T3 commands 7개 FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T3 (rc=$rc)"
fi
rm -rf "$sb"

# T4 commands/*.md 에 superpowers 런타임 참조 삽입 — FAIL
sb=$(mktemp -d); make_sandbox "$sb"
printf -- '---\nname: bad\n---\nsuperpowers: call-this-at-runtime\n' > "$sb/commands/c1.md"
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
  # 의도적 깨진 YAML (닫히지 않은 flow mapping — pyyaml 6.x도 reject)
  printf -- '---\nname: { unclosed\n  - bad\n---\n' > "$sb/commands/c1.md"
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
