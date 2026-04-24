#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
RULES="$PLUGIN/hooks/rules.jsonl"

# T5.a rules.jsonl 존재 + 5 룰
if [ -f "$RULES" ]; then
  count=$(jq -s 'length' "$RULES" 2>/dev/null)
  if [ "$count" = "5" ]; then
    PASS=$((PASS+1)); echo "PASS T5.a rules.jsonl 5 룰"
  else
    FAIL=$((FAIL+1)); echo "FAIL T5.a (count=$count expect=5)"
  fi
else
  FAIL=$((FAIL+1)); echo "FAIL T5.a (rules.jsonl 부재)"
fi

# T5.b R-1 ~ R-5 각 룰 필수 필드 완비
for id in R-1 R-2 R-3 R-4 R-5; do
  hit=$(jq -e --arg id "$id" 'select(.id == $id and .enabled == true and (.principle == 1 or .principle == 5) and (.matcher == "posttool" or .matcher == "stop") and (.severity == "warn"))' "$RULES" 2>/dev/null)
  if [ -n "$hit" ]; then
    PASS=$((PASS+1)); echo "PASS T5.b $id 완비"
  else
    FAIL=$((FAIL+1)); echo "FAIL T5.b $id"
  fi
done

# T5.c matcher 분류: posttool 3개 (R-1/R-2/R-3), stop 2개 (R-4/R-5)
posttool_count=$(jq -s '[.[] | select(.matcher == "posttool")] | length' "$RULES" 2>/dev/null)
stop_count=$(jq -s '[.[] | select(.matcher == "stop")] | length' "$RULES" 2>/dev/null)
if [ "$posttool_count" = "3" ] && [ "$stop_count" = "2" ]; then
  PASS=$((PASS+1)); echo "PASS T5.c matcher 분류 posttool=3 stop=2"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.c (posttool=$posttool_count stop=$stop_count)"
fi

# T6.a R-1 verify 부재 → 매칭
source "$PLUGIN/hooks/governance-lib.sh"
FIXTURES="$PLUGIN/scripts/tests/governance/fixtures"
rule_r1=$(jq -c 'select(.id == "R-1")' "$PLUGIN/hooks/rules.jsonl")
out=$(apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" "Bash" 'git commit -m "feat: x"')
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-1"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T6.a R-1 verify 부재 → 매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.a (out=$out)"
fi

# T6.b R-1 verify 있음 → 미매칭
out=$(apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/r1-commit-with-verify.jsonl" "Bash" 'git commit -m "feat: x"')
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T6.b R-1 verify 있음 → 미매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.b (out=$out)"
fi

# T6.c R-1 trigger 명령 불일치 (Bash ls) → 미매칭
out=$(apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" "Bash" 'ls -la')
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T6.c trigger 불일치 → 미매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.c (out=$out)"
fi

# T6.d R-2 gh pr create + verify 부재 → 매칭 (R-2 는 R-1 과 동일 로직 검증)
rule_r2=$(jq -c 'select(.id == "R-2")' "$PLUGIN/hooks/rules.jsonl")
out=$(apply_lookback_rule "$rule_r2" "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" "Bash" 'gh pr create --title "x"')
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-2"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T6.d R-2 gh pr create 매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.d (out=$out)"
fi

# T7.a R-3 선언 부재 → 매칭
out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-without-declaration.jsonl" "specops-auto-ko:planning-ko")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-3"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T7.a R-3 선언 부재 매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T7.a (out=$out)"
fi

# T7.b R-3 영문 Using 선언 → 미매칭
out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-with-english-declaration.jsonl" "specops-auto-ko:planning-ko")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T7.b Using 영문 선언 미매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T7.b (out=$out)"
fi

# T7.c~f 한국어 변형 4 종
for variant in 사용 호출 진입 이동; do
  out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-with-korean-${variant}.jsonl" "specops-auto-ko:planning-ko")
  if [ -z "$out" ]; then
    PASS=$((PASS+1)); echo "PASS T7.c-f 한국어 '${variant}' 미매칭"
  else
    FAIL=$((FAIL+1)); echo "FAIL T7.c-f ${variant} (out=$out)"
  fi
done

# T7.g R-3 직전 1 메시지 아닌 더 앞의 선언 → 매칭 (느슨 규약: Q-C "직전 1 assistant 메시지" 만 검사)
out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-with-earlier-declaration.jsonl" "specops-auto-ko:planning-ko")
if [ -n "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T7.g 직전 1 외 선언 → 매칭 (Q-C 느슨 규약)"
else
  FAIL=$((FAIL+1)); echo "FAIL T7.g (out=$out)"
fi

# T9.a R-4 성공 주장 + test runner 부재 → 매칭
rule_r4=$(jq -c 'select(.id == "R-4")' "$PLUGIN/hooks/rules.jsonl")
out=$(apply_assertion_without_test_rule "$rule_r4" "$FIXTURES/transcripts/r4-claim-without-runner.jsonl")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-4"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T9.a R-4 claim without runner 매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T9.a (out=$out)"
fi

# T9.b R-4 성공 주장 + bats 실행 있음 → 미매칭
out=$(apply_assertion_without_test_rule "$rule_r4" "$FIXTURES/transcripts/r4-claim-with-runner.jsonl")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T9.b R-4 claim with runner 미매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T9.b (out=$out)"
fi

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
