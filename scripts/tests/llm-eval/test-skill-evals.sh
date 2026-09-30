#!/usr/bin/env bash
# skill 별 활성화·행동 eval — 데이터 스키마·pilot 6개 커버리지·파서·stub·러너 판정 (stub 전용, 토큰 0)
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
# T2 (AC-2) pilot 6개 커버리지 — 실 트리 읽기 전용 (20260930-skill-eval-expand: 3 → 6)
for s in specifying-ko karpathy-ko advisor-ko systematic-debugging-ko tdd-ko analyzing-ko; do
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
[ "$n" -ge 6 ] && [ -z "$bad" ] && ok "T2.all skills/ 전 디렉터리($n) 스키마 통과" || nope "T2.all" "디렉터리 ${n}개 · 위반:$bad"
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
# T5.t~x (20260930-skill-eval-tool-lock) — 조사·우회 도구 차단 인자 · MCP 비활성 · SKIP(error) stderr 부착
DENY='--allowedTools Skill --disallowedTools Bash Read Glob Grep Agent Edit Write NotebookEdit WebFetch WebSearch ToolSearch'
_run '{"skills":["karpathy-ko"]}' -- --trigger
_n=$(grep -c . "$TMP/args.log"); _d=$(grep -cF -- "$DENY" "$TMP/args.log")
_run '{"skills":["karpathy-ko"]}' ANTHROPIC_API_KEY=k -- --trigger
_ni=$(grep -c . "$TMP/args.log"); _di=$(grep -cF -- "$DENY" "$TMP/args.log")
if [ "$_n" -eq 2 ] && [ "$_d" -eq 2 ] && [ "$_ni" -eq 2 ] && [ "$_di" -eq 2 ]; then
  ok "T5.t routed·isolated 모든 호출에 조사·우회 도구 차단 인자"; else nope "T5.t" "routed $_d/$_n · isolated $_di/$_ni"; fi
_run '{"skills":["karpathy-ko"]}' -- --trigger; _m=$(grep -cF -- '--strict-mcp-config' "$TMP/args.log")
_run '{"skills":["karpathy-ko"]}' ANTHROPIC_API_KEY=k -- --trigger; _mi=$(grep -cF -- '--strict-mcp-config' "$TMP/args.log")
[ "$_m" -eq 2 ] && [ "$_mi" -eq 2 ] && ok "T5.x routed·isolated 모든 호출에 --strict-mcp-config (MCP 우회 차단)" || nope "T5.x" "routed $_m/2 · isolated $_mi/2"
printf '#!/usr/bin/env bash\nprintf "boom: rate limited\\nsecond line\\n" >&2\nexit 1\n' > "$TMP/err-claude"; chmod +x "$TMP/err-claude"
_run '{}' CLAUDE_BIN="$TMP/err-claude" -- --trigger
if _line pos-1 | grep -qF 'SKIP(error: result 이벤트 없음 — 실행 실패) — stderr: boom: rate limited' \
   && _line neg-1 | grep -qF '— stderr: boom: rate limited' && ! printf '%s' "$RUN_OUT" | grep -qF 'second line' \
   && printf '%s' "$RUN_OUT" | grep -q 'pass=0 fail=0 skip=2'; then
  ok "T5.u SKIP(error) 에 claude stderr 첫 줄 부착 · skip 으로 집계"; else nope "T5.u" "$RUN_OUT"; fi
printf '#!/usr/bin/env bash\nprintf "%%0200d\\n" 0 | tr 0 x >&2\nexit 1\n' > "$TMP/long-claude"; chmod +x "$TMP/long-claude"
_run '{}' CLAUDE_BIN="$TMP/long-claude" -- --trigger
_line pos-1 | grep -qE -- '— stderr: x{120}$' && ok "T5.v stderr 첫 줄 120자 상한" || nope "T5.v" "$(_line pos-1 | tail -c 60)"
_run '{}' CLAUDE_BIN="$TMP/dead-claude" -- --trigger
_line pos-1 | grep -qE 'SKIP\(error: result 이벤트 없음 — 실행 실패\)$' && ok "T5.w stderr 없는 실패 → 기존 문구 그대로(부착 없음)" || nope "T5.w" "$(_line pos-1)"
# T5.y~ak (20260930-skill-eval-fixture-repo · cp-note) — 공유 픽스처 repo 를 커밋한 sandbox · 부재 시 종전 · 원본 무변경
FIX="$TMP/fixture"; mkdir -p "$FIX/src"; printf 'a\n' > "$FIX/src/a.js"; printf 'b\n' > "$FIX/b.py"
_fix_before=$(cd "$FIX" && find . | LC_ALL=C sort)
cat > "$TMP/git-claude" <<EOF
#!/usr/bin/env bash
{ printf 'tracked=%s\n' "\$(git ls-files | LC_ALL=C sort | paste -sd, -)"; printf 'dirty=%s\n' "\$(git status --porcelain | grep -c .)"; printf 'commits=%s\n' "\$(git rev-list --count HEAD 2>/dev/null || echo 0)"; } >> "$TMP/git.log"
exec bash "$LE/stub-claude.sh" "\$@"
EOF
chmod +x "$TMP/git-claude"
rm -f "$TMP/git.log"; _run '{"skills":["karpathy-ko"]}' CLAUDE_BIN="$TMP/git-claude" SKILL_EVAL_FIXTURE="$FIX" -- --trigger
if [ "$(grep -c '^tracked=CLAUDE.md,b.py,src/a.js$' "$TMP/git.log")" -eq 2 ] && [ "$(grep -c '^dirty=0$' "$TMP/git.log")" -eq 2 ]; then
  ok "T5.y 픽스처 커밋 sandbox — 픽스처·CLAUDE.md tracked · git status clean"; else nope "T5.y" "$(tr '\n' ' ' < "$TMP/git.log")"; fi
printf '%s' "$RUN_OUT" | grep -q 'pass=1 fail=1 skip=0' && ok "T5.z 픽스처 경로에서도 판정·요약 형식 불변" || nope "T5.z" "$RUN_OUT"
rm -f "$TMP/git.log"; _run '{"skills":["karpathy-ko"]}' CLAUDE_BIN="$TMP/git-claude" SKILL_EVAL_FIXTURE="$TMP/no-such-fixture" -- --trigger
if [ "$(grep -c '^tracked=$' "$TMP/git.log")" -eq 2 ] && [ "$(grep -c '^commits=0$' "$TMP/git.log")" -eq 2 ]; then
  ok "T5.aa 픽스처 부재 → 종전 빈 sandbox(커밋 0 · tracked 없음)"; else nope "T5.aa" "$(tr '\n' ' ' < "$TMP/git.log")"; fi
[ "$(cd "$FIX" && find . | LC_ALL=C sort)" = "$_fix_before" ] && ok "T5.ab 원본 픽스처 무변경(.git·CLAUDE.md·.specops 미생성)" || nope "T5.ab" "$(cd "$FIX" && find . | tr '\n' ' ')"
# 적대적 사용자 전역 git 설정(실패 훅 · templateDir 훅 · 전역 gitignore 에 CLAUDE.md) 에서도 커밋이 성립해야 한다
mkdir -p "$TMP/hostile/hooks" "$TMP/hostile/tpl/hooks"
printf '#!/bin/sh\nexit 1\n' > "$TMP/hostile/hooks/pre-commit"; cp "$TMP/hostile/hooks/pre-commit" "$TMP/hostile/tpl/hooks/pre-commit"
chmod +x "$TMP/hostile/hooks/pre-commit" "$TMP/hostile/tpl/hooks/pre-commit"; printf 'CLAUDE.md\n' > "$TMP/hostile/ignore"
mkdir -p "$TMP/hostile/tpl/info"; printf '*.py\n' > "$TMP/hostile/tpl/info/exclude"   # templateDir 가 복사하는 info/exclude — excludesFile 로는 못 덮는다
printf '[core]\n\thooksPath = %s\n\texcludesFile = %s\n[init]\n\ttemplateDir = %s\n[commit]\n\tgpgsign = true\n[gpg]\n\tprogram = false\n' \
  "$TMP/hostile/hooks" "$TMP/hostile/ignore" "$TMP/hostile/tpl" > "$TMP/hostile/gitconfig"
rm -f "$TMP/git.log"; _run '{"skills":["karpathy-ko"]}' CLAUDE_BIN="$TMP/git-claude" SKILL_EVAL_FIXTURE="$FIX" GIT_CONFIG_GLOBAL="$TMP/hostile/gitconfig" \
  GIT_INDEX_FILE="$TMP/hostile/stray-index" -- --trigger
if [ "$(grep -c '^tracked=CLAUDE.md,b.py,src/a.js$' "$TMP/git.log")" -eq 2 ] && [ "$(grep -c '^dirty=0$' "$TMP/git.log")" -eq 2 ]; then
  ok "T5.ad 적대적 git 환경(실패 훅·templateDir 훅·info/exclude·전역 gitignore·서명·GIT_INDEX_FILE 누출)에도 픽스처 커밋 성립"; else nope "T5.ad" "$(tr '\n' ' ' < "$TMP/git.log")"; fi
[ ! -e "$TMP/hostile/stray-index" ] && ok "T5.ae 호출자 GIT_INDEX_FILE 이 가리키는 곳에 index 미생성(sandbox 밖 무접촉)" || nope "T5.ae" "stray index 생성됨"
# 커밋 실패는 무음이면 안 된다 — 빈 sandbox 로 강등됐다는 NOTE 를 1회 낸다(Phase C Important 1)
mkdir -p "$TMP/failgit"; _realgit=$(command -v git)
printf '#!/usr/bin/env bash\ncase " $* " in *" commit "*) exit 1 ;; esac\nexec "%s" "$@"\n' "$_realgit" > "$TMP/failgit/git"; chmod +x "$TMP/failgit/git"
_run '{"skills":["karpathy-ko"]}' SKILL_EVAL_FIXTURE="$FIX" PATH="$TMP/failgit:$PATH" -- --trigger
if [ "$(printf '%s\n' "$RUN_OUT" | grep -c '^NOTE: 픽스처 커밋 실패')" -eq 1 ] && printf '%s' "$RUN_OUT" | grep -q 'pass=1 fail=1 skip=0'; then
  ok "T5.af 픽스처 커밋 실패 → NOTE 1회 · 판정 경로 불변"; else nope "T5.af" "$RUN_OUT"; fi
_run '{"skills":["karpathy-ko"]}' SKILL_EVAL_FIXTURE="$FIX" -- --trigger
printf '%s' "$RUN_OUT" | grep -q '^NOTE: 픽스처' && nope "T5.ag" "성공인데 NOTE: $RUN_OUT" || ok "T5.ag 픽스처 커밋 성공 → NOTE 없음"
# 복사 실패·빈 픽스처도 무음이면 안 된다(20260930-skill-eval-fixture-cp-note) — 원인별 NOTE 를 run 당 1회 낸다
# 픽스처 경로가 인자에 있을 때만 실패하고 그 밖의 cp 는 진짜 cp 로 넘긴다 — 무관한 cp 가 늘어도 이 단언이 흔들리지 않게(root 에서도 재현: chmod 000 은 root 에 무력)
mkdir -p "$TMP/failcp"; _realcp=$(command -v cp)
printf '#!/usr/bin/env bash\ncase "$*" in *"%s"*) exit 1 ;; esac\nexec "%s" "$@"\n' "$FIX" "$_realcp" > "$TMP/failcp/cp"; chmod +x "$TMP/failcp/cp"
_run '{"skills":["karpathy-ko"]}' SKILL_EVAL_FIXTURE="$FIX" PATH="$TMP/failcp:$PATH" -- --trigger
if [ "$(printf '%s\n' "$RUN_OUT" | grep -c '^NOTE: 픽스처 복사 실패')" -eq 1 ] && printf '%s' "$RUN_OUT" | grep -q 'pass=1 fail=1 skip=0'; then
  ok "T5.ai cp 실패 → NOTE 픽스처 복사 실패 1회 · 판정 요약 불변"; else nope "T5.ai" "$RUN_OUT"; fi
mkdir -p "$TMP/emptyfix"
_run '{"skills":["karpathy-ko"]}' SKILL_EVAL_FIXTURE="$TMP/emptyfix" -- --trigger
if [ "$(printf '%s\n' "$RUN_OUT" | grep -c '^NOTE: 픽스처가 비어 있음')" -eq 1 ] && printf '%s' "$RUN_OUT" | grep -q 'pass=1 fail=1 skip=0'; then
  ok "T5.aj 빈 픽스처 → NOTE 픽스처가 비어 있음 1회 · 판정 요약 불변"; else nope "T5.aj" "$RUN_OUT"; fi
# 복사 실패와 커밋 실패가 겹치면 근본 원인(복사 실패) 하나만, 그것도 1회 — 우선순위 가드 잠금
_run '{"skills":["karpathy-ko"]}' SKILL_EVAL_FIXTURE="$FIX" PATH="$TMP/failcp:$TMP/failgit:$PATH" -- --trigger
if [ "$(printf '%s\n' "$RUN_OUT" | grep -c '^NOTE: 픽스처')" -eq 1 ] && printf '%s\n' "$RUN_OUT" | grep -q '^NOTE: 픽스처 복사 실패'; then
  ok "T5.ak 복사 실패+커밋 실패 겹침 → 복사 실패 NOTE 하나만"; else nope "T5.ak" "$RUN_OUT"; fi
# 픽스처에 .git 이 있어도 sandbox 의 git 에 섞이지 않는다(Phase C Important 2 — cp -R 이 .git 을 병합해 HEAD 가 바뀌던 결함)
FIXG="$TMP/fixture-git"; mkdir -p "$FIXG"; printf 'g\n' > "$FIXG/g.js"
git -C "$FIXG" init -q; git -C "$FIXG" -c user.email=x@x -c user.name=x -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q --allow-empty -m "foreign-fixture-commit"
cat > "$TMP/head-claude" <<EOF
#!/usr/bin/env bash
{ printf 'history=%s\n' "\$(git log --format=%s 2>/dev/null | paste -sd, -)"; printf 'tracked=%s\n' "\$(git ls-files | LC_ALL=C sort | paste -sd, -)"; } >> "$TMP/head.log"
exec bash "$LE/stub-claude.sh" "\$@"
EOF
chmod +x "$TMP/head-claude"; rm -f "$TMP/head.log"
_run '{"skills":["karpathy-ko"]}' CLAUDE_BIN="$TMP/head-claude" SKILL_EVAL_FIXTURE="$FIXG" -- --trigger
if [ "$(grep -c '^history=fixture$' "$TMP/head.log")" -eq 2 ] && [ "$(grep -c '^tracked=CLAUDE.md,g.js$' "$TMP/head.log")" -eq 2 ] && [ -d "$FIXG/.git" ]; then
  ok "T5.ah 픽스처의 .git 은 sandbox 에 섞이지 않음(이력=fixture 커밋 1개 · 원본 .git 보존)"; else nope "T5.ah" "$(tr '\n' ' ' < "$TMP/head.log")"; fi
_rf="$PLUGIN/scripts/tests/llm-eval/skill-eval-fixture-repo"
if [ -f "$_rf/src/auth.js" ] && [ -f "$_rf/src/orders/discount.js" ] && [ -f "$_rf/src/export/csv.js" ] && [ -f "$_rf/tests/test_counter.py" ] \
   && [ -z "$(find "$_rf" -name '*.sh' 2>/dev/null)" ] && [ ! -e "$_rf/.git" ]; then
  ok "T5.ac 실 픽스처 — 질의가 언급하는 파일 존재 · .sh·.git 없음"; else nope "T5.ac" "$(find "$_rf" -type f 2>/dev/null | tr '\n' ' ')"; fi
printf '#!/usr/bin/env bash\nsleep 5\n' > "$TMP/slow-claude"; chmod +x "$TMP/slow-claude"
_run '{}' CLAUDE_BIN="$TMP/slow-claude" LLM_EVAL_TIMEOUT=1 -- --evals
_line e-1 | grep -q 'SKIP(timeout)' && ok "T5.n 시간 초과 → SKIP(timeout)" || nope "T5.n" "$RUN_OUT"
WTO=$((1000 + $$ % 8000))   # 실행별 고유 timeout — 같은 머신의 동시 실행과 pgrep 가 섞이지 않게
_run '{"skills":["karpathy-ko"]}' LLM_EVAL_TIMEOUT="$WTO" -- --trigger
sleep 1
# 워치독 서브셸은 부모 러너의 argv 를 물려받는다(실측) — 러너 경로로 잔존을 센다. 고정 sleep 대신 기한부 대기(병렬 run-all 경합)
_wd=0; _n=0
while :; do _wd=$(pgrep -f "$LE/run-skill-evals.sh" | grep -c .); [ "$_wd" -eq 0 ] || [ "$_n" -ge 6 ] && break; sleep 1; _n=$((_n + 1)); done
_orph=$(pgrep -fx "sleep $WTO" | grep -c .)
if [ "$_orph" -eq 0 ] && [ "$_wd" -eq 0 ]; then ok "T5.o 정상 종료 후 워치독 sleep 고아 0 · 워치독 서브셸 잔존 0 (≤6s)"
else nope "T5.o" "고아 sleep $WTO ${_orph}개 · 워치독 서브셸 ${_wd}개 (6s 후)"
  pkill -fx "sleep $WTO"; pkill -f "$LE/run-skill-evals.sh"; fi
mkdir -p "$TMP/data2/karpathy-ko"
jq -n '{skill:"karpathy-ko",should_trigger:[{id:"pos-1",query:"a\\b\tc"}],should_not_trigger:[{id:"neg-1",query:"q"}]}' > "$TMP/data2/karpathy-ko/trigger-queries.json"
_run '{"skills":["karpathy-ko"]}' SKILL_EVAL_DIR="$TMP/data2" -- --trigger
head -1 "$TMP/args.log" | grep -qF -- "$(printf -- '-p a\\b\tc ')" && ok "T5.p 질의의 백슬래시·탭을 그대로 전달" \
  || nope "T5.p" "$(head -1 "$TMP/args.log")"
# macOS mktemp 는 존재하지 않는 TMPDIR 를 무시하고 기본 경로로 폴백한다(실측) — PATH shim 으로 `mktemp -d` 만 실패시킨다
CWD5Q="$TMP/cwd5q"; mkdir -p "$CWD5Q" "$TMP/failbin"; printf '{"skills":["karpathy-ko"]}\n' > "$TMP/plan.jsonl"; rm -f "$TMP/state"
printf '#!/usr/bin/env bash\ncase " $* " in *" -d "*) exit 1 ;; esac\nexec %s "$@"\n' "$(command -v mktemp)" > "$TMP/failbin/mktemp"
chmod +x "$TMP/failbin/mktemp"
RUN_OUT=$( cd "$CWD5Q" && env -u ANTHROPIC_API_KEY -u SKILL_EVAL_MODE -u LLM_EVAL_RUNS PATH="$TMP/failbin:$PATH" \
  CLAUDE_BIN="$TMP/rec-claude" STUB_PLAN="$TMP/plan.jsonl" STUB_STATE="$TMP/state" SKILL_EVAL_DIR="$DATA" \
  bash "$LE/run-skill-evals.sh" --trigger 2>&1 ); RUN_RC=$?
if _line pos-1 | grep -q 'SKIP(error' && [ ! -e "$CWD5Q/.git" ] && [ ! -e "$CWD5Q/CLAUDE.md" ] && [ "$RUN_RC" -eq 0 ]; then
  ok "T5.q mktemp 실패 → SKIP(error) · 호출자 cwd 에 .git·CLAUDE.md 미생성 · rc 0"
else nope "T5.q" "rc=$RUN_RC cwd=[$(ls -A "$CWD5Q" | tr '\n' ' ')] $RUN_OUT"; fi
# 신호 정리형 워치독 재유입 방지 — flag 폴링 블록(run-pressure-evals run_once 와 동형) 고정 문자열 검사
_rc_body=$(sed -n '/^eval::run_claude()/,/^}/p' "$LE/eval-lib.sh")
if printf '%s' "$_rc_body" | grep -qF 'n=0; while [ "$n" -lt "$lim" ]; do [ -e "$flag" ] || exit 0; sleep 1; n=$((n + 1)); done' \
   && printf '%s' "$_rc_body" | grep -qF 'rm -f "$flag"' && ! printf '%s' "$_rc_body" | grep -qF 'sp=$!'; then
  ok "T5.s eval::run_claude 워치독 = flag 폴링 (신호 정리형 부재)"
else nope "T5.s" "eval::run_claude 에 flag 폴링 블록 부재 또는 신호 정리형 워치독 잔존"; fi

# T6 (AC-7) isolated 미확인 표기 + 단발 실행
_run '{"skills":["advisor-ko"]}\n{"skills":["karpathy-ko"]}' ANTHROPIC_API_KEY=k LLM_EVAL_RUNS=3 -- --trigger
printf '%s' "$RUN_OUT" | grep -q '^SKILL-EVAL: mode=isolated(unverified) trigger ' \
  && ok "T6.a 키 설정 → mode=isolated(unverified)" || nope "T6.a" "$RUN_OUT"
[ "$(cat "$TMP/state" 2>/dev/null)" = "2" ] && ok "T6.b 전부 FAIL + LLM_EVAL_RUNS=3 에도 호출 2회(재시도·N-run 없음)" \
  || nope "T6.b" "stub 호출 $(cat "$TMP/state" 2>/dev/null)회"
_run '{"text":"x"}' -- --evals
printf '%s' "$RUN_OUT" | grep -q '^SKILL-EVAL: mode=routed evals ' && [ "$(cat "$TMP/state")" = "1" ] \
  && ok "T6.c 키 미설정 → mode=routed · evals 호출 1회" || nope "T6.c" "$RUN_OUT"
# T8 (20260930-eval-llm-judge) 진짜 llm_rubric 채점기 · 러너 통합 · 보정 — stub 전용, 토큰 0
JUDGE_VERDICT=""; JUDGE_REASON=""; JUDGE_COST=""   # 구현이 없을 때 unbound variable 로 스위트가 중단되지 않고 단언이 개별 FAIL 하게
_judge() {  # <plan 행(JSON 한 줄)> [bin] → JUDGE_* 전역 (서브셸 밖 직접 호출)
  printf '%s\n' "$1" > "$TMP/jplan.jsonl"; rm -f "$TMP/jstate" "$TMP/args.log"
  STUB_PLAN="$TMP/jplan.jsonl" STUB_STATE="$TMP/jstate" eval::judge_rubric "${2:-$TMP/rec-claude}" "응답본문" "기준문안" 30
}
_judge '{"text":"VERDICT: PASS\n근거 한 줄","cost":0.1}'
[ "$JUDGE_VERDICT" = PASS ] && [ "$JUDGE_REASON" = "근거 한 줄" ] && [ "$JUDGE_COST" = 0.1 ] \
  && ok "T8.a VERDICT: PASS 파싱 · 근거 첫 줄 · 비용" || nope "T8.a" "$JUDGE_VERDICT|$JUDGE_REASON|$JUDGE_COST"
_judge '{"text":"VERDICT: FAIL\n범위를 넘겼다"}'
[ "$JUDGE_VERDICT" = FAIL ] && [ "$JUDGE_REASON" = "범위를 넘겼다" ] && ok "T8.b VERDICT: FAIL 파싱" || nope "T8.b" "$JUDGE_VERDICT|$JUDGE_REASON"
_judge '{"text":"`VERDICT: PASS`\n근거"}'; _f1="$JUDGE_VERDICT"; _judge '{"text":"**VERDICT: FAIL**\n근거"}'; _f2="$JUDGE_VERDICT"
[ "$_f1" = PASS ] && [ "$_f2" = FAIL ] && ok "T8.a2 백틱·굵게로 감싼 첫 줄도 형식 차이로 보고 판정 (의미는 엄격 일치)" || nope "T8.a2" "$_f1|$_f2"
_judge '{"text":"기준을 만족하므로 통과로 봅니다."}'
[ "$JUDGE_VERDICT" = ERROR ] && ok "T8.c VERDICT 줄 없는 산문 → ERROR (산문에서 PASS 를 추정하지 않음)" || nope "T8.c" "$JUDGE_VERDICT"
_judge '{"text":"VERDICT: PASS 그러나 FAIL 일 수도 있다"}'
[ "$JUDGE_VERDICT" = ERROR ] && ok "T8.d 모호한 첫 줄 → ERROR" || nope "T8.d" "$JUDGE_VERDICT"
_judge '{"text":"판정을 내립니다.\nVERDICT: PASS\n근거"}'
[ "$JUDGE_VERDICT" = ERROR ] && ok "T8.e 첫 줄이 아닌 곳의 VERDICT → ERROR" || nope "T8.e" "$JUDGE_VERDICT"
_judge '{}' "$TMP/dead-claude"
[ "$JUDGE_VERDICT" = ERROR ] && printf '%s' "$JUDGE_REASON" | grep -q '채점 호출 실패' && ok "T8.f result 없음 → ERROR · 사유" || nope "T8.f" "$JUDGE_VERDICT|$JUDGE_REASON"
printf '#!/usr/bin/env bash\nprintf "boom: rate limited\\nsecond\\n" >&2\nexit 1\n' > "$TMP/err-claude"; chmod +x "$TMP/err-claude"; _judge '{}' "$TMP/err-claude"
[ "$JUDGE_VERDICT" = ERROR ] && printf '%s' "$JUDGE_REASON" | grep -qF '채점 호출 실패(rc=' && printf '%s' "$JUDGE_REASON" | grep -qF ' — boom: rate limited' && ! printf '%s' "$JUDGE_REASON" | grep -qF second \
  && ok "T8.f2 호출 실패 사유에 claude stderr 첫 줄 부착" || nope "T8.f2" "$JUDGE_REASON"
_x=$(printf 'x%.0s' $(seq 1 100)); _judge '{"text":"VERDICT: FAIL\n\u001b[31m'"$_x"'"}'
[ "${#JUDGE_REASON}" -eq 80 ] && ! printf '%s' "$JUDGE_REASON" | grep -q "$(printf '\033')" && ok "T8.g 근거 80자 절단 · 제어문자 제거" || nope "T8.g" "len=${#JUDGE_REASON}"
_judge '{"text":"VERDICT: PASS\nok"}'
if grep -qF -- '--max-turns 1' "$TMP/args.log" && grep -qF -- '--strict-mcp-config' "$TMP/args.log" \
   && grep -qF -- '--disallowedTools Bash Read Glob Grep Agent Edit Write NotebookEdit WebFetch WebSearch ToolSearch Skill' "$TMP/args.log" \
   && ! grep -qF -- '--model' "$TMP/args.log"; then ok "T8.h 격리 인자 (max-turns 1 · strict-mcp · 도구+Skill 차단 · 기본은 --model 없음)"; else nope "T8.h" "$(head -c 300 "$TMP/args.log")"; fi
LLM_EVAL_JUDGE_MODEL=judge-m _judge '{"text":"VERDICT: PASS\nok"}'
grep -qF -- '--model judge-m' "$TMP/args.log" && ok "T8.i LLM_EVAL_JUDGE_MODEL → --model" || nope "T8.i" "$(head -c 300 "$TMP/args.log")"
cat > "$TMP/cwd-claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$(ls -A | wc -l | tr -d ' ')" >> "$TMP/cwd.log"
exec bash "$LE/stub-claude.sh" "\$@"
EOF
chmod +x "$TMP/cwd-claude"; rm -f "$TMP/cwd.log"; _judge '{"text":"VERDICT: PASS\nok"}' "$TMP/cwd-claude"
[ "$(cat "$TMP/cwd.log" 2>/dev/null)" = 0 ] && ok "T8.j 채점 호출 cwd 는 빈 디렉터리" || nope "T8.j" "cwd 파일 수 $(cat "$TMP/cwd.log" 2>/dev/null)"
mkdir -p "$TMP/data3/karpathy-ko"
jq -n '{skill:"karpathy-ko",cases:[{id:"e-1",prompt:"질문원문XYZ",asserts:[{type:"llm_rubric",value:"기준"}]}]}' > "$TMP/data3/karpathy-ko/evals.json"
_run '{"text":"응답","cost":0.2}\n{"text":"VERDICT: PASS\\n근거","cost":0.1}' SKILL_EVAL_DIR="$TMP/data3" -- --evals
if _line e-1 | grep -q 'PASS' && printf '%s' "$RUN_OUT" | grep -qE 'pass=1 fail=0 skip=0 cost=\$0\.30$'; then
  ok "T8.k 러너: 채점 PASS → 케이스 PASS · 비용 = 응답 + 채점"; else nope "T8.k" "$RUN_OUT"; fi
grep -qxF '[질문]' "$TMP/args.log" && ok "T8.w 러너가 케이스 prompt 를 채점자에게 전달" || nope "T8.w" "채점 호출에 [질문] 섹션 없음"
_run '{"text":"응답"}\n{"text":"VERDICT: FAIL\\n범위를 넘겼다"}' SKILL_EVAL_DIR="$TMP/data3" -- --evals
_line e-1 | grep -qF '첫 실패 llm_rubric:범위를 넘겼다' && printf '%s' "$RUN_OUT" | grep -q 'pass=0 fail=1 skip=0' \
  && ok "T8.l 러너: 채점 FAIL → 사유에 근거" || nope "T8.l" "$RUN_OUT"
_run '{"text":"응답"}\n{"text":"통과로 봅니다"}' SKILL_EVAL_DIR="$TMP/data3" -- --evals
_line e-1 | grep -qF 'SKIP(error: 채점 실패' && printf '%s' "$RUN_OUT" | grep -q 'pass=0 fail=0 skip=1' \
  && ok "T8.m 러너: 채점 ERROR → SKIP (PASS/FAIL 로 세지 않음)" || nope "T8.m" "$RUN_OUT"
# 응답 구분자는 호출마다 다른 nonce — 응답이 구분자를 위조해 채점 지시를 끼워 넣기 어렵게(완전 방어는 아님)
_p1=$(eval::judge_prompt "기준" "응답본문" N123); _p2=$(eval::judge_prompt "기준" "응답본문" N456)
if printf '%s\n' "$_p1" | grep -qxF '[응답-N123 시작]' && printf '%s\n' "$_p1" | grep -qxF '[응답-N123 끝]' && [ "$_p1" != "$_p2" ] \
   && printf '%s\n' "$_p1" | grep -qF -- '`VERDICT: PASS` 또는 `VERDICT: FAIL`'; then ok "T8.u 채점 프롬프트 — nonce 응답 구분자 · 출력 형식 지시"; else nope "T8.u" "$_p1"; fi
# 채점자는 원 질문을 본다 — 질문의 코드와 대조해야 자백 없는 변경을 잡는다
_q1=$(eval::judge_prompt "기준" "응답본문" N1 "질문원문XYZ"); _q0=$(eval::judge_prompt "기준" "응답본문" N1)
if printf '%s\n' "$_q1" | grep -qxF '[질문]' && printf '%s\n' "$_q1" | grep -qxF '질문원문XYZ' && ! printf '%s\n' "$_q0" | grep -qxF '[질문]'; then
  ok "T8.v 채점 프롬프트에 [질문] 섹션 (있을 때만)"; else nope "T8.v" "$_q1"; fi
CAL="$LE/judge-calibration/cases.jsonl"
if [ "$(jq -s 'length' "$CAL")" -eq 10 ] \
   && [ "$(jq -s '[.[]|select((.id|type=="string" and length>0) and (.prompt|type=="string" and length>0) and (.rubric|type=="string" and length>0) and (.response|type=="string" and length>0) and (.note|type=="string" and length>0) and (.expect=="PASS" or .expect=="FAIL"))]|length' "$CAL")" -eq 10 ] \
   && [ "$(jq -s '[.[].id]|unique|length' "$CAL")" -eq 10 ] \
   && [ "$(jq -s '[.[]|select(.expect=="PASS")]|length' "$CAL")" -ge 5 ] && [ "$(jq -s '[.[]|select(.expect=="FAIL")]|length' "$CAL")" -ge 5 ]; then
  ok "T8.n 보정 세트 계약 (10건 · prompt·rubric·response·note 필드 · id 유일 · PASS·FAIL 각 5건 이상)"; else nope "T8.n" "$CAL"; fi
jq -nc '{id:"a",rubric:"r",response:"x",expect:"PASS",note:"n"}' > "$TMP/cal4.jsonl"; jq -nc '{id:"b",rubric:"r",response:"x",expect:"FAIL",note:"n"}' >> "$TMP/cal4.jsonl"
jq -nc '{id:"c",rubric:"r",response:"x",expect:"PASS",note:"n"}' >> "$TMP/cal4.jsonl"; jq -nc '{id:"d",rubric:"r",response:"x",expect:"FAIL",note:"n"}' >> "$TMP/cal4.jsonl"
_cal() {  # <plan 행들(\n)> <claude bin> → 보정 러너 출력
  printf '%b\n' "$1" > "$TMP/cplan.jsonl"; rm -f "$TMP/cstate"
  env CLAUDE_BIN="$2" STUB_PLAN="$TMP/cplan.jsonl" STUB_STATE="$TMP/cstate" JUDGE_CAL_FILE="$TMP/cal4.jsonl" JUDGE_CAL_RUNS=1 bash "$LE/run-judge-calibration.sh" 2>&1
}
_o=$(_cal '{"text":"VERDICT: PASS\\nok"}\n{"text":"VERDICT: FAIL\\nno"}\n{"text":"VERDICT: PASS\\nok"}\n{"text":"VERDICT: FAIL\\nno"}' "$TMP/rec-claude")
printf '%s' "$_o" | grep -q '^CALIBRATION: agree=4/4 false_pass=0 error=0 ' && printf '%s' "$_o" | grep -q '^CALIBRATION-VERDICT: ADOPT$' \
  && ok "T8.o 보정 러너: 기대와 모두 일치 → ADOPT" || nope "T8.o" "$_o"
_o=$(_cal '{"text":"VERDICT: PASS\\nok"}' "$TMP/rec-claude")
printf '%s' "$_o" | grep -q 'false_pass=2 ' && printf '%s' "$_o" | grep -q '^CALIBRATION-VERDICT: REJECT$' \
  && ok "T8.p 보정 러너: 오답을 PASS 로 내는 채점기 → false_pass=2 · REJECT" || nope "T8.p" "$_o"
# 핵심 안전장치: 오답 오통과가 단 1건이면 일치율이 90%(경계)여도 REJECT — 일치율만 보면 관대한 채점기가 통과한다
: > "$TMP/cal10.jsonl"
for _i in 1 2 3 4 5; do jq -nc --arg id "p$_i" '{id:$id,rubric:"r",response:"x",expect:"PASS",note:"n"}' >> "$TMP/cal10.jsonl"; done
for _i in 1 2 3 4 5; do jq -nc --arg id "f$_i" '{id:$id,rubric:"r",response:"x",expect:"FAIL",note:"n"}' >> "$TMP/cal10.jsonl"; done
_pl=""; for _i in 1 2 3 4 5; do _pl="${_pl}"'{"text":"VERDICT: PASS\\nok"}\n'; done
for _i in 1 2 3 4; do _pl="${_pl}"'{"text":"VERDICT: FAIL\\nno"}\n'; done
_pl="${_pl}"'{"text":"VERDICT: PASS\\nleak"}'
printf '%b\n' "$_pl" > "$TMP/cplan10.jsonl"; rm -f "$TMP/cstate10"
_o=$(env CLAUDE_BIN="$TMP/rec-claude" STUB_PLAN="$TMP/cplan10.jsonl" STUB_STATE="$TMP/cstate10" JUDGE_CAL_FILE="$TMP/cal10.jsonl" JUDGE_CAL_RUNS=1 bash "$LE/run-judge-calibration.sh" 2>&1)
printf '%s' "$_o" | grep -q '^CALIBRATION: agree=9/10 false_pass=1 error=0 ' && printf '%s' "$_o" | grep -q '^CALIBRATION-VERDICT: REJECT$' \
  && ok "T8.s 보정 러너: 일치 9/10 이어도 오답 오통과 1건이면 REJECT" || nope "T8.s" "$_o"
_o=$(_cal '{"model":"claude-judge-x","text":"VERDICT: PASS\\nok"}\n{"model":"claude-judge-x","text":"VERDICT: FAIL\\nno"}\n{"model":"claude-judge-x","text":"VERDICT: PASS\\nok"}\n{"model":"claude-judge-x","text":"VERDICT: FAIL\\nno"}' "$TMP/rec-claude")
printf '%s' "$_o" | grep -q '^CALIBRATION-MODEL: claude-judge-x ' && ok "T8.x 보정 러너: 채점 모델 ID 기록 (모델 변경 시 재보정 안내)" || nope "T8.x" "$_o"
_o=$(_cal '{"text":"VERDICT: PASS\\nok"}\n{"text":"VERDICT: FAIL\\nno"}\n{"text":"VERDICT: PASS\\nok"}\n{"text":"VERDICT: FAIL\\nno"}' "$TMP/rec-claude")
printf '%s' "$_o" | grep -q '^CALIBRATION-MODEL: unknown ' && ok "T8.y 모델 ID 를 알 수 없으면 unknown" || nope "T8.y" "$_o"
_o=$(_cal '{}' "$TMP/dead-claude")
printf '%s' "$_o" | grep -q 'agree=0/4 false_pass=0 error=4 ' && printf '%s' "$_o" | grep -q '^CALIBRATION-VERDICT: REJECT$' \
  && ok "T8.q 보정 러너: 채점 오류 → error 집계 · REJECT (일치로 세지 않음)" || nope "T8.q" "$_o"
if grep -q 'run-judge-calibration.sh' "$PLUGIN/CLAUDE.md" && grep -q 'run-judge-calibration.sh' "$PLUGIN/scripts/README.md"; then
  ok "T8.r CLAUDE.md · scripts/README.md 에 보정 러너 등재"; else nope "T8.r" "run-judge-calibration.sh 미등재"; fi
# T7 (AC-6) 문서 등재 — 수동 러너는 CLAUDE.md 테스트 명령 + scripts/README.md llm-eval 절에 적는다
if grep -q 'run-skill-evals.sh' "$PLUGIN/CLAUDE.md" && grep -q 'run-skill-evals.sh' "$PLUGIN/scripts/README.md"; then
  ok "T7 CLAUDE.md · scripts/README.md 등재"; else nope "T7" "run-skill-evals.sh 미등재"; fi
echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
