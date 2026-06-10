#!/usr/bin/env bash
# specops-auto-ko v0.0 PoC · scripts/_internal/validate-structure.sh 검증
# baseline: P1 flat — commands=1, skills/<name>/SKILL.md=16, templates=6 (sandbox 격리)
# U4 후: sandbox 가 .structure-baseline 자체 생성. agents/ 빈 디렉토리 OK.
# (meta skill 필수: skills/using-specops-auto-ko-ko/SKILL.md + hooks/session-start.sh exec-bit)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/_internal/validate-structure.sh"

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
  mkdir -p "$sb"/{commands,skills,templates,docs,hooks,scripts/_internal,agents,.claude-plugin}
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
  cp "$SCRIPT" "$sb/scripts/_internal/validate-structure.sh"
  chmod +x "$sb/scripts/_internal/validate-structure.sh"
  # U4: sandbox 자체 .structure-baseline (agents 카테고리 생략 — sandbox 가 다루지 않음)
  cat > "$sb/scripts/_internal/.structure-baseline" <<'EOF'
{"category":"commands","glob":"commands/*.md","count":1}
{"category":"skills","glob":"skills/*/SKILL.md","count":16}
{"category":"templates","glob":"templates/*.md","count":6}
EOF
}

# T3a 정상 baseline sandbox — OK
sb=$(mktemp -d); make_sandbox "$sb"
out=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '✅ file_counts: OK' && echo "$out" | grep -q '✅ meta_injection: OK'; then
  PASS=$((PASS+1)); echo "PASS T3a baseline sandbox passes"
else
  FAIL=$((FAIL+1)); echo "FAIL T3a baseline sandbox (rc=$rc)"
  echo "$out" | sed 's/^/    /'
fi
rm -rf "$sb"

# T3b skills 15개(baseline 16에서 -1) — FAIL
sb=$(mktemp -d); make_sandbox "$sb"; rm -rf "$sb/skills/context-resets-ko"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'file_counts: FAIL'; then
  PASS=$((PASS+1)); echo "PASS T3b skills 15개 FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T3b (rc=$rc)"
fi
rm -rf "$sb"

# T3c 메타 skill 누락 — FAIL (P1 핵심 가설 위반)
sb=$(mktemp -d); make_sandbox "$sb"; rm -rf "$sb/skills/using-specops-auto-ko-ko"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'meta_injection: FAIL'; then
  PASS=$((PASS+1)); echo "PASS T3c 메타 skill 누락 FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T3c (rc=$rc)"
fi
rm -rf "$sb"

# T3d session-start.sh exec-bit 없음 — FAIL
sb=$(mktemp -d); make_sandbox "$sb"; chmod -x "$sb/hooks/session-start.sh"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'meta_injection: FAIL'; then
  PASS=$((PASS+1)); echo "PASS T3d session-start exec-bit 없음 FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T3d (rc=$rc)"
fi
rm -rf "$sb"

# T4 commands/start.md 에 superpowers 런타임 참조 삽입 — FAIL
sb=$(mktemp -d); make_sandbox "$sb"
printf -- '---\nname: bad\n---\nsuperpowers: call-this-at-runtime\n' > "$sb/commands/start.md"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'no_superpowers: FAIL'; then
  PASS=$((PASS+1)); echo "PASS T4 superpowers runtime ref FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T4 (rc=$rc, out=$(echo "$err" | head -10))"
fi
rm -rf "$sb"

# T5 manifest version 불일치 — FAIL
sb=$(mktemp -d); make_sandbox "$sb"
echo '{"version":"0.2.0"}' > "$sb/.claude-plugin/plugin.json"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
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
  err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
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

# ── U4 회귀: .structure-baseline 동적화 ─────────

# T8.a baseline 부재 → file_counts FAIL + 명시 메시지
sb=$(mktemp -d); make_sandbox "$sb"
rm -f "$sb/scripts/_internal/.structure-baseline"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q '.structure-baseline 부재'; then
  PASS=$((PASS+1)); echo "PASS T8.a (U4) baseline 부재 → FAIL + 명시 메시지"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.a (rc=$rc, out=$(echo "$err" | head -3 | tr '\n' ';'))"
fi
rm -rf "$sb"

# T8.b baseline 카운트가 실측과 다름 → FAIL + "got X, expect Y"
sb=$(mktemp -d); make_sandbox "$sb"
# templates 카운트를 6 → 99 로 의도적으로 mismatch
sed -i.bak 's/"glob":"templates\/\*.md","count":6/"glob":"templates\/*.md","count":99/' "$sb/scripts/_internal/.structure-baseline"
rm -f "$sb/scripts/_internal/.structure-baseline.bak"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'templates: got 6, expect 99'; then
  PASS=$((PASS+1)); echo "PASS T8.b (U4) 카운트 mismatch → FAIL + got/expect 메시지"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.b (rc=$rc, out=$(echo "$err" | grep file_counts))"
fi
rm -rf "$sb"

# T8.c --update-baseline → 갱신 후 재검증 PASS
sb=$(mktemp -d); make_sandbox "$sb"
# templates 카운트를 6 → 99 mismatch
sed -i.bak 's/"glob":"templates\/\*.md","count":6/"glob":"templates\/*.md","count":99/' "$sb/scripts/_internal/.structure-baseline"
rm -f "$sb/scripts/_internal/.structure-baseline.bak"
# --update-baseline 호출 → 실측 6 으로 갱신
update_out=$(bash "$sb/scripts/_internal/validate-structure.sh" --update-baseline 2>&1)
update_rc=$?
# 재검증 → PASS 기대
revalidate_out=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1)
revalidate_rc=$?
if [ $update_rc -eq 0 ] && [ $revalidate_rc -eq 0 ] \
   && echo "$update_out" | grep -q '갱신 완료' \
   && echo "$revalidate_out" | grep -q '✅ file_counts: OK' \
   && grep -q '"count":6' "$sb/scripts/_internal/.structure-baseline"; then
  PASS=$((PASS+1)); echo "PASS T8.c (U4) --update-baseline → 갱신 후 재검증 PASS"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.c (update_rc=$update_rc revalidate_rc=$revalidate_rc)"
fi
rm -rf "$sb"

# ── drift guard (v1.12): version_sync · readme_counts · changelog_body · xref_resolve ─────────

# sandbox 에 plugin 버전(0.1.0)과 정합하는 README/CHANGELOG 추가
add_docs() {
  local sb=$1
  cat > "$sb/README.md" <<'EOF'
# test-plugin (v0.1.0)

├── skills/    ← flat: skills/<name>/SKILL.md × 16

*초기화: 2026-01-01 · **최신: v0.1.0 (2026-01-01)** · test*
EOF
  cat > "$sb/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

## [0.1.0] — 2026-01-01

### Added
- 최초 릴리즈
EOF
}

# T9.a docs 정합 → 신규 체크 4종 전부 OK + rc=0
sb=$(mktemp -d); make_sandbox "$sb"; add_docs "$sb"
out=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '✅ version_sync: OK' \
   && echo "$out" | grep -q '✅ readme_counts: OK' \
   && echo "$out" | grep -q '✅ changelog_body: OK' \
   && echo "$out" | grep -q '✅ xref_resolve: OK'; then
  PASS=$((PASS+1)); echo "PASS T9.a drift 4종 정합 → OK"
else
  FAIL=$((FAIL+1)); echo "FAIL T9.a (rc=$rc)"; echo "$out" | sed 's/^/    /'
fi
rm -rf "$sb"

# T9.b README footer 버전 불일치 → version_sync FAIL
sb=$(mktemp -d); make_sandbox "$sb"; add_docs "$sb"
sed -i.bak 's/최신: v0.1.0/최신: v0.0.9/' "$sb/README.md"; rm -f "$sb/README.md.bak"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'version_sync: FAIL' && echo "$err" | grep -q 'README.footer=v0.0.9'; then
  PASS=$((PASS+1)); echo "PASS T9.b footer drift → version_sync FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T9.b (rc=$rc, out=$(echo "$err" | grep version_sync))"
fi
rm -rf "$sb"

# T9.c CHANGELOG 최신 헤딩 버전 불일치 → version_sync FAIL
sb=$(mktemp -d); make_sandbox "$sb"; add_docs "$sb"
sed -i.bak 's/## \[0.1.0\]/## [0.0.9]/' "$sb/CHANGELOG.md"; rm -f "$sb/CHANGELOG.md.bak"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'version_sync: FAIL' && echo "$err" | grep -q 'CHANGELOG.latest=0.0.9'; then
  PASS=$((PASS+1)); echo "PASS T9.c CHANGELOG drift → version_sync FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T9.c (rc=$rc, out=$(echo "$err" | grep version_sync))"
fi
rm -rf "$sb"

# T9.d marketplace description 버전 토큰 불일치 → version_sync FAIL
sb=$(mktemp -d); make_sandbox "$sb"; add_docs "$sb"
echo '{"metadata":{"description":"test (v0.0.9 — local)"},"plugins":[{"version":"0.1.0"}]}' > "$sb/.claude-plugin/marketplace.json"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'version_sync: FAIL' && echo "$err" | grep -q 'marketplace.description=v0.0.9'; then
  PASS=$((PASS+1)); echo "PASS T9.d marketplace description drift → version_sync FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T9.d (rc=$rc, out=$(echo "$err" | grep version_sync))"
fi
rm -rf "$sb"

# T9.e README/CHANGELOG 부재 (기존 sandbox) → version_sync SKIP (기존 테스트 비파괴)
sb=$(mktemp -d); make_sandbox "$sb"
out=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q 'version_sync: SKIP'; then
  PASS=$((PASS+1)); echo "PASS T9.e docs 부재 → SKIP (graceful)"
else
  FAIL=$((FAIL+1)); echo "FAIL T9.e (rc=$rc)"
fi
rm -rf "$sb"

# T10.a README skill 카운트 불일치 → readme_counts FAIL
sb=$(mktemp -d); make_sandbox "$sb"; add_docs "$sb"
sed -i.bak 's/× 16/× 99/' "$sb/README.md"; rm -f "$sb/README.md.bak"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'readme_counts: FAIL' && echo "$err" | grep -q 'README=99 actual=16'; then
  PASS=$((PASS+1)); echo "PASS T10.a skill 카운트 drift → readme_counts FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T10.a (rc=$rc, out=$(echo "$err" | grep readme_counts))"
fi
rm -rf "$sb"

# T11.a CHANGELOG 최신 릴리즈 본문 공백 → changelog_body FAIL
sb=$(mktemp -d); make_sandbox "$sb"; add_docs "$sb"
cat > "$sb/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

## [0.1.0] — 2026-01-01

## [0.0.9] — 2025-12-01

### Added
- old
EOF
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'changelog_body: FAIL'; then
  PASS=$((PASS+1)); echo "PASS T11.a 최신 릴리즈 본문 공백 → changelog_body FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T11.a (rc=$rc, out=$(echo "$err" | grep changelog_body))"
fi
rm -rf "$sb"

# T12.a 미존재 skill 토큰 참조 → xref_resolve FAIL
sb=$(mktemp -d); make_sandbox "$sb"; add_docs "$sb"
printf -- '---\nname: tdd-ko\n---\n다음은 specops-auto-ko:nonexistent-zz 호출.\n' > "$sb/skills/tdd-ko/SKILL.md"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'xref_resolve: FAIL' && echo "$err" | grep -q 'nonexistent-zz'; then
  PASS=$((PASS+1)); echo "PASS T12.a 미존재 토큰 → xref_resolve FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.a (rc=$rc, out=$(echo "$err" | grep xref_resolve))"
fi
rm -rf "$sb"

# T13 실제 repo — 신규 체크 4종 전부 ✅ (drift 0 상태 유지 보증)
out=$(bash "$SCRIPT" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '✅ version_sync: OK' \
   && echo "$out" | grep -q '✅ readme_counts: OK' \
   && echo "$out" | grep -q '✅ changelog_body: OK' \
   && echo "$out" | grep -q '✅ xref_resolve: OK'; then
  PASS=$((PASS+1)); echo "PASS T13 실제 repo drift 4종 ✅"
else
  FAIL=$((FAIL+1)); echo "FAIL T13 (rc=$rc)"; echo "$out" | grep -E 'version_sync|readme_counts|changelog_body|xref_resolve' | sed 's/^/    /'
fi

echo "passed=$PASS failed=$FAIL"
exit $FAIL
