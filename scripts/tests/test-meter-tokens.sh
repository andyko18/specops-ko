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

# mk_core <envdir> — 핵심 fixture: A(8,8,8,1008 · cr100 cw50) + B(10 · cr200 cw20) + synthetic 2줄 + 깨진 줄
mk_core() {
  local d="$1" f="$1/cfg/projects/-p/$SID.jsonl"
  {
    _line msg_A m1 8    2026-09-30T10:00:05.123Z 2 100 50
    _line msg_A m1 8    2026-09-30T10:00:05.200Z 2 100 50
    _line msg_A m1 8    2026-09-30T10:00:05.900Z 2 100 50
    _line msg_A m1 1008 2026-09-30T10:00:06.000Z 2 100 50
    _line msg_B m1 10   2026-09-30T10:00:07.000Z 2 200 20
    _line msg_S '<synthetic>' 9999 2026-09-30T10:00:08.000Z 2 100 50
    _line msg_S '<synthetic>' 9999 2026-09-30T10:00:08.500Z 2 100 50
    echo 'broken{'
  } > "$f"
}

# T2.a id별 4필드 최댓값 합산 + synthetic 제외(건수만) (AC-1)
d=$(mk_env t2a); mk_core "$d"
out=$(run_meter "$d"); ec=$?
if [ "$ec" -eq 0 ] && jq -e 'select(.agent=="main") |
     .output==1018 and .input==4 and .cache_read==300 and .cache_write==70 and .messages==2
     and .synthetic_excluded==1 and .dedupe=="max-per-message-id" and .model=="m1"' "$(TOK "$d")" >/dev/null 2>&1; then
  ok "T2.a id별 max 합산 + synthetic 제외(건수 1)"
else
  nope "T2.a" "ec=$ec out='$out' rec=$(cat "$(TOK "$d")" 2>/dev/null)"
fi

# T2.b --transcript 직접 지정(env 없이)도 동일 합계
d=$(mk_env t2b); mk_core "$d"
( cd "$d/work" && env -u CLAUDE_CODE_SESSION_ID CLAUDE_CONFIG_DIR=/nonexistent bash "$METER" "$FID" --transcript "$d/cfg/projects/-p/$SID.jsonl" >/dev/null 2>&1 )
if jq -e 'select(.agent=="main") | .output==1018 and .messages==2' "$(TOK "$d")" >/dev/null 2>&1; then
  ok "T2.b --transcript 지정 동일 합계"
else
  nope "T2.b" "rec=$(cat "$(TOK "$d")" 2>/dev/null)"
fi

# mk_window <envdir> — 구간 fixture: P(1000·기준점 이전) S(7·같은 초) N(3) F(500·미래)
mk_window() {
  local f="$1/cfg/projects/-p/$SID.jsonl"
  {
    _line msg_P m1 1000 2026-09-30T09:59:59.900Z
    _line msg_S m1 7    2026-09-30T10:00:00.100Z
    _line msg_N m1 3    2026-09-30T10:05:00.000Z
    _line msg_F m1 500  2099-01-01T00:00:00.000Z
  } > "$f"
}

# T3.a 기준점 이전·미래 제외, 같은 초 포함 (AC-2)
d=$(mk_env t3a); mk_window "$d"; run_meter "$d" >/dev/null
if jq -e 'select(.agent=="main") | .messages==2 and .output==10 and .scope=="fid-window"' "$(TOK "$d")" >/dev/null 2>&1; then
  ok "T3.a 구간 경계(같은 초 포함·이전/미래 제외)"
else
  nope "T3.a" "rec=$(cat "$(TOK "$d")" 2>/dev/null)"
fi

# T3.b 구간 안 메시지 0건 → 0 레코드가 아니라 unmeasured 사유 레코드 (AC-10)
d=$(mk_env t3b)
{ _line msg_P m1 1000 2026-09-30T09:59:59.900Z; } > "$d/cfg/projects/-p/$SID.jsonl"
run_meter "$d" >/dev/null
if [ "$(/usr/bin/wc -l < "$(TOK "$d")" | tr -d ' ')" = 1 ] \
   && jq -e '.status=="unmeasured" and .reason=="no-messages-in-window" and (has("input")|not)' "$(TOK "$d")" >/dev/null 2>&1; then
  ok "T3.b 0건 → unmeasured(no-messages-in-window), 토큰 필드 없음"
else
  nope "T3.b" "rec=$(cat "$(TOK "$d")" 2>/dev/null)"
fi

# T3.c --since 수동 기준점 → scope since-manual (AC-12)
d=$(mk_env t3c); : > "$d/work/.specops/$FID/metrics.jsonl"; mk_window "$d"
run_meter "$d" --since 2026-09-30T10:00:00Z >/dev/null
if jq -e 'select(.agent=="main") | .scope=="since-manual" and .window_start=="2026-09-30T10:00:00Z" and .output==10' "$(TOK "$d")" >/dev/null 2>&1; then
  ok "T3.c --since → scope=since-manual"
else
  nope "T3.c" "rec=$(cat "$(TOK "$d")" 2>/dev/null)"
fi

finish
