#!/usr/bin/env bash
# check-foundation-shell-baseline.sh — foundation 셸 screens 불변 검사 (20260812)
# Usage:
#   check-foundation-shell-baseline.sh snapshot <out-file>
#   check-foundation-shell-baseline.sh verify <snapshot-file>
# Exit: 0 = PASS|SKIP · 1 = FAIL · 2 = usage
#
# 왜: foundation Step 5.5 가 채운 AppShell 등 셸 screens 를 Phase 2.5-A 가
#   기능 화면 통합 설계로 재작성하면 UI 공통 계약이 무너진다. allowlist∩마커
#   파일 해시를 A 직전 snapshot → 직후 verify 로 잠근다.
set -u

MODE="${1:-}"
ARG="${2:-}"
SCREENS_DIR="${SPECOPS_SCREENS_DIR:-screens}"

# v1 allowlist — exact slug match
ALLOWLIST="app-shell layout login"

usage() {
  echo "usage: $0 snapshot <out-file> | verify <snapshot-file>" >&2
  exit 2
}

[ -n "$MODE" ] && [ -n "$ARG" ] || usage

_is_allowlisted() {
  local slug="$1" s
  for s in $ALLOWLIST; do
    [ "$s" = "$slug" ] && return 0
  done
  return 1
}

_sha_file() {
  local f="$1" sha
  sha=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
  [ -n "$sha" ] || sha=$(openssl dgst -sha256 "$f" 2>/dev/null | awk '{print $NF}')
  printf '%s' "$sha"
}

# stdout: 한 줄씩 RELPATH|SHA  (marker+allowlist만)
_collect() {
  local md slug html sha lines="" rel
  [ -d "$SCREENS_DIR" ] || {
    printf '%s' ""
    return 0
  }
  # shellcheck disable=SC2044
  for md in $(find "$SCREENS_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort); do
    [ -f "$md" ] || continue
    slug=$(basename "$md" .md)
    _is_allowlisted "$slug" || continue
    grep -qE '<!--[[:space:]]*foundation-shell[[:space:]]*-->' "$md" || continue
    rel="$md"
    sha=$(_sha_file "$md")
    [ -n "$sha" ] || continue
    if [ -z "$lines" ]; then
      lines="${rel}|${sha}"
    else
      lines="${lines}
${rel}|${sha}"
    fi
    html="${SCREENS_DIR}/${slug}.html"
    if [ -f "$html" ]; then
      sha=$(_sha_file "$html")
      lines="${lines}
${html}|${sha}"
    fi
  done
  printf '%s' "$lines"
  return 0
}

case "$MODE" in
  snapshot)
    out_file="$ARG"
    mkdir -p "$(dirname "$out_file")" 2>/dev/null || true
    collected=$(_collect)
    if [ -z "$collected" ]; then
      printf 'SKIP\n' > "$out_file"
      echo "FOUNDATION-SHELL-BASELINE: SKIP (셸 screens 0)"
      exit 0
    fi
    printf '%s\n' "$collected" > "$out_file"
    echo "FOUNDATION-SHELL-BASELINE: SNAPSHOT ($(printf '%s\n' "$collected" | grep -c . | tr -d ' ') files)"
    exit 0
    ;;
  verify)
    snap="$ARG"
    [ -f "$snap" ] || {
      echo "FOUNDATION-SHELL-BASELINE: FAIL — snapshot 부재: $snap"
      exit 1
    }
    first=$(head -1 "$snap")
    if [ "$first" = "SKIP" ]; then
      echo "FOUNDATION-SHELL-BASELINE: SKIP (snapshot 이 SKIP)"
      exit 0
    fi
    collected=$(_collect)
    sort_snap=$(grep -v '^$' "$snap" | sort)
    sort_now=$(printf '%s\n' "$collected" | grep -v '^$' | sort)
    if [ "$sort_snap" = "$sort_now" ]; then
      echo "FOUNDATION-SHELL-BASELINE: PASS"
      exit 0
    fi
    echo "FOUNDATION-SHELL-BASELINE: FAIL — foundation-shell screens 변경"
    echo "  Phase 2.5-A 는 셸(app-shell/layout/login + foundation-shell 마커)을 재작성하지 마세요."
    echo "  셸 변경은 /start-foundation 또는 /design-screen(셸 슬러그)만."
    echo "  --- snapshot ---"
    printf '%s\n' "$sort_snap" | sed 's/^/  /'
    echo "  --- current ---"
    printf '%s\n' "$sort_now" | sed 's/^/  /'
    exit 1
    ;;
  *)
    usage
    ;;
esac
