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

# B#1: 버전 단조성 — 현재 plugin.json 버전보다 높아야 (회귀/중복 버전 발행 차단).
# 미태그 회귀버전(release 1.5.0)·동일버전 재발행을 사전 차단 — partial-failure 후
# 잔류 commit(plugin.json 이미 bump) 재실행도 여기서 명확히 거부된다.
PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"
if [ -f "$PLUGIN_JSON" ]; then
  CUR_VER=$(grep -oE '"version": *"[0-9]+\.[0-9]+\.[0-9]+"' "$PLUGIN_JSON" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  if [ -n "$CUR_VER" ]; then
    higher=$(printf '%s\n%s\n' "$CUR_VER" "$VERSION" | sort -V | tail -1)
    if [ "$VERSION" = "$CUR_VER" ] || [ "$higher" != "$VERSION" ]; then
      echo "Error: v${VERSION} 는 현재 버전 v${CUR_VER} 이하입니다 — 회귀/중복 발행 차단 (단조 증가 필요)" >&2
      exit 1
    fi
  fi
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

# B층: llm-eval staleness soft 경고 (비차단 — LLM chain 은 run-all 밖이라 별도 신호)
# stat: GNU(-c) 우선, Darwin(-f) fallback — 역순이면 GNU 에서 -f 가 fs 덤프 출력 (hard fail 원인)
STAMP="$PLUGIN_ROOT/.specops-cache/llm-eval-last-run"
if [ ! -f "$STAMP" ]; then
  echo "⚠️  llm-eval 실행 기록 없음 — 릴리즈 전 bash scripts/tests/llm-eval/run-evals.sh 권장 (soft)" >&2
else
  stamp_epoch=$(stat -c %Y "$STAMP" 2>/dev/null || stat -f %m "$STAMP" 2>/dev/null || echo 0)
  age_days=$(( ( $(date +%s) - stamp_epoch ) / 86400 ))
  if [ "$stamp_epoch" -eq 0 ]; then
    echo "⚠️  llm-eval 스탬프 시각 판독 불가 — 재실행 권장 (soft)" >&2
  elif [ "$age_days" -gt 7 ]; then
    echo "⚠️  llm-eval 마지막 실행 ${age_days}일 경과 — 재실행 권장 (soft)" >&2
  fi
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
  echo "7. git push (origin 존재 시): main + v${VERSION} 태그"
  echo "8. gh release create v${VERSION} (gh 설치 시): CHANGELOG [${VERSION}] 노트 + --latest"
  echo "--- DRY-RUN 완료 (변경 없음) ---"
  trap - EXIT
  exit 0
fi

# FR-4+FR-5: CHANGELOG 변환 (awk — cross-platform)
# B#2: 멱등 가드 — [VERSION] 섹션이 이미 존재하면 변환 skip (부분 실패 재실행 시
#   [Unreleased] 잔존으로 인한 [VERSION] heading 이중삽입 방지). 단조성 게이트(B#1)와 중첩 방어.
if grep -qE "^## \[${VERSION//./\\.}\]( |$)" "$CHANGELOG"; then
  echo "Warning: CHANGELOG 에 [${VERSION}] 섹션 이미 존재 — CHANGELOG 변환 skip (멱등)" >&2
elif grep -q '^## \[Unreleased\]$' "$CHANGELOG"; then
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
  if grep -qE '^\*specops-ko v[0-9]' "$cmd_file"; then
    footer_ver=$(grep '^\*specops-ko' "$cmd_file" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 | tr -d 'v')
    if [ -n "$footer_ver" ] && [ "$footer_ver" != "$fm_ver" ]; then
      CHANGED_FILES+=("$cmd_file")
      _sed_i "s|^\(\*specops-ko v\)[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*|\1${fm_ver}|" "$cmd_file"
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

# FR-12: 원격 push + GitHub Release 발행
# origin 부재 시(테스트 임시 repo 등) push/release skip — fail-safe, 테스트 무손상
if ! git -C "$PLUGIN_ROOT" remote get-url origin > /dev/null 2>&1; then
  echo "원격 origin 없음 — push/release skip. 수동: git push && git push --tags"
  exit 0
fi

echo "-> 원격 push..."
git -C "$PLUGIN_ROOT" push
git -C "$PLUGIN_ROOT" push origin "v${VERSION}"

# gh CLI 미설치 시 release 만 graceful skip (push 는 이미 성공)
if ! command -v gh > /dev/null 2>&1; then
  echo "Warning: gh CLI 미설치 — GitHub Release 생성 skip." >&2
  echo "  수동: gh release create v${VERSION} --verify-tag --latest --generate-notes" >&2
  exit 0
fi

echo "-> GitHub Release 생성..."
# CHANGELOG 의 [VERSION] 섹션 본문을 release 노트로 추출 (헤더 제외)
NOTES_FILE=$(mktemp)
awk -v v="$VERSION" '
  $0 ~ "^## \\[" v "\\]" { f=1; next }
  f && /^## \[/ { exit }
  f { print }
' "$CHANGELOG" > "$NOTES_FILE"

# compare 링크 추가 (PREV/BASE_URL 은 CHANGELOG 변환 단계에서 산출됨)
if [ -n "${PREV:-}" ] && [ -n "${BASE_URL:-}" ]; then
  printf '\n**Full Changelog**: %s/compare/%s...v%s\n' "$BASE_URL" "$PREV" "$VERSION" >> "$NOTES_FILE"
fi

# 노트 본문이 비면 gh 자동 생성으로 fallback
if [ -s "$NOTES_FILE" ]; then
  gh release create "v${VERSION}" \
    --repo "$(git -C "$PLUGIN_ROOT" remote get-url origin)" \
    --title "v${VERSION}" \
    --notes-file "$NOTES_FILE" \
    --verify-tag --latest
else
  gh release create "v${VERSION}" \
    --repo "$(git -C "$PLUGIN_ROOT" remote get-url origin)" \
    --title "v${VERSION}" \
    --verify-tag --latest --generate-notes
fi
rm -f "$NOTES_FILE"

echo ""
echo "릴리즈 발행 완료 (v${VERSION})"
