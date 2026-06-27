#!/usr/bin/env bash
set -u  # set -e 의도적 미사용 — rc 수동 체크 패턴 (테스트별 개별 판정)
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
RELEASE="$PLUGIN/scripts/release.sh"


# AC-7 격리: tmpdir + git init (실제 repo 오염 차단)
_make_git_fixture() {
  local dir="$1"
  git -C "$dir" init -q
  git -C "$dir" config user.email "t@t.com"
  git -C "$dir" config user.name "T"
  mkdir -p "$dir/commands"
  mkdir -p "$dir/.claude-plugin"
  cat > "$dir/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "specops-auto-ko",
  "version": "1.9.0",
  "description": "test"
}
JSON
  cat > "$dir/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "specops-auto-ko",
  "metadata": {
    "description": "specops-auto-ko 로컬 마켓플레이스 (v1.9.0 — test)"
  },
  "version": "1.9.0"
}
JSON
  cat > "$dir/CHANGELOG.md" <<'CHANGELOG'
# Changelog

## [Unreleased]

### Added
- test entry

[Unreleased]: https://github.com/kohaedong/specops-auto-ko/compare/v1.9.0...HEAD
[1.9.0]: https://github.com/kohaedong/specops-auto-ko/compare/v1.8.0...v1.9.0
CHANGELOG
  cat > "$dir/README.md" <<'README'
# specops-auto-ko (v1.9.0)

Test.

*초기화: 2026-01-01 · **최신: v1.9.0 (2026-01-01)** · test*
README
  cat > "$dir/commands/cmd.md" <<'CMD'
---
name: cmd
specops_version: 1.9.0
---

Content

*specops-auto-ko v1.8.0 · 2026-01-01 · test*
CMD
  git -C "$dir" add -A
  git -C "$dir" commit -m "init" -q
}

# T1: AC-1 semver 검증
out=$(bash "$RELEASE" abc 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T1.a semver 'abc' → exit 1" || fail "T1.a (rc=$rc)"
out=$(bash "$RELEASE" 1.2 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T1.b semver '1.2' → exit 1" || fail "T1.b (rc=$rc)"
out=$(bash "$RELEASE" 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T1.c semver 인자 없음 → exit 1" || fail "T1.c (rc=$rc)"

# T2: AC-2 git 클린 워킹트리
TD=$(mktemp -d); _make_git_fixture "$TD"
echo "dirty" >> "$TD/README.md"
out=$(RELEASE_PLUGIN_ROOT="$TD" RELEASE_PREFLIGHT_CMD=true bash "$RELEASE" 1.11.0 2>&1); rc=$?
rm -rf "$TD"
[ "$rc" -eq 1 ] && echo "$out" | grep -q "클린하지 않" \
  && ok "T2.a git unclean → exit 1 + 메시지" || fail "T2.a (rc=$rc out='$out')"

# T3: AC-2 already tagged
TD=$(mktemp -d); _make_git_fixture "$TD"
git -C "$TD" tag v1.11.0
out=$(RELEASE_PLUGIN_ROOT="$TD" RELEASE_PREFLIGHT_CMD=true bash "$RELEASE" 1.11.0 2>&1); rc=$?
rm -rf "$TD"
[ "$rc" -eq 1 ] && echo "$out" | grep -q "already tagged" \
  && ok "T3.a already tagged → exit 1 + 메시지" || fail "T3.a (rc=$rc out='$out')"

# T4: AC-4 CHANGELOG 변환
TD=$(mktemp -d); _make_git_fixture "$TD"
DATE=$(date +%Y-%m-%d)
RELEASE_PLUGIN_ROOT="$TD" RELEASE_PREFLIGHT_CMD=true bash "$RELEASE" 1.11.0
grep -q "## \[1.11.0\]" "$TD/CHANGELOG.md" \
  && grep -q "^## \[Unreleased\]$" "$TD/CHANGELOG.md" \
  && grep -q "\[Unreleased\]: .*/compare/v1.11.0\.\.\.HEAD" "$TD/CHANGELOG.md" \
  && grep -q "\[1.11.0\]: .*/compare/v1.9.0\.\.\.v1.11.0" "$TD/CHANGELOG.md" \
  && ok "T4.a CHANGELOG 변환 (헤딩+링크)" || fail "T4.a CHANGELOG"
rm -rf "$TD"

# T5: AC-5 README 배지
TD=$(mktemp -d); _make_git_fixture "$TD"
RELEASE_PLUGIN_ROOT="$TD" RELEASE_PREFLIGHT_CMD=true bash "$RELEASE" 1.11.0
grep -q "(v1.11.0)" "$TD/README.md" && ! grep -q "(v1.9.0)" "$TD/README.md" \
  && ok "T5.a README 배지 갱신" || fail "T5.a README"
rm -rf "$TD"

# T6: AC-6 footer 스탬프 불일치 수정
TD=$(mktemp -d); _make_git_fixture "$TD"
RELEASE_PLUGIN_ROOT="$TD" RELEASE_PREFLIGHT_CMD=true bash "$RELEASE" 1.11.0
# frontmatter=1.9.0, footer는 1.8.0 → footer가 1.9.0으로 수정되어야 함
grep -q "specops-auto-ko v1.9.0" "$TD/commands/cmd.md" \
  && ! grep -q "specops-auto-ko v1.8.0" "$TD/commands/cmd.md" \
  && ok "T6.a footer 스탬프 불일치 수정" || fail "T6.a footer"
rm -rf "$TD"

# T7: AC-7 git commit + annotated tag
TD=$(mktemp -d); _make_git_fixture "$TD"
RELEASE_PLUGIN_ROOT="$TD" RELEASE_PREFLIGHT_CMD=true bash "$RELEASE" 1.11.0
commit_msg=$(git -C "$TD" log --oneline -1 2>/dev/null)
tag_exists=$(git -C "$TD" tag -l "v1.11.0" 2>/dev/null)
echo "$commit_msg" | grep -q "chore: release v1.11.0" && [ "$tag_exists" = "v1.11.0" ] \
  && ok "T7.a git commit + annotated tag 생성" || fail "T7.a (commit='$commit_msg' tag='$tag_exists')"
rm -rf "$TD"

# T8: AC-8 --dry-run 파일 미변경
TD=$(mktemp -d); _make_git_fixture "$TD"
BEFORE=$(cat "$TD/CHANGELOG.md")
RELEASE_PLUGIN_ROOT="$TD" RELEASE_PREFLIGHT_CMD=true bash "$RELEASE" 1.11.0 --dry-run; rc=$?
AFTER=$(cat "$TD/CHANGELOG.md")
tag_after=$(git -C "$TD" tag -l "v1.11.0" 2>/dev/null)
[ "$rc" -eq 0 ] && [ "$BEFORE" = "$AFTER" ] && [ -z "$tag_after" ] \
  && ok "T8.a --dry-run: 파일 미변경, exit 0" || fail "T8.a (rc=$rc)"
rm -rf "$TD"

# T9: AC-9 pre-flight FAIL → abort, 파일 미변경
TD=$(mktemp -d); _make_git_fixture "$TD"
BEFORE=$(cat "$TD/CHANGELOG.md")
out=$(RELEASE_PLUGIN_ROOT="$TD" RELEASE_PREFLIGHT_CMD=false bash "$RELEASE" 1.11.0 2>&1); rc=$?
AFTER=$(cat "$TD/CHANGELOG.md")
[ "$rc" -eq 1 ] && echo "$out" | grep -q "pre-flight 검증 실패" && [ "$BEFORE" = "$AFTER" ] \
  && ok "T9.a pre-flight FAIL → exit 1 + 파일 미변경" || fail "T9.a (rc=$rc)"
rm -rf "$TD"

# T-manifest: AC-1/AC-2 plugin.json + marketplace.json 버전 bump
TD=$(mktemp -d); _make_git_fixture "$TD"
RELEASE_PLUGIN_ROOT="$TD" RELEASE_PREFLIGHT_CMD=true bash "$RELEASE" 1.11.0 > /dev/null 2>&1
plugin_ver=$(grep '"version"' "$TD/.claude-plugin/plugin.json" | grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' | tr -d '"')
market_ver=$(grep '"version"' "$TD/.claude-plugin/marketplace.json" | grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' | tr -d '"')
[ "$plugin_ver" = "1.11.0" ] \
  && ok "T-manifest.a plugin.json 버전 1.11.0 갱신" || fail "T-manifest.a (got: $plugin_ver)"
[ "$market_ver" = "1.11.0" ] \
  && ok "T-manifest.b marketplace.json 버전 1.11.0 갱신" || fail "T-manifest.b (got: $market_ver)"
rm -rf "$TD"

# T10: pre-flight 실제 경로 검증 (Important fix — PREFLIGHT_CMD 우회 없이)
# T10.a: 스크립트 파일 존재 확인
[ -f "$PLUGIN/scripts/_internal/validate-structure.sh" ] \
  && [ -f "$PLUGIN/scripts/tests/run-all.sh" ] \
  && ok "T10.a pre-flight 스크립트 경로 실재" || fail "T10.a pre-flight 경로 미존재"

# T10.b: 실제 repo dry-run — RELEASE_PREFLIGHT_CMD 미설정, repo clean 시에만 실행
# run-all 내부에서 호출된 경우(SPECOPS_RUN_ALL=1)에도 재귀 가드 메시지로 통과해야 함
if [ -z "$(git -C "$PLUGIN" status --porcelain 2>/dev/null)" ] \
    && ! git -C "$PLUGIN" tag -l "v9.99.0" 2>/dev/null | grep -q "v9.99.0"; then
  out=$(bash "$RELEASE" 9.99.0 --dry-run 2>&1); rc=$?
  [ "$rc" -eq 0 ] && echo "$out" | grep -qE "pre-flight (PASS|skip)" \
    && ok "T10.b 실제 pre-flight 경로 dry-run PASS" || fail "T10.b (rc=$rc out='$out')"
else
  ok "T10.b (SKIP — repo unclean 또는 v9.99.0 태그 존재)"
fi

# T11: 재귀 가드 — SPECOPS_RUN_ALL=1 + PREFLIGHT_CMD 미설정 → pre-flight skip (run-all 무한 재귀 방지)
TD=$(mktemp -d); _make_git_fixture "$TD"
out=$(RELEASE_PLUGIN_ROOT="$TD" SPECOPS_RUN_ALL=1 bash "$RELEASE" 1.11.0 --dry-run 2>&1); rc=$?
rm -rf "$TD"
[ "$rc" -eq 0 ] && echo "$out" | grep -q "재귀 방지" \
  && ok "T11.a SPECOPS_RUN_ALL=1 → pre-flight skip (재귀 가드)" || fail "T11.a (rc=$rc out='$out')"

# T12: FR-6b README footer 최신 스탬프 갱신
TD=$(mktemp -d); _make_git_fixture "$TD"
RELEASE_PLUGIN_ROOT="$TD" RELEASE_PREFLIGHT_CMD=true bash "$RELEASE" 1.11.0 > /dev/null 2>&1
TODAY=$(date +%Y-%m-%d)
grep -q "최신: v1.11.0 (${TODAY})" "$TD/README.md" && ! grep -q "최신: v1.9.0" "$TD/README.md" \
  && ok "T12.a README footer 최신 스탬프 갱신" || fail "T12.a (footer=$(grep '최신' "$TD/README.md"))"
rm -rf "$TD"

# T13: FR-7c marketplace metadata.description 버전 토큰 갱신
TD=$(mktemp -d); _make_git_fixture "$TD"
RELEASE_PLUGIN_ROOT="$TD" RELEASE_PREFLIGHT_CMD=true bash "$RELEASE" 1.11.0 > /dev/null 2>&1
grep -q "(v1.11.0 — test)" "$TD/.claude-plugin/marketplace.json" \
  && ! grep -q "(v1.9.0 — test)" "$TD/.claude-plugin/marketplace.json" \
  && ok "T13.a marketplace description 버전 갱신" || fail "T13.a (desc=$(grep description "$TD/.claude-plugin/marketplace.json"))"
rm -rf "$TD"

# T14: FR-12 origin 존재 시 push + gh release 발행 (bare origin + gh stub — 실제 GitHub 호출 없음)
TD=$(mktemp -d); _make_git_fixture "$TD"
BARE=$(mktemp -d); git init --bare -q "$BARE"
git -C "$TD" remote add origin "$BARE"
git -C "$TD" push -q -u origin HEAD          # upstream 설정 (release.sh 의 `git push` 대상)
FAKEBIN=$(mktemp -d); GH_LOG=$(mktemp)
cat > "$FAKEBIN/gh" <<GHSTUB
#!/usr/bin/env bash
echo "\$@" >> "$GH_LOG"
exit 0
GHSTUB
chmod +x "$FAKEBIN/gh"
out=$(RELEASE_PLUGIN_ROOT="$TD" RELEASE_PREFLIGHT_CMD=true PATH="$FAKEBIN:$PATH" bash "$RELEASE" 1.11.0 2>&1); rc=$?
[ "$rc" -eq 0 ] && echo "$out" | grep -q "릴리즈 발행 완료" \
  && ok "T14.a origin 존재 → push+release exit 0" || fail "T14.a (rc=$rc out='$out')"
git -C "$BARE" tag -l "v1.11.0" 2>/dev/null | grep -q "v1.11.0" \
  && ok "T14.b 태그 v1.11.0 origin(bare) push 확인" || fail "T14.b 태그 미push"
grep -q "release create" "$GH_LOG" && grep -q -- "--verify-tag" "$GH_LOG" && grep -q -- "--latest" "$GH_LOG" \
  && ok "T14.c gh release create --verify-tag --latest 호출" || fail "T14.c (gh_log='$(cat "$GH_LOG")')"
grep -q -- "--notes-file" "$GH_LOG" \
  && ok "T14.d CHANGELOG 노트 --notes-file 전달" || fail "T14.d (gh_log='$(cat "$GH_LOG")')"
rm -rf "$TD" "$BARE" "$FAKEBIN" "$GH_LOG"

# T15: FR-12 origin 부재 시 push/release skip (commit/tag 는 로컬 수행, exit 0)
TD=$(mktemp -d); _make_git_fixture "$TD"
out=$(RELEASE_PLUGIN_ROOT="$TD" RELEASE_PREFLIGHT_CMD=true bash "$RELEASE" 1.11.0 2>&1); rc=$?
[ "$rc" -eq 0 ] && echo "$out" | grep -q "원격 origin 없음" \
  && ok "T15.a origin 부재 → push/release skip exit 0" || fail "T15.a (rc=$rc out='$out')"
git -C "$TD" tag -l "v1.11.0" 2>/dev/null | grep -q "v1.11.0" \
  && ok "T15.b origin 부재여도 로컬 태그 v1.11.0 생성" || fail "T15.b 로컬 태그 미생성"
rm -rf "$TD"

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
