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

# T5.b R-1 ~ R-5 각 룰 필수 필드 완비 (R-6 disabled — gbrain-ko manual-only 설계)
for id in R-1 R-2 R-3 R-4 R-5; do
  hit=$(jq -e --arg id "$id" 'select(.id == $id and .enabled == true and (.principle == 1 or .principle == 5) and (.matcher == "posttool" or .matcher == "stop") and (.severity == "warn"))' "$RULES" 2>/dev/null)
  if [ -n "$hit" ]; then
    PASS=$((PASS+1)); echo "PASS T5.b $id 완비"
  else
    FAIL=$((FAIL+1)); echo "FAIL T5.b $id"
  fi
done

# T5.c matcher 분류: posttool 3개 (R-1/R-2/R-3), stop 2개 (R-4/R-5 — R-6 disabled)
posttool_count=$(jq -s '[.[] | select(.matcher == "posttool" and .enabled == true)] | length' "$RULES" 2>/dev/null)
stop_count=$(jq -s '[.[] | select(.matcher == "stop" and .enabled == true)] | length' "$RULES" 2>/dev/null)
if [ "$posttool_count" = "3" ] && [ "$stop_count" = "2" ]; then
  PASS=$((PASS+1)); echo "PASS T5.c matcher 분류 posttool=3 stop=2"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.c (posttool=$posttool_count stop=$stop_count)"
fi

# T6.a R-1 verify 부재 → 매칭
source "$PLUGIN/hooks/governance-lib.sh"
FIXTURES="$PLUGIN/scripts/tests/governance/fixtures"
rule_r1=$(jq -c 'select(.id == "R-1")' "$PLUGIN/hooks/rules.jsonl")
# T6 격리: apply_lookback_rule 이 detect_fid → 실 repo .specops/session-progress.md 의
# /verify PASS 를 읽어 위반을 면제(false-negative)하지 않도록 빈 cwd 로 격리 (governance-lookback-fix).
# T6.* 케이스는 전부 절대경로($PLUGIN/$FIXTURES) 인자만 사용 → cwd 변경 무해. T7+ 는 자체 mktemp/subshell 격리.
_t6_orig=$PWD; _t6_sb=$(mktemp -d) || exit 1; cd "$_t6_sb" || exit 1
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

# T6.g R-1 bare VAR=val prefix 우회 → 매칭 (F-2 회귀)
out=$(apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" "Bash" 'FOO=bar git commit -m "x"')
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-1"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T6.g R-1 bare VAR=val prefix 우회 매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.g R-1 bare VAR=val prefix 우회 — out: $out"
fi
# T6.h R-1 git -c 옵션 우회 → 매칭 (F-1 회귀)
out=$(apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" "Bash" 'git -c k=v commit -m "x"')
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-1"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T6.h R-1 git -c 옵션 우회 매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.h R-1 git -c 옵션 우회 — out: $out"
fi
# T6.i R-1 over-match 제거: git <opt> <arg> commit(commit=ref명) → 미매칭(allow)
out=$(apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" "Bash" 'git --no-pager log commit')
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T6.i R-1 over-match 미매칭(allow)"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.i R-1 over-match — 매칭됨(deny): $out"
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
# T6.hd (AC-7) 감사 경로(apply_lookback_rule)에도 heredoc 전처리 적용 — pretool L35 는 이 경로 **앞**에서
#   차단하므로 pretool 테스트로는 여기가 검증되지 않는다(assert-by-assumption 방지 — 독립 케이스로 잠근다).
hd_doc=$'cat > spec.md <<EOF\ngit commit -m "예시"\nEOF'
out=$(apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" "Bash" "$hd_doc")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T6.hd (AC-7) heredoc 문서 본문 → 감사 미매칭(오탐 제거)"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.hd (AC-7) heredoc 본문 오탐 — out: $out"
fi
# T6.hd2 (AC-5) 감사 경로도 실행자 heredoc 본문은 유지 → 매칭 보존
hd_bash=$'bash <<EOF\ngit commit -m x\nEOF'
out=$(apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/r1-commit-without-verify.jsonl" "Bash" "$hd_bash")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-1"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T6.hd2 (AC-5) 감사 경로 bash <<EOF 본문 → 매칭 유지"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.hd2 (AC-5) 실행자 heredoc 미매칭 — out: $out"
fi
# ── Wave A — R-1 implement 창 = task receipt 필수 (실행증거 fallthrough 폐지) ──
# implement 창(tasks.md 존재·evidence.md 부재)에서 receipt 없거나 무효면 deny.
# 격리: 각 케이스 자체 sandbox 에 .specops/session-progress.md + tasks.md 구성.
_bfid="20260101-x"
_b_setup() {  # $1=sandbox dir, $2=evidence?(yes/no)
  mkdir -p "$1/.specops/$_bfid"
  printf '## %s\n\n- 2026-01-01 10:00 /implement DONE (T1)\n' "$_bfid" > "$1/.specops/session-progress.md"
  echo "tasks" > "$1/.specops/$_bfid/tasks.md"
  [ "$2" = "yes" ] && echo "# evidence (no stamp)" > "$1/.specops/$_bfid/evidence.md"
}

# T6.B1 (AC-1): 실행증거만으로는 더 이상 면제 아님 → R-1 매칭(deny)
_sb1=$(mktemp -d); _b_setup "$_sb1" no
out=$(cd "$_sb1" && apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/exec-evidence-pass.jsonl" "Bash" 'git commit -m "feat: T1"')
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-1"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T6.B1 (AC-1) implement 창 실행증거-only → deny (receipt 필수)"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.B1 (AC-1) 실행증거-only 면제 잔존 — out: $out"
fi
rm -rf "$_sb1"

# T6.B1b: 유효 receipt + staged⊆outputs → 면제 (exec 불요)
_sb1b=$(mktemp -d)
mkdir -p "$_sb1b/.specops/$_bfid" "$_sb1b/scripts/tests" "$_sb1b/src"
printf '<!-- active-fid: %s -->\n## %s\n- 2026-01-01 10:00 /implement DONE (T1)\n' "$_bfid" "$_bfid" \
  > "$_sb1b/.specops/session-progress.md"
printf 'echo ok\n' > "$_sb1b/scripts/tests/test-foo.sh"; chmod +x "$_sb1b/scripts/tests/test-foo.sh"
printf 'x\n' > "$_sb1b/src/foo.sh"
cat > "$_sb1b/.specops/$_bfid/tasks.md" <<'EOF'
# tasks
## 의존 그래프
```yaml
tasks:
  - id: T1
    test_command: "bash scripts/tests/test-foo.sh"
    depends_on: []
    inputs: []
    outputs: [src/foo.sh, scripts/tests/test-foo.sh]
    ac: [AC-1]
```
EOF
(cd "$_sb1b" && git init -q && git add src scripts && git -c user.name=t -c user.email=t@e.com commit -qm init)
printf 'updated\n' > "$_sb1b/src/foo.sh"
(cd "$_sb1b" && bash "$PLUGIN/scripts/_internal/record-task-receipt.sh" "$_bfid" T1) >/dev/null
(cd "$_sb1b" && git add src/foo.sh scripts/tests/test-foo.sh)
out=$(cd "$_sb1b" && apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/exec-evidence-absent.jsonl" \
  "Bash" 'git commit -m "feat: T1"')
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T6.B1b 유효 receipt → R-1 면제"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.B1b receipt 면제 실패 — out: $out"
fi
rm -rf "$_sb1b"

# T6.B2 (AC-2): receipt 없음 → 매칭(deny) — 실행증거 유무와 무관
_sb2=$(mktemp -d); _b_setup "$_sb2" no
out=$(cd "$_sb2" && apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/exec-evidence-absent.jsonl" "Bash" 'git commit -m "feat: T1"')
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-1"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T6.B2 (AC-2) receipt 없으면 deny"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.B2 (AC-2) receipt 없이 면제됨 — out: $out"
fi
rm -rf "$_sb2"

# T6.B3 (AC-3): evidence.md 존재 → implement 창 닫힘 → verify 앵커 없으면 매칭(deny)
_sb3=$(mktemp -d); _b_setup "$_sb3" yes
out=$(cd "$_sb3" && apply_lookback_rule "$rule_r1" "$FIXTURES/transcripts/exec-evidence-pass.jsonl" "Bash" 'git commit -m "feat: T1"')
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-1"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T6.B3 (AC-3) evidence.md 존재 시 implement receipt 경로 닫힘"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.B3 (AC-3) evidence 존재해도 면제 — out: $out"
fi
rm -rf "$_sb3"

# T6 격리 해제 — 원 repo cwd 복귀 (T7+ 는 자체 mktemp/subshell 격리)
cd "$_t6_orig" || exit 1; rm -rf "$_t6_sb"

# T7.a R-3 선언 부재 → 매칭
out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-without-declaration.jsonl" "specops-ko:planning-ko")
if [ -n "$out" ] && echo "$out" | jq -e '.rule_id == "R-3"' >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T7.a R-3 선언 부재 매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T7.a (out=$out)"
fi

# T7.b R-3 영문 Using 선언 → 미매칭
out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-with-english-declaration.jsonl" "specops-ko:planning-ko")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T7.b Using 영문 선언 미매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T7.b (out=$out)"
fi

# T7.c~g 한국어 변형 5 종 (AC-9 한국어 변형 regex 에 '넘어감' 포함)
for variant in 사용 호출 진입 이동 넘어감; do
  out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-with-korean-${variant}.jsonl" "specops-ko:planning-ko")
  if [ -z "$out" ]; then
    PASS=$((PASS+1)); echo "PASS T7.c-g 한국어 '${variant}' 미매칭"
  else
    FAIL=$((FAIL+1)); echo "FAIL T7.c-g ${variant} (out=$out)"
  fi
done

# T7.g (v0.4-pre W1 정정) R-3 lookback N=3 이내 선언 → 미매칭 (옛 N=1 규약에서는 매칭이었음)
# 의도 변경: 옛 "직전 1 외" 매칭 → 새 "직전 3 이내" 미매칭 (false positive 해소)
out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-with-earlier-declaration.jsonl" "specops-ko:planning-ko")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T7.g 직전 N=3 이내 선언 → 미매칭 (v0.4-pre W1 lookback 확장)"
else
  FAIL=$((FAIL+1)); echo "FAIL T7.g (out=$out)"
fi

# T7.h~T7.l (v0.4-pre W1) R-3 declaration regex 확장 — 한국어 시작/진행 + 영문 invoking/switching + user turn 첫 진입 예외
declare -a r3_extra=(
  "r3-skill-with-korean-시작.jsonl|specops-ko:planning-ko|h|한국어 시작"
  "r3-skill-with-korean-진행.jsonl|specops-ko:clarifying-ko|i|한국어 진행"
  "r3-skill-with-english-invoking.jsonl|specops-ko:decomposing-ko|j|영문 Invoking"
  "r3-skill-with-english-switching.jsonl|specops-ko:verifying-evidence-ko|k|영문 Switching to"
  "r3-skill-after-user-turn.jsonl|specops-ko:specifying-ko|l|user turn /start 첫 진입 예외"
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

# T9.f (20260716 #209 전파) R-4 downstream 표준 배치 bash tests/*.sh 실행 → 미매칭
#   runner pattern 이 scripts/tests/ 하드코딩이면 외부 repo 의 정직한 러너 실행이 false-warn.
r4ds=$(mktemp)
printf '%s\n' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"검증 완료. 테스트 통과 확인."}]}}' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"bash tests/test-todo.sh"}}]}}' \
  '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"PASS=4 FAIL=0"}]}}' > "$r4ds"
out=$(apply_assertion_without_test_rule "$rule_r4" "$r4ds")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T9.f R-4 downstream bash tests/*.sh 미매칭 (#209 전파)"
else
  FAIL=$((FAIL+1)); echo "FAIL T9.f downstream 러너 false-warn (out=$out)"
fi
rm -f "$r4ds"

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

# T7.m R-3 full name 선언 (specops-ko:<short>) → 미매칭 (v0.4b W1)
out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-with-fullname-declaration.jsonl" "specops-ko:planning-ko")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T7.m R-3 full name 선언 → 미매칭 (v0.4b W1)"
else
  FAIL=$((FAIL+1)); echo "FAIL T7.m (out=$out)"
fi

# T7.n R-3 lifecycle chain 자동 호출 → 미매칭 (v0.5 W1)
# fixture: requesting-code-review-ko 직후 receiving-code-review-ko 자동 chain
out=$(apply_skill_declaration_rule "$FIXTURES/transcripts/r3-skill-chain-auto-next.jsonl" "specops-ko:receiving-code-review-ko")
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
printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"specops-ko:verifying-evidence-ko"}}]}}\n' > "$tmp_fixture"
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
# specops-ko:gbrain 조회만으로 R-6 silence 되지 않음 검증.
tmpfx2=$(mktemp)
cat > "$tmpfx2" <<'EOF'
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"specops-ko:verifying-evidence-ko"}}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Write","input":{"file_path":".specops/20260526-r6-fix-followup/evidence.md","content":"# evidence"}}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"specops-ko:gbrain"}}]}}
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
printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"specops-ko:verifying-evidence-ko"}}]}}\n' > "$tmp_fixture2"
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

# T-R6.15 stop-governance.sh end-to-end 통합 (R-6 disabled 검증 — gbrain manual-only 설계)
# R-6 disabled 상태에서 정상 완주 시 friction-log에 R-6 미기록 + continue:true 확인
# sandbox: mktemp + .specops/session-progress.md(FID) + R-6 FAIL transcript
# 격리: 모든 쓰기를 temp .specops/ 로 (실 repo 오염 차단 — S0/S7 격리 규율과 동일)
e2e_tmp=$(mktemp -d)
e2e_fid="20260529-r6-e2e-stop"
mkdir -p "$e2e_tmp/.specops"
printf '## %s\n' "$e2e_fid" > "$e2e_tmp/.specops/session-progress.md"
e2e_tx="$e2e_tmp/transcript.jsonl"
printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"specops-ko:verifying-evidence-ko"}}]}}\n' > "$e2e_tx"
printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Write","input":{"file_path":".specops/%s/evidence.md","content":"# evidence"}}]}}\n' "$e2e_fid" >> "$e2e_tx"
e2e_out=$(cd "$e2e_tmp" && printf '{"transcript_path":"%s","stop_hook_active":false}' "$e2e_tx" | bash "$PLUGIN/hooks/stop-governance.sh" 2>/dev/null)
e2e_cont=$(echo "$e2e_out" | jq -r '.continue' 2>/dev/null)
e2e_log="$e2e_tmp/.specops/$e2e_fid/friction-log.jsonl"
# R-6 disabled → friction-log 미생성(모든 룰 미발화) 또는 R-6 항목 없음 모두 PASS
# log 미생성은 R-6 trigger 조건(verifying-evidence-ko + evidence.md Write, gbrain 부재)이
# R-6 disabled 로 인해 friction-log 를 생성하지 않은 정상 결과임.
# R-6 재활성화 시 동일 transcript 에서 R-6 발화 여부는 T-R6.1~T-R6.5 단위 테스트가 보장.
r6_absent=true
[ -f "$e2e_log" ] && grep -q '"rule_id":"R-6"' "$e2e_log" 2>/dev/null && r6_absent=false
if [ "$e2e_cont" = "true" ] && [ "$r6_absent" = "true" ]; then
  PASS=$((PASS+1)); echo "PASS T-R6.15 stop-governance.sh E2E — R-6 disabled, friction-log 미기록 + continue:true"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.15 E2E cont=$e2e_cont r6_in_log=$(grep -c '\"rule_id\":\"R-6\"' "$e2e_log" 2>/dev/null || echo 0)"
fi
rm -rf "$e2e_tmp"

# T-R6.16 stop-governance.sh 멱등 가드 (NFR-4 — stop_hook_active=true 시 friction 미기록)
e2e_tmp2=$(mktemp -d)
mkdir -p "$e2e_tmp2/.specops"
printf '## %s\n' "$e2e_fid" > "$e2e_tmp2/.specops/session-progress.md"
e2e_tx2="$e2e_tmp2/transcript.jsonl"
printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill","input":{"skill":"specops-ko:verifying-evidence-ko"}}]}}\n' > "$e2e_tx2"
printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Write","input":{"file_path":".specops/%s/evidence.md","content":"# evidence"}}]}}\n' "$e2e_fid" >> "$e2e_tx2"
out2=$(cd "$e2e_tmp2" && printf '{"transcript_path":"%s","stop_hook_active":true}' "$e2e_tx2" | bash "$PLUGIN/hooks/stop-governance.sh" 2>/dev/null)
if [ "$(echo "$out2" | jq -r '.continue' 2>/dev/null)" = "true" ] && [ ! -f "$e2e_tmp2/.specops/$e2e_fid/friction-log.jsonl" ]; then
  PASS=$((PASS+1)); echo "PASS T-R6.16 stop-governance.sh 멱등 — active=true 시 friction 미기록"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.16 멱등 가드 깨짐 (active=true 인데 friction 기록됨)"
fi
rm -rf "$e2e_tmp2"

# T-R6.17 한 turn(단일 JSON 라인)에 Write+Bash 공존 (characterization — Minor1 리팩터 가드)
# 현 동작: 같은 line_no 에서 Write fp 갱신 후 Bash invocation 분기가 synth_path 로 덮음 → Bash 우선.
# 이 동작을 lock 하여 jq 호출 구조 변경(2-fork) 시 회귀 차단. T-R6.14 는 별개 라인(line2/3), 본 케이스는 동일 라인.
out=$(apply_gbrain_absence_rule "$rule_r6" "$FIXTURES/transcripts/r6-verify-write-bash-same-turn.jsonl")
if [ -n "$out" ]; then
  fid=$(echo "$out" | jq -r '.fid'); offset=$(echo "$out" | jq -r '.offset')
  if [ "$fid" = "20260529-fid-bash" ] && [ "$offset" = "1" ]; then
    PASS=$((PASS+1)); echo "PASS T-R6.17 same-turn Write+Bash — Bash 분기 우선 (fid=bash offset=1)"
  else
    FAIL=$((FAIL+1)); echo "FAIL T-R6.17 fid=$fid offset=$offset (20260529-fid-bash/1 기대)"
  fi
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.17 same-turn 미매칭"
fi

# T-R6.18 negative — evidence Write 없음 + Bash 무관 명령(ls) → 미매칭 (AC-R-2 보완)
out=$(apply_gbrain_absence_rule "$rule_r6" "$FIXTURES/transcripts/r6-verify-bash-irrelevant.jsonl")
if [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T-R6.18 negative — evidence 없음 + Bash 무관 미매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R6.18 negative 매칭됨: $out"
fi

# T-H1 (single-source 정합): pretool prefilter 는 rules.jsonl R-1/R-2 trigger_pattern 을 **동적 로드**한다 —
# 하드코딩 literal 부재 검사 (T-R8 동형). 구버전은 literal 복제 + 문자열 비교였으나, VAR=val 인용값 클래스
# 도입으로 literal 에 quote-splice 가 생겨 추출 비교 불가 → 참조 검사로 격상. 앵커 `--no-optional-locks` 는
# trigger 정규식에만 존재하는 표식 — 잔존 시 literal 복제가 되살아난 것.
if grep -q 'trigger_pattern' "$PLUGIN/hooks/pretool-governance.sh" \
   && ! grep -q -- '--no-optional-locks' "$PLUGIN/hooks/pretool-governance.sh"; then
  PASS=$((PASS+1)); echo "PASS T-H1 pretool prefilter ≡ rules.jsonl 동적 로드 (single-source, literal 복제 0)"
else
  FAIL=$((FAIL+1)); echo "FAIL T-H1 prefilter literal 복제 잔존 또는 동적 참조 부재"
fi
# T-H1b 동적 로드 실효 canary — rules.jsonl 의 R-1 trigger 로 실제 deny 가 나오는지는 test-pretool T1 이
# 행위로 검증한다(로드가 깨지면 fail-open allow → T1 FAIL). 여기서는 로드 표현식 자체의 산출값을 확인.
h1_re=$(jq -rs '[.[]|select(.id=="R-1" or .id=="R-2")|.trigger_pattern|select(.!=null)]|join("|")' "$PLUGIN/hooks/rules.jsonl" 2>/dev/null)
if [ -n "$h1_re" ] && printf '%s' "git commit -m x" | grep -Eq "$h1_re" \
   && printf '%s' "gh pr create --fill" | grep -Eq "$h1_re" \
   && ! printf '%s' "ls -la" | grep -Eq "$h1_re"; then
  PASS=$((PASS+1)); echo "PASS T-H1b rules.jsonl trigger join 산출값 실효 (commit·pr 매칭, 무관 명령 미매칭)"
else
  FAIL=$((FAIL+1)); echo "FAIL T-H1b trigger join 산출값 비정상: [$h1_re]"
fi

# T-R8 (single-source 정합): R-3 trigger 패턴은 rules.jsonl R-3.trigger_skill_pattern 단일소스.
# posttool 이 그 값을 동적 참조하고 하드코딩 literal grep 을 갖지 않아야(drift 차단 — R-1/R-2 T-H1 동류).
r8_pat=$(jq -r 'select(.id=="R-3")|.trigger_skill_pattern' "$PLUGIN/hooks/rules.jsonl")
if [ -n "$r8_pat" ] && [ "$r8_pat" != "null" ] \
   && grep -q 'trigger_skill_pattern' "$PLUGIN/hooks/posttool-governance.sh" \
   && ! grep -qE "grep -Eq '\^specops-ko:'" "$PLUGIN/hooks/posttool-governance.sh"; then
  PASS=$((PASS+1)); echo "PASS T-R8 R-3 trigger ≡ rules.jsonl single-source"
else
  FAIL=$((FAIL+1)); echo "FAIL T-R8 (pat=[$r8_pat] — posttool R-3 하드코딩 drift?)"
fi

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
