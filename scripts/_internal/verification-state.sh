#!/usr/bin/env bash
# 검증 판정 단일 SoT.
# Usage:
#   verification-state.sh current <FID>
#   verification-state.sh record <FID> <NOT_RUN|PASS|PARTIAL|FAIL|WAIVED> [options]
# 신규 FID는 verification-state.json을 우선하며, 기존 evidence stamp는 읽기 호환만 제공한다.
set -u

SPECOPS="${SPECOPS_ROOT:-.specops}"

# 파일 분류 단일 SoT (20260912-verify-stale-docs-scope).
#   ★ ${BASH_SOURCE[0]%/*} 로 해석한다 — .githooks/pre-push 가 이 파일을 **상대경로**로 source 하므로
#     $0 기반 해석은 깨진다. 슬래시 없는 source 면 이 확장이 파일명을 그대로 돌려주어 source 가
#     실패하는데, 아래 가드가 fail-safe(전건 비문서=지문 확대)로 받는다.
_VS_DIR="${BASH_SOURCE[0]%/*}"
if [ -f "$_VS_DIR/file-class.sh" ]; then
  # shellcheck source=/dev/null
  . "$_VS_DIR/file-class.sh"
else
  echo "verification-state: file-class.sh 로드 실패 — 전건 비문서로 판정한다" >&2
  fc::is_doc() { return 1; }
  fc::is_plugin_repo() { return 1; }
fi

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

# 비문서 지문 — 문서 전용 변경에는 불변이다 (20260912-verify-stale-docs-scope).
#   왜 별도 함수인가: vs::workspace_fingerprint 는 pre-push 마커·receipt 가 "이 트리가 통과했다" 는
#   진술로 쓰던 값이다. 의미를 바꾸지 않고 **비문서 한정 지문을 추가**해, 소비자가 어느 의미를
#   원하는지 호출부에서 드러나게 한다.
#   왜 과거 트리를 조회하지 않는가: write-tree 산출 트리는 어떤 ref 에서도 도달 불가라 git gc 대상이다
#   (실측: 이 저장소 기록 55건 중 3건이 이미 소실). 기록 시점에 지문을 남겨야 대조가 성립한다.
vs::nondoc_fingerprint() {
  if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
    printf 'NO_GIT'
    return 0
  fi
  local idx plugin_rc=1 line f out="" top
  idx=$(mktemp "${TMPDIR:-/tmp}/vs-nidx.XXXXXX") || { printf 'NO_GIT'; return 0; }
  # ★ 저장소 루트에 앵커한다 — pathspec `.` 과 `:(exclude).specops` 는 **cwd 상대**라
  #   서브디렉터리에서 부르면 그 아래만 열거된다. workspace_fingerprint 는 같은 트리면 cwd 와
  #   무관하게 같은 값을 주는데 nondoc 만 갈리면, 기록 cwd ≠ 조회 cwd 일 때 가짜 STALE·
  #   `tree stale` 오거부가 나고 반대로 같은 서브디렉터리끼리면 바깥 코드 변경을 못 본다
  #   (실측: 루트 c372baae vs sub fd7dce69 — 같은 트리인데 다름). Phase C I-3.
  #   `:/` 접두는 "저장소 루트 기준" 이라 exclude 도 함께 정확해진다(.specops 자기오염 방지 복원).
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { rm -f "$idx"; printf 'NO_GIT'; return 0; }
  GIT_INDEX_FILE="$idx" git -C "$top" read-tree HEAD >/dev/null 2>&1 || true
  GIT_INDEX_FILE="$idx" git -C "$top" add -A -- ':/' ':(exclude,glob):/.specops/**' >/dev/null 2>&1 || true
  fc::is_plugin_repo && plugin_rc=0   # 루프 **밖에서 1회만** — 파일마다 부르면 프로세스를 스폰한다
  # ★ --full-name 필수 — 없으면 서브디렉터리 호출 시 경로가 cwd 상대로 나와 분류가 오판한다
  #   (실측: scripts/ 에서 `README.md` vs `scripts/README.md`).
  # ★★ `-C "$top"` 도 필수다 — `ls-files` 는 **cwd 하위만 열거**한다. read-tree·add 만 앵커하고
  #   이 줄을 빠뜨리면 인덱스에는 전체가 들어와도 **목록이 cwd 아래로 잘려** 지문이 갈린다.
  #   실측(수정 전 HEAD): 같은 깨끗한 트리에서 루트 c5e6e0a9 vs sub fd7dce69, 그리고 루트 code.sh 를
  #   고쳐도 sub 에서는 값이 안 변했다(바깥 변경이 안 보임). Phase C 재판정이 이걸 잡았다 —
  #   78·79 만 고치고 "cwd 의존 제거" 라 적었던 것은 **거짓 주장**이었고, probe 재실행을 했으면 잡혔다.
  # ★ core.quotePath=false — 비ASCII 경로를 `"\355\225\234..."` 로 인용하지 않고 원문으로 낸다.
  #   인용되면 fc::is_doc 이 받는 이름이 실제 경로와 달라져 분류 근거가 흔들린다(M-2).
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    f=${line#*$'\t'}
    fc::is_doc "$f" "$plugin_rc" && continue
    out="${out}${line}"$'\n'
  done <<EOF
$(GIT_INDEX_FILE="$idx" git -C "$top" -c core.quotePath=false ls-files -s --full-name 2>/dev/null)
EOF
  rm -f "$idx"
  [ -z "$out" ] && { printf 'EMPTY'; return 0; }
  printf '%s' "$out" | shasum -a 256 | awk '{print $1}' | tr -d '\n'
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

  # PASS 이후 변경 판정 — 문서 전용 변경은 무효화하지 않는다 (20260912-verify-stale-docs-scope).
  #   nondoc_hash 가 있으면 그것으로 비교하고, 없으면(구버전 기록) 종전 전체 지문 비교로 떨어진다.
  #   부재 시 방향은 **더 엄격한 쪽**이라 fail-safe 다 — 기존 기록이 갑자기 느슨해지지 않는다.
  if [ "$verdict" = "PASS" ]; then
    recorded_hash=$(jq -r '.nondoc_hash // ""' "$state" 2>/dev/null)
    if [ -n "$recorded_hash" ] && [ "$recorded_hash" != "NO_GIT" ]; then
      current_hash=$(vs::nondoc_fingerprint)
    else
      recorded_hash=$(jq -r '.tree_hash // ""' "$state" 2>/dev/null)
      current_hash=$(vs::workspace_fingerprint)
    fi
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
  # 비문서 지문을 함께 남긴다 — 조회 시점에 과거 트리를 못 찾는 문제(gc)를 구조적으로 피한다.
  #   schema_version 은 올리지 않는다: 필드 부재가 곧 구버전이고 소비측이 종전 경로로 떨어진다.
  local nondoc
  nondoc=$(vs::nondoc_fingerprint)
  jq -n \
    --argjson schema_version 1 --arg fid "$fid" --arg verdict "$verdict" \
    --arg recorded_at "$ts" --arg head_sha "$head_sha" --arg tree_hash "$tree" \
    --arg nondoc_hash "$nondoc" \
    --argjson executed "$executed" --argjson skipped "$skipped" \
    --argjson failed "$failed" --argjson duration_ms "$duration_ms" \
    --arg waiver_reason "$waiver_reason" --arg waiver_approved_by "$waiver_approved_by" \
    --arg waiver_expires_at "$waiver_expires_at" \
    '{schema_version:$schema_version,fid:$fid,verdict:$verdict,recorded_at:$recorded_at,
      head_sha:$head_sha,tree_hash:$tree_hash,nondoc_hash:$nondoc_hash,
      executed:$executed,skipped:$skipped,
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
