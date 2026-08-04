#!/usr/bin/env bash
# specops-ko v0.0 PoC · scripts/_internal/validate-structure.sh 검증
# baseline: P1 flat — commands=1, skills/<name>/SKILL.md=16, templates=6 (sandbox 격리)
# U4 후: sandbox 가 .structure-baseline 자체 생성. agents/ 빈 디렉토리 OK.
# (meta skill 필수: skills/using-specops-ko/SKILL.md + hooks/session-start.sh exec-bit)
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
  using-specops-ko
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
  # chain fixture (FID 20260702-chain-single-source): 기존 skill 2개 재사용 — 신규 skill 생성 금지
  # (신규 skill 은 xref_resolve 미존재 FAIL + baseline 카운트 + add_docs README 하드코딩 3중 회귀)
  # s1=specifying-ko → s2=clarifying-ko (T12.a 가 변조하는 tdd-ko 회피)
  printf -- '\n## 다음 skill\n\nSkill: specops-ko:clarifying-ko\n' >> "$sb/skills/specifying-ko/SKILL.md"
  cat > "$sb/hooks/chain.yaml" <<'EOF'
edges:
  - {from: specifying-ko, to: clarifying-ko}
EOF
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
sb=$(mktemp -d); make_sandbox "$sb"; rm -rf "$sb/skills/using-specops-ko"
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
printf -- '---\nname: tdd-ko\n---\n다음은 specops-ko:nonexistent-zz 호출.\n' > "$sb/skills/tdd-ko/SKILL.md"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'xref_resolve: FAIL' && echo "$err" | grep -q 'nonexistent-zz'; then
  PASS=$((PASS+1)); echo "PASS T12.a 미존재 토큰 → xref_resolve FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.a (rc=$rc, out=$(echo "$err" | grep xref_resolve))"
fi
rm -rf "$sb"

# ── xref bare 토큰 (FID 20260713-ghost-agent-drift): prefix 없는 유령 에이전트 적발 ─────────
# 배경: 기존 xref_resolve 는 `specops-ko:` prefix 토큰만 수집 → bare 로 서술된 유령
#       (analyzer-ko·planner-ko 등)이 검사망 밖이었다. 93 테스트 전부 통과하던 거짓.

# T12.b bare 유령 토큰 (prefix 없음) → xref_resolve FAIL (AC-4)
sb=$(mktemp -d) || exit 1; make_sandbox "$sb"; add_docs "$sb"
pre=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); pre_rc=$?
printf -- '---\nname: tdd-ko\n---\n판정은 analyzer-ko 가 수행한다.\n' > "$sb/skills/tdd-ko/SKILL.md"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $pre_rc -eq 0 ] && echo "$pre" | grep -q '✅ xref_resolve: OK' \
   && [ $rc -eq 1 ] && echo "$err" | grep -q 'xref_resolve: FAIL' && echo "$err" | grep -q 'analyzer-ko'; then
  PASS=$((PASS+1)); echo "PASS T12.b bare 유령 토큰 → xref_resolve FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.b (pre_rc=$pre_rc rc=$rc, out=$(echo "$err" | grep xref_resolve))"
fi
rm -rf "$sb"

# T12.c allowlist (플러그인명·upstream 참조) → xref_resolve OK (AC-5 false-positive 차단)
sb=$(mktemp -d) || exit 1; make_sandbox "$sb"; add_docs "$sb"
printf -- '---\nname: tdd-ko\n---\nspecops-ko 는 specops-ko 의 writing-plans-ko · subagent-driven-development-ko 를 참조한다.\n' > "$sb/skills/tdd-ko/SKILL.md"
out=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '✅ xref_resolve: OK'; then
  PASS=$((PASS+1)); echo "PASS T12.c allowlist 토큰 → xref_resolve OK (오탐 0)"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.c (rc=$rc, out=$(echo "$out" | grep xref_resolve))"
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

# ── chain_consistency (FID 20260702-chain-single-source): hooks/chain.yaml 단일 source 대조 ─────────

# T14.a 실제 repo — chain_consistency OK (오탐 0 보증, AC-1)
out=$(bash "$SCRIPT" 2>&1); rc=$?
if [ $rc -eq 0 ] && printf '%s' "$out" | grep -q 'chain_consistency: OK'; then
  PASS=$((PASS+1)); echo "PASS T14.a chain_consistency 실제 repo OK"
else
  FAIL=$((FAIL+1)); echo "FAIL T14.a chain_consistency 누락 또는 FAIL: $(printf '%s' "$out" | grep chain_consistency || echo '검사 부재')"
fi

# T14.b SKILL.md 측 drift — s1 의 Skill: 라인 대상을 제3 skill 로 변경 (chain.yaml 미갱신) → FAIL + edge 명시 (AC-2)
sb=$(mktemp -d); make_sandbox "$sb"
pre=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); pre_rc=$?
sed -i.bak 's/^Skill: specops-ko:clarifying-ko$/Skill: specops-ko:planning-ko/' "$sb/skills/specifying-ko/SKILL.md"
rm -f "$sb/skills/specifying-ko/SKILL.md.bak"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $pre_rc -eq 0 ] && printf '%s' "$pre" | grep -q 'chain_consistency: OK' \
   && [ $rc -ne 0 ] && printf '%s' "$err" | grep -q 'chain_consistency: FAIL' \
   && printf '%s' "$err" | grep -q 'specifying-ko → planning-ko'; then
  PASS=$((PASS+1)); echo "PASS T14.b SKILL.md 측 drift → chain_consistency FAIL + edge 명시"
else
  FAIL=$((FAIL+1)); echo "FAIL T14.b (pre_rc=$pre_rc rc=$rc, out=$(printf '%s' "$err" | grep chain_consistency))"
fi
rm -rf "$sb"

# T14.c chain.yaml 측 drift — edge 1개 제거 (edges: [] 화, SKILL.md 미변경) → FAIL + edge 명시 (AC-3)
sb=$(mktemp -d); make_sandbox "$sb"
pre=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); pre_rc=$?
printf 'edges: []\n' > "$sb/hooks/chain.yaml"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $pre_rc -eq 0 ] && printf '%s' "$pre" | grep -q 'chain_consistency: OK' \
   && [ $rc -ne 0 ] && printf '%s' "$err" | grep -q 'chain_consistency: FAIL' \
   && printf '%s' "$err" | grep -q 'SKILL.md에만: specifying-ko → clarifying-ko'; then
  PASS=$((PASS+1)); echo "PASS T14.c chain.yaml 측 drift → chain_consistency FAIL + edge 명시"
else
  FAIL=$((FAIL+1)); echo "FAIL T14.c (pre_rc=$pre_rc rc=$rc, out=$(printf '%s' "$err" | grep chain_consistency))"
fi
rm -rf "$sb"

# T14.d 메타 fixture 미선언 edge — 화살표 라인 s2 → s1 추가 (chain.yaml 미변경) → FAIL (AC-4)
sb=$(mktemp -d); make_sandbox "$sb"
pre=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); pre_rc=$?
printf -- '\nclarifying-ko → specifying-ko\n' >> "$sb/skills/using-specops-ko/SKILL.md"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $pre_rc -eq 0 ] && printf '%s' "$pre" | grep -q 'chain_consistency: OK' \
   && [ $rc -ne 0 ] && printf '%s' "$err" | grep -q 'chain_consistency: FAIL' \
   && printf '%s' "$err" | grep -q '메타목록 미선언 edge: clarifying-ko → specifying-ko'; then
  PASS=$((PASS+1)); echo "PASS T14.d 메타목록 미선언 edge → chain_consistency FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T14.d (pre_rc=$pre_rc rc=$rc, out=$(printf '%s' "$err" | grep chain_consistency))"
fi
rm -rf "$sb"

# T14.e chain.yaml 절단 파손 → FAIL "파싱 실패" (silent pass 금지, AC-6)
sb=$(mktemp -d); make_sandbox "$sb"
pre=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); pre_rc=$?
printf 'edges: [{from:\n' > "$sb/hooks/chain.yaml"
err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
if [ $pre_rc -eq 0 ] && printf '%s' "$pre" | grep -q 'chain_consistency: OK' \
   && [ $rc -ne 0 ] && printf '%s' "$err" | grep -q 'chain_consistency: FAIL' \
   && printf '%s' "$err" | grep -q '파싱 실패'; then
  PASS=$((PASS+1)); echo "PASS T14.e yaml 파손 → chain_consistency FAIL (파싱 실패)"
else
  FAIL=$((FAIL+1)); echo "FAIL T14.e (pre_rc=$pre_rc rc=$rc, out=$(printf '%s' "$err" | grep chain_consistency))"
fi
rm -rf "$sb"

# T14.f pyyaml 부재 graceful SKIP (AC-5)
# 한계 고백: 기존 T6 은 pyyaml "존재"를 전제(부재 시 케이스 자체 skip)하는 기법이라 SKIP 경로 런타임 모의 불가
# (python3 PATH 조작은 frontmatter 등 다른 검사까지 SKIP 시켜 sandbox 단언이 무의미해짐).
# → SKIP 분기 코드 존재를 정적 검증 (frontmatter SKIP 선례와 동일 분기 구조).
if grep -q 'emit chain_consistency SKIP' "$SCRIPT"; then
  PASS=$((PASS+1)); echo "PASS T14.f pyyaml 부재 SKIP 분기 존재 (정적 검증)"
else
  FAIL=$((FAIL+1)); echo "FAIL T14.f chain_consistency SKIP 분기 부재"
fi

# ── agent_tools marker 역방향 스캔 (FID 20260702-marker-reverse-scan) ─────────

# T15.a 실제 repo — agent_tools 가 role: evaluator 역방향 스캔으로 7종 검사
#   (Phase 2.5 design-reviewer-ko 추가로 6→7)
ev_count=$(grep -l '^role: evaluator' "$PLUGIN"/agents/*.md 2>/dev/null | grep -c . || true)
if [ "$ev_count" -eq 7 ] && bash "$SCRIPT" 2>&1 | grep -q 'agent_tools: OK'; then
  PASS=$((PASS+1)); echo "PASS T15.a role: evaluator 마킹 7종 + 역방향 스캔 OK"
else
  FAIL=$((FAIL+1)); echo "FAIL T15.a evaluator 마킹 $ev_count/7 또는 agent_tools 비OK"
fi

# T15.b 가짜 evaluator (role: evaluator + Write) 자동 편입 적발 — 스크립트 무수정 (AC-2)
#       파일명 비reviewer(fake-audit-ko)로 2차 방어 분기와 판정 단일화
sb=$(mktemp -d); make_sandbox "$sb"
pre=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1)
if ! echo "$pre" | grep -q 'agent_tools: SKIP'; then
  FAIL=$((FAIL+1)); echo "FAIL T15.b 변조 전 단언 (agents 빈 sandbox 가 SKIP 아님)"
else
  printf -- '---\nname: good-eval-ko\nrole: evaluator\ntools: Read\n---\n' > "$sb/agents/good-eval-ko.md"
  printf -- '---\nname: fake-audit-ko\nrole: evaluator\ntools: Read, Write\n---\n' > "$sb/agents/fake-audit-ko.md"
  err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
  if [ $rc -eq 1 ] && echo "$err" | grep -q 'agent_tools: FAIL' && echo "$err" | grep -q 'fake-audit-ko:Write/Edit포함'; then
    PASS=$((PASS+1)); echo "PASS T15.b 가짜 evaluator 자동 편입 적발"
  else
    FAIL=$((FAIL+1)); echo "FAIL T15.b (rc=$rc, out=$(echo "$err" | grep agent_tools))"
  fi
fi
rm -rf "$sb"

# T15.c 미마킹 reviewer (role 없음) 2차 방어 (AC-3)
sb=$(mktemp -d); make_sandbox "$sb"
pre=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1)
if ! echo "$pre" | grep -q 'agent_tools: SKIP'; then
  FAIL=$((FAIL+1)); echo "FAIL T15.c 변조 전 단언 (agents 빈 sandbox 가 SKIP 아님)"
else
  printf -- '---\nname: good-eval-ko\nrole: evaluator\ntools: Read\n---\n' > "$sb/agents/good-eval-ko.md"
  printf -- '---\nname: fake-reviewer-ko\ntools: Read\n---\n' > "$sb/agents/fake-reviewer-ko.md"
  err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
  if [ $rc -eq 1 ] && echo "$err" | grep -q 'agent_tools: FAIL' && echo "$err" | grep -q 'fake-reviewer-ko:role마킹누락'; then
    PASS=$((PASS+1)); echo "PASS T15.c 미마킹 reviewer 2차 방어"
  else
    FAIL=$((FAIL+1)); echo "FAIL T15.c (rc=$rc, out=$(echo "$err" | grep agent_tools))"
  fi
fi
rm -rf "$sb"

# T15.d agents 파일 존재 + evaluator 마킹 0건 → 공회전 방지 (AC-4)
sb=$(mktemp -d); make_sandbox "$sb"
pre=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1)
if ! echo "$pre" | grep -q 'agent_tools: SKIP'; then
  FAIL=$((FAIL+1)); echo "FAIL T15.d 변조 전 단언 (agents 빈 sandbox 가 SKIP 아님)"
else
  printf -- '---\nname: plain-agent-ko\ntools: Read\n---\n' > "$sb/agents/plain-agent-ko.md"
  err=$(bash "$sb/scripts/_internal/validate-structure.sh" 2>&1); rc=$?
  if [ $rc -eq 1 ] && echo "$err" | grep -q 'agent_tools: FAIL' && echo "$err" | grep -q 'evaluator마킹0건'; then
    PASS=$((PASS+1)); echo "PASS T15.d 마킹 0건 공회전 방지"
  else
    FAIL=$((FAIL+1)); echo "FAIL T15.d (rc=$rc, out=$(echo "$err" | grep agent_tools))"
  fi
fi
rm -rf "$sb"
echo "passed=$PASS failed=$FAIL"
exit $FAIL
