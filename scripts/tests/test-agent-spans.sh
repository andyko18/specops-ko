#!/usr/bin/env bash
# agent-spans.sh · stage-timing.sh --by-agent — 서브에이전트 대기의 역할별 분해 계측 (fixture 만 사용 — 실제 ~/.claude 를 읽지 않는다, 토큰 0)
set -u
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq 필요"; exit 0; }
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ST="$PLUGIN/scripts/stage-timing.sh"
AS="$PLUGIN/scripts/_internal/agent-spans.sh"
BASH_BIN=$(command -v bash)
# shellcheck disable=SC2034  # Part B(T7.c)에서 쓴다
REAL_JQ=$(command -v jq)
SB=$(mktemp -d)
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/tmp"

ck() { if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS+1)); else echo "FAIL $1 — exp '$3' got '$2'"; FAIL=$((FAIL+1)); fi; }

# 서브에이전트 fixture: mkag 폴더 ID META — 본문(jsonl)은 stdin. META 가 "-" 면 meta 파일이 없다. meta 는 끝 개행 없이 쓴다(실제 포맷).
mkag() { mkdir -p "$1" && cat > "$1/agent-$2.jsonl" && touch -t 203001010000 "$1/agent-$2.jsonl"; [ "$3" = "-" ] || printf '%s' "$3" > "$1/agent-$2.meta.json"; }
# 레코드 한 줄: rec HH:MM:SS [YYYY-MM-DD] (기본 2026-10-01 UTC)
rec() { printf '{"type":"user","timestamp":"%sT%s.000Z","message":{"content":"x"}}\n' "${2:-2026-10-01}" "$1"; }
# 구현자형·리뷰어형·탐색형 meta
META_IMPL='{"agentType":"specops-ko:implementer-ko","toolUseId":"toolu_a","spawnDepth":1}'
META_SPEC='{"agentType":"specops-ko:spec-reviewer-ko","toolUseId":"toolu_b","spawnDepth":1}'
META_NAMED='{"agentType":"iso-T1","spawnDepth":0}'
# transcript fixture(세션 파일): mktr 경로 — 본문은 stdin. mtime 을 먼 미래로 고정해 원장 기간 필터에 항상 걸리게 한다.
mktr() { mkdir -p "$(dirname "$1")" && cat > "$1" && touch -t 203001010000 "$1"; }
ledger() { mkdir -p "$SB/$1" && cat > "$SB/$1/session-progress.md"; }
# 실행: runs 원장이름 옵션... — TZ=UTC · 전역 OUT·ERR·RC. TMPDIR 은 전용 디렉토리(누출 검사용).
runs() {
  local nm="$1"; shift
  OUT=$(TZ="${TZV:-UTC}" TMPDIR="$SB/tmp" SPECOPS_ROOT="$SB/$nm" "$BASH_BIN" "$ST" "$@" 2>"$SB/err"); RC=$?
  # shellcheck disable=SC2034  # Part B 의 단언에서 쓴다
  ERR=$(cat "$SB/err")
}
cnt() { printf '%s\n' "$OUT" | grep -c -- "$1"; }
# 역할 표의 한 행을 "합계 비중 n 중앙값 p90 max" 로 뽑는다(열: 합계 비중 n 중앙값 p90 max 역할)
arow() { printf '%s\n' "$OUT" | grep -E "  $1\$" | awk '{print $1, $2, $3, $4, $5, $6}'; }
# 역할 표에 나온 역할 이름을 위에서 아래로(머리행·미분류 줄 제외)
roles() { printf '%s\n' "$OUT" | sed -n '/^   합계    비중     n  중앙값    p90    max  역할$/,/^미분류/p' | grep -vE '^   합계|^미분류' | awk '{print $NF}' | tr '\n' ','; }

# ── 공통 fixture: 세션 파일(AC-3 의 10:01 H · 10:05 D 4분 · 10:09 N · 10:10 D 1분 · 10:13 H)과 원장 ──
SESSION_BODY=$(cat <<'EOF'
{"type":"user","timestamp":"2026-10-01T10:01:00.000Z","isMeta":false,"origin":{"kind":"human"},"message":{"role":"user","content":"BODY-A"}}
{"type":"system","subtype":"turn_duration","timestamp":"2026-10-01T10:05:00.000Z","durationMs":240000}
{"type":"user","timestamp":"2026-10-01T10:09:00.000Z","isMeta":false,"origin":{"kind":"task-notification"},"message":{"role":"user","content":"BODY-C"}}
{"type":"system","subtype":"turn_duration","timestamp":"2026-10-01T10:10:00.000Z","durationMs":60000}
{"type":"user","timestamp":"2026-10-01T10:13:00.000Z","isMeta":false,"origin":{"kind":"human"},"message":{"role":"user","content":"BODY-D"}}
EOF
)
ledger la <<'EOF'
## 20261001-aaa · A

- 2026-10-01 10:15 /plan 완료 (x)
- 2026-10-01 10:00 /specify 완료 (x)
EOF
newtd() { printf '%s\n' "$SESSION_BODY" | mktr "$SB/$1/s1.jsonl"; }

# ══ AC-1: 헬퍼 — 에이전트당 역할·시작·끝·wall·내부 간격 ══
H="$SB/h/s/subagents"
{ rec 10:00:00; rec 10:03:00; rec 10:20:00; } | mkag "$H" a1 "$META_IMPL"
{ rec 10:00:00; rec 10:01:00; } | mkag "$H" a2 "$META_NAMED"
{ rec 10:00:00; rec 10:02:00; } | mkag "$H" a3 '{"agentType":"evil name; $(x)","toolUseId":"toolu_c","spawnDepth":1}'
{ rec 10:00:00; rec 10:03:00; } | mkag "$H" a4 -
: | mkag "$H" a5 "$META_SPEC"
{ echo 'this is not json'; echo '{"type":"user"}'; rec 10:00:00; echo '{"timestamp":"garbage"}'; rec 10:00:30; } | mkag "$H" a6 "$META_SPEC"
{ rec 10:00:00; rec 10:05:00; rec 12:00:00; } | mkag "$H" a7 '{"agentType":"Explore","toolUseId":"toolu_d","spawnDepth":1}'
{ rec 10:00:00; rec 10:02:00; } | mkag "$H" a8 '{"agentType":"general-purpose","toolUseId":"","spawnDepth":1}'
HF=("$H"/agent-a1.jsonl "$H"/agent-a2.jsonl "$H"/agent-a3.jsonl "$H"/agent-a4.jsonl "$H"/agent-a5.jsonl "$H"/agent-a6.jsonl)
EXP_H=$(printf '%s\n' "1790848800	1790850000	1200	1	1020	0	0	specops-ko:implementer-ko" "1790848800	1790848860	60	0	0	0	0	-" "1790848800	1790848920	120	0	0	0	0	-" "1790848800	1790848980	180	0	0	0	0	-" "1790848800	1790848830	30	0	0	0	0	specops-ko:spec-reviewer-ko")
OUT=$(TZ=UTC "$BASH_BIN" "$AS" --local "${HF[@]}" 2>/dev/null); RC=$?
ck "T1.a 에이전트마다 1줄 — 구현자 wall 1200·10분 초과 간격 1건(1020초) · 이름 지정·자유 텍스트 역할·meta 없음은 '-' · 빈 jsonl 무출력 · 불량 JSON·시각 없는 줄은 건너뜀 · rc=0" "$RC|$OUT" "0|$EXP_H"
OUT=$(TZ=UTC "$BASH_BIN" "$AS" --local "$H"/agent-a7.jsonl 2>/dev/null)
ck "T1.b 기본 방치 상한(720분): 115분 간격은 제외하지 않고 10분 초과 1건(6900초)으로만 센다 · wall 7200" "$OUT" "1790848800	1790856000	7200	1	6900	0	0	Explore"
OUT=$(TZ=UTC "$BASH_BIN" "$AS" --local --gap-cap-min 60 "$H"/agent-a7.jsonl 2>/dev/null)
ck "T1.c --gap-cap-min 60: 115분 간격은 방치로 빼고(wall 300) 상한초과 1건(6900초) · 10분 초과 건수에는 안 센다" "$OUT" "1790848800	1790856000	300	0	0	1	6900	Explore"
OUT=$(TZ=Asia/Seoul "$BASH_BIN" "$AS" --local "$H"/agent-a1.jsonl 2>/dev/null)
ck "T1.d --local 은 TZ 를 따른다(KST = UTC+9h): 시작·끝 +32400초" "$OUT" "1790881200	1790882400	1200	1	1020	0	0	specops-ko:implementer-ko"
OUT=$(TZ=UTC "$BASH_BIN" "$AS" "$H"/agent-a1.jsonl 2>/dev/null)
ck "T1.e --local 없으면 UTC epoch 그대로" "$OUT" "1790848800	1790850000	1200	1	1020	0	0	specops-ko:implementer-ko"
ck "T1.f toolUseId 가 빈 문자열인 에이전트의 역할은 '-'(meta 파일이 끝 개행 없이 이어진 입력에서도 파일마다 올바른 역할)" "$(TZ=UTC "$BASH_BIN" "$AS" "$H"/agent-a8.jsonl "$H"/agent-a1.jsonl "$H"/agent-a7.jsonl 2>/dev/null | awk -F'\t' '{print $8}' | tr '\n' ',')|$([ "$(tail -c1 "$H/agent-a1.meta.json" | od -An -c | tr -d ' ')" = '\n' ] && echo nl || echo nonl)" "-,specops-ko:implementer-ko,Explore,|nonl"
RCS=""
"$BASH_BIN" "$AS" >/dev/null 2>&1; RCS="$RCS$?"
"$BASH_BIN" "$AS" "$SB/없는파일.jsonl" >/dev/null 2>&1; RCS="$RCS$?"
"$BASH_BIN" "$AS" --bogus "$H"/agent-a1.jsonl >/dev/null 2>&1; RCS="$RCS$?"
"$BASH_BIN" "$AS" --gap-cap-min abc "$H"/agent-a1.jsonl >/dev/null 2>&1; RCS="$RCS$?"
"$BASH_BIN" "$AS" --gap-cap-min >/dev/null 2>&1; RCS="$RCS$?"
{ rec 10:00:00; rec 10:03:00; } | mkag "$SB/hd/s1/subagents" ax "$META_IMPL"
{ rec 11:00:00; rec 11:05:00; } | mkag "$SB/hd/s2/subagents" ax "$META_SPEC"
OUT=$(TZ=UTC "$BASH_BIN" "$AS" --local "$SB/hd/s1/subagents/agent-ax.jsonl" "$SB/hd/s2/subagents/agent-ax.jsonl" 2>/dev/null)
ck "T1.i 같은 ID 의 에이전트가 다른 세션 폴더에 있어도 합쳐지지 않고 각자의 역할·시간으로 2줄이 나온다(경로로 구분)" "$OUT" "$(printf '%s\n' "1790848800	1790848980	180	0	0	0	0	specops-ko:implementer-ko" "1790852400	1790852700	300	0	0	0	0	specops-ko:spec-reviewer-ko")"
ck "T1.g 인자 없음·없는 파일·알 수 없는 옵션·잘못된 --gap-cap-min·값 없음 → 전부 rc=2" "$RCS" "22222"
OUT=$("$BASH_BIN" "$AS" "$SB/없는파일.jsonl" "$H"/agent-a1.jsonl 2>/dev/null); RC=$?
ck "T1.g2 읽을 수 없는 파일이 하나라도 섞이면 일부 결과를 내지 않고 통째로 rc=2(부분 집계가 전체처럼 읽히지 않게)" "$RC|$OUT" "2|"
mkdir -p "$SB/nojq"; for t in awk sort grep sed find mktemp rm cat dirname printf touch date; do p=$(command -v "$t") && [ -n "$p" ] && ln -sf "$p" "$SB/nojq/$t"; done
PATH="$SB/nojq" "$BASH_BIN" "$AS" "$H"/agent-a1.jsonl >/dev/null 2>&1; ck "T1.h 헬퍼는 jq 부재 시 rc=3" "$?" "3"

# ══ AC-2: 프라이버시 — 본문·허용 외 키는 어디에도 나오지 않는다 ══
CAN="CANARY-$$-ZQX"
P="$SB/pv/s1/subagents"
{ printf '{"type":"user","timestamp":"2026-10-01T10:00:00.000Z","message":{"content":"%s-BODY"},"toolUseResult":{"x":"%s-TR"},"attachment":"%s-ATT"}\n' "$CAN" "$CAN" "$CAN"
  printf '{"type":"assistant","timestamp":"2026-10-01T10:04:00.000Z","message":{"content":[{"type":"tool_use","input":{"cmd":"%s-IN"}}]},"extra":"%s-EX"}\n' "$CAN" "$CAN"
  printf '%s-NOTJSON\n' "$CAN"; } | mkag "$P" b1 "{\"agentType\":\"specops-ko:implementer-ko\",\"toolUseId\":\"toolu_p\",\"spawnDepth\":1,\"description\":\"$CAN-DESC\",\"foo\":\"$CAN-FOO\"}"
{ rec 10:00:00; rec 10:05:00; } | mkag "$P" b2 "{\"agentType\":\"$CAN bad role\",\"toolUseId\":\"toolu_q\",\"description\":\"$CAN-D2\"}"
mktr "$SB/pv/s1.jsonl" <<EOF
{"type":"user","timestamp":"2026-10-01T10:01:00.000Z","isMeta":false,"origin":{"kind":"human"},"message":{"content":"$CAN-SESS"}}
{"type":"system","subtype":"turn_duration","timestamp":"2026-10-01T10:05:00.000Z","durationMs":240000}
EOF
OUT1=$(TZ=UTC TMPDIR="$SB/tmp" "$BASH_BIN" "$AS" --local "$P"/agent-b1.jsonl "$P"/agent-b2.jsonl 2>"$SB/e1"); E1=$(cat "$SB/e1")
ck "T2.a 헬퍼: 본문·도구 입출력·첨부·meta description·허용 외 키·형식 불일치 역할 이름에 심은 카나리가 stdout·stderr 에 0건" "$(printf '%s\n%s\n' "$OUT1" "$E1" | grep -c "$CAN")" "0"
JQSRC=$(sed -n '/^# JQ-META-BEGIN$/,/^# JQ-META-END$/p;/^# JQ-SPANS-BEGIN$/,/^# JQ-SPANS-END$/p' "$AS")
KEYS=$(printf '%s\n' "$JQSRC" | grep -v '^#' | sed -E 's/"[^"]*"//g' | grep -oE '\.[A-Za-z_][A-Za-z0-9_]*' | sort -u | tr '\n' ' ')
BAD=$(printf '%s\n' "$KEYS" | tr ' ' '\n' | grep -vE '^$|^\.(timestamp|agentType|toolUseId|ts|id|key|value)$' | tr '\n' ' ')
MREFS=$(printf '%s\n' "$JQSRC" | grep -v '^#' | sed -E 's/"[^"]*"//g' | grep -oE '\$m\.[A-Za-z_]+' | sort -u | tr '\n' ' ')
ck "T2.e 헬퍼 jq 프로그램이 참조하는 키는 timestamp·agentType·toolUseId(와 내부 이름 ts·id·key·value)뿐이고 meta 객체에서는 agentType·toolUseId 만 꺼낸다 — description·spawnDepth·message·content 등은 참조하지 않는다" "$BAD|$MREFS" "|\$m.agentType \$m.toolUseId "
ck "T2.g 정적: 헬퍼의 jq 호출 두 곳 모두 stderr 를 버린다(jq 오류 문구는 문제 값을 그대로 찍는다)" "$(grep -c "@tsv' 2>/dev/null)" "$AS")$(grep -cE '"\$@" 2>/dev/null$' "$AS")" "11"
ck "T2.f 정적 검사 자체가 헛돌지 않는다: 프로그램 텍스트가 비어 있지 않고 timestamp·agentType·toolUseId 를 실제로 참조한다" "$(printf '%s\n' "$KEYS" | grep -c 'timestamp')$(printf '%s\n' "$KEYS" | grep -c 'agentType')$(printf '%s\n' "$KEYS" | grep -c 'toolUseId')" "111"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
