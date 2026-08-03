#!/usr/bin/env bash
# 검증 판정 단일 SoT.
# Usage:
#   verification-state.sh current <FID>
#   verification-state.sh record <FID> <NOT_RUN|PASS|PARTIAL|FAIL|WAIVED> [options]
# 신규 FID는 verification-state.json을 우선하며, 기존 evidence stamp는 읽기 호환만 제공한다.
set -u

SPECOPS="${SPECOPS_ROOT:-.specops}"

vs::valid_fid() {
  printf '%s' "$1" | grep -qE '^[0-9]{8}-[a-z0-9-]+$'
}

vs::valid_verdict() {
  case "$1" in
    NOT_RUN|PASS|PARTIAL|FAIL|WAIVED) return 0 ;;
    *) return 1 ;;
  esac
}

# 워크스페이스 내용 지문 — HEAD 문자열이 아니라 임시 인덱스의 write-tree 해시.
# 동일 내용을 커밋해도 지문이 바뀌지 않아 verify→commit 정상 흐름이 STALE로 뒤집히지 않는다.
# .specops 는 검증 기록 자기오염을 막기 위해 제외한다.
vs::workspace_fingerprint() {
  if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
    printf 'NO_GIT'
    return 0
  fi
  local idx tree
  idx=$(mktemp "${TMPDIR:-/tmp}/vs-idx.XXXXXX") || { printf 'NO_GIT'; return 0; }
  # 저장소 인덱스 비오염: GIT_INDEX_FILE 격리. unborn HEAD 도 add→write-tree 로 식별.
  GIT_INDEX_FILE="$idx" git read-tree HEAD >/dev/null 2>&1 || true
  GIT_INDEX_FILE="$idx" git add -A -- . ':(exclude).specops' >/dev/null 2>&1 || true
  tree=$(GIT_INDEX_FILE="$idx" git write-tree 2>/dev/null) || tree=""
  rm -f "$idx"
  if [ -n "$tree" ]; then
    printf '%s' "$tree"
  else
    printf 'NO_GIT'
  fi
}

vs::legacy_verdict() {
  local evidence="$1" verdict
  [ -f "$evidence" ] || { printf 'NOT_RUN'; return 0; }
  verdict=$(grep '^RUN-VERIFICATION-RESULT: ' "$evidence" 2>/dev/null | tail -1 | sed 's/^RUN-VERIFICATION-RESULT: //')
  vs::valid_verdict "$verdict" && printf '%s' "$verdict" || printf 'NOT_RUN'
}

vs::current() {
  local fid="$1"
  local state="$SPECOPS/$fid/verification-state.json"
  if [ ! -f "$state" ]; then
    vs::legacy_verdict "$SPECOPS/$fid/evidence.md"
    return 0
  fi

  local verdict recorded_hash current_hash expires now
  verdict=$(jq -r '.verdict // "NOT_RUN"' "$state" 2>/dev/null) || { printf 'NOT_RUN'; return 0; }
  vs::valid_verdict "$verdict" || { printf 'NOT_RUN'; return 0; }

  # WAIVED는 저장값이 아니라 조회 시점에 만료를 계산한다. 만료·메타 부재는 면제 종료.
  if [ "$verdict" = "WAIVED" ]; then
    expires=$(jq -r '.waiver.expires_at // empty' "$state" 2>/dev/null)
    if [ -z "$expires" ]; then
      printf 'NOT_RUN'
      return 0
    fi
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    if [[ "$now" > "$expires" ]]; then
      printf 'NOT_RUN'
      return 0
    fi
  fi

  if [ "$verdict" = "PASS" ]; then
    recorded_hash=$(jq -r '.tree_hash // ""' "$state" 2>/dev/null)
    current_hash=$(vs::workspace_fingerprint)
    if [ -n "$recorded_hash" ] && [ "$recorded_hash" != "NO_GIT" ] && [ "$recorded_hash" != "$current_hash" ]; then
      printf 'STALE'
      return 0
    fi
  fi
  printf '%s' "$verdict"
}

vs::record() {
  local fid="$1" verdict="$2"; shift 2
  vs::valid_fid "$fid" || { echo "verification-state: invalid FID" >&2; return 1; }
  vs::valid_verdict "$verdict" || { echo "verification-state: invalid verdict: $verdict" >&2; return 1; }
  [ ! -L "$SPECOPS" ] || { echo "verification-state: $SPECOPS symlink 거부" >&2; return 1; }
  [ ! -L "$SPECOPS/$fid" ] || { echo "verification-state: FID symlink 거부" >&2; return 1; }

  local executed=0 skipped=0 failed=0 duration_ms=0
  local waiver_reason="" waiver_approved_by="" waiver_expires_at=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --executed) executed="${2:-}"; shift 2 ;;
      --skipped) skipped="${2:-}"; shift 2 ;;
      --failed) failed="${2:-}"; shift 2 ;;
      --duration-ms) duration_ms="${2:-}"; shift 2 ;;
      --waiver-reason) waiver_reason="${2:-}"; shift 2 ;;
      --waiver-approved-by) waiver_approved_by="${2:-}"; shift 2 ;;
      --waiver-expires-at) waiver_expires_at="${2:-}"; shift 2 ;;
      *) echo "verification-state: unknown option: $1" >&2; return 1 ;;
    esac
  done
  local n
  for n in "$executed" "$skipped" "$failed" "$duration_ms"; do
    printf '%s' "$n" | grep -qE '^[0-9]+$' || { echo "verification-state: numeric value required" >&2; return 1; }
  done
  if [ "$verdict" = "WAIVED" ]; then
    [ -n "$waiver_reason" ] && [ -n "$waiver_approved_by" ] && [ -n "$waiver_expires_at" ] \
      || { echo "verification-state: WAIVED requires reason, approved-by, expires-at" >&2; return 1; }
    [ ${#waiver_reason} -le 200 ] && [ ${#waiver_approved_by} -le 120 ] \
      || { echo "verification-state: waiver field too long" >&2; return 1; }
    printf '%s' "$waiver_expires_at" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
      || { echo "verification-state: invalid waiver expiry" >&2; return 1; }
  elif [ -n "$waiver_reason$waiver_approved_by$waiver_expires_at" ]; then
    echo "verification-state: waiver options require WAIVED verdict" >&2
    return 1
  fi

  mkdir -p "$SPECOPS/$fid" || return 1
  local target="$SPECOPS/$fid/verification-state.json"
  local tmp="$SPECOPS/$fid/.verification-state.$$.tmp"
  [ ! -L "$target" ] || { echo "verification-state: state file symlink 거부" >&2; return 1; }
  local ts head_sha tree
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  head_sha=$(git rev-parse HEAD 2>/dev/null || printf 'UNBORN')
  tree=$(vs::workspace_fingerprint)
  jq -n \
    --argjson schema_version 1 --arg fid "$fid" --arg verdict "$verdict" \
    --arg recorded_at "$ts" --arg head_sha "$head_sha" --arg tree_hash "$tree" \
    --argjson executed "$executed" --argjson skipped "$skipped" \
    --argjson failed "$failed" --argjson duration_ms "$duration_ms" \
    --arg waiver_reason "$waiver_reason" --arg waiver_approved_by "$waiver_approved_by" \
    --arg waiver_expires_at "$waiver_expires_at" \
    '{schema_version:$schema_version,fid:$fid,verdict:$verdict,recorded_at:$recorded_at,
      head_sha:$head_sha,tree_hash:$tree_hash,executed:$executed,skipped:$skipped,
      failed:$failed,duration_ms:$duration_ms,
      waiver:(if $verdict=="WAIVED" then
        {reason:$waiver_reason,approved_by:$waiver_approved_by,expires_at:$waiver_expires_at}
        else null end)}' > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$target"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  action="${1:-}"; fid="${2:-}"
  case "$action" in
    current)
      vs::valid_fid "$fid" || { echo "verification-state: invalid FID" >&2; exit 1; }
      vs::current "$fid"; printf '\n'
      ;;
    record)
      [ "$#" -ge 3 ] || { echo "usage: $0 record <FID> <verdict> [options]" >&2; exit 1; }
      shift 2
      vs::record "$fid" "$@"
      ;;
    *)
      echo "usage: $0 {current <FID>|record <FID> <verdict> [options]}" >&2
      exit 1
      ;;
  esac
fi
