#!/usr/bin/env bash
# meter-tokens.sh — FID 20261001-token-usage-metering (관측 전용 · fail-open)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
METER="$PLUGIN/scripts/_internal/meter-tokens.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq 필요"; exit 0; }

TD=$(mktemp -d) || exit 1
trap 'rm -rf "$TD"' EXIT
SID=11111111-2222-3333-4444-555555555555
FID=20261001-demo

# 합성 transcript 줄: _line <id> <model> <output> <ts> [input] [cache_read] [cache_write]
_line() {
  jq -nc --arg id "$1" --arg m "$2" --argjson o "$3" --arg ts "$4" \
    --argjson i "${5:-2}" --argjson cr "${6:-100}" --argjson cw "${7:-50}" \
    '{type:"assistant",timestamp:$ts,message:{id:$id,model:$m,usage:{input_tokens:$i,output_tokens:$o,cache_read_input_tokens:$cr,cache_creation_input_tokens:$cw}}}'
}
# fixture 환경: $TD/<name>/{work/.specops/$FID/metrics.jsonl(compact, fid-start 10:00:00Z), cfg/projects/-p/}
mk_env() {
  local d="$TD/$1"; rm -rf "$d"
  mkdir -p "$d/work/.specops/$FID" "$d/cfg/projects/-p"
  jq -nc --arg fid "$FID" '{schema_version:2,ts:"2026-09-30T10:00:00Z",fid:$fid,phase:"fid-start"}' \
    > "$d/work/.specops/$FID/metrics.jsonl"
  echo "$d"
}
# run_meter <envdir> [meter 인자...] — env 주입, stdout+stderr 합쳐 출력, rc 보존
run_meter() {
  local d="$1"; shift
  ( cd "$d/work" && CLAUDE_CONFIG_DIR="$d/cfg" CLAUDE_CODE_SESSION_ID="$SID" bash "$METER" "$FID" "$@" 2>&1 )
}
TOK() { echo "$1/work/.specops/$FID/tokens.jsonl"; }

# T1.a fid-start 부재 → transcript 를 열지 않고 무기록·exit 0·출력 없음 (AC-8)
d=$(mk_env t1a); : > "$d/work/.specops/$FID/metrics.jsonl"
out=$( cd "$d/work" && HOME=/nonexistent CLAUDE_CONFIG_DIR=/nonexistent CLAUDE_CODE_SESSION_ID="$SID" bash "$METER" "$FID" 2>&1 ); ec=$?
if [ "$ec" -eq 0 ] && [ -z "$out" ] && [ ! -e "$(TOK "$d")" ]; then
  ok "T1.a fid-start 부재 → 무기록·exit 0·무출력"
else
  nope "T1.a" "ec=$ec out='$out'"
fi

# T1.b 잘못된 FID → exit 2·tokens.jsonl 부재
d=$(mk_env t1b)
( cd "$d/work" && bash "$METER" "BAD" >/dev/null 2>&1 ); ec=$?
if [ "$ec" -eq 2 ] && [ ! -e "$(TOK "$d")" ]; then ok "T1.b 잘못된 FID → exit 2"; else nope "T1.b" "ec=$ec"; fi

# T1.c FID 인자 없음 → exit 2
d=$(mk_env t1c)
( cd "$d/work" && bash "$METER" >/dev/null 2>&1 ); ec=$?
[ "$ec" -eq 2 ] && ok "T1.c FID 인자 없음 → exit 2" || nope "T1.c" "ec=$ec"

finish
