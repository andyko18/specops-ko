#!/usr/bin/env bash
# 비용·수율 메타데이터 JSONL 기록기. 프롬프트·응답 원문을 받는 옵션은 의도적으로 제공하지 않는다.
# Usage: record-metric.sh --fid <FID> --phase <phase> [schema options]
set -u

SPECOPS="${SPECOPS_ROOT:-.specops}"
fid=""; task=""; phase=""; model=""
input_tokens=null; output_tokens=null; cache_read_tokens=null; cache_write_tokens=null
wall_ms=null; retry_count=0; timeout=false; fallback=false
verdict=""; finding_severity=""; fixed=null

need_value() {
  [ "$#" -ge 2 ] && [ -n "${2:-}" ] || { echo "record-metric: $1 값 필요" >&2; exit 1; }
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --fid) need_value "$@"; fid="$2"; shift 2 ;;
    --task) need_value "$@"; task="$2"; shift 2 ;;
    --phase) need_value "$@"; phase="$2"; shift 2 ;;
    --model) need_value "$@"; model="$2"; shift 2 ;;
    --input-tokens) need_value "$@"; input_tokens="$2"; shift 2 ;;
    --output-tokens) need_value "$@"; output_tokens="$2"; shift 2 ;;
    --cache-read-tokens) need_value "$@"; cache_read_tokens="$2"; shift 2 ;;
    --cache-write-tokens) need_value "$@"; cache_write_tokens="$2"; shift 2 ;;
    --wall-ms) need_value "$@"; wall_ms="$2"; shift 2 ;;
    --retry-count) need_value "$@"; retry_count="$2"; shift 2 ;;
    --timeout) need_value "$@"; timeout="$2"; shift 2 ;;
    --fallback) need_value "$@"; fallback="$2"; shift 2 ;;
    --verdict) need_value "$@"; verdict="$2"; shift 2 ;;
    --finding-severity) need_value "$@"; finding_severity="$2"; shift 2 ;;
    --fixed) need_value "$@"; fixed="$2"; shift 2 ;;
    *) echo "record-metric: unknown option: $1" >&2; exit 1 ;;
  esac
done

printf '%s' "$fid" | grep -qE '^[0-9]{8}-[a-z0-9-]+$' || { echo "record-metric: invalid FID" >&2; exit 1; }
printf '%s' "$phase" | grep -qE '^[a-z0-9][a-z0-9_-]*$' || { echo "record-metric: invalid phase" >&2; exit 1; }
# task/model은 식별자만 허용 — 공백·개행 등 자유 텍스트(비밀 원문) 유입 경로를 스키마에서 닫는다.
if [ -n "$task" ]; then
  printf '%s' "$task" | grep -qE '^[A-Za-z0-9][A-Za-z0-9._-]{0,39}$' \
    || { echo "record-metric: invalid task id" >&2; exit 1; }
fi
if [ -n "$model" ]; then
  printf '%s' "$model" | grep -qE '^[A-Za-z0-9][A-Za-z0-9._/@+-]{0,119}$' \
    || { echo "record-metric: invalid model id" >&2; exit 1; }
fi

for n in "$input_tokens" "$output_tokens" "$cache_read_tokens" "$cache_write_tokens" "$wall_ms"; do
  [ "$n" = "null" ] || printf '%s' "$n" | grep -qE '^[0-9]+$' || { echo "record-metric: numeric value required" >&2; exit 1; }
done
printf '%s' "$retry_count" | grep -qE '^[0-9]+$' || { echo "record-metric: invalid retry-count" >&2; exit 1; }
case "$timeout" in true|false) ;; *) echo "record-metric: timeout must be true|false" >&2; exit 1 ;; esac
case "$fallback" in true|false) ;; *) echo "record-metric: fallback must be true|false" >&2; exit 1 ;; esac
case "$fixed" in true|false|null) ;; *) echo "record-metric: fixed must be true|false" >&2; exit 1 ;; esac
case "$verdict" in ""|NOT_RUN|PASS|PARTIAL|FAIL|WAIVED|STALE) ;; *) echo "record-metric: invalid verdict" >&2; exit 1 ;; esac
case "$finding_severity" in ""|none|low|medium|high|critical) ;; *) echo "record-metric: invalid severity" >&2; exit 1 ;; esac

[ ! -L "$SPECOPS" ] || { echo "record-metric: $SPECOPS symlink 거부" >&2; exit 1; }
[ ! -L "$SPECOPS/$fid" ] || { echo "record-metric: FID symlink 거부" >&2; exit 1; }
mkdir -p "$SPECOPS/$fid" || exit 1
target="$SPECOPS/$fid/metrics.jsonl"
[ ! -L "$target" ] || { echo "record-metric: metrics file symlink 거부" >&2; exit 1; }

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
jq -nc \
  --argjson schema_version 1 --arg ts "$ts" --arg fid "$fid" \
  --arg task "$task" --arg phase "$phase" --arg model "$model" \
  --argjson input "$input_tokens" --argjson output "$output_tokens" \
  --argjson cache_read "$cache_read_tokens" --argjson cache_write "$cache_write_tokens" \
  --argjson wall_ms "$wall_ms" --argjson retry_count "$retry_count" \
  --argjson timeout "$timeout" --argjson fallback "$fallback" \
  --arg verdict "$verdict" --arg severity "$finding_severity" --argjson fixed "$fixed" \
  '{schema_version:$schema_version,ts:$ts,fid:$fid,
    task:(if $task=="" then null else $task end),phase:$phase,
    model:(if $model=="" then null else $model end),
    tokens:{input:$input,output:$output,cache_read:$cache_read,cache_write:$cache_write},
    wall_ms:$wall_ms,retry_count:$retry_count,timeout:$timeout,fallback:$fallback,
    verdict:(if $verdict=="" then null else $verdict end),
    finding_severity:(if $severity=="" then null else $severity end),fixed:$fixed}' >> "$target"
