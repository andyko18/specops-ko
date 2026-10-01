#!/usr/bin/env bash
# stage-timing.sh --split · transcript-turns.sh — 작업·사람·백그라운드 분리 계측 (fixture 만 사용 — 실제 ~/.claude 를 읽지 않는다, 토큰 0)
set -u
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq 필요"; exit 0; }
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ST="$PLUGIN/scripts/stage-timing.sh"
TT="$PLUGIN/scripts/_internal/transcript-turns.sh"
BASH_BIN=$(command -v bash)
SB=$(mktemp -d)
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/tmp"

ck() { if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS+1)); else echo "FAIL $1 — exp '$3' got '$2'"; FAIL=$((FAIL+1)); fi; }

# transcript fixture 파일을 만든다: mktr 경로 — 본문은 stdin. mtime 을 먼 미래로 고정해 원장 기간 필터(mtime ≥ 원장 최초 날짜)에 항상 걸리게 한다.
mktr() { mkdir -p "$(dirname "$1")" && cat > "$1" && touch -t 203001010000 "$1"; }
# 원장 fixture: ledger 이름 — 본문은 stdin. SPECOPS_ROOT 로 쓸 디렉토리를 만든다.
ledger() { mkdir -p "$SB/$1" && cat > "$SB/$1/session-progress.md"; }
# 실행: runs 이름 [옵션...] — TZ=UTC · 원장 $SB/이름 · 전역 OUT·ERR·RC. TMPDIR 은 전용 디렉토리(누출 검사용).
runs() {
  local nm="$1"; shift
  OUT=$(TZ="${TZV:-UTC}" TMPDIR="$SB/tmp" SPECOPS_ROOT="$SB/$nm" "$BASH_BIN" "$ST" "$@" 2>"$SB/err"); RC=$?
  ERR=$(cat "$SB/err")
}
# 표에서 단계 행의 "합계 … 작업 사람 백그라운드 기타" 를 뽑는다(열: 합계 비중 n 중앙값 p90 max 작업 사람 백그라운드 기타 단계)
row() { printf '%s\n' "$OUT" | grep -E " $1\$" | awk '{print $1, $7, $8, $9, $10}'; }
cnt() { printf '%s\n' "$OUT" | grep -c -- "$1"; }

# ── 공통 fixture: AC-3 transcript (10:01 H · 10:05 D 4분 · 10:09 N · 10:10 D 1분 · 10:13 H) ──
mktr "$SB/td1/s1.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-10-01T10:01:00.000Z","isMeta":false,"origin":{"kind":"human"},"message":{"role":"user","content":"BODY-A"}}
{"type":"assistant","timestamp":"2026-10-01T10:03:00.000Z","message":{"content":[{"type":"text","text":"BODY-B"}]}}
{"type":"system","subtype":"turn_duration","timestamp":"2026-10-01T10:05:00.000Z","durationMs":240000}
{"type":"user","timestamp":"2026-10-01T10:09:00.000Z","isMeta":false,"origin":{"kind":"task-notification"},"message":{"role":"user","content":"BODY-C"}}
{"type":"system","subtype":"turn_duration","timestamp":"2026-10-01T10:10:00.000Z","durationMs":60000}
{"type":"user","timestamp":"2026-10-01T10:13:00.000Z","isMeta":false,"origin":{"kind":"human"},"message":{"role":"user","content":"BODY-D"}}
EOF

# ══ AC-1: 헬퍼 추출·분류 ══
mktr "$SB/h1.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-10-01T10:00:30.000Z","isMeta":false,"origin":{"kind":"weird-kind"},"message":{"content":"x"}}
{"type":"system","subtype":"turn_duration","timestamp":"2026-10-01T10:00:20.000Z","durationMs":12345}
{"type":"user","timestamp":"2026-10-01T10:00:10.000Z","isMeta":false,"origin":{"kind":"human"},"message":{"content":"x"}}
{"type":"user","timestamp":"2026-10-01T10:00:11.000Z","isMeta":false,"message":{"content":"x"}}
{"type":"user","timestamp":"2026-10-01T10:00:12.000Z","isMeta":false,"origin":{"kind":"task-notification"},"message":{"content":"x"}}
{"type":"user","timestamp":"2026-10-01T10:00:13.000Z","isMeta":true,"origin":{"kind":"human"},"message":{"content":"x"}}
{"type":"user","timestamp":"2026-10-01T10:00:14.000Z","isMeta":false,"origin":{"kind":"human"},"message":{"content":[{"type":"tool_result","content":"x"}]}}
{"type":"user","timestamp":"2026-10-01T10:00:15.000Z","isMeta":false,"isSidechain":true,"origin":{"kind":"human"},"message":{"content":"x"}}
{"type":"user","isMeta":false,"origin":{"kind":"human"},"message":{"content":"x"}}
this line is not json
{"type":"system","subtype":"other","timestamp":"2026-10-01T10:00:16.000Z","durationMs":5}
{"type":"assistant","timestamp":"2026-10-01T10:00:17.000Z","message":{"content":"x"}}
{"type":"system","subtype":"turn_duration","timestamp":"2026-10-01T10:00:18.000Z"}
{"type":"system","subtype":"turn_duration","timestamp":"2026-10-01T10:00:19.000Z","durationMs":-7}
EOF
EXP1=$(printf '%s\n' "1790848810	H	0" "1790848811	U	0" "1790848812	N	0" "1790848818	D	0" "1790848819	D	0" "1790848820	D	12345" "1790848830	U	0")
OUT1=$(TZ=UTC "$BASH_BIN" "$TT" "$SB/h1.jsonl"); RC1=$?
ck "T1.a 허용 필드만으로 D·H·N·U 분류·시간순 정렬 · 제외 대상(isMeta·도구결과·사이드체인·시각 없음·불량 JSON·다른 subtype·assistant) 무출력 · rc=0" "$RC1|$OUT1" "0|$EXP1"
EXP2=$(printf '%s\n' "$EXP1" "0	F	0" "1790848860	H	0" "1790849100	D	240000" "1790849340	N	0" "1790849400	D	60000" "1790849580	H	0")
OUT2=$("$BASH_BIN" "$TT" "$SB/h1.jsonl" "$SB/td1/s1.jsonl")
ck "T1.b 두 파일: 파일마다 시간순 정렬 + 둘째 파일 앞에 F 경계 한 줄(파일 사이에만)" "$OUT2" "$EXP2"
OUT3=$("$BASH_BIN" "$TT" "$SB/td1/s1.jsonl"); ck "T1.c 파일 하나면 F 없음" "$(printf '%s\n' "$OUT3" | grep -c $'\tF\t')" "0"
"$BASH_BIN" "$TT" >/dev/null 2>&1; R_A=$?; "$BASH_BIN" "$TT" "$SB/없는파일.jsonl" >/dev/null 2>&1; R_B=$?; "$BASH_BIN" "$TT" --bogus "$SB/h1.jsonl" >/dev/null 2>&1; R_C=$?
ck "T1.d 인자 없음·없는 파일·알 수 없는 옵션 → rc=2" "$R_A|$R_B|$R_C" "2|2|2"
OUT_KST=$(TZ=Asia/Seoul "$BASH_BIN" "$TT" --local "$SB/td1/s1.jsonl" | head -1 | cut -f1); OUT_UTC=$(TZ=UTC "$BASH_BIN" "$TT" --local "$SB/td1/s1.jsonl" | head -1 | cut -f1)
dd() { awk -v a="$1" -v b="$2" 'BEGIN { printf "%d", a - b }'; }   # 빈 값이어도 산술 오류로 단언이 사라지지 않게 awk 로 뺀다
ck "T1.e --local 은 TZ 를 따른다(KST = UTC+9h)" "$(dd "$OUT_KST" "$OUT_UTC")" "32400"
mktr "$SB/tz.jsonl" <<'EOF'
{"type":"system","subtype":"turn_duration","timestamp":"2026-01-15T12:00:00.000Z","durationMs":1}
{"type":"system","subtype":"turn_duration","timestamp":"2026-07-15T12:00:00.000Z","durationMs":1}
EOF
TZLINES=$(TZ=America/New_York "$BASH_BIN" "$TT" --local "$SB/tz.jsonl" | cut -f1); W0=$(TZ=UTC "$BASH_BIN" "$TT" "$SB/tz.jsonl" | cut -f1)
ck "T1.f DST: 뉴욕 겨울 -5h · 여름 -4h" "$(dd "$(echo "$TZLINES" | sed -n 1p)" "$(echo "$W0" | sed -n 1p)")|$(dd "$(echo "$TZLINES" | sed -n 2p)" "$(echo "$W0" | sed -n 2p)")" "-18000|-14400"

# durationMs 상한: 7일(604800000)까지는 그대로, 초과·터무니없는 값은 0 — 깨진 큰 값이 구간 버킷 루프를 폭주시키지 않게
mktr "$SB/dur.jsonl" <<'EOF'
{"type":"system","subtype":"turn_duration","timestamp":"2026-10-01T10:00:01.000Z","durationMs":604800000}
{"type":"system","subtype":"turn_duration","timestamp":"2026-10-01T10:00:02.000Z","durationMs":604800001}
{"type":"system","subtype":"turn_duration","timestamp":"2026-10-01T10:00:03.000Z","durationMs":1000000000000000}
EOF
ck "T1.g durationMs 상한: 7일 경계는 유지 · 초과·1e15 는 0" "$("$BASH_BIN" "$TT" "$SB/dur.jsonl" | cut -f3 | tr '\n' ',')" "604800000,0,0,"

# ══ AC-2: 프라이버시 — 본문·키 값·불량 값 어디에도 카나리가 새지 않는다 ══
mktr "$SB/tdc/c1.jsonl" <<'EOF'
{"type":"user","timestamp":"2026-10-01T10:01:00.000Z","isMeta":false,"origin":{"kind":"human"},"message":{"role":"user","content":"CANARY-BODY"},"toolUseResult":"CANARY-TOOL","attachment":{"x":"CANARY-ATT"}}
{"type":"assistant","timestamp":"2026-10-01T10:03:00.000Z","message":{"content":[{"type":"text","text":"CANARY-ASSIST"},{"type":"tool_use","input":{"cmd":"CANARY-INPUT"}}]}}
{"type":"user","timestamp":"2026-10-01T10:04:00.000Z","isMeta":false,"message":{"content":[{"type":"tool_result","content":"CANARY-RESULT"}]}}
{"type":"system","subtype":"turn_duration","timestamp":"2026-10-01T10:05:00.000Z","durationMs":240000,"extra":"CANARY-EXTRA"}
{"type":"user","timestamp":"2026-10-01T10:09:00.000Z","isMeta":false,"origin":{"kind":"CANARY-KIND"},"message":{"content":"CANARY-BODY2"}}
{"type":"system","subtype":"CANARY-SUBTYPE","timestamp":"2026-10-01T10:10:00.000Z","durationMs":60000}
{"type":"user","timestamp":"CANARY-TS","isMeta":false,"origin":{"kind":"human"},"message":{"content":"CANARY-BODY3"}}
{"type":"user","timestamp":"2026-10-01T10:11:00.000Z","durationMs":"CANARY-DUR","isMeta":false,"origin":{"kind":"human"},"message":{"content":"x"}}
{"type":"system","subtype":"turn_duration","timestamp":"2026-10-01T10:12:00.000Z","durationMs":"CANARY-DURMS"}
{"CANARY-BROKEN": "json line without closing
EOF
ledger lc <<'EOF'
## 20261001-aaa · A

- 2026-10-01 10:15 /plan 완료 (x)
- 2026-10-01 10:00 /specify 완료 (x)
EOF
HOUT=$(TZ=UTC TMPDIR="$SB/tmp" "$BASH_BIN" "$TT" --local "$SB/tdc/c1.jsonl" 2>"$SB/herr"); HERR=$(cat "$SB/herr")
runs lc --split --transcript-dir "$SB/tdc"; SOUT="$OUT"; SERR="$ERR"
runs lc --split --transcript-dir "$SB/없는디렉토리"; EOUT="$OUT"; EERR="$ERR"
ck "T2.a 카나리가 헬퍼 stdout·stderr 에 0건" "$(printf '%s%s' "$HOUT" "$HERR" | grep -c CANARY)" "0"
ck "T2.b 카나리가 stage-timing stdout·stderr 에 0건(정상·오류 경로)" "$(printf '%s%s%s%s' "$SOUT" "$SERR" "$EOUT" "$EERR" | grep -c CANARY)" "0"
ck "T2.c 임시 디렉토리에 카나리 0건 · 임시 파일 잔존 0건" "$(grep -rl CANARY "$SB/tmp" 2>/dev/null | wc -l | tr -d ' ')|$(ls -A "$SB/tmp" | wc -l | tr -d ' ')" "0|0"
JQP=$(sed -n '/^# JQ-PROGRAM-BEGIN/,/^# JQ-PROGRAM-END/p' "$TT")
BADKEYS=$(printf '%s\n' "$JQP" | grep -oE '\.[A-Za-z_][A-Za-z0-9_]*' | sort -u | grep -vxE '\.(type|subtype|timestamp|durationMs|isMeta|isSidechain|origin|kind|message|content|cur|buf|out|key|value)' | tr '\n' ' ')
ck "T2.d 헬퍼 jq 프로그램은 허용 키 외를 참조하지 않는다(내부 상태 이름 제외)" "$BADKEYS" ""
ck "T2.e message.content 는 타입 검사로만 쓴다" "$(printf '%s\n' "$JQP" | grep -c 'message\.content')|$(printf '%s\n' "$JQP" | grep -c 'message\.content | type')" "1|1"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
