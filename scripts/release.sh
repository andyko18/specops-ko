#!/usr/bin/env bash
# Requires: git 2.23+ (rollback 이 `git restore` 사용), jq, bash 3.2+
set -euo pipefail

PLUGIN_ROOT="${RELEASE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PREFLIGHT_CMD="${RELEASE_PREFLIGHT_CMD:-}"
VERSION="${1:-}"
DRY_RUN=false
[ "${2:-}" = "--dry-run" ] && DRY_RUN=true

_sed_i() {
  if [[ "$(uname)" == "Darwin" ]]; then sed -i '' "$@"; else sed -i "$@"; fi
}

# FR-1: semver X.Y.Z 검증
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Error: semver X.Y.Z 형식이 아닙니다: '${VERSION}'" >&2
  exit 1
fi

# FR-2: git 워킹트리 클린 확인
if [ -n "$(git -C "$PLUGIN_ROOT" status --porcelain 2>/dev/null)" ]; then
  echo "Error: git 워킹트리가 클린하지 않습니다. 커밋 또는 stash 후 재시도하세요." >&2
  exit 1
fi

# FR-11: 이미 태그된 버전 확인
if git -C "$PLUGIN_ROOT" tag -l "v${VERSION}" 2>/dev/null | grep -q "^v${VERSION}$"; then
  echo "Error: v${VERSION} already tagged" >&2
  exit 1
fi

_run_check() {
  local label="$1"
  if [ -n "$PREFLIGHT_CMD" ]; then
    # 테스트 전용 override (RELEASE_PREFLIGHT_CMD=true/false) — 프로덕션 미설정
    if ! eval "$PREFLIGHT_CMD" > /dev/null 2>&1; then
      echo "Error: pre-flight 검증 실패 ($label)" >&2
      exit 1
    fi
  else
    if ! bash "$PLUGIN_ROOT/$label" > /dev/null 2>&1; then
      echo "Error: pre-flight 검증 실패 ($label)" >&2
      exit 1
    fi
  fi
}

# run-all.sh 내부에서 호출된 경우 (test-release T10.b) pre-flight 재실행 시 무한 재귀 — skip
if [ "${SPECOPS_RUN_ALL:-}" = "1" ] && [ -z "$PREFLIGHT_CMD" ]; then
  echo "-> pre-flight skip (run-all 내부 — 재귀 방지)"
else
  echo "-> pre-flight 검증 시작 (전체 테스트 aggregator)..."
  _run_check "scripts/tests/run-all.sh"
  echo "-> pre-flight PASS"
fi

CHANGELOG="$PLUGIN_ROOT/CHANGELOG.md"
README="$PLUGIN_ROOT/README.md"
DATE=$(date +%Y-%m-%d)
CHANGED_FILES=()

# trap EXIT: best-effort 롤백
_do_rollback() {
  if [ ${#CHANGED_FILES[@]} -gt 0 ]; then
    echo "Error: 중간 실패 — best-effort 롤백 중..." >&2
    git -C "$PLUGIN_ROOT" restore -- "${CHANGED_FILES[@]}" 2>/dev/null || true
  fi
}
trap '_do_rollback' EXIT

# dry-run 분기
if $DRY_RUN; then
  echo "--- DRY-RUN 예정 작업 ---"
  echo "1. CHANGELOG: [Unreleased] -> [${VERSION}] — ${DATE} 변환"
  echo "2. README: 버전 배지 갱신"
  echo "3. commands/*.md: footer 스탬프 불일치 수정"
  echo "4. .claude-plugin/plugin.json + marketplace.json: 버전 bump"
  echo "5. git commit: chore: release v${VERSION}"
  echo "6. git tag: v${VERSION}"
  echo "--- DRY-RUN 완료 (변경 없음) ---"
  trap - EXIT
  exit 0
fi

# FR-4+FR-5: CHANGELOG 변환 (awk — cross-platform)
if grep -q '^## \[Unreleased\]$' "$CHANGELOG"; then
  CHANGED_FILES+=("$CHANGELOG")
  PREV=$(grep '^\[Unreleased\]:' "$CHANGELOG" | sed 's|.*compare/\([^.]*\.[^.]*\.[^.]*\)\.\.\.HEAD|\1|')
  BASE_URL=$(grep '^\[Unreleased\]:' "$CHANGELOG" | sed 's|\[Unreleased\]: \(.*\)/compare/.*|\1|')
  [ -z "$PREV" ] && echo "Warning: CHANGELOG.md에 [Unreleased]: compare 링크 없음 — 링크 갱신 skip" >&2

  # [Unreleased] 헤딩 아래 새 버전 헤딩 삽입
  awk -v ver="$VERSION" -v date="$DATE" '
    /^## \[Unreleased\]$/ { print; print ""; print "## [" ver "] — " date; next }
    { print }
  ' "$CHANGELOG" > "${CHANGELOG}.tmp" && mv "${CHANGELOG}.tmp" "$CHANGELOG"

  # compare 링크 갱신
  awk -v ver="$VERSION" -v prev="$PREV" -v base="$BASE_URL" '
    /^\[Unreleased\]:.*HEAD$/ {
      print "[Unreleased]: " base "/compare/v" ver "...HEAD"
      print "[" ver "]: " base "/compare/" prev "...v" ver
      next
    }
    { print }
  ' "$CHANGELOG" > "${CHANGELOG}.tmp" && mv "${CHANGELOG}.tmp" "$CHANGELOG"
else
  echo "Warning: CHANGELOG.md에 '## [Unreleased]' 섹션 없음 — CHANGELOG 갱신 skip" >&2
fi

# FR-6: README 버전 배지 갱신
CHANGED_FILES+=("$README")
OLD_VER=$(grep -oE '\(v[0-9]+\.[0-9]+\.[0-9]+\)' "$README" | head -1 | tr -d '()')
if [ -n "$OLD_VER" ]; then
  _sed_i "s|(${OLD_VER})|(v${VERSION})|g" "$README"
fi

# FR-6b: README footer 최신 버전 스탬프 갱신 (**최신: vX.Y.Z (날짜)**)
if grep -qE '최신: v[0-9]+\.[0-9]+\.[0-9]+' "$README"; then
  _sed_i "s|최신: v[0-9][0-9.]* ([0-9-]*)|최신: v${VERSION} (${DATE})|" "$README"
fi

# FR-7: commands/*.md footer 스탬프 불일치 수정
for cmd_file in "$PLUGIN_ROOT/commands/"*.md; do
  [ -f "$cmd_file" ] || continue
  fm_ver=$(awk 'BEGIN{n=0} /^---/{n++; if(n==2)exit} /^specops_version:/{print $2}' "$cmd_file")
  [ -z "$fm_ver" ] && continue
  if grep -qE '^\*specops-auto-ko v[0-9]' "$cmd_file"; then
    footer_ver=$(grep '^\*specops-auto-ko' "$cmd_file" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d 'v')
    if [ -n "$footer_ver" ] && [ "$footer_ver" != "$fm_ver" ]; then
      CHANGED_FILES+=("$cmd_file")
      _sed_i "s|^\(\*specops-auto-ko v\)[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*|\1${fm_ver}|" "$cmd_file"
    fi
  fi
done

# FR-7b: plugin.json/marketplace.json 버전 bump
for manifest in "$PLUGIN_ROOT/.claude-plugin/plugin.json" \
                "$PLUGIN_ROOT/.claude-plugin/marketplace.json"; do
  [ -f "$manifest" ] || continue
  _sed_i "s/\"version\": \"[0-9][^\"]*\"/\"version\": \"${VERSION}\"/" "$manifest"
  CHANGED_FILES+=("$manifest")
done

# FR-7c: marketplace metadata.description 내 (vX.Y.Z — 토큰 갱신
MARKET="$PLUGIN_ROOT/.claude-plugin/marketplace.json"
if [ -f "$MARKET" ] && grep -qE '\(v[0-9]+\.[0-9]+\.[0-9]+ —' "$MARKET"; then
  _sed_i "s|(v[0-9][0-9.]* —|(v${VERSION} —|" "$MARKET"
fi

echo "-> 파일 변환 완료"

# FR-8: post-flight
echo "-> post-flight 검증 시작..."
_run_check "scripts/_internal/validate-structure.sh"
echo "-> post-flight PASS"

# FR-9~FR-10: git commit + annotated tag
echo "-> git 커밋 및 태그 생성..."
git -C "$PLUGIN_ROOT" add "${CHANGED_FILES[@]}"
git -C "$PLUGIN_ROOT" commit -m "chore: release v${VERSION}"
git -C "$PLUGIN_ROOT" tag -a "v${VERSION}" -m "Release v${VERSION}"

trap - EXIT

echo ""
echo "로컬 릴리즈 완료 (v${VERSION})"
echo "다음 명령으로 원격에 push하세요:"
echo "  git push && git push --tags"
