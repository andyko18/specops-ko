#!/usr/bin/env bash
# specops-auto-ko llm-eval — runner 판정 로직 단위 테스트 (stub 기반, 토큰 0)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
EVAL="$PLUGIN/scripts/tests/llm-eval"
FIXTURES="$EVAL/fixtures.jsonl"
RUNNER="$EVAL/run-evals.sh"
STUB="$EVAL/stub-claude.sh"

# 스탬프 격리 — stub 케이스가 실 repo .specops-cache/ 를 갱신하면 release staleness 경고가 영구 미발화 (false-green)
LLM_EVAL_STAMP_DIR=$(mktemp -d) || exit 1
export LLM_EVAL_STAMP_DIR
trap 'rm -rf "$LLM_EVAL_STAMP_DIR"' EXIT
# T8.c 격리 실증용 — 실 repo 스탬프 상태 사전 캡처 (mtime 또는 absent)
REAL_STAMP="$PLUGIN/.specops-cache/llm-eval-last-run"
REAL_STAMP_BEFORE=$(stat -c %Y "$REAL_STAMP" 2>/dev/null || stat -f %m "$REAL_STAMP" 2>/dev/null || echo absent)

# T1.a fixtures.jsonl 전 라인 jq 유효
ok=1
while IFS= read -r line; do
  [ -z "$line" ] && continue
  printf '%s' "$line" | jq -e . >/dev/null 2>&1 || ok=0
done < "$FIXTURES"
if [ "$ok" = "1" ] && [ -s "$FIXTURES" ]; then
  PASS=$((PASS+1)); echo "PASS T1.a fixtures jsonl 유효"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a (invalid jsonl)"
fi

# T1.b 건수 ≥10 + 분류별 ≥2 (specifying-ko / analyzing-ko / none) + expect_any ≥2
total=$(grep -c . "$FIXTURES")
n_spec=$(jq -s '[.[] | select(.expect_skill=="specifying-ko")] | length' "$FIXTURES")
n_ana=$(jq -s '[.[] | select(.expect_skill=="analyzing-ko")] | length' "$FIXTURES")
n_none=$(jq -s '[.[] | select(.expect_skill=="none")] | length' "$FIXTURES")
n_any=$(jq -s '[.[] | select(.expect_any)] | length' "$FIXTURES")
if [ "$total" -ge 10 ] && [ "$n_spec" -ge 2 ] && [ "$n_ana" -ge 2 ] && [ "$n_none" -ge 2 ] && [ "$n_any" -ge 2 ]; then
  PASS=$((PASS+1)); echo "PASS T1.b 분류 구성 (total=$total spec=$n_spec ana=$n_ana none=$n_none any=$n_any)"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.b (total=$total spec=$n_spec ana=$n_ana none=$n_none any=$n_any)"
fi

# T1.c 부트스트랩·표현다양화 fixture — boot 2건 + sandbox_seed ≥2 + maintain ≥3
n_boot=$(jq -s '[.[] | select(.expect_bootstrap != null)] | length' "$FIXTURES")
n_seed=$(jq -s '[.[] | select(.sandbox_seed != null)] | length' "$FIXTURES")
n_maint=$(jq -s '[.[] | select(.expect_flag=="maintain")] | length' "$FIXTURES")
if [ "$n_boot" -ge 2 ] && [ "$n_seed" -ge 2 ] && [ "$n_maint" -ge 3 ]; then
  PASS=$((PASS+1)); echo "PASS T1.c boot=$n_boot seed=$n_seed maint=$n_maint"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.c (boot=$n_boot seed=$n_seed maint=$n_maint)"
fi

# T1.d 무결성 — expect_any + expect_bootstrap 동시 보유 금지 (boot 차원 silent 무시 방어, Phase C Important#1)
n_conflict=$(jq -s '[.[] | select(.expect_any != null and .expect_bootstrap != null)] | length' "$FIXTURES")
if [ "$n_conflict" -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS T1.d any+boot 동시보유 0건"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.d (conflict=$n_conflict — expect_any+expect_bootstrap 동시 fixture는 boot 무시됨)"
fi

# T2.a stub — STUB_PLAN 1째 줄 skill 지정 시 tool_use 이벤트 + result 이벤트 출력
TD=$(mktemp -d)
export STUB_STATE="$TD/count" STUB_PLAN="$TD/plan.jsonl"
echo '{"skill":"specops-auto-ko:specifying-ko","args":"CSV CLI","cost":0.1}' > "$STUB_PLAN"
out=$(bash "$STUB" -p "아무 프롬프트" --output-format stream-json 2>/dev/null)
got_skill=$(printf '%s\n' "$out" | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill' | head -1)
got_cost=$(printf '%s\n' "$out" | jq -r 'select(.type=="result") | .total_cost_usd' | head -1)
if [ "$got_skill" = "specops-auto-ko:specifying-ko" ] && [ "$got_cost" = "0.1" ] && [ "$(cat "$STUB_STATE")" = "1" ]; then
  PASS=$((PASS+1)); echo "PASS T2.a stub tool_use + result + 카운터"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.a (skill=$got_skill cost=$got_cost)"
fi
rm -rf "$TD"

# ── T3 runner 코어 (stub 기반) ──
mk_fx() { # $1=파일 $2...=jsonl 줄들
  local f="$1"; shift; : > "$f"
  for l in "$@"; do printf '%s\n' "$l" >> "$f"; done
}

# T3.a 일치 → PASS + exit 0
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" '{"id":"new-1","prompt":"CLI 만들어줘","expect_skill":"specifying-ko","expect_flag":"new"}'
mk_fx "$STUB_PLAN" '{"skill":"specops-auto-ko:specifying-ko","args":"CLI","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '^PASS new-1'; then
  PASS=$((PASS+1)); echo "PASS T3.a 일치 판정"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.a (rc=$rc out=$out)"
fi
rm -rf "$TD"

# T3.b skill 불일치 → FAIL + exit 1 (재시도 2회 모두 불일치)
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" '{"id":"new-1","prompt":"CLI 만들어줘","expect_skill":"specifying-ko","expect_flag":"new"}'
mk_fx "$STUB_PLAN" '{"skill":"specops-auto-ko:analyzing-ko","args":"x","cost":0}' '{"skill":"specops-auto-ko:analyzing-ko","args":"x","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q '^FAIL new-1'; then
  PASS=$((PASS+1)); echo "PASS T3.b 불일치 판정"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.b (rc=$rc out=$out)"
fi
rm -rf "$TD"

# T3.c expect_skill=none 인데 Skill 호출 → FAIL
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" '{"id":"none-1","prompt":"jq 어디서 써?","expect_skill":"none","expect_flag":"none"}'
mk_fx "$STUB_PLAN" '{"skill":"specops-auto-ko:specifying-ko","args":"x","cost":0}' '{"skill":"specops-auto-ko:specifying-ko","args":"x","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q '^FAIL none-1'; then
  PASS=$((PASS+1)); echo "PASS T3.c none 위반 판정"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.c (rc=$rc out=$out)"
fi
rm -rf "$TD"

# T3.d none + Skill 미호출 → PASS / maintain flag 누락 → FAIL (AC-4)
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" \
  '{"id":"none-2","prompt":"개념 설명해줘","expect_skill":"none","expect_flag":"none"}' \
  '{"id":"maint-1","prompt":"버그 고쳐줘","expect_skill":"analyzing-ko","expect_flag":"maintain"}'
mk_fx "$STUB_PLAN" \
  '{"skill":null}' \
  '{"skill":"specops-auto-ko:analyzing-ko","args":"버그 고쳐줘 (flag 없음)","cost":0}' \
  '{"skill":"specops-auto-ko:analyzing-ko","args":"버그 고쳐줘 (flag 없음)","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q '^PASS none-2' && echo "$out" | grep -q '^FAIL maint-1'; then
  PASS=$((PASS+1)); echo "PASS T3.d none-PASS + maintain flag 누락 FAIL"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.d (rc=$rc out=$out)"
fi
rm -rf "$TD"

# T3.e maintain flag 첫 줄 포함 → PASS (AC-4 양성) + 요약 포맷 (AC-5)
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" '{"id":"maint-1","prompt":"버그 고쳐줘","expect_skill":"analyzing-ko","expect_flag":"maintain"}'
mk_fx "$STUB_PLAN" '{"skill":"specops-auto-ko:analyzing-ko","args":"<!-- entry: maintain -->\n버그 고쳐줘","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '^PASS maint-1' \
   && echo "$out" | grep -qE 'PASS=[0-9]+ FAIL=[0-9]+ SKIP=[0-9]+ BORDERLINE=[0-9]+ COST=\$'; then
  PASS=$((PASS+1)); echo "PASS T3.e maintain flag PASS + 요약 포맷"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.e (rc=$rc out=$out)"
fi
rm -rf "$TD"

# T3.f claude 부재 → SKIP + exit 0 (AC-3) — 기대 SKIP 수는 fixtures 실측 (M-2: 하드코딩 제거)
fx_n=$(grep -c . "$FIXTURES")
out=$(CLAUDE_BIN=/nonexistent-claude bash "$RUNNER" "$FIXTURES" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '^SKIP: claude CLI 부재' && echo "$out" | grep -q "SKIP=$fx_n"; then
  PASS=$((PASS+1)); echo "PASS T3.f CLI 부재 graceful SKIP"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.f (rc=$rc out=$out)"
fi

# ── T7 부트스트랩 차원 (expect_bootstrap early-return + sandbox_seed) ──

# T7.b RED 실증 — expect_bootstrap fixture 안내 미발화 시 FAIL 되어야.
#   원본(미구현): judge expect_bootstrap 무시 + expect_skill 기본 none + Skill 미호출(got="") → 오판 PASS(rc=0)
#     → 단언(rc=1 && FAIL boot-none) 불충족 → 본 테스트 FAIL = RED.
#   구현 후: early-return text "진행합니다" 미매칭 → FAIL(rc=1) → 단언 충족 → PASS.
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" '{"id":"boot-none","prompt":"x","sandbox_seed":"none","expect_bootstrap":"/init-project|초기화되지 않|--resume|권장|부트스트랩"}'
mk_fx "$STUB_PLAN" '{"text":"네 알겠습니다 진행합니다","cost":0}' '{"text":"네 알겠습니다 진행합니다","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q '^FAIL boot-none'; then PASS=$((PASS+1)); echo "PASS T7.b 안내 미발화 FAIL"; else FAIL=$((FAIL+1)); echo "FAIL T7.b (rc=$rc out=$out)"; fi
rm -rf "$TD"

# T7.a expect_bootstrap — 부트스트랩 안내 text 방출 → text 정규식 매칭 PASS (Skill 차원 무시)
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" '{"id":"boot-none","prompt":"CLI 만들어줘","sandbox_seed":"none","expect_bootstrap":"/init-project|초기화되지 않|--resume|권장|부트스트랩"}'
mk_fx "$STUB_PLAN" '{"text":"프로젝트가 초기화되지 않았습니다. /init-project 권장 [y/N]","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '^PASS boot-none'; then PASS=$((PASS+1)); echo "PASS T7.a expect_bootstrap 매칭"; else FAIL=$((FAIL+1)); echo "FAIL T7.a (rc=$rc out=$out)"; fi
rm -rf "$TD"

# T7.c expect_bootstrap 미정의 + Skill 호출 → 기존 Skill 차원 회귀 (early-return 미발동)
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" '{"id":"new-1","prompt":"CLI 만들어줘","expect_skill":"specifying-ko","expect_flag":"new"}'
mk_fx "$STUB_PLAN" '{"skill":"specops-auto-ko:specifying-ko","args":"CLI","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '^PASS new-1'; then PASS=$((PASS+1)); echo "PASS T7.c expect_bootstrap 미정의 회귀"; else FAIL=$((FAIL+1)); echo "FAIL T7.c (rc=$rc out=$out)"; fi
rm -rf "$TD"

# ── T4 재시도·BORDERLINE·비용 ──

# T4.a 재시도 성공 — 1차 오답 → 2차 정답 → PASS + retry 표기 + stub 2회 호출 (AC-6)
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" '{"id":"new-1","prompt":"CLI 만들어줘","expect_skill":"specifying-ko","expect_flag":"new"}'
mk_fx "$STUB_PLAN" '{"skill":null}' '{"skill":"specops-auto-ko:specifying-ko","args":"CLI","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
calls=$(cat "$STUB_STATE")
if [ $rc -eq 0 ] && echo "$out" | grep -q '^PASS new-1 retry' && [ "$calls" = "2" ]; then
  PASS=$((PASS+1)); echo "PASS T4.a 재시도 cap=1 성공 경로"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.a (rc=$rc calls=$calls out=$out)"
fi
rm -rf "$TD"

# T4.b BORDERLINE — expect_any 목록 밖 → BORDERLINE 표기 + FAIL 미산입 + exit 0 + 재시도 없음 (AC-11)
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" '{"id":"border-1","prompt":"설명해줘 그리고 고쳐줘","expect_any":["analyzing-ko","none"]}'
mk_fx "$STUB_PLAN" '{"skill":"specops-auto-ko:specifying-ko","args":"x","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
calls=$(cat "$STUB_STATE")
if [ $rc -eq 0 ] && echo "$out" | grep -q '^BORDERLINE border-1' \
   && echo "$out" | grep -q 'FAIL=0' && echo "$out" | grep -q 'BORDERLINE=1' && [ "$calls" = "1" ]; then
  PASS=$((PASS+1)); echo "PASS T4.b BORDERLINE 비차단·재시도 없음"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.b (rc=$rc calls=$calls out=$out)"
fi
rm -rf "$TD"

# T4.c 비용 합산 — cost 0.5 × fixture 2건 → COST=$1.00 (AC-10)
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
mk_fx "$TD/fx.jsonl" \
  '{"id":"new-1","prompt":"a","expect_skill":"specifying-ko","expect_flag":"new"}' \
  '{"id":"new-2","prompt":"b","expect_skill":"specifying-ko","expect_flag":"new"}'
mk_fx "$STUB_PLAN" \
  '{"skill":"specops-auto-ko:specifying-ko","args":"a","cost":0.5}' \
  '{"skill":"specops-auto-ko:specifying-ko","args":"b","cost":0.5}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q 'COST=\$1\.00'; then
  PASS=$((PASS+1)); echo "PASS T4.c 비용 합산"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.c (rc=$rc out=$out)"
fi
rm -rf "$TD"

# T4.d timeout 경로 — LLM_EVAL_TIMEOUT=1 + sleep stub → none fixture 가양성 차단, TIMEOUT FAIL (I-2)
TD=$(mktemp -d)
cat > "$TD/slow-claude.sh" <<'SLOW'
#!/usr/bin/env bash
echo "stub: simulated hang" >&2
exec sleep 30
SLOW
chmod +x "$TD/slow-claude.sh"
mk_fx "$TD/fx.jsonl" '{"id":"none-1","prompt":"질문","expect_skill":"none","expect_flag":"none"}'
out=$(CLAUDE_BIN="$TD/slow-claude.sh" LLM_EVAL_TIMEOUT=1 bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 1 ] && echo "$out" | grep -q '^FAIL none-1.*TIMEOUT'; then
  PASS=$((PASS+1)); echo "PASS T4.d timeout TIMEOUT FAIL 처리"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.d (rc=$rc out=$out)"
fi
rm -rf "$TD"

# ── T5 run-all 등재 + 문서 (AC-7, AC-8) ──

# T5.a run-all glob 에 llm-eval/test-*.sh 포함 + run-evals.sh 미포함
if grep -q 'scripts/tests/llm-eval/test-\*\.sh' "$PLUGIN/scripts/tests/run-all.sh" \
   && ! grep -q 'run-evals' "$PLUGIN/scripts/tests/run-all.sh"; then
  PASS=$((PASS+1)); echo "PASS T5.a run-all 등재 (단위 테스트만)"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.a run-all glob"
fi

# T5.b 문서 등재 — scripts/README.md + CLAUDE.md 에 run-evals.sh 언급
if grep -q 'run-evals.sh' "$PLUGIN/scripts/README.md" && grep -q 'run-evals.sh' "$PLUGIN/CLAUDE.md"; then
  PASS=$((PASS+1)); echo "PASS T5.b 문서 등재"
else
  FAIL=$((FAIL+1)); echo "FAIL T5.b 문서 등재"
fi

# ── T6 headless 부작용 격리 (fix-loop 1/3) ──

# T6.a stdin 격리 — 가짜 claude 가 stdin 을 덤프: 비어 있어야 함 (fixtures FD 누수 없음) + 2건 모두 판정
TD=$(mktemp -d)
export DUMP_F="$TD/stdin-dump"
cat > "$TD/dump-claude.sh" <<'DUMP'
#!/usr/bin/env bash
cat >> "$DUMP_F"
exit 0
DUMP
chmod +x "$TD/dump-claude.sh"
mk_fx "$TD/fx.jsonl" \
  '{"id":"none-1","prompt":"질문1","expect_skill":"none","expect_flag":"none"}' \
  '{"id":"none-2","prompt":"질문2","expect_skill":"none","expect_flag":"none"}'
out=$(CLAUDE_BIN="$TD/dump-claude.sh" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 0 ] && [ ! -s "$DUMP_F" ] \
   && echo "$out" | grep -q '^PASS none-1' && echo "$out" | grep -q '^PASS none-2'; then
  PASS=$((PASS+1)); echo "PASS T6.a stdin 격리 (덤프 빈 파일 + 2건 판정)"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.a (rc=$rc dump_size=$(wc -c < "$DUMP_F" 2>/dev/null || echo 0) out=$out)"
fi
unset DUMP_F; rm -rf "$TD"

# T6.b sandbox cwd — 가짜 claude 가 pwd 기록: repo 경로와 다름 + temp 계열 경로
TD=$(mktemp -d)
export PWD_F="$TD/pwd-log"
cat > "$TD/pwd-claude.sh" <<'PWDC'
#!/usr/bin/env bash
pwd >> "$PWD_F"
exit 0
PWDC
chmod +x "$TD/pwd-claude.sh"
mk_fx "$TD/fx.jsonl" '{"id":"none-1","prompt":"질문","expect_skill":"none","expect_flag":"none"}'
out=$(CLAUDE_BIN="$TD/pwd-claude.sh" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
got_pwd=$(head -1 "$PWD_F" 2>/dev/null || true)
case "$got_pwd" in
  /tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*) tmpok=1 ;;
  *) tmpok=0 ;;
esac
if [ $rc -eq 0 ] && [ -n "$got_pwd" ] && [ "$got_pwd" != "$PLUGIN" ] && [ "$tmpok" = "1" ]; then
  PASS=$((PASS+1)); echo "PASS T6.b sandbox cwd 격리 (pwd=$got_pwd)"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.b (rc=$rc pwd=${got_pwd:-없음})"
fi
unset PWD_F; rm -rf "$TD"

# T6.c expect_any + TIMEOUT → BORDERLINE 비차단 (외부 리뷰 Minor — 미보유 분기 단위 테스트)
TD=$(mktemp -d)
cat > "$TD/hang-claude.sh" <<'HANG'
#!/usr/bin/env bash
echo "stub: simulated hang for any" >&2
exec sleep 30
HANG
chmod +x "$TD/hang-claude.sh"
mk_fx "$TD/fx.jsonl" '{"id":"border-1","prompt":"애매한 질문","expect_any":["analyzing-ko","none"]}'
out=$(LLM_EVAL_TIMEOUT=1 CLAUDE_BIN="$TD/hang-claude.sh" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -qE '^BORDERLINE border-1.*TIMEOUT' \
   && echo "$out" | grep -q 'FAIL=0' && echo "$out" | grep -q 'BORDERLINE=1'; then
  PASS=$((PASS+1)); echo "PASS T6.c expect_any+TIMEOUT → BORDERLINE 비차단"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.c (rc=$rc out=$out)"
fi
rm -rf "$TD"

# ── T8 완주 스탬프 (B층 신호원 — AC-4) ──

# T8.a stub 완주(비 SKIP) → $LLM_EVAL_STAMP_DIR/llm-eval-last-run 존재 + ISO-8601 1줄
TD=$(mktemp -d); export STUB_STATE="$TD/c" STUB_PLAN="$TD/p.jsonl"
rm -f "$LLM_EVAL_STAMP_DIR/llm-eval-last-run"   # 선행 케이스 완주 잔재 제거 — 본 케이스가 기록 주체임을 단언
mk_fx "$TD/fx.jsonl" '{"id":"new-1","prompt":"CLI 만들어줘","expect_skill":"specifying-ko","expect_flag":"new"}'
mk_fx "$STUB_PLAN" '{"skill":"specops-auto-ko:specifying-ko","args":"CLI","cost":0}'
out=$(CLAUDE_BIN="$STUB" bash "$RUNNER" "$TD/fx.jsonl" 2>&1); rc=$?
if [ $rc -eq 0 ] && [ -f "$LLM_EVAL_STAMP_DIR/llm-eval-last-run" ] \
   && grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$LLM_EVAL_STAMP_DIR/llm-eval-last-run"; then
  PASS=$((PASS+1)); echo "PASS T8.a 완주 스탬프 기록 (ISO-8601)"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.a (rc=$rc stamp=$(cat "$LLM_EVAL_STAMP_DIR/llm-eval-last-run" 2>/dev/null || echo 부재) out=$out)"
fi
rm -rf "$TD"

# T8.b SKIP 경로(claude 부재) → 스탬프 미기록 (별도 STAMP_DIR 로 T8.a 잔재와 격리)
SKIP_SD=$(mktemp -d)
out=$(LLM_EVAL_STAMP_DIR="$SKIP_SD" CLAUDE_BIN=/nonexistent-claude bash "$RUNNER" "$FIXTURES" 2>&1); rc=$?
if [ $rc -eq 0 ] && [ ! -f "$SKIP_SD/llm-eval-last-run" ]; then
  PASS=$((PASS+1)); echo "PASS T8.b SKIP 경로 스탬프 미기록"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.b (rc=$rc stamp_exists=$([ -f "$SKIP_SD/llm-eval-last-run" ] && echo yes || echo no))"
fi
rm -rf "$SKIP_SD"

# T8.c 격리 실증 — 본 스위트 전체(stub 완주 다수)가 실 repo .specops-cache 스탬프를 생성/갱신하지 않음
REAL_STAMP_AFTER=$(stat -c %Y "$REAL_STAMP" 2>/dev/null || stat -f %m "$REAL_STAMP" 2>/dev/null || echo absent)
if [ "$REAL_STAMP_BEFORE" = "$REAL_STAMP_AFTER" ]; then
  PASS=$((PASS+1)); echo "PASS T8.c 실 repo 스탬프 미생성/미갱신 (before=$REAL_STAMP_BEFORE after=$REAL_STAMP_AFTER)"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.c (before=$REAL_STAMP_BEFORE after=$REAL_STAMP_AFTER — 격리 붕괴)"
fi

# T8.d fixtures-smoke drift 가드 — smoke 서브셋 6줄이 원본 fixtures.jsonl 에 자구 그대로 존재 (AC-1 영구 잠금, Phase C 권고)
SMOKE="$PLUGIN/scripts/tests/llm-eval/fixtures-smoke.jsonl"
if [ -f "$SMOKE" ] && [ "$(grep -F -x -f "$SMOKE" "$PLUGIN/scripts/tests/llm-eval/fixtures.jsonl" | wc -l | tr -d ' ')" = "6" ] && [ "$(grep -c . "$SMOKE")" = "6" ]; then
  PASS=$((PASS+1)); echo "PASS T8.d fixtures-smoke 6/6 원본 자구 동일"
else
  FAIL=$((FAIL+1)); echo "FAIL T8.d fixtures-smoke drift 또는 부재"
fi

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
