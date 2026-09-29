#!/usr/bin/env bash
# 워치독 고아·잔존 — 5 러너 종료 후 고아 sleep·워치독 0 · 시간초과 판정 보존 · 부하 반복 · 옛 idiom 재유입 가드 (stub 전용, 토큰 0)
# 20260929-run-evals-orphan-sleep AC-1~AC-6
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
LE="$PLUGIN/scripts/tests/llm-eval"
ok()   { echo "PASS $1"; PASS=$((PASS+1)); }
nope() { echo "FAIL $1 — $2"; FAIL=$((FAIL+1)); }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# 실행별 고유 값 — 같은 머신의 동시 실행(병렬 run-all 등)과 pgrep 가 섞이지 않게
BASE=$(( 1000 + ($$ % 400) * 200 ))   # slot 1~6 · +100 오프셋이 다른 실행의 값과 겹치지 않는 간격

printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/fast"; chmod +x "$TMP/fast"
_hang() {  # <초> → 자식 sleep 을 띄우고 멈추는 stub 경로 (stdout)
  printf '#!/usr/bin/env bash\nsleep %s\n' "$1" > "$TMP/hang$1"; chmod +x "$TMP/hang$1"
  printf '%s' "$TMP/hang$1"
}
_count() {  # <pgrep -f 패턴> → 매칭 프로세스 수 (남은 것은 정리)
  local n
  n=$(pgrep -f -- "$1" | grep -c .)
  [ "$n" -gt 0 ] && pkill -f -- "$1" 2>/dev/null
  printf '%s' "$n"
}
# 러너가 반환된 뒤 워치독은 flag 삭제를 1초 안에 보고 스스로 끝나야 한다 — 병렬 run-all 의 CPU 경합을 감안해
#   최대 6초까지 0 이 되길 기다린 뒤 센다(고정 대기는 경합 시 거짓 FAIL). 옛 idiom 의 고아 sleep 은 TIMEOUT 초 동안
#   남으므로 6초 안에 사라지지 않는다 — 판별력 유지.
#   남는 것: 긴 sleep(`sleep <값>`)과 워치독 서브셸(러너의 고유 인자를 argv 로 물려받는다 — 실측)
_leftover() {  # <sleep 값> <러너 고유 인자> → "sleep수/워치독수"
  local k=0
  sleep 1
  while [ "$k" -lt 5 ] && { pgrep -fx "sleep $1" >/dev/null || pgrep -f -- "$2" >/dev/null; }; do sleep 1; k=$((k + 1)); done
  printf '%s/%s' "$(_count "^sleep $1\$")" "$(_count "$2")"
}
_llm() {  # <러너> <인자> <timeout> <CLAUDE_BIN> → 러너 stdout+stderr
  env LLM_EVAL_TIMEOUT="$3" CLAUDE_BIN="$4" bash "$LE/$1" "$2" 2>&1
}

head -1 "$LE/fixtures.jsonl" > "$TMP/fx.jsonl"
head -1 "$LE/pressure-fixtures.jsonl" > "$TMP/pfx.jsonl"
mkdir -p "$TMP/ab" "$TMP/cs"
cp -R "$LE/plan-ab-fixtures/cov-miss" "$TMP/ab/"
cp -R "$LE/chain-stage-fixtures/decompose-covmiss" "$TMP/cs/"

# T1 (AC-1·AC-2) llm-eval 러너 4종 — 종료 후 고아 sleep·워치독 0 · 시간초과 판정 보존
_check_llm() {  # <id> <러너> <인자> <정상경로 금지 regex(빈값=검사 안 함)> <시간초과 기대 regex> <slot>
  local id="$1" r="$2" a="$3" nofalse="$4" want="$5" slot="$6" v h out left
  v=$((BASE + slot)); h=$((BASE + slot + 100))
  out=$(_llm "$r" "$a" "$v" "$TMP/fast"); left=$(_leftover "$v" "$a")
  if [ "$left" = "0/0" ] && { [ -z "$nofalse" ] || ! printf '%s' "$out" | grep -Eq "$nofalse"; }; then
    ok "$id.a $r 정상 종료 → 고아 sleep·워치독 0 · 거짓 timeout 없음"
  else nope "$id.a" "$r 잔존 sleep/워치독=$left / out=$(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; fi
  out=$(_llm "$r" "$a" 1 "$(_hang "$h")"); left=$(_leftover "$h" "$a")
  if printf '%s' "$out" | grep -Eq "$want" && [ "$left" = "0/0" ]; then
    ok "$id.b $r 시간초과 → 종전 판정 · 멈춘 stub 자손·워치독 정리"
  else nope "$id.b" "$r 기대 /$want/ · 잔존 stub자손/워치독=$left / out=$(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; fi
}
_check_llm T1.1 run-evals.sh          "$TMP/fx.jsonl"  'TIMEOUT'     'TIMEOUT 1s'            1
_check_llm T1.2 run-pressure-evals.sh "$TMP/pfx.jsonl" '\(timeout\)' '\(timeout\)'           2
_check_llm T1.3 run-plan-ab.sh        "$TMP/ab"        ''            '방식 A: recall=0/2'    3
_check_llm T1.4 run-chain-stage.sh    "$TMP/cs"        ''            'decompose: recall=0/1' 4
echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
