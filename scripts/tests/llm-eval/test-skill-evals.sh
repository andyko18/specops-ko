#!/usr/bin/env bash
# skill 별 활성화·행동 eval — 데이터 스키마·pilot 커버리지·파서·stub·러너 판정 (stub 전용, 토큰 0)
# 20260929-skill-behavior-eval AC-1~AC-7
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
LE="$PLUGIN/scripts/tests/llm-eval"
# shellcheck disable=SC1091
source "$LE/eval-lib.sh"
# shellcheck disable=SC1091
source "$LE/skill-evals-lib.sh"
ok()   { echo "PASS $1"; PASS=$((PASS+1)); }
nope() { echo "FAIL $1 — $2"; FAIL=$((FAIL+1)); }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── 픽스처: 가짜 skills 루트 + 유효 데이터 쌍 ──
ROOT="$TMP/skills-root"; mkdir -p "$ROOT/fake-a"; : > "$ROOT/fake-a/SKILL.md"
_valid_trigger() {  # <skill>
  jq -n --arg s "$1" '{skill:$s,
    should_trigger:[{id:"pos-1",query:"기능 만들어줘"}],
    should_not_trigger:[{id:"neg-1",query:"2+2 는?"}]}'
}
_valid_evals() {  # <skill>
  jq -n --arg s "$1" '{skill:$s,
    cases:[{id:"e-1",prompt:"기능 만들어줘",asserts:[{type:"regex",value:"설계"},{type:"cost_lt",value:"2.0"}]}]}'
}
_mk() {  # <dir> <trigger json> <evals json> → 데이터 디렉터리 생성
  mkdir -p "$1"; printf '%s\n' "$2" > "$1/trigger-queries.json"; printf '%s\n' "$3" > "$1/evals.json"
}
_expect_fail() {  # <id> <kind> <file> <사유 부분문자열>
  local out rc
  out=$(skill_evals::check "$2" "$3" "$ROOT"); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF -- "$4"; then ok "$1"; else nope "$1" "rc=$rc out='$out' (기대 사유 '$4')"; fi
}
# T1 (AC-1) 스키마 계약
V="$TMP/v/fake-a"; _mk "$V" "$(_valid_trigger fake-a)" "$(_valid_evals fake-a)"
if skill_evals::check trigger "$V/trigger-queries.json" "$ROOT" >/dev/null \
   && skill_evals::check evals "$V/evals.json" "$ROOT" >/dev/null; then ok "T1.a 유효 쌍 통과"; else nope "T1.a" "유효 쌍이 거부됨"; fi

D="$TMP/m1/fake-a"; _mk "$D" "$(_valid_trigger fake-a | jq '.should_not_trigger=[]')" "$(_valid_evals fake-a)"
_expect_fail "T1.b ① 빈 should_not_trigger" trigger "$D/trigger-queries.json" "should_not_trigger 비어 있음"
D="$TMP/m2/fake-a"; _mk "$D" "$(_valid_trigger fake-a | jq 'del(.skill)')" "$(_valid_evals fake-a)"
_expect_fail "T1.c ② skill 필드 누락" trigger "$D/trigger-queries.json" "skill 필드 누락"
D="$TMP/m3/fake-a"; _mk "$D" "$(_valid_trigger fake-a | jq '.should_not_trigger[0].id="pos-1"')" "$(_valid_evals fake-a)"
_expect_fail "T1.d ③ id 중복" trigger "$D/trigger-queries.json" "id 중복: pos-1"
D="$TMP/m4/fake-a"; _mk "$D" "$(_valid_trigger fake-a)" "$(_valid_evals fake-a | jq '.cases[0].asserts[0].type="equals"')"
_expect_fail "T1.e ④ 어휘 밖 assert type" evals "$D/evals.json" "미지 assert type: equals"
D="$TMP/m5/fake-a"; _mk "$D" "$(_valid_trigger fake-a)" "$(_valid_evals fake-a | jq '.cases[0].asserts[0].value=""')"
_expect_fail "T1.f ⑤ 빈 assert value" evals "$D/evals.json" "빈 assert value"
D="$TMP/m6/fake-a"; _mk "$D" "$(_valid_trigger fake-b)" "$(_valid_evals fake-a)"
_expect_fail "T1.g ⑥ skill 필드≠디렉터리" trigger "$D/trigger-queries.json" "skill 필드(fake-b) ≠ 디렉터리(fake-a)"
D="$TMP/m7/ghost-x"; _mk "$D" "$(_valid_trigger ghost-x)" "$(_valid_evals ghost-x)"
_expect_fail "T1.h ⑦ 실존하지 않는 skill" trigger "$D/trigger-queries.json" "실존하지 않는 skill: ghost-x"
D="$TMP/m8/fake-a"; mkdir -p "$D"; printf '{"skill": "fake-a",\n' > "$D/evals.json"
_expect_fail "T1.i ⑧ JSON 파싱 불가" evals "$D/evals.json" "JSON 파싱 불가"
# T3 (AC-3) 스트림 전체 Skill 호출 파서
s0='{"type":"assistant","message":{"content":[{"type":"text","text":"안녕"}]}}'
s1='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"specifying-ko"}}]}}'
s2='{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"advisor-ko"}}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"이어서"}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"specops-ko:karpathy-ko"}}]}}'
[ -z "$(printf '%s\n' "$s0" | eval::all_skills)" ] && ok "T3.a 호출 0건 → 빈 출력" || nope "T3.a" "빈 출력 아님"
[ "$(printf '%s\n' "$s1" | eval::all_skills)" = "specifying-ko" ] && ok "T3.b 1건" || nope "T3.b" "1건 파싱 실패"
got=$(printf '%s\n' "$s2" | eval::all_skills | paste -sd, -)
[ "$got" = "advisor-ko,specops-ko:karpathy-ko" ] && ok "T3.c 2건 순서 유지" || nope "T3.c" "got='$got'"

# T4 (AC-4) stub 다중 호출 + 하위호환
_stub() {  # <plan 행> → stub stdout
  printf '%s\n' "$1" > "$TMP/plan4.jsonl"; rm -f "$TMP/state4"
  STUB_PLAN="$TMP/plan4.jsonl" STUB_STATE="$TMP/state4" bash "$LE/stub-claude.sh" -p x
}
o=$(_stub '{"skills":["advisor-ko","karpathy-ko"]}')
[ "$(printf '%s\n' "$o" | eval::all_skills | paste -sd, -)" = "advisor-ko,karpathy-ko" ] \
  && [ "$(printf '%s\n' "$o" | tail -1 | jq -r .type)" = "result" ] && ok "T4.a skills 배열 → 2건 순서 + result" || nope "T4.a" "$o"
o=$(_stub '{"skill":"specifying-ko","args":"x"}')
[ "$(printf '%s\n' "$o" | jq -r 'select(.type=="assistant")|.message.content[0].input|"\(.skill)|\(.args)"')" = "specifying-ko|x" ] \
  && [ "$(printf '%s\n' "$o" | grep -c .)" -eq 2 ] && ok "T4.b 기존 skill 형식 무변경" || nope "T4.b" "$o"
o=$(_stub '{"text":"안녕"}')
[ "$(printf '%s\n' "$o" | eval::extract_text)" = "안녕" ] && [ "$(printf '%s\n' "$o" | grep -c .)" -eq 2 ] \
  && ok "T4.c 기존 text 형식 무변경" || nope "T4.c" "$o"
# T2 (AC-2) pilot 3개 커버리지 — 실 트리 읽기 전용
for s in specifying-ko karpathy-ko advisor-ko; do
  d="$LE/skills/$s"
  if skill_evals::check trigger "$d/trigger-queries.json" "$PLUGIN/skills" >/dev/null \
     && skill_evals::check evals "$d/evals.json" "$PLUGIN/skills" >/dev/null \
     && [ "$(jq '.should_trigger|length' "$d/trigger-queries.json")" -ge 3 ] \
     && [ "$(jq '.should_not_trigger|length' "$d/trigger-queries.json")" -ge 3 ] \
     && [ "$(jq '.cases|length' "$d/evals.json")" -ge 3 ]; then
    ok "T2.$s pilot 두 파일 · 양성≥3 · 음성≥3 · case≥3"
  else nope "T2.$s" "pilot 데이터 누락·스키마 위반·개수 부족 ($d)"; fi
done
bad=""; n=0
for d in "$LE"/skills/*/; do
  [ -d "$d" ] || continue
  n=$((n+1))
  for k in trigger evals; do
    f="$d/trigger-queries.json"; [ "$k" = evals ] && f="$d/evals.json"
    skill_evals::check "$k" "$f" "$PLUGIN/skills" >/dev/null || bad="$bad $(basename "$d")/$k"
  done
done
[ "$n" -ge 3 ] && [ -z "$bad" ] && ok "T2.all skills/ 전 디렉터리($n) 스키마 통과" || nope "T2.all" "디렉터리 ${n}개 · 위반:$bad"
# 에코 가드 — contains/regex 는 프롬프트 자신에 매칭되면 안 된다(질문 단어를 되받기만 해도 PASS 하는 변별력 0 assert 차단)
echo_bad=""
for d in "$LE"/skills/*/; do
  [ -f "$d/evals.json" ] || continue
  while IFS= read -r c; do
    p=$(printf '%s' "$c" | jq -r .prompt)
    while IFS= read -r a; do
      t=$(printf '%s' "$a" | jq -r .type); v=$(printf '%s' "$a" | jq -r '.value|tostring')
      case "$t" in contains|regex) [ "$(eval::assert "$t" "$p" "$v")" = PASS ] && echo_bad="$echo_bad $(basename "$d")/$(printf '%s' "$c" | jq -r .id)" ;; esac
    done < <(printf '%s' "$c" | jq -c '.asserts[]')
  done < <(jq -c '.cases[]' "$d/evals.json")
done
[ -z "$echo_bad" ] && ok "T2.echo assert 가 프롬프트 자신에 매칭되지 않음" || nope "T2.echo" "프롬프트 에코로 통과하는 assert:$echo_bad"
# ── T5·T6 러너 픽스처: 실존 skill(karpathy-ko) 1개 · 양성 1 · 음성 1 · case 1 ──
DATA="$TMP/data"; mkdir -p "$DATA/karpathy-ko"
jq -n '{skill:"karpathy-ko",should_trigger:[{id:"pos-1",query:"q1"}],should_not_trigger:[{id:"neg-1",query:"q2"}]}' > "$DATA/karpathy-ko/trigger-queries.json"
jq -n '{skill:"karpathy-ko",cases:[{id:"e-1",prompt:"p1",asserts:[{type:"contains",value:"설계"}]}]}' > "$DATA/karpathy-ko/evals.json"
cat > "$TMP/rec-claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$TMP/args.log"
exec bash "$LE/stub-claude.sh" "\$@"
EOF
chmod +x "$TMP/rec-claude"
_run() {  # <plan 행들(\n)> <env 할당...> -- <러너 인자...> → 러너 stdout (rc 는 RUN_RC)
  printf '%b\n' "$1" > "$TMP/plan.jsonl"; shift
  rm -f "$TMP/state" "$TMP/args.log"
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
  RUN_OUT=$(env -u ANTHROPIC_API_KEY -u SKILL_EVAL_MODE -u LLM_EVAL_RUNS \
    CLAUDE_BIN="$TMP/rec-claude" STUB_PLAN="$TMP/plan.jsonl" STUB_STATE="$TMP/state" \
    SKILL_EVAL_DIR="$DATA" "${envs[@]+"${envs[@]}"}" bash "$LE/run-skill-evals.sh" "$@" 2>&1); RUN_RC=$?
}
_line() { printf '%s\n' "$RUN_OUT" | grep -F -- "  $1  " | head -1; }

# T5 (AC-5) 러너 판정·모드·경계
_run '{"skills":["advisor-ko","karpathy-ko"]}\n{"skills":["advisor-ko","karpathy-ko"]}' -- --trigger
_line pos-1 | grep -q 'PASS' && ok "T5.a ① 양성 — 두 번째 호출도 PASS" || nope "T5.a" "$RUN_OUT"
_line neg-1 | grep -q 'FAIL' && ok "T5.b ② 음성 — 두 번째 호출된 대상 FAIL" || nope "T5.b" "$RUN_OUT"
_run '{"skills":["karpathy-ko"]}\n{"skills":["advisor-ko"]}' -- --trigger
_line neg-1 | grep -q 'PASS' && ok "T5.c ③ 음성 — 다른 skill 만 호출 PASS" || nope "T5.c" "$RUN_OUT"
_run '{"text":"먼저 설계를 봅니다"}' -- --evals
_line e-1 | grep -q 'PASS' && ok "T5.d ④ eval asserts 만족 PASS" || nope "T5.d" "$RUN_OUT"
_run '{"text":"바로 코드 작성"}' -- --evals
_line e-1 | grep -q 'FAIL' && ok "T5.e ④ eval asserts 불만족 FAIL" || nope "T5.e" "$RUN_OUT"
_run '{"skills":["karpathy-ko"]}' ANTHROPIC_API_KEY=k -- --trigger
if [ "$(printf '%s\n' "$RUN_OUT" | grep -c '^MODE=isolated  ')" -eq 2 ] \
   && grep -qF -- '--bare' "$TMP/args.log" && grep -qF -- "--plugin-dir $PLUGIN" "$TMP/args.log"; then
  ok "T5.f ⑤ 키 설정 → MODE=isolated + --bare --plugin-dir"; else nope "T5.f" "$RUN_OUT / $(cat "$TMP/args.log")"; fi
_run '{"skills":["karpathy-ko"]}' -- --trigger
if [ "$(printf '%s\n' "$RUN_OUT" | grep -c '^MODE=routed  ')" -eq 2 ] \
   && printf '%s' "$RUN_OUT" | grep -q 'isolated 불가(ANTHROPIC_API_KEY 부재)' \
   && ! grep -q -- '--bare' "$TMP/args.log" && ! grep -q -- '--plugin-dir' "$TMP/args.log"; then
  ok "T5.g ⑤ 키 미설정 → MODE=routed + 폴백 고지 + 격리 인자 없음"; else nope "T5.g" "$RUN_OUT"; fi
_run '{"skills":["karpathy-ko"]}' ANTHROPIC_API_KEY=k SKILL_EVAL_MODE=routed -- --trigger
if [ "$(printf '%s\n' "$RUN_OUT" | grep -c '^MODE=routed  ')" -eq 2 ] && ! grep -q -- '--bare' "$TMP/args.log" \
   && ! grep -q -- '--plugin-dir' "$TMP/args.log"; then
  ok "T5.h ⑤ SKILL_EVAL_MODE=routed 강제"; else nope "T5.h" "$RUN_OUT"; fi
_run '{}' CLAUDE_BIN="$TMP/no-such-claude" -- --trigger
printf '%s' "$RUN_OUT" | grep -q '^SKIP: claude CLI 부재' && [ "$RUN_RC" -eq 0 ] \
  && ok "T5.i ⑥ CLI 부재 → SKIP · rc 0" || nope "T5.i" "rc=$RUN_RC $RUN_OUT"
_run '{}' -- --trigger advisor-ko
printf '%s' "$RUN_OUT" | grep -q 'advisor-ko  -  SKIP(데이터 파일 부재' && [ "$RUN_RC" -eq 0 ] \
  && ok "T5.j ⑦ 데이터 부재 → SKIP(사유)" || nope "T5.j" "rc=$RUN_RC $RUN_OUT"
_run '{"skills":["advisor-ko"]}\n{"skills":["karpathy-ko"]}' -- --trigger
printf '%s' "$RUN_OUT" | grep -qE '^SKILL-EVAL: mode=routed trigger pass=0 fail=2 skip=0 cost=\$[0-9.]+$' && [ "$RUN_RC" -eq 0 ] \
  && ok "T5.k 요약줄 형식 · 전부 FAIL 이어도 rc 0" || nope "T5.k" "rc=$RUN_RC $RUN_OUT"

_run '{}' -- 
[ "$RUN_RC" -eq 0 ] && printf '%s' "$RUN_OUT" | grep -q '^사용: ' && ok "T5.l 인자 없음 → 사용법 · rc 0 (FR-8)" || nope "T5.l" "rc=$RUN_RC $RUN_OUT"
printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/dead-claude"; chmod +x "$TMP/dead-claude"
_run '{}' CLAUDE_BIN="$TMP/dead-claude" -- --trigger
if _line neg-1 | grep -q 'SKIP(error' && _line pos-1 | grep -q 'SKIP(error' \
   && printf '%s' "$RUN_OUT" | grep -q 'pass=0 fail=0 skip=2'; then
  ok "T5.m result 이벤트 없음 → SKIP(error) — 음성이 PASS 로 위장되지 않음"; else nope "T5.m" "$RUN_OUT"; fi
printf '#!/usr/bin/env bash\nsleep 5\n' > "$TMP/slow-claude"; chmod +x "$TMP/slow-claude"
_run '{}' CLAUDE_BIN="$TMP/slow-claude" LLM_EVAL_TIMEOUT=1 -- --evals
_line e-1 | grep -q 'SKIP(timeout)' && ok "T5.n 시간 초과 → SKIP(timeout)" || nope "T5.n" "$RUN_OUT"
WTO=$((1000 + $$ % 8000))   # 실행별 고유 timeout — 같은 머신의 동시 실행과 pgrep 가 섞이지 않게
_run '{"skills":["karpathy-ko"]}' LLM_EVAL_TIMEOUT="$WTO" -- --trigger
sleep 1
[ "$(pgrep -fx "sleep $WTO" | grep -c .)" -eq 0 ] && ok "T5.o 정상 종료 후 워치독 sleep 고아 0" \
  || { nope "T5.o" "고아 sleep $WTO $(pgrep -fx "sleep $WTO" | grep -c .)개"; pkill -fx "sleep $WTO"; }
mkdir -p "$TMP/data2/karpathy-ko"
jq -n '{skill:"karpathy-ko",should_trigger:[{id:"pos-1",query:"a\\b\tc"}],should_not_trigger:[{id:"neg-1",query:"q"}]}' > "$TMP/data2/karpathy-ko/trigger-queries.json"
_run '{"skills":["karpathy-ko"]}' SKILL_EVAL_DIR="$TMP/data2" -- --trigger
head -1 "$TMP/args.log" | grep -qF -- "$(printf -- '-p a\\b\tc ')" && ok "T5.p 질의의 백슬래시·탭을 그대로 전달" \
  || nope "T5.p" "$(head -1 "$TMP/args.log")"

# T6 (AC-7) isolated 미확인 표기 + 단발 실행
_run '{"skills":["advisor-ko"]}\n{"skills":["karpathy-ko"]}' ANTHROPIC_API_KEY=k LLM_EVAL_RUNS=3 -- --trigger
printf '%s' "$RUN_OUT" | grep -q '^SKILL-EVAL: mode=isolated(unverified) trigger ' \
  && ok "T6.a 키 설정 → mode=isolated(unverified)" || nope "T6.a" "$RUN_OUT"
[ "$(cat "$TMP/state" 2>/dev/null)" = "2" ] && ok "T6.b 전부 FAIL + LLM_EVAL_RUNS=3 에도 호출 2회(재시도·N-run 없음)" \
  || nope "T6.b" "stub 호출 $(cat "$TMP/state" 2>/dev/null)회"
_run '{"text":"x"}' -- --evals
printf '%s' "$RUN_OUT" | grep -q '^SKILL-EVAL: mode=routed evals ' && [ "$(cat "$TMP/state")" = "1" ] \
  && ok "T6.c 키 미설정 → mode=routed · evals 호출 1회" || nope "T6.c" "$RUN_OUT"
echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
