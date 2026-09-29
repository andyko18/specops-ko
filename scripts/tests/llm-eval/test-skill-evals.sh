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
echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
