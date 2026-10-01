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

# mk_sub <envdir> — 서브에이전트 2개(aaa: meta 있음 / bbb: meta 없음) + 겹치는 다른 세션 파일 1개
mk_sub() {
  local d="$1" sd="$1/cfg/projects/-p/$SID/subagents"
  mkdir -p "$sd"
  { _line msg_a1 m2 40 2026-09-30T10:01:00.000Z; _line msg_a2 m2 60 2026-09-30T10:02:00.000Z; } > "$sd/agent-aaa.jsonl"
  printf '{"agentType":"general-purpose","model":"sonnet"}' > "$sd/agent-aaa.meta.json"
  { _line msg_b1 m3 5 2026-09-30T10:03:00.000Z; } > "$sd/agent-bbb.jsonl"
  echo '{}' > "$d/cfg/projects/-p/other-session.jsonl"
}

# T4.a 서브에이전트 레코드: agent/model/agent_model, 메인과 분리 (AC-3)
d=$(mk_env t4a); mk_core "$d"; mk_sub "$d"; run_meter "$d" >/dev/null
T=$(TOK "$d")
if jq -e 'select(.agent=="general-purpose:aaa") | .model=="m2" and .agent_model=="sonnet" and .output==100 and .messages==2' "$T" >/dev/null 2>&1 \
   && jq -e 'select(.agent=="unknown:bbb") | .model=="m3" and .agent_model=="unknown" and .output==5' "$T" >/dev/null 2>&1 \
   && jq -e 'select(.agent=="main") | .output==1018' "$T" >/dev/null 2>&1; then
  ok "T4.a 서브에이전트 별도 레코드·meta 누락 unknown·메인 불변"
else
  nope "T4.a" "rec=$(cat "$T" 2>/dev/null)"
fi

# T4.b main 레코드의 overlap_other_sessions (mtime 이 구간 안인 다른 세션 파일 1개 — "최근 M분" 근사, 최대 1분 오차)
if jq -e 'select(.agent=="main") | .overlap_other_sessions==1' "$T" >/dev/null 2>&1; then
  ok "T4.b overlap_other_sessions=1"
else
  nope "T4.b" "rec=$(jq -c 'select(.agent=="main")' "$T" 2>/dev/null)"
fi

# T5.a 같은 호출 2회 → 레코드 수 불변, 값 교체 (AC-4)
d=$(mk_env t5a); mk_core "$d"; mk_sub "$d"
run_meter "$d" >/dev/null; n1=$(/usr/bin/wc -l < "$(TOK "$d")" | tr -d ' ')
run_meter "$d" >/dev/null; n2=$(/usr/bin/wc -l < "$(TOK "$d")" | tr -d ' ')
if [ "$n1" = "$n2" ] && [ "$n1" -ge 3 ]; then ok "T5.a 멱등 upsert (줄 수 $n1 불변)"; else nope "T5.a" "n1=$n1 n2=$n2"; fi

# T5.b 키 집합 정확 일치 + 원문 필드 부재
T=$(TOK "$d")
base='agent,cache_read,cache_write,dedupe,fid,input,messages,model,output,schema_version,scope,session,ts,window_end,window_start'
# jq keys 는 코드포인트 정렬 — 기대값도 같은 규칙으로 정렬해 "집합" 일치만 본다(순서 무관)
_ksort() { jq -rn --arg w "$1" '$w | split(",") | sort | join(",")'; }
want_main=$(_ksort "$base,overlap_other_sessions,synthetic_excluded"); want_sub=$(_ksort "$base,agent_model")
got_main=$(jq -r 'select(.agent=="main")|keys|join(",")' "$T"); got_sub=$(jq -r 'select(.agent=="general-purpose:aaa")|keys|join(",")' "$T")
# 원문 필드 검사는 -s any — 줄별 -e 는 마지막 레코드의 판정만 종료 코드에 남는다
if [ -n "$want_main" ] && [ "$got_main" = "$want_main" ] && [ "$got_sub" = "$want_sub" ] \
   && jq -se 'length >= 3 and (any(.[]; has("prompt") or has("content") or has("text") or has("message")) | not)' "$T" >/dev/null 2>&1; then
  ok "T5.b 키 집합 정확 일치·원문 필드 없음"
else
  nope "T5.b" "main=$got_main sub=$got_sub"
fi

# T5.c --session 으로 다른 세션 추가 → 두 세션 레코드 공존, 첫 세션 보존
SID2=22222222-3333-4444-5555-666666666666
{ _line msg_X m9 77 2026-09-30T10:10:00.000Z; } > "$d/cfg/projects/-p/$SID2.jsonl"
run_meter "$d" --session "$SID2" >/dev/null
if jq -e --arg s "$SID" 'select(.session==$s and .agent=="main")' "$T" >/dev/null 2>&1 \
   && jq -e --arg s "$SID2" 'select(.session==$s and .agent=="main" and .output==77)' "$T" >/dev/null 2>&1; then
  ok "T5.c --session 두 세션 공존"
else
  nope "T5.c" "sessions=$(jq -r '.session' "$T" | sort -u | tr '\n' ' ')"
fi

# T5.d 같은 id 의 여러 줄에서 input·cache_read·cache_write 도 달라질 때 4필드 모두 id별 최댓값 (AC-1·AC-4)
#   msg_D: 최댓값이 가운데 줄 — 첫 줄(.[0])·마지막 줄(.[-1]) 채택 변이와 구분된다
#     (i1 cr90 cw40 o5) → (i3 cr120 cw60 o7) → (i2 cr100 cw50 o6)  ⇒ max i3 cr120 cw60 o7
#   msg_E: 1줄 (i4 cr10 cw5 o1) — id 간 합산
d=$(mk_env t5d)
{
  _line msg_D m1 5 2026-09-30T10:00:10.000Z 1 90  40
  _line msg_D m1 7 2026-09-30T10:00:10.300Z 3 120 60
  _line msg_D m1 6 2026-09-30T10:00:10.600Z 2 100 50
  _line msg_E m1 1 2026-09-30T10:00:11.000Z 4 10  5
} > "$d/cfg/projects/-p/$SID.jsonl"
run_meter "$d" >/dev/null
if jq -e 'select(.agent=="main") |
     .input==7 and .output==8 and .cache_read==130 and .cache_write==65 and .messages==2' "$(TOK "$d")" >/dev/null 2>&1; then
  ok "T5.d id별 4필드 모두 max(가운데 줄 최댓값) 합산"
else
  nope "T5.d" "rec=$(jq -c 'select(.agent=="main")' "$(TOK "$d")" 2>/dev/null)"
fi

# T5.e 구간 밖 mtime 의 다른 세션 파일은 overlap 에서 제외 (기준점 2026-09-30T10:00Z 이전 mtime)
d=$(mk_env t5e); mk_core "$d"; mk_sub "$d"
echo '{}' > "$d/cfg/projects/-p/other-old.jsonl"
touch -t 202609290000 "$d/cfg/projects/-p/other-old.jsonl"
run_meter "$d" >/dev/null
if jq -e 'select(.agent=="main") | .overlap_other_sessions==1' "$(TOK "$d")" >/dev/null 2>&1; then
  ok "T5.e 구간 밖 mtime 세션 파일 제외 (overlap 1 유지)"
else
  nope "T5.e" "rec=$(jq -c 'select(.agent=="main")' "$(TOK "$d")" 2>/dev/null)"
fi

_one() { jq -c 'select(.status=="unmeasured")|.reason' "$1" 2>/dev/null | tr -d '"'; }

# T6.a env 부재 → exit 0·unmeasured(no-session-id)·무출력 (AC-5)
d=$(mk_env t6a); mk_core "$d"
out=$( cd "$d/work" && env -u CLAUDE_CODE_SESSION_ID CLAUDE_CONFIG_DIR="$d/cfg" bash "$METER" "$FID" 2>&1 ); ec=$?
[ "$ec" -eq 0 ] && [ -z "$out" ] && [ "$(_one "$(TOK "$d")")" = "no-session-id" ] && ok "T6.a env 부재 → no-session-id" || nope "T6.a" "ec=$ec out='$out' rec=$(cat "$(TOK "$d")" 2>/dev/null)"

# T6.a2 같은 env 부재 호출 2회 → session "unknown" 레코드가 교체(1줄 유지) — _upsert 의 ${SID:-unknown}
( cd "$d/work" && env -u CLAUDE_CODE_SESSION_ID CLAUDE_CONFIG_DIR="$d/cfg" bash "$METER" "$FID" >/dev/null 2>&1 )
n=$(/usr/bin/wc -l < "$(TOK "$d")" 2>/dev/null | tr -d ' ')
[ "$n" = 1 ] && jq -e '.session=="unknown"' "$(TOK "$d")" >/dev/null 2>&1 && ok "T6.a2 unknown 세션 멱등 (1줄)" || nope "T6.a2" "n=$n rec=$(cat "$(TOK "$d")" 2>/dev/null)"

# T6.b transcript 부재 → transcript-not-found
d=$(mk_env t6b)
out=$(run_meter "$d"); ec=$?
[ "$ec" -eq 0 ] && [ -z "$out" ] && [ "$(_one "$(TOK "$d")")" = "transcript-not-found" ] && ok "T6.b transcript 부재" || nope "T6.b" "ec=$ec out='$out' rec=$(cat "$(TOK "$d")" 2>/dev/null)"

# T6.c usage 없는 줄만 / T6.d 깨진 줄만 → no-messages-in-window
d=$(mk_env t6c); echo '{"type":"assistant","timestamp":"2026-09-30T10:01:00.000Z","message":{"id":"msg_n","model":"m1"}}' > "$d/cfg/projects/-p/$SID.jsonl"
out=$(run_meter "$d"); ec=$?
[ "$ec" -eq 0 ] && [ -z "$out" ] && [ "$(_one "$(TOK "$d")")" = "no-messages-in-window" ] && ok "T6.c usage 없음" || nope "T6.c" "rec=$(cat "$(TOK "$d")" 2>/dev/null)"
d=$(mk_env t6d); printf 'broken{\n{also broken\n' > "$d/cfg/projects/-p/$SID.jsonl"
out=$(run_meter "$d"); ec=$?
[ "$ec" -eq 0 ] && [ -z "$out" ] && [ "$(_one "$(TOK "$d")")" = "no-messages-in-window" ] && ok "T6.d 깨진 JSON" || nope "T6.d" "rec=$(cat "$(TOK "$d")" 2>/dev/null)"

# T6.e jq 부재(PATH 비움, /bin/bash 절대경로) → exit 0·무기록·무출력
d=$(mk_env t6e); mk_core "$d"; mkdir -p "$TD/empty"
out=$( cd "$d/work" && env PATH="$TD/empty" CLAUDE_CONFIG_DIR="$d/cfg" CLAUDE_CODE_SESSION_ID="$SID" /bin/bash "$METER" "$FID" 2>&1 ); ec=$?
[ "$ec" -eq 0 ] && [ -z "$out" ] && [ ! -e "$(TOK "$d")" ] && ok "T6.e jq 부재 → 무기록·무출력" || nope "T6.e" "ec=$ec out='$out'"

# T6.f(NFR-3) tokens.jsonl 이 symlink → 링크 유지·원본(victim) 불변·exit 0·무출력
#   victim 은 유효 JSON — 비 JSON 이면 검사 줄을 지워도 _upsert 의 jq 실패로 mv 전에 빠져 판별력이 없다
d=$(mk_env t6f); mk_core "$d"; echo '{"session":"victim"}' > "$TD/victim"; ln -s "$TD/victim" "$(TOK "$d")"
out=$(run_meter "$d"); ec=$?
[ "$ec" -eq 0 ] && [ -z "$out" ] && [ -L "$(TOK "$d")" ] && [ "$(cat "$TD/victim")" = '{"session":"victim"}' ] && ok "T6.f symlink 거부" || nope "T6.f" "ec=$ec link=$([ -L "$(TOK "$d")" ] && echo y || echo n) victim=$(cat "$TD/victim")"

# T6.g(NFR-3) FID 경로 이탈 → exit 2·무기록
d=$(mk_env t6g)
( cd "$d/work" && bash "$METER" '../x' >/dev/null 2>&1 ); ec=$?
[ "$ec" -eq 2 ] && ok "T6.g FID 검증 exit 2" || nope "T6.g" "ec=$ec"

# T6.h(AC-8 테스트 격리) fid-start 없음 + 읽을 수 없는 CLAUDE_CONFIG_DIR → 에러·출력·기록 없음·3초 이내
d=$(mk_env t6h); : > "$d/work/.specops/$FID/metrics.jsonl"; mkdir -p "$TD/noread"; chmod 000 "$TD/noread"
t0=$(date +%s)
out=$( cd "$d/work" && HOME=/nonexistent CLAUDE_CONFIG_DIR="$TD/noread" CLAUDE_CODE_SESSION_ID="$SID" bash "$METER" "$FID" 2>&1 ); ec=$?
t1=$(date +%s); chmod 755 "$TD/noread"
[ "$ec" -eq 0 ] && [ -z "$out" ] && [ ! -e "$(TOK "$d")" ] && [ $((t1 - t0)) -le 3 ] && ok "T6.h fid-start 부재 → 접근 시도 없음(출력·에러·기록 0)" || nope "T6.h" "ec=$ec out='$out' dt=$((t1 - t0)) rec=$(cat "$(TOK "$d")" 2>/dev/null)"

# T6.i 기준점 파싱 실패(--since 비 ISO) → exit 0·무출력·unmeasured(bad-baseline)
d=$(mk_env t6i); mk_core "$d"
out=$(run_meter "$d" --since not-a-date); ec=$?
[ "$ec" -eq 0 ] && [ -z "$out" ] && [ "$(_one "$(TOK "$d")")" = "bad-baseline" ] && ok "T6.i 기준점 파싱 실패 → bad-baseline" || nope "T6.i" "ec=$ec out='$out' rec=$(cat "$(TOK "$d")" 2>/dev/null)"

# report 는 transcript 를 읽지 않는다 — config·HOME 을 없는 경로로 고정해 실행(조회 전용)
RUN_REPORT() { ( cd "$1/work" && HOME=/nonexistent CLAUDE_CONFIG_DIR=/nonexistent CLAUDE_CODE_SESSION_ID="$SID" bash "$METER" --report "${@:2}" 2>&1 ); }
_has() { printf '%s\n' "$1" | /usr/bin/grep -q -- "$2"; }
_hasx() { printf '%s\n' "$1" | /usr/bin/grep -qxF -- "$2"; }

# T7.a 단일 FID report: 헤더·행·TOTAL·한계 문구 (AC-9)
#   main(2msg i4 o1018 cr300 cw70) + aaa(2msg i4 o100 cr200 cw100) + bbb(1msg i2 o5 cr100 cw50)
#   ⇒ TOTAL 5 10 1123 600 220 — 한 열이라도 합산에서 빠지면 이 줄이 달라진다
d=$(mk_env t7a); mk_core "$d"; mk_sub "$d"; run_meter "$d" >/dev/null
out=$(RUN_REPORT "$d" "$FID"); ec=$?
rows=$(printf '%s\n' "$out" | /usr/bin/grep -c '^11111111  ')
if [ "$ec" -eq 0 ] && [ "$rows" = 3 ] \
   && _hasx "$out" 'SESSION  AGENT  MODEL  MESSAGES  INPUT  OUTPUT  CACHE_READ  CACHE_WRITE' \
   && _hasx "$out" '11111111  main  m1  2  4  1018  300  70' \
   && _hasx "$out" '11111111  general-purpose:aaa  m2  2  4  100  200  100' \
   && _hasx "$out" '11111111  unknown:bbb  m3  1  2  5  100  50' \
   && _hasx "$out" 'TOTAL  -  -  5  10  1123  600  220' \
   && _has "$out" '^※ 중복 제거: message.id 별 최댓값' \
   && _has "$out" '^※ advisor .*미포함' \
   && _hasx "$out" '※ 포함 세션: 11111111' \
   && _has "$out" '^※ 구간과 겹치는 다른 세션 1개 미포함'; then
  ok "T7.a 단일 FID report 구성(합계 표·중복 제거·advisor·포함 세션·겹침)"
else
  nope "T7.a" "ec=$ec rows=$rows out=$out"
fi

# T7.b FID 생략 → 헤더 없이 FID당 정확히 1줄, unmeasured 는 사유 표기, exit 0 (AC-11)
d2=$(mk_env t7b); FID2=20261001-other; mkdir -p "$d2/work/.specops/$FID2"
cp "$d/work/.specops/$FID/tokens.jsonl" "$d2/work/.specops/$FID/tokens.jsonl"
jq -nc --arg fid "$FID2" '{schema_version:1,ts:"2026-10-01T00:00:00Z",fid:$fid,session:"x",status:"unmeasured",reason:"no-messages-in-window"}' > "$d2/work/.specops/$FID2/tokens.jsonl"
out=$(RUN_REPORT "$d2"); ec=$?; n=$(printf '%s\n' "$out" | /usr/bin/wc -l | tr -d ' ')
if [ "$ec" -eq 0 ] && [ "$n" = 2 ] \
   && _hasx "$out" "$FID2  측정 안 됨 (no-messages-in-window)" \
   && _hasx "$out" "$FID  input=10 output=1123 cache_read=600 cache_write=220 sessions=1"; then
  ok "T7.b FID 생략 → FID당 1줄(합계 / 측정 안 됨 (사유))"
else
  nope "T7.b" "ec=$ec n=$n out=$out"
fi

# T7.c 기록 없는 FID → '측정 안 됨 (기록 없음)' (0 이 아님), exit 0
d3=$(mk_env t7c); out=$(RUN_REPORT "$d3" "$FID"); ec=$?
[ "$ec" -eq 0 ] && _hasx "$out" "$FID  측정 안 됨 (기록 없음)" && ! _has "$out" 'TOTAL' \
  && ok "T7.c 기록 없음 표기" || nope "T7.c" "ec=$ec out=$out"

# T7.d 다중 세션(--session) + 다중 서브에이전트 → TOTAL·포함 세션·FID 생략 요약이 두 세션을 합산
#   T7.a 값 + SID2 main(1msg i2 o77 cr100 cw50) ⇒ TOTAL 6 12 1200 700 270 · sessions=2
#   (겹침 수는 단언하지 않는다 — 두 번째 세션 레코드는 이미 포함된 첫 세션 파일도 세므로)
d4=$(mk_env t7d); mk_core "$d4"; mk_sub "$d4"; run_meter "$d4" >/dev/null
{ _line msg_X m9 77 2026-09-30T10:10:00.000Z; } > "$d4/cfg/projects/-p/$SID2.jsonl"
run_meter "$d4" --session "$SID2" >/dev/null
out=$(RUN_REPORT "$d4" "$FID"); sum=$(RUN_REPORT "$d4")
if _hasx "$out" 'TOTAL  -  -  6  12  1200  700  270' \
   && _hasx "$out" '22222222  main  m9  1  2  77  100  50' \
   && _hasx "$out" '※ 포함 세션: 11111111,22222222' \
   && [ "$sum" = "$FID  input=12 output=1200 cache_read=700 cache_write=270 sessions=2" ]; then
  ok "T7.d 다중 세션·서브에이전트 TOTAL·요약 합산"
else
  nope "T7.d" "out=$out sum=$sum"
fi

# T7.e report 는 조회 전용 — transcript 를 열지 않고(config 없는 경로) tokens.jsonl 도 바꾸지 않는다
cp "$(TOK "$d")" "$TD/t7e.before"
out=$(RUN_REPORT "$d" "$FID"); ec=$?
if [ "$ec" -eq 0 ] && cmp -s "$TD/t7e.before" "$(TOK "$d")" \
   && _hasx "$out" 'TOTAL  -  -  5  10  1123  600  220' && ! _has "$out" '측정 안 됨'; then
  ok "T7.e report 읽기 전용(transcript 미접근·기록 불변)"
else
  nope "T7.e" "ec=$ec out=$out rec=$(cat "$(TOK "$d")" 2>/dev/null)"
fi

# ── T8 verify 러너 배선 (AC-6·AC-13) ─────────────────────────────────────────
FIDW=20260101-wiring   # 도입 cutoff 이전 날짜 — 신규 게이트(intent 등)가 fixture 를 막지 않게
mk_plugin() {
  local p="$TD/plugin"; rm -rf "$p"; mkdir -p "$p/scripts"
  cp -R "$PLUGIN/scripts/_internal" "$p/scripts/_internal"
  cp -R "$PLUGIN/scripts/dag" "$p/scripts/dag"   # extract-test-commands.sh 가 ../dag/parse-dag.sh 를 source
  echo "$p"
}
# mk_vwork <name> <cmd-script> [nofidstart] — tasks.md 에 해당 dummy 한 줄, fid-start(compact) 기록
mk_vwork() {
  local w="$TD/$1"; rm -rf "$w"; mkdir -p "$w/.specops/$FIDW" "$w/scripts/tests"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$w/scripts/tests/dummy-pass.sh"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$w/scripts/tests/dummy-fail.sh"
  printf -- '- [ ] **스텝 4**: 실행: `bash scripts/tests/%s`\n' "$2" > "$w/.specops/$FIDW/tasks.md"
  if [ "${3:-}" = nofidstart ]; then
    jq -nc '{phase:"risk-profile",ts:"2026-09-30T10:00:00Z"}' > "$w/.specops/$FIDW/metrics.jsonl"
  else
    jq -nc '{phase:"fid-start",ts:"2026-09-30T10:00:00Z"}' > "$w/.specops/$FIDW/metrics.jsonl"
  fi
  echo "$w"
}
# mk_stub <marker> <tail-cmd> — meter 자리를 대체: marker touch + stdout·stderr 에 'meter-stub' 출력 후 <tail-cmd>
#   (출력이 있어야 배선의 >/dev/null 2>&1 이 빠졌을 때 누출이 보인다 — 무출력 stub 은 그 변이를 못 잡는다)
mk_stub() {
  printf '#!/usr/bin/env bash\ntouch "%s/%s"\necho meter-stub-out\necho meter-stub-err >&2\n%s\n' \
    "$TD" "$1" "$2" > "$P/scripts/_internal/meter-tokens.sh"
}

# T8.a 정적 배선: bounded_run 5 + fid-start 가드 (AC-6)
RV="$PLUGIN/scripts/_internal/run-verification.sh"
if /usr/bin/grep -q 'bounded_run 5 bash "\$METER_SH"' "$RV" && /usr/bin/grep -q '"phase":"fid-start"' "$RV"; then
  ok "T8.a 배선 문자열(bounded_run 5·fid-start 가드)"; else nope "T8.a" "미배선"; fi

# T8.b meter 를 sleep stub 으로 교체 — 호출됐는지(marker)와 5초 상한·verdict·stamp 불변·출력 무누출 (AC-13·AC-6)
P=$(mk_plugin)
mk_stub meter-ran 'sleep 30'
W=$(mk_vwork vw1 dummy-pass.sh); rm -f "$TD/meter-ran"
t0=$(date +%s); out=$( cd "$W" && bash "$P/scripts/_internal/run-verification.sh" "$FIDW" 2>"$TD/vw1.err" ); ec=$?; t1=$(date +%s)
if [ -e "$TD/meter-ran" ] && [ "$ec" -eq 0 ] && [ $((t1 - t0)) -lt 12 ] \
   && [ "$(printf '%s\n' "$out" | tail -1)" = "VERIFY: PASS" ] \
   && ! printf '%s\n' "$out" | /usr/bin/grep -qiE 'meter|Terminated' \
   && ! /usr/bin/grep -qiE 'meter|Terminated' "$TD/vw1.err" \
   && [ "$(/usr/bin/grep -c 'RUN-VERIFICATION-RESULT: PASS' "$W/.specops/$FIDW/evidence.md")" = 1 ]; then
  ok "T8.b meter 호출됨·5초 상한 후 VERIFY: PASS·rc 0·PASS stamp·meter 출력 없음"
else
  nope "T8.b" "ran=$([ -e "$TD/meter-ran" ] && echo y || echo n) ec=$ec dt=$((t1 - t0)) out='$out' err=$(/usr/bin/grep -iE 'meter|Terminated' "$TD/vw1.err")"
fi

# T8.c meter 가 exit 1 이어도 PASS 경로 불변
mk_stub meter-ran2 'exit 1'
W=$(mk_vwork vw2 dummy-pass.sh); rm -f "$TD/meter-ran2"
out=$( cd "$W" && bash "$P/scripts/_internal/run-verification.sh" "$FIDW" 2>/dev/null ); ec=$?
[ -e "$TD/meter-ran2" ] && [ "$ec" -eq 0 ] && [ "$(printf '%s\n' "$out" | tail -1)" = "VERIFY: PASS" ] \
  && ok "T8.c meter exit 1 → verdict 불변" || nope "T8.c" "ec=$ec out='$out'"

# T8.d verify FAIL 경로: rc 1·stderr VERIFY: FAIL·evidence stamp 불변·출력 무누출 (AC-6)
W=$(mk_vwork vw3 dummy-fail.sh); rm -f "$TD/meter-ran2"
( cd "$W" && bash "$P/scripts/_internal/run-verification.sh" "$FIDW" >"$TD/vw3.out" 2>"$TD/vw3.err" ); ec=$?
if [ "$ec" -eq 1 ] && /usr/bin/grep -q 'VERIFY: FAIL' "$TD/vw3.err" \
   && /usr/bin/grep -q 'RUN-VERIFICATION-RESULT: FAIL' "$W/.specops/$FIDW/evidence.md" \
   && [ -e "$TD/meter-ran2" ] && ! /usr/bin/grep -qiE 'meter|Terminated' "$TD/vw3.err" "$TD/vw3.out"; then
  ok "T8.d FAIL 경로 불변(rc 1·stderr·stamp)·meter 호출됨"
else
  nope "T8.d" "ec=$ec err=$(head -3 "$TD/vw3.err") leak=$(/usr/bin/grep -iE 'meter|Terminated' "$TD/vw3.err" "$TD/vw3.out")"
fi

# T8.e fid-start 가드: metrics.jsonl 에 fid-start 가 없는 FID(=기존 스위트 fixture)는 meter 호출 자체가 없다 (AC-6)
W=$(mk_vwork vw4 dummy-pass.sh nofidstart); rm -f "$TD/meter-ran2"
out=$( cd "$W" && bash "$P/scripts/_internal/run-verification.sh" "$FIDW" 2>/dev/null ); ec=$?
if [ ! -e "$TD/meter-ran2" ] && [ "$ec" -eq 0 ] && [ "$(printf '%s\n' "$out" | tail -1)" = "VERIFY: PASS" ]; then
  ok "T8.e fid-start 부재 FID → meter 비호출·verdict 불변"
else
  nope "T8.e" "ran=$([ -e "$TD/meter-ran2" ] && echo y || echo n) ec=$ec out='$out'"
fi

finish
