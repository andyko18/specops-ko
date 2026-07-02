#!/usr/bin/env bash
# scripts/critic-ask.sh 검증 — CRITIC_BIN stub 주입 (토큰 0)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/critic-ask.sh"
TD=$(mktemp -d); trap 'rm -rf "$TD"' EXIT

printf '검토 지시문\n' > "$TD/prompt.md"
printf '플랜 본문 alpha\n' > "$TD/target.md"

# T1.a stub 성공 — 합성 프롬프트가 stub stdin 으로 전달 + CRITIC[custom]: 헤더 + 의견 출력 (AC-1)
cat > "$TD/stub.sh" <<'STUB'
#!/usr/bin/env bash
cat > "$STUB_IN"
echo "외부 의견: 위험 1건"
STUB
chmod +x "$TD/stub.sh"
export STUB_IN="$TD/received"
out=$(CRITIC_BIN="$TD/stub.sh" bash "$SCRIPT" "$TD/prompt.md" --files "$TD/target.md"); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '^CRITIC\[custom\]:' && echo "$out" | grep -q '외부 의견: 위험 1건' \
   && grep -q '검토 지시문' "$STUB_IN" && grep -q -- '--- 파일: ' "$STUB_IN" && grep -q '플랜 본문 alpha' "$STUB_IN"; then
  PASS=$((PASS+1)); echo "PASS T1.a stub 위탁 + 합성 전달"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a (rc=$rc out=$out)"
fi
unset STUB_IN

# T1.b provider 전부 부재 → SKIP + exit 0 (AC-2 — PATH 축소 격리, clarify Q5)
out=$(env -i PATH="/usr/bin:/bin" HOME="$HOME" bash "$SCRIPT" "$TD/prompt.md" 2>&1); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '^CRITIC: SKIP (외부 CLI 부재)'; then
  PASS=$((PASS+1)); echo "PASS T1.b 부재 SKIP + exit 0"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.b (rc=$rc out=$out)"
fi

# T1.c timeout → CRITIC: FAIL + exit 0 (AC-3 — advisory 비차단)
cat > "$TD/hang.sh" <<'HANG'
#!/usr/bin/env bash
echo "hang stderr" >&2
exec sleep 30
HANG
chmod +x "$TD/hang.sh"
out=$(CRITIC_TIMEOUT=1 CRITIC_BIN="$TD/hang.sh" bash "$SCRIPT" "$TD/prompt.md" 2>/dev/null); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '^CRITIC: FAIL (timeout'; then
  PASS=$((PASS+1)); echo "PASS T1.c timeout FAIL + exit 0"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.c (rc=$rc out=$out)"
fi

# T1.d 200KB 절단 — 고지 + stub 수신 ≤ 한도+여유 (AC-4)
awk 'BEGIN{for(i=0;i<30000;i++) print "padding line padding line"}' > "$TD/big.md"
cat > "$TD/size-stub.sh" <<'SZ'
#!/usr/bin/env bash
wc -c | tr -d " " > "$SZ_OUT"
echo "ok"
SZ
chmod +x "$TD/size-stub.sh"
export SZ_OUT="$TD/size"
err=$(CRITIC_BIN="$TD/size-stub.sh" bash "$SCRIPT" "$TD/prompt.md" --files "$TD/big.md" 2>&1 >/dev/null); rc=$?
got=$(cat "$SZ_OUT" 2>/dev/null || echo 0)
if [ $rc -eq 0 ] && echo "$err" | grep -q '절단' && [ "$got" -le 205000 ]; then
  PASS=$((PASS+1)); echo "PASS T1.d 절단 + 고지 (수신 ${got}B)"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.d (rc=$rc got=$got err=$err)"
fi
unset SZ_OUT

# T1.e prompt-file 부재 → exit 1 (사용 오류)
err=$(bash "$SCRIPT" "$TD/nope.md" 2>&1 >/dev/null); rc=$?
if [ $rc -eq 1 ] && echo "$err" | grep -q 'ERROR'; then
  PASS=$((PASS+1)); echo "PASS T1.e prompt 부재 exit 1"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.e (rc=$rc err=$err)"
fi

# T1.g provider 즉시 실패 (exit 1) → CRITIC: FAIL (provider rc=1) + exit 0 (AC-3 — advisory 비차단)
cat > "$TD/fail-stub.sh" <<'FS'
#!/usr/bin/env bash
echo "boom" >&2
exit 1
FS
chmod +x "$TD/fail-stub.sh"
out=$(CRITIC_BIN="$TD/fail-stub.sh" bash "$SCRIPT" "$TD/prompt.md" 2>/dev/null); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q '^CRITIC: FAIL (provider rc=1)'; then
  PASS=$((PASS+1)); echo "PASS T1.g provider 실패 FAIL + exit 0"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.g (rc=$rc out=$out)"
fi

# T1.f 템플릿 2종 존재 + respond-in-Korean 지시 (AC-8)
if [ -f "$PLUGIN/templates/critic-prompt-plan.md" ] && [ -f "$PLUGIN/templates/critic-prompt-diff.md" ] \
   && grep -qi 'respond in korean' "$PLUGIN/templates/critic-prompt-plan.md" \
   && grep -qi 'respond in korean' "$PLUGIN/templates/critic-prompt-diff.md"; then
  PASS=$((PASS+1)); echo "PASS T1.f 템플릿 2종"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.f 템플릿 누락"
fi

# ── T2 skill 연결 (AC-5·6·7) ──

# T2.a planning-ko — critic 병행 단계 (PASS 직후·§8 기록·advisory) (AC-5)
PL="$PLUGIN/skills/planning-ko/SKILL.md"
if grep -q 'critic-ask.sh' "$PL" && grep -q 'critic-prompt-plan.md' "$PL" \
   && awk '/### 외부 critic 병행/,/^## /' "$PL" | grep -q '판정 권한 없음'; then
  PASS=$((PASS+1)); echo "PASS T2.a planning-ko 연결"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.a"
fi

# T2.b requesting-code-review-ko — diff 의견 병행 (저장 경로·경로만 전달·advisory) (AC-6)
RQ="$PLUGIN/skills/requesting-code-review-ko/SKILL.md"
if grep -q 'critic-ask.sh' "$RQ" && grep -q 'critic-prompt-diff.md' "$RQ" \
   && grep -q 'reviews/external-critic.md' "$RQ" \
   && awk '/### 외부 모델 의견 병행/,/^## /' "$RQ" | grep -q '판정 권한 없음'; then
  PASS=$((PASS+1)); echo "PASS T2.b requesting-code-review-ko 연결"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.b"
fi

# T2.c advisor-ko — 외부 위탁 경로 문서화 (세션 미접근 한계 포함) (AC-7)
AD="$PLUGIN/skills/advisor-ko/SKILL.md"
if grep -q 'critic-ask.sh' "$AD" && grep -q 'conversation' "$AD" \
   && grep -qE '(advisor disabled|disabled 환경)' "$AD"; then
  PASS=$((PASS+1)); echo "PASS T2.c advisor-ko 문서화"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.c"
fi

# ── T3 문서 등재 (AC-9) ──
if grep -q 'critic-ask.sh' "$PLUGIN/scripts/README.md"; then
  PASS=$((PASS+1)); echo "PASS T3.a scripts/README 등재"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.a"
fi

# ── T-ollama provider 정적 검증 (AC-5) ──

# T-ollama provider 로직 정적 검증 (실 위탁은 verify smoke — 토큰0)
SRC_FILE="$SCRIPT"   # critic-ask.sh 경로
if grep -q 'provider="ollama"' "$SRC_FILE" && grep -q 'api/generate' "$SRC_FILE" && grep -q 'CRITIC_MODEL' "$SRC_FILE"; then
  PASS=$((PASS+1)); echo "PASS T-ollama provider 로직(감지+API+CRITIC_MODEL) 존재"
else
  FAIL=$((FAIL+1)); echo "FAIL T-ollama provider 로직 누락"
fi

# T-ollama-2 CRITIC_BIN 최우선 보존 — ollama 설치돼도 CRITIC_BIN 우선 (디스패치 우선순위)
cat > "$TD/stub2.sh" <<'STUB2'
#!/usr/bin/env bash
cat >/dev/null; echo "stub-custom-opinion"
STUB2
chmod +x "$TD/stub2.sh"
out=$(CRITIC_BIN="$TD/stub2.sh" bash "$SCRIPT" "$TD/prompt.md"); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q "CRITIC\[custom\]"; then
  PASS=$((PASS+1)); echo "PASS T-ollama-2 CRITIC_BIN 최우선(ollama 무관)"
else
  FAIL=$((FAIL+1)); echo "FAIL T-ollama-2 (rc=$rc out=$out)"
fi

# ── T-claude provider 정적 검증 (advisor 백엔드 최우선 — fable 우선·opus fallback) ──

# T-claude provider 로직 존재 (감지 + --model/--fallback-model + CRITIC_CLAUDE_MODEL override)
if grep -q 'provider="claude"' "$SRC_FILE" \
   && grep -q -- '--fallback-model' "$SRC_FILE" \
   && grep -q 'CRITIC_CLAUDE_MODEL' "$SRC_FILE"; then
  PASS=$((PASS+1)); echo "PASS T-claude provider 로직(감지+fallback-model+CRITIC_CLAUDE_MODEL) 존재"
else
  FAIL=$((FAIL+1)); echo "FAIL T-claude provider 로직 누락"
fi

# T-claude-2 감지 우선순위: CRITIC_BIN > claude (custom override 가 claude 설치보다 우선)
out=$(CRITIC_BIN="$TD/stub2.sh" bash "$SCRIPT" "$TD/prompt.md"); rc=$?
if [ $rc -eq 0 ] && echo "$out" | grep -q "CRITIC\[custom\]"; then
  PASS=$((PASS+1)); echo "PASS T-claude-2 CRITIC_BIN 이 claude 보다 우선"
else
  FAIL=$((FAIL+1)); echo "FAIL T-claude-2 (rc=$rc out=$out)"
fi

# T-claude-3 기본 모델 = fable, fallback = opus (요구 계약)
if grep -q 'CRITIC_CLAUDE_MODEL:-fable' "$SRC_FILE" && grep -q 'CRITIC_CLAUDE_FALLBACK:-opus' "$SRC_FILE"; then
  PASS=$((PASS+1)); echo "PASS T-claude-3 기본 fable·fallback opus"
else
  FAIL=$((FAIL+1)); echo "FAIL T-claude-3 기본 모델 계약 누락"
fi

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
