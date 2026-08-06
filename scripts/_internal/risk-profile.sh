#!/usr/bin/env bash
# 위험 프로파일 분류기 (P1 → Wave B limited live).
# Usage:
#   risk-profile.sh compute <FID> [--floor standard|strict]
#   risk-profile.sh show <FID>
# lite/standard/strict 를 계산·기록한다. mode=live 이며, effective=lite 일 때만
# reductions_allowed=["batch-review-skip"] (requesting/receiving skip). Phase B·TDD·verify·receipt 축소 금지.
# 참고: review_mode:end-loaded 는 B/C 생략이 아니라 말미 1회 수행 — reductions_allowed 와 무관.
set -u

SPECOPS="${SPECOPS_ROOT:-.specops}"
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
METRIC_SH="$PLUGIN/scripts/_internal/record-metric.sh"
# shellcheck source=/dev/null
source "$PLUGIN/scripts/dag/parse-dag.sh" 2>/dev/null || true

rp::rank() {
  case "$1" in lite) echo 1 ;; standard) echo 2 ;; strict) echo 3 ;; *) echo 0 ;; esac
}

rp::max_profile() {
  local a="$1" b="$2" ra rb
  ra=$(rp::rank "$a"); rb=$(rp::rank "$b")
  [ "$ra" -ge "$rb" ] && printf '%s' "$a" || printf '%s' "$b"
}

rp::collect_files() {
  local files base
  files=$(git diff HEAD --name-only --no-renames 2>/dev/null || true)
  [ -z "$files" ] && files=$(git diff --cached --name-only --no-renames 2>/dev/null || true)
  if [ -z "$files" ]; then
    base=$(git show-ref --verify --quiet refs/heads/main && echo main \
      || { git show-ref --verify --quiet refs/heads/master && echo master || true; })
    [ -n "$base" ] && files=$(git diff "$base"...HEAD --name-only --no-renames 2>/dev/null || true)
  fi
  # tasks outputs 보강
  if [ -n "${_RP_YAML:-}" ] && command -v python3 >/dev/null 2>&1; then
    local extra
    extra=$(SPECOPS_DAG_YAML="$_RP_YAML" python3 -c '
import os, sys
try:
  import yaml
except Exception:
  sys.exit(0)
doc = yaml.safe_load(os.environ.get("SPECOPS_DAG_YAML", "")) or {}
for t in doc.get("tasks") or []:
  if not isinstance(t, dict):
    continue
  for o in (t.get("outputs") or []):
    if isinstance(o, str) and o:
      print(o)
' 2>/dev/null || true)
    [ -n "$extra" ] && files=$(printf '%s\n%s\n' "$files" "$extra")
  fi
  printf '%s\n' "$files" | awk 'NF' | sort -u
}

rp::docs_only() {
  local f
  [ -z "$1" ] && return 1
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      *.md|*.txt|*.rst|screens/*.html|.specops/*) ;;
      *) return 1 ;;
    esac
  done <<< "$1"
  return 0
}

rp::impl_file_count() {
  local f n=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      *.md|*.txt|*.rst|screens/*.html|.specops/*) ;;
      *test*|*spec*|*/__tests__/*) ;;
      *) n=$((n + 1)) ;;
    esac
  done <<< "$1"
  printf '%d' "$n"
}

rp::detect_strict_signals() {
  local corpus="$1" files="$2" signals="" 
  # keyword / path signals (라인수 무관)
  printf '%s\n%s\n' "$corpus" "$files" | grep -qiE \
    '(^|[^a-z])(auth|oauth|jwt|rbac|permission|credential|secret|\.env)([^a-z]|$)' \
    && signals="${signals} auth"
  printf '%s\n%s\n' "$corpus" "$files" | grep -qiE \
    '(migration|alembic|prisma/migrations|supabase/migrations|CREATE TABLE|ALTER TABLE|DROP TABLE|data-model\.md)' \
    && signals="${signals} db_migration"
  printf '%s\n%s\n' "$corpus" "$files" | grep -qiE \
    '(irreversible:\s*true|Delete:|unlink\(|rm -rf|path\.join|filesystem|fs\.(unlink|rm))' \
    && signals="${signals} destructive_fs"
  printf '%s\n%s\n' "$corpus" "$files" | grep -qiE \
    '(payment|billing|pii|개인정보|주민등록|credit.?card)' \
    && signals="${signals} payment_pii"
  printf '%s\n%s\n' "$corpus" "$files" | grep -qiE \
    '(api-spec\.md|/api/|openapi|public api|엔드포인트)' \
    && signals="${signals} public_api"
  printf '%s\n%s\n' "$corpus" "$files" | grep -qiE \
    '(\.github/workflows|Dockerfile|terraform|kubernetes|k8s|helm|deploy)' \
    && signals="${signals} infra"
  printf '%s\n%s\n' "$corpus" "$files" | grep -qiE \
    '(subprocess|child_process|os\.system|exec\(|bash -c|Runtime\.exec)' \
    && signals="${signals} external_exec"
  # parallel batch
  if [ -n "${_RP_YAML:-}" ] && command -v dag::find_independent_batch >/dev/null 2>&1; then
    local batch
    batch=$(dag::find_independent_batch "$_RP_YAML" 2>/dev/null || true)
    [ -n "$batch" ] && signals="${signals} parallel_batch"
  fi
  # cross-service heuristic
  printf '%s\n%s\n' "$corpus" "$files" | grep -qiE \
    '(cross-service|microservice|message.?queue|sqs|kafka|external api)' \
    && signals="${signals} cross_service"

  printf '%s' "$signals" | xargs -n1 2>/dev/null | sort -u | xargs
}

rp::compute() {
  local fid="$1" floor="${2:-}"
  printf '%s' "$fid" | grep -qE '^[0-9]{8}-[a-z0-9-]+$' || {
    echo "risk-profile: invalid FID" >&2; return 1
  }
  case "$floor" in
    ""|standard|strict) ;;
    lite) echo "risk-profile: floor 하향(lite) 거부 — 상향만 허용" >&2; return 1 ;;
    *) echo "risk-profile: invalid floor: $floor" >&2; return 1 ;;
  esac

  local fid_dir="$SPECOPS/$fid"
  [ -d "$fid_dir" ] || { echo "risk-profile: FID dir missing" >&2; return 1; }
  [ ! -L "$SPECOPS" ] && [ ! -L "$fid_dir" ] || {
    echo "risk-profile: symlink 거부" >&2; return 1
  }

  local spec="$fid_dir/spec.md" tasks="$fid_dir/tasks.md"
  local corpus="" files
  [ -f "$spec" ] && corpus=$(cat "$spec")
  [ -f "$tasks" ] && corpus=$(printf '%s\n%s\n' "$corpus" "$(cat "$tasks")")

  _RP_YAML=""
  if [ -f "$tasks" ] && command -v dag::extract_yaml >/dev/null 2>&1; then
    _RP_YAML=$(dag::extract_yaml "$tasks" 2>/dev/null || true)
  fi

  files=$(rp::collect_files)
  local strict_signals docs_only=false impl_files parallel_batch=false irreversible=false
  strict_signals=$(rp::detect_strict_signals "$corpus" "$files")
  printf '%s' "$strict_signals" | grep -qw parallel_batch && parallel_batch=true
  if printf '%s' "$corpus" | grep -qiE 'irreversible:[[:space:]]*true'; then
    irreversible=true
    printf '%s' "$strict_signals" | grep -qw destructive_fs \
      || strict_signals=$(printf '%s\ndestructive_fs\n' "$strict_signals" | awk 'NF' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//')
  fi

  if rp::docs_only "$files"; then docs_only=true; else docs_only=false; fi
  impl_files=$(rp::impl_file_count "$files")

  local computed=standard
  if [ -n "$strict_signals" ]; then
    computed=strict
  elif [ "$docs_only" = true ] && [ "$impl_files" -le 1 ]; then
    computed=lite
  else
    computed=standard
  fi

  # §유형=trivial 단독으로는 lite 강제 금지 (이미 computed 유지)

  local effective="$computed"
  if [ -n "$floor" ]; then
    effective=$(rp::max_profile "$computed" "$floor")
  fi
  # ENV floor
  if [ -n "${SPECOPS_RISK_PROFILE_FLOOR:-}" ]; then
    case "$SPECOPS_RISK_PROFILE_FLOOR" in
      standard|strict)
        effective=$(rp::max_profile "$effective" "$SPECOPS_RISK_PROFILE_FLOOR")
        ;;
    esac
  fi

  local lite_eligible=false
  [ "$computed" = "lite" ] && lite_eligible=true

  local ts signals_json dj pj ij lj
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  signals_json=$(printf '%s' "$strict_signals" | awk 'NF{printf "%s\"%s\"", (n++?",":""), $1}')
  [ "$docs_only" = true ] && dj=true || dj=false
  [ "$parallel_batch" = true ] && pj=true || pj=false
  [ "$irreversible" = true ] && ij=true || ij=false
  [ "$lite_eligible" = true ] && lj=true || lj=false

  mkdir -p "$fid_dir" || return 1
  local target="$fid_dir/risk-profile.json" tmp="$fid_dir/.risk-profile.$$.tmp"
  local allowed_json='[]'
  [ "$effective" = "lite" ] && allowed_json='["batch-review-skip"]'
  jq -n \
    --argjson schema_version 1 --arg fid "$fid" \
    --arg computed "$computed" --arg effective "$effective" \
    --arg floor "${floor:-}" --arg mode live \
    --argjson docs_only "$dj" --argjson impl_files "$impl_files" \
    --argjson parallel_batch "$pj" --argjson irreversible "$ij" \
    --argjson lite_eligible "$lj" \
    --argjson strict_signals "[$signals_json]" \
    --argjson reductions_allowed "$allowed_json" \
    --arg recorded_at "$ts" --arg runner "risk-profile.sh" \
    '{schema_version:$schema_version,fid:$fid,computed:$computed,effective:$effective,
      user_floor:(if $floor=="" then null else $floor end),
      mode:$mode,
      signals:{strict:$strict_signals,lite_eligible:$lite_eligible,docs_only:$docs_only,
               impl_files:$impl_files,parallel_batch:$parallel_batch,irreversible:$irreversible},
      sources:{spec:(".specops/"+$fid+"/spec.md"),
               tasks:(".specops/"+$fid+"/tasks.md"),diff_ref:"HEAD"},
      reductions_allowed:$reductions_allowed,reductions_applied:[],
      recorded_at:$recorded_at,runner:$runner}' > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$target"

  if [ -f "$METRIC_SH" ]; then
    bash "$METRIC_SH" --fid "$fid" --phase risk-profile --verdict PASS --finding-severity none 2>/dev/null || true
  fi

  printf 'RISK_PROFILE: computed=%s effective=%s mode=live\n' "$computed" "$effective"
  printf '%s\n' "$effective"

  # ── §lite × strict 승격 가드 (H1, 20260806) ────────────────────────────────
  # specifying-ko:122·131 의 `★ strict 승격 가드` 는 산문(모델의 키워드 판단)뿐이었다.
  # lite 는 clarify·plan 을 **이미 건너뛴 뒤** decompose 에 도달하므로, strict 가 뒤늦게
  # 드러나도 되돌릴 게이트가 없었다 — 잃어버린 clarify·plan 은 스스로 돌아오지 않는다.
  #
  # self-detect 인 이유: `--lite-guard` 류 플래그 설계면 플래그를 안 넘기는 것으로 우회된다.
  #   spec.md 의 `**§lite**: true`(specifying-ko Step 6 이 강제 기재)를 직접 읽는다.
  # 범위 한정: §lite 만. `§유형: trivial` 단독은 제외 — public_api 가 "엔드포인트" 한 단어에
  #   걸리므로 최빈 경로인 trivial 까지 묶으면 false-block 생성기가 된다.
  # 자동 해제: plan.md 가 생기면(=승격 완료) 가드 무발화 — 영구 차단 방지.
  # 주권 탈출구: env + **사유 병기 필수**(SPECOPS_GOVERNANCE_BYPASS 규약 동형).
  #   마커 파일이 아닌 env 인 이유 — 파일은 모델이 쓸 수 있어 자기발급 면제표가 된다.
  # 강도: rc=3 은 **기계 탐지**이지 하드 차단이 아니다 (emit-context.sh fail-fast 와 동급 —
  #   체인 레벨 강제). 판정 불가(spec.md 부재 등)는 fail-open.
  local _spec="$fid_dir/spec.md"
  if [ "$effective" = "strict" ] && [ -f "$_spec" ] \
     && grep -qE '^\*\*§lite\*\*:[[:space:]]*true' "$_spec" 2>/dev/null \
     && [ ! -f "$fid_dir/plan.md" ]; then
    if [ "${SPECOPS_LITE_STRICT_OVERRIDE:-}" = "1" ] && [ -n "${SPECOPS_LITE_STRICT_REASON:-}" ]; then
      [ -f "$METRIC_SH" ] && bash "$METRIC_SH" --fid "$fid" --phase lite-strict-override \
        --verdict WAIVED --finding-severity high 2>/dev/null || true
      printf 'LITE-STRICT-GUARD: override (사유 기록됨) — lite 유지\n' >&2
      return 0
    fi
    [ -f "$METRIC_SH" ] && bash "$METRIC_SH" --fid "$fid" --phase lite-strict-guard \
      --verdict FAIL --finding-severity high 2>/dev/null || true
    cat >&2 <<EOF
LITE-STRICT-GUARD: §lite FID 인데 위험 프로파일이 strict 입니다 (신호: ${strict_signals:-none}).
  lite 는 clarify·plan 을 이미 건너뛴 상태라 이대로 진행하면 고위험 변경이 설계 검토 없이 구현됩니다.

  승격(권장): specops-ko:clarifying-ko → specops-ko:planning-ko 수행 후 decomposing 재진입.
              plan.md 가 생기면 본 가드는 자동 해제됩니다.
  사용자 주권 우회(사유 병기 필수):
              SPECOPS_LITE_STRICT_OVERRIDE=1 SPECOPS_LITE_STRICT_REASON='<한 줄 사유>' <명령>
EOF
    return 3
  fi
  return 0
}

rp::show() {
  local fid="$1" state="$SPECOPS/$fid/risk-profile.json"
  [ -f "$state" ] || { echo "risk-profile: not recorded" >&2; return 1; }
  jq -r '"\(.effective) (computed=\(.computed), mode=\(.mode))"' "$state"
}

action="${1:-}"; fid="${2:-}"
case "$action" in
  compute)
    [ -n "$fid" ] || { echo "usage: $0 compute <FID> [--floor standard|strict]" >&2; exit 1; }
    shift 2
    floor=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --floor) floor="${2:-}"; shift 2 ;;
        *) echo "risk-profile: unknown option: $1" >&2; exit 1 ;;
      esac
    done
    rp::compute "$fid" "$floor"
    ;;
  show)
    [ -n "$fid" ] || { echo "usage: $0 show <FID>" >&2; exit 1; }
    rp::show "$fid"
    ;;
  *)
    echo "usage: $0 {compute <FID> [--floor …]|show <FID>}" >&2
    exit 1
    ;;
esac
