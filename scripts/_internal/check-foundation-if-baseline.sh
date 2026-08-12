#!/usr/bin/env bash
# check-foundation-if-baseline.sh — foundation IF 마커 구간 불변 검사 (20260812)
# Usage:
#   check-foundation-if-baseline.sh snapshot <out-file>
#   check-foundation-if-baseline.sh verify <snapshot-file>
# Exit: 0 = PASS|SKIP · 1 = FAIL · 2 = usage
#
# 왜: foundation Step 5.6 이 채운 공통 api-spec/data-model 을 Phase 2.5-B 가
#   "동일 경로 행 갱신"으로 재작성하면 baseline 이 무너진다. 마커 본문 해시를
#   B 직전 snapshot → 직후 verify 로 잠근다.
set -u

MODE="${1:-}"
ARG="${2:-}"
SPECOPS="${SPECOPS_ROOT:-.specops}"
MEM="$SPECOPS/memory"

usage() {
  echo "usage: $0 snapshot <out-file> | verify <snapshot-file>" >&2
  exit 2
}

[ -n "$MODE" ] && [ -n "$ARG" ] || usage

_files() {
  for f in "$MEM/api-spec.md" "$MEM/data-model.md"; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
}

# stdout: 한 줄씩 PATH|INDEX|SHA  · stderr 깨진 짝 · rc 1 if broken
_scan_file() {
  local path="$1"
  local start=0 end=0 idx=0 in=0 body="" line
  while IFS= read -r line || [ -n "$line" ]; do
    if printf '%s' "$line" | grep -qE '<!--[[:space:]]*foundation-baseline:start[[:space:]]*-->'; then
      if [ "$in" -eq 1 ]; then
        echo "FOUNDATION-IF-BASELINE: FAIL — nested/unclosed start in $path" >&2
        return 1
      fi
      start=$((start + 1))
      in=1
      body=""
      continue
    fi
    if printf '%s' "$line" | grep -qE '<!--[[:space:]]*foundation-baseline:end[[:space:]]*-->'; then
      end=$((end + 1))
      if [ "$in" -ne 1 ]; then
        echo "FOUNDATION-IF-BASELINE: FAIL — end without start in $path" >&2
        return 1
      fi
      # trim leading/trailing blank lines from body
      body=$(printf '%s' "$body" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' | sed -e '/./,$!d')
      sha=$(printf '%s' "$body" | shasum -a 256 2>/dev/null | awk '{print $1}')
      [ -n "$sha" ] || sha=$(printf '%s' "$body" | openssl dgst -sha256 2>/dev/null | awk '{print $NF}')
      printf '%s|%s|%s\n' "$path" "$idx" "$sha"
      idx=$((idx + 1))
      in=0
      body=""
      continue
    fi
    if [ "$in" -eq 1 ]; then
      body="${body}${line}
"
    fi
  done < "$path"
  if [ "$in" -eq 1 ]; then
    echo "FOUNDATION-IF-BASELINE: FAIL — start without end in $path" >&2
    return 1
  fi
  if [ "$start" -ne "$end" ]; then
    echo "FOUNDATION-IF-BASELINE: FAIL — start/end count mismatch in $path ($start/$end)" >&2
    return 1
  fi
  return 0
}

_collect() {
  local f lines="" out rc=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! out=$(_scan_file "$f"); then
      return 1
    fi
    if [ -n "$out" ]; then
      if [ -z "$lines" ]; then
        lines="$out"
      else
        lines="$lines
$out"
      fi
    fi
  done <<EOF
$(_files)
EOF
  printf '%s' "$lines"
  return 0
}

case "$MODE" in
  snapshot)
    out_file="$ARG"
    mkdir -p "$(dirname "$out_file")" 2>/dev/null || true
    if ! collected=$(_collect); then
      echo "FOUNDATION-IF-BASELINE: FAIL — marker pair broken (snapshot)"
      exit 1
    fi
    if [ -z "$collected" ]; then
      printf 'SKIP\n' > "$out_file"
      echo "FOUNDATION-IF-BASELINE: SKIP (마커 0)"
      exit 0
    fi
    printf '%s\n' "$collected" > "$out_file"
    echo "FOUNDATION-IF-BASELINE: SNAPSHOT ($(printf '%s\n' "$collected" | grep -c . | tr -d ' ') regions)"
    exit 0
    ;;
  verify)
    snap="$ARG"
    [ -f "$snap" ] || {
      echo "FOUNDATION-IF-BASELINE: FAIL — snapshot 부재: $snap"
      exit 1
    }
    first=$(head -1 "$snap")
    if [ "$first" = "SKIP" ]; then
      echo "FOUNDATION-IF-BASELINE: SKIP (snapshot 이 SKIP)"
      exit 0
    fi
    if ! collected=$(_collect); then
      echo "FOUNDATION-IF-BASELINE: FAIL — marker pair broken (verify)"
      exit 1
    fi
    # normalize sort for compare
    sort_snap=$(grep -v '^$' "$snap" | sort)
    sort_now=$(printf '%s\n' "$collected" | grep -v '^$' | sort)
    if [ "$sort_snap" = "$sort_now" ]; then
      echo "FOUNDATION-IF-BASELINE: PASS"
      exit 0
    fi
    echo "FOUNDATION-IF-BASELINE: FAIL — foundation-baseline 마커 본문 변경"
    echo "  Phase 2.5-B 는 마커 밖만 append/갱신하세요. baseline 변경은 /start-foundation 또는 /design-interface."
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
