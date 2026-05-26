#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
RULES="$PLUGIN/hooks/rules.jsonl"

# T5.a rules.jsonl 존재 + 6 룰
if [ -f "$RULES" ]; then
  count=$(jq -s 'length' "$RULES" 2>/dev/null)
  if [ "$count" = "6" ]; then
    PASS=$((PASS+1)); echo "PASS T5.a rules.jsonl 6 룰"
  else
    FAIL=$((FAIL+1)); echo "FAIL T5.a (count=$count expect=6)"
  fi
else
  FAIL=$((FAIL+1)); echo "FAIL T5.a (rules.jsonl 부재)"
fi

# T5.b R-1 ~ R-6 각 룰 필수 필드 완비
for id in R-1 R-2 R-3 R-4 R-5 R-6; do
  hit=$(jq -e --arg id "$id" 'select(.id == $id and .enabled == true and (.principle == 1 or .principle == 5) and (.matcher == "posttool" or .matcher == "stop") and (.severity == "warn"))' "$RULES" 2>/dev/null)
  if [ -n "$hit" ]; then
    PASS=$((PASS+1)); echo "PASS T5.b $id 완비"
  else
    FAIL=$((FAIL+1)); echo "FAIL T5.b $id"
  fi
done

# T5.c matcher 분류: posttool 3개 (R-1/R-2/R-3), stop 3개 (R-4/R-5/R-6)
posttool_count=$(jq -s '[.[] | select(.matcher == "posttool")] | length' "$RULES" 2>/dev/null)
stop_count=$(jq -s '[.[] | select(.matcher == "stop")] | length' "$RULES" 2>/dev/null)
if [ "$posttool_count" = "3" ] && [ "$stop_count" = "3" ]; then
  PASS=$((PASS+1)); echo "PASS T5.c matcher 분류 posttool=3 stop=3"
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

# T6.e R-1 offset 회귀 방지: 2 매칭 transcript 에서 triggering(마지막) 라인 번호 반환
# fixture r1-two-commits-without-verify.jsonl: line 0 = first commit, line 1 = ls, line 2 = second commit
# PostToolUse 는 현재 이벤트 직후 발화 → 마지막 매칭(라인 2)이 triggering
out=$(apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/r1-two-commits-without-verify.jsonl" "Bash" 'git commit -m "feat: second"')
offset=$(echo "$out" | jq -r '.offset' 2>/dev/null)
if [ "$offset" = "2" ]; then
  PASS=$((PASS+1)); echo "PASS T6.e offset=2 (마지막 매칭 라인, 상수 버그 해소 증명)"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.e (offset=$offset, expect 2, out=$out)"
fi

# T6.f R-1 1 매칭 transcript 는 offset=1 (r1-commit-without-verify.jsonl 의 git commit 은 2번째 라인)
out=$(apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" "Bash" 'git commit -m "feat: x"')
offset=$(echo "$out" | jq -r '.offset' 2>/dev/null)
if [ "$offset" = "1" ]; then
  PASS=$((PASS+1)); echo "PASS T6.f offset=1 (단일 매칭 라인 번호)"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.f (offset=$offset, expect 1, out=$out)"
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

# T7.c~g 한국어 변형 5 종 (AC-9 한국어 변형 regex 에 '넘어감' 포함)
for variant in 사용 호출 진입 이동 넘어감; do
  out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-with-korean-${variant}.jsonl" "specops-auto-ko:planning-ko")
  if [ -z "$out" ]; then
    PASS=$((PASS+1)); echo "PASS T7.c-g 한국어 '${variant}' 미매칭"
  else
    FAIL=$((FAIL+1)); echo "FAIL T7.c-g ${variant} (out=$out)"
  fi
done

# T7.g (v0.4-pre W1 정정) R-3 lookback N=3 이내 선언 → 미매칭 (옛 N=1 규약에서는 매칭이었음)
# 의도 변경: 옛 "직전 1 외" 매칭 → 새 "직전 3 이내" 미매칭 (false positive 해소)
out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-with-earlier-declaration.jsonl" "specops-auto-ko:planning-ko")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T7.g 직전 N=3 이내 선언 → 미매칭 (v0.4-pre W1 lookback 확장)"
else
  FAIL=$((FAIL+1)); echo "FAIL T7.g (out=$out)"
fi

# T7.h~T7.l (v0.4-pre W1) R-3 declaration regex 확장 — 한국어 시작/진행 + 영문 invoking/switching + user turn 첫 진입 예외
declare -a r3_extra=(
  "r3-skill-with-korean-시작.jsonl|specops-auto-ko:planning-ko|h|한국어 시작"
  "r3-skill-with-korean-진행.jsonl|specops-auto-ko:clarifying-ko|i|한국어 진행"
  "r3-skill-with-english-invoking.jsonl|specops-auto-ko:decomposing-ko|j|영문 Invoking"
  "r3-skill-with-english-switching.jsonl|specops-auto-ko:verifying-evidence-ko|k|영문 Switching to"
  "r3-skill-after-user-turn.jsonl|specops-auto-ko:specifying-ko|l|user turn /start 첫 진입 예외"
)
for entry in "${r3_extra[@]}"; do
  IFS='|' read -r fix skill letter desc <<< "$entry"
  out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/$fix" "$skill")
  if [ -z "$out" ]; then
    PASS=$((PASS+1)); echo "PASS T7.${letter} R-3 ${desc} → 미매칭 (v0.4-pre W1)"
  else
    FAIL=$((FAIL+1)); echo "FAIL T7.${letter} ${desc} (out=$out)"
  fi
done

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

# T9.c (v0.4-pre W2) R-4 검증 완료 + bash test 실행 → 미매칭
out=$(apply_assertion_without_test_rule "$rule_r4" "$FIXTURES/transcripts/r4-claim-with-bash-runner.jsonl")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T9.c R-4 검증 완료 + bash test 미매칭 (v0.4-pre runner 확장)"
else
  FAIL=$((FAIL+1)); echo "FAIL T9.c (out=$out)"
fi

# T9.d (v0.4-pre W2) R-4 단계 완료만 → 미매칭 (lifecycle 단계 종료 false positive 해소)
out=$(apply_assertion_without_test_rule "$rule_r4" "$FIXTURES/transcripts/r4-claim-stage-only.jsonl")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T9.d R-4 단계 완료만 미매칭 (v0.4-pre 단독 '완료' 제거)"
else
  FAIL=$((FAIL+1)); echo "FAIL T9.d (out=$out)"
fi

# T9.e (v0.4-pre W2) R-4 검증 완료 + runner 부재 → 매칭 (true positive 보존)
out=$(apply_assertion_without_test_rule "$rule_r4" "$FIXTURES/transcripts/r4-claim-verify-without-runner.jsonl")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-4"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T9.e R-4 검증 완료 + runner 부재 매칭 (true positive)"
else
  FAIL=$((FAIL+1)); echo "FAIL T9.e (out=$out)"
fi

# R-5 용 transcript fixture 치환 헬퍼 (Edit — 기존 파일 수정)
make_r5_transcript() {
  local spec_path="$1"
  local out="$2"
  printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Edit","input":{"file_path":"%s","old_string":"x","new_string":"y"}}]}}\n' "$spec_path" > "$out"
}

# T10.a R-5 data row 1+ → 미매칭
rule_r5=$(jq -c 'select(.id == "R-5")' "$PLUGIN/hooks/rules.jsonl")
tmp=$(mktemp -d); cp "$FIXTURES/r5-with-data-row.md" "$tmp/spec.md"
make_r5_transcript "$tmp/spec.md" "$tmp/transcript.jsonl"
out=$(apply_advisor_section_rule "$rule_r5" "$tmp/transcript.jsonl")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T10.a data row 존재 → 미매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T10.a (out=$out)"
fi
rm -rf "$tmp"

# T10.b R-5 "해당 없음" 문자열 → 미매칭
tmp=$(mktemp -d); cp "$FIXTURES/r5-with-haedang-eopseum.md" "$tmp/spec.md"
make_r5_transcript "$tmp/spec.md" "$tmp/transcript.jsonl"
out=$(apply_advisor_section_rule "$rule_r5" "$tmp/transcript.jsonl")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T10.b '해당 없음' → 미매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T10.b (out=$out)"
fi
rm -rf "$tmp"

# T10.c R-5 빈 섹션 → 매칭
tmp=$(mktemp -d); cp "$FIXTURES/r5-empty-section.md" "$tmp/spec.md"
make_r5_transcript "$tmp/spec.md" "$tmp/transcript.jsonl"
out=$(apply_advisor_section_rule "$rule_r5" "$tmp/transcript.jsonl")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-5"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T10.c 빈 섹션 → 매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T10.c (out=$out)"
fi
rm -rf "$tmp"

# T10.d R-5 섹션 자체 부재 → 매칭
tmp=$(mktemp -d); cp "$FIXTURES/r5-no-section.md" "$tmp/spec.md"
make_r5_transcript "$tmp/spec.md" "$tmp/transcript.jsonl"
out=$(apply_advisor_section_rule "$rule_r5" "$tmp/transcript.jsonl")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-5"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T10.d 섹션 부재 → 매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T10.d (out=$out)"
fi
rm -rf "$tmp"

# T10.e R-5 MultiEdit 으로 수정 + 빈 섹션 → 매칭 (MAJOR 2: Write/Edit 외 MultiEdit 도 감지)
tmp=$(mktemp -d); cp "$FIXTURES/r5-empty-section.md" "$tmp/spec.md"
printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"MultiEdit","input":{"file_path":"%s","edits":[]}}]}}\n' "$tmp/spec.md" > "$tmp/transcript.jsonl"
out=$(apply_advisor_section_rule "$rule_r5" "$tmp/transcript.jsonl")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-5"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T10.e MultiEdit + 빈 섹션 → 매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T10.e (out=$out)"
fi
rm -rf "$tmp"

# T10.g (U1) R-5 §유형: trivial + 빈 섹션 → 미매칭 (trivial skip)
tmp=$(mktemp -d)
cat > "$tmp/spec.md" <<'EOF'
# Spec

## 1. 개요
**§유형**: trivial

## 9. Advisor 협의 기록

| 일시 | 질의 요지 | advisor 권고 | 채택 여부 | 반영 위치 |
|---|---|---|---|---|

## 10. 참조
EOF
make_r5_transcript "$tmp/spec.md" "$tmp/transcript.jsonl"
out=$(apply_advisor_section_rule "$rule_r5" "$tmp/transcript.jsonl")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T10.g (U1) §유형: trivial + 빈 섹션 → 미매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T10.g (out=$out)"
fi
rm -rf "$tmp"

# T10.h (U1) R-5 §유형: 유지보수 + 빈 섹션 → 매칭 (회귀 보호 — trivial 만 skip)
tmp=$(mktemp -d)
cat > "$tmp/spec.md" <<'EOF'
# Spec

## 1. 개요
**§유형**: 유지보수

## 9. Advisor 협의 기록

| 일시 | 질의 요지 | advisor 권고 | 채택 여부 | 반영 위치 |
|---|---|---|---|---|

## 10. 참조
EOF
make_r5_transcript "$tmp/spec.md" "$tmp/transcript.jsonl"
out=$(apply_advisor_section_rule "$rule_r5" "$tmp/transcript.jsonl")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-5"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T10.h (U1) §유형: 유지보수 + 빈 섹션 → 매칭 (회귀 보호)"
else
  FAIL=$((FAIL+1)); echo "FAIL T10.h (out=$out)"
fi
rm -rf "$tmp"

# T7.m R-3 full name 선언 (specops-auto-ko:<short>) → 미매칭 (v0.4b W1)
out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-with-fullname-declaration.jsonl" "specops-auto-ko:planning-ko")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T7.m R-3 full name 선언 → 미매칭 (v0.4b W1)"
else
  FAIL=$((FAIL+1)); echo "FAIL T7.m (out=$out)"
fi

# T7.n R-3 lifecycle chain 자동 호출 → 미매칭 (v0.5 W1)
# fixture: requesting-code-review-ko 직후 receiving-code-review-ko 자동 chain
out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-chain-auto-next.jsonl" "specops-auto-ko:receiving-code-review-ko")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T7.n R-3 lifecycle chain 자동 호출 → 미매칭 (v0.5 W1)"
else
  FAIL=$((FAIL+1)); echo "FAIL T7.n (out=$out)"
fi

# T10.f R-5 Write(신규 생성) + 섹션 부재 → 미매칭 (v0.5 W2 — fresh Write는 advisor 불필요)
tmp=$(mktemp -d); cp "$FIXTURES/r5-no-section.md" "$tmp/plan.md"
printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Write","input":{"file_path":"%s","content":"x"}}]}}\n' "$tmp/plan.md" > "$tmp/transcript.jsonl"
out=$(apply_advisor_section_rule "$rule_r5" "$tmp/transcript.jsonl")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T10.f Write(신규 생성) + 섹션 부재 → 미매칭 (v0.5 W2)"
else
  FAIL=$((FAIL+1)); echo "FAIL T10.f (out=$out)"
fi
rm -rf "$tmp"

# T11.a log_friction dedup — 같은 rule_id + snippet 두 번 호출 시 1건만 기록
tmp=$(mktemp -d)
(cd "$tmp" &&
  source "$PLUGIN/hooks/governance-lib.sh" &&
  log_friction "20260426-test-fid" "R-5" 1 "섹션 부재: plan.md" 10 &&
  log_friction "20260426-test-fid" "R-5" 1 "섹션 부재: plan.md" 10)
count=$(wc -l < "$tmp/.specops/20260426-test-fid/friction-log.jsonl" 2>/dev/null | tr -d ' ')
if [ "$count" = "1" ]; then
  PASS=$((PASS+1)); echo "PASS T11.a log_friction dedup — 중복 skip (v0.4b W1)"
else
  FAIL=$((FAIL+1)); echo "FAIL T11.a (count=$count expect=1)"
fi
rm -rf "$tmp"

# ── U8 회귀: detect_fid first-only 버그 ─────────

# T12.a (U8) active-fid 마커 우선 — 다중 ## 헤더 환경에서도 마커 FID 반환
tmp=$(mktemp -d)
mkdir -p "$tmp/.specops" && cat > "$tmp/.specops/session-progress.md" <<'EOF'
# Session Progress
<!-- active-fid: 20260601-newer-fid -->

## 20260401-older-fid
old entry

## 20260601-newer-fid
new entry
EOF
result=$(cd "$tmp" && source "$PLUGIN/hooks/governance-lib.sh"; detect_fid)
if [ "$result" = "20260601-newer-fid" ]; then
  PASS=$((PASS+1)); echo "PASS T12.a (U8) active-fid 마커 우선 (다중 ## 헤더 환경)"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.a (got='$result')"
fi
rm -rf "$tmp"

# T12.b (U8) 마커 부재 → 첫 ## 헤더 fallback (기존 동작 보존)
tmp=$(mktemp -d)
result=$(cd "$tmp" && mkdir -p .specops && cat > .specops/session-progress.md <<'EOF'
# Session Progress

## 20260401-first-fid
entry
EOF
  source "$PLUGIN/hooks/governance-lib.sh"; detect_fid)
if [ "$result" = "20260401-first-fid" ]; then
  PASS=$((PASS+1)); echo "PASS T12.b (U8) 마커 부재 → 첫 ## 헤더 fallback"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.b (got='$result')"
fi
rm -rf "$tmp"

# T12.c (U8) session-progress.md 자체 부재 → 빈 결과
tmp=$(mktemp -d)
result=$(cd "$tmp" && source "$PLUGIN/hooks/governance-lib.sh"; detect_fid)
if [ -z "$result" ]; then
  PASS=$((PASS+1)); echo "PASS T12.c (U8) session-progress.md 부재 → 빈 결과"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.c (got='$result')"
fi
rm -rf "$tmp"

# ── R-6 (T-R6) 테스트 섹션 ─────────

# T-R6.0 fixture 존재 검증
for fx in r6-verify-with-gbrain r6-verify-without-gbrain r6-no-verify r6-verify-no-evidence r6-multi-verify; do
  if [ -f "$FIXTURES/transcripts/$fx.jsonl" ]; then
    PASS=$((PASS+1)); echo "PASS T-R6.0 fixture $fx 존재"
  else
    FAIL=$((FAIL+1)); echo "FAIL T-R6.0 fixture $fx 부재"
  fi
done

# T-R6.1 PASS 케이스 (verify + evidence + gbrain) → 빈 출력
rule_r6=$(jq -c 'select(.id == "R-6")' "$PLUGIN/hooks/rules.jsonl")
out=$(apply_gbrain_absence_rule "$rule_r6" "$FIXTURES/transcripts/r6-verify-with-gbrain.jsonl")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T-R6.1 PASS 케이스 미매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.1 PASS 케이스가 매칭됨: $out"
fi

# T-R6.2 FAIL 케이스 (verify + evidence O, gbrain X) → 매칭 + fid 추출
out=$(apply_gbrain_absence_rule "$rule_r6" "$FIXTURES/transcripts/r6-verify-without-gbrain.jsonl")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-6"' >/dev/null; then
  fid=$(echo "$out" | jq -r '.fid')
  if [ "$fid" = "20260526-r6-gbrain-soft-warn" ]; then
    PASS=$((PASS+1)); echo "PASS T-R6.2 FAIL 케이스 매칭 + fid 추출"
  else
    FAIL=$((FAIL+1)); echo "FAIL T-R6.2 fid 추출 오류: $fid"
  fi
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.2 FAIL 케이스 미매칭"
fi

# T-R6.3 no-verify → 미매칭
out=$(apply_gbrain_absence_rule "$rule_r6" "$FIXTURES/transcripts/r6-no-verify.jsonl")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T-R6.3 no-verify 미매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.3 no-verify 가 매칭됨"
fi

# T-R6.4 verify-no-evidence → 미매칭
out=$(apply_gbrain_absence_rule "$rule_r6" "$FIXTURES/transcripts/r6-verify-no-evidence.jsonl")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T-R6.4 verify-no-evidence 미매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.4 verify-no-evidence 가 매칭됨"
fi

# T-R6.5 enabled=false → load_rules 결과에 R-6 부재
rule_r6_disabled=$(jq -c 'select(.id == "R-6") | .enabled = false' "$PLUGIN/hooks/rules.jsonl")
matcher_count=$(echo "$rule_r6_disabled" | jq -r 'select(.enabled == false and .matcher == "stop") | .id' | wc -l | tr -d ' ')
if [ "$matcher_count" = "1" ]; then
  PASS=$((PASS+1)); echo "PASS T-R6.5 enabled=false 시 비활성 가능 (jq 변환 검증)"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.5 enabled toggle"
fi

# T-R6.6 멱등성 — 동일 transcript 2회 실행 시 동일 출력
out1=$(apply_gbrain_absence_rule "$rule_r6" "$FIXTURES/transcripts/r6-verify-without-gbrain.jsonl")
out2=$(apply_gbrain_absence_rule "$rule_r6" "$FIXTURES/transcripts/r6-verify-without-gbrain.jsonl")
if [ "$out1" = "$out2" ] && [ -n "$out1" ]; then
  PASS=$((PASS+1)); echo "PASS T-R6.6 멱등성 — 동일 출력"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.6 출력 불일치 또는 빈 값"
fi

# T-R6.7 multi-verify — 가장 최근 verify+evidence (FID-new) 만 매칭, fid=FID-new
out=$(apply_gbrain_absence_rule "$rule_r6" "$FIXTURES/transcripts/r6-multi-verify.jsonl")
if [ -n "$out" ]; then
  fid=$(echo "$out" | jq -r '.fid')
  if [ "$fid" = "FID-new" ]; then
    PASS=$((PASS+1)); echo "PASS T-R6.7 multi-verify — 가장 최근 (FID-new) 매칭"
  else
    FAIL=$((FAIL+1)); echo "FAIL T-R6.7 fid=$fid (FID-new 기대)"
  fi
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.7 multi-verify 미매칭"
fi

# T-R6.7b stop-governance.sh case 문에 R-6 라우팅 존재 검증
if grep -q 'R-6) result=$(apply_gbrain_absence_rule' "$PLUGIN/hooks/stop-governance.sh"; then
  PASS=$((PASS+1)); echo "PASS T-R6.7b case 라우팅 존재"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.7b case 라우팅 부재"
fi

# T-R6.8 trivial-skip — §유형 trivial spec.md 옆 evidence.md 일 때 skip
tmpfid_dir=$(mktemp -d)
mkdir -p "$tmpfid_dir/.specops/trivial-test-fid"
cat > "$tmpfid_dir/.specops/trivial-test-fid/spec.md" <<'EOF'
# trivial spec
**§유형**: trivial
EOF
tmp_fixture="$tmpfid_dir/r6-trivial.jsonl"
# evidence.md path 절대경로 사용 — sed 의 [^/]+ 패턴 매칭은 디렉토리 마지막 segment 사용
ev_path="$tmpfid_dir/.specops/trivial-test-fid/evidence.md"
printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"specops-auto-ko:verifying-evidence-ko"}}]}}\n' > "$tmp_fixture"
printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Write","input":{"file_path":"%s","content":"# evidence"}}]}}\n' "$ev_path" >> "$tmp_fixture"
out=$(apply_gbrain_absence_rule "$rule_r6" "$tmp_fixture")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T-R6.8 trivial-skip — §유형 trivial 시 skip"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.8 trivial 인데 매칭됨: $out"
fi
rm -rf "$tmpfid_dir"

# T-R6.9 Edit tool 로 evidence.md 작성 (외부 review 후속 fix)
# Edit 도 Write 와 동일하게 evidence.md 산출로 인정. gbrain 부재 시 매칭, fid 추출 정상.
out=$(apply_gbrain_absence_rule "$rule_r6" "$FIXTURES/transcripts/r6-verify-edit-evidence.jsonl")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-6"' >/dev/null; then
  fid=$(echo "$out" | jq -r '.fid')
  if [ "$fid" = "20260526-r6-fix-followup" ]; then
    PASS=$((PASS+1)); echo "PASS T-R6.9 Edit tool evidence 매칭 + fid 추출"
  else
    FAIL=$((FAIL+1)); echo "FAIL T-R6.9 fid=$fid (20260526-r6-fix-followup 기대)"
  fi
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.9 Edit tool evidence 미매칭 (gbrain 부재인데 매칭 안 됨)"
fi

# T-R6.10 gbrain_runner_pattern false-PASS 회귀 (외부 review #2 fix)
# specops-auto-ko:gbrain 조회만으로 R-6 silence 되지 않음 검증.
tmpfx2=$(mktemp)
cat > "$tmpfx2" <<'EOF'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"specops-auto-ko:verifying-evidence-ko"}}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Write","input":{"file_path":".specops/20260526-r6-fix-followup/evidence.md","content":"# evidence"}}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"specops-auto-ko:gbrain"}}]}}
EOF
out=$(apply_gbrain_absence_rule "$rule_r6" "$tmpfx2")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-6"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T-R6.10 gbrain (조회 skill) 호출만으로 silence 안 됨 — 매칭 발화"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.10 gbrain 조회만으로 R-6 silence 됨 (false PASS)"
fi
rm -f "$tmpfx2"

# T-R6.11 Bash invocation 단독 evidence 매칭 (외부 review #3 fix — dogfood 경로)
# bash scripts/_internal/run-verification.sh <FID> invocation 만으로 evidence 의도 인정.
out=$(apply_gbrain_absence_rule "$rule_r6" "$FIXTURES/transcripts/r6-verify-bash-invocation-only.jsonl")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-6"' >/dev/null; then
  fid=$(echo "$out" | jq -r '.fid')
  if [ "$fid" = "20260526-bash-redirect-evidence" ]; then
    PASS=$((PASS+1)); echo "PASS T-R6.11 Bash invocation 단독 매칭 + fid 추출"
  else
    FAIL=$((FAIL+1)); echo "FAIL T-R6.11 fid=$fid (20260526-bash-redirect-evidence 기대)"
  fi
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.11 Bash invocation 단독 미매칭 (gbrain 부재인데 매칭 안 됨)"
fi

# T-R6.12 Bash invocation + gbrain runner → PASS (silence)
out=$(apply_gbrain_absence_rule "$rule_r6" "$FIXTURES/transcripts/r6-verify-bash-invocation-with-gbrain.jsonl")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T-R6.12 Bash invocation + gbrain runner → silence"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.12 gbrain 호출됐는데 매칭됨: $out"
fi

# T-R6.13 trivial-skip with Bash invocation (AC-5 — invocation 분기 trivial 보존)
# T-R6.8 mktemp 동적 fixture 패턴 응용 — invocation 분기에서도 trivial-skip 발동 검증
tmpfid_dir2=$(mktemp -d)
mkdir -p "$tmpfid_dir2/.specops/trivial-invocation-fid"
cat > "$tmpfid_dir2/.specops/trivial-invocation-fid/spec.md" <<'EOF'
# trivial spec
**§유형**: trivial
EOF
tmp_fixture2="$tmpfid_dir2/r6-trivial-invocation.jsonl"
printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"specops-auto-ko:verifying-evidence-ko"}}]}}\n' > "$tmp_fixture2"
printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"bash scripts/_internal/run-verification.sh trivial-invocation-fid"}}]}}\n' >> "$tmp_fixture2"
# trivial-skip 은 last_evi_path 의 dirname 기준 spec.md 조회 — CWD 기반 상대경로라 tmpfid_dir2 진입 필요
out=$(cd "$tmpfid_dir2" && apply_gbrain_absence_rule "$rule_r6" "$tmp_fixture2")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T-R6.13 trivial-skip with Bash invocation"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.13 trivial 인데 invocation 으로 매칭됨: $out"
fi
rm -rf "$tmpfid_dir2"

# T-R6.14 mixed Write+Bash invocation line max 선택 (AC-3 직접 검증, Phase C M1 fix)
# r6-verify-bash-invocation.jsonl 가 Write(line 2) + Bash invocation(line 3) 동시 보유 — while-loop 가 line_no 더 큰 Bash 분기 결과 채택해야 함
out=$(apply_gbrain_absence_rule "$rule_r6" "$FIXTURES/transcripts/r6-verify-bash-invocation.jsonl")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-6"' >/dev/null; then
  fid=$(echo "$out" | jq -r '.fid')
  offset=$(echo "$out" | jq -r '.offset')
  # AC-3 핵심: Bash line (offset=2, 0-based) 채택 — Write line(1) 보다 큼
  if [ "$fid" = "20260526-bash-redirect-evidence" ] && [ "$offset" = "2" ]; then
    PASS=$((PASS+1)); echo "PASS T-R6.14 mixed Write+Bash line max 선택 (offset=2 Bash 채택)"
  else
    FAIL=$((FAIL+1)); echo "FAIL T-R6.14 fid=$fid offset=$offset (fid=20260526-bash-redirect-evidence offset=2 기대)"
  fi
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.14 mixed fixture 미매칭"
fi

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
