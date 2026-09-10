#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/show-fid-status.sh"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# T1 — AC-1: 잘못된 FID 형식 → stderr 오류 + exit 1
stdout_out=$("$SCRIPT" "invalid" 2>/dev/null); rc=$?
stderr_out=$("$SCRIPT" "invalid" 2>&1 1>/dev/null)
if [ "$rc" -ne 0 ] && [ -z "$stdout_out" ] && [ -n "$stderr_out" ]; then
  PASS=$((PASS+1)); echo "PASS T1 invalid-fid-format"
else
  FAIL=$((FAIL+1)); echo "FAIL T1 (rc=$rc stdout='$stdout_out' stderr='$stderr_out')"
fi

# T2 — AC-2: 올바른 FID 형식이지만 디렉토리 없음 → exit 1
stdout_out=$("$SCRIPT" "20991231-nonexistent" 2>/dev/null); rc=$?
stderr_out=$("$SCRIPT" "20991231-nonexistent" 2>&1 1>/dev/null)
if [ "$rc" -ne 0 ] && [ -z "$stdout_out" ] && [ -n "$stderr_out" ]; then
  PASS=$((PASS+1)); echo "PASS T2 fid-dir-missing"
else
  FAIL=$((FAIL+1)); echo "FAIL T2 (rc=$rc stdout='$stdout_out' stderr='$stderr_out')"
fi

# T3 — AC-3: 디렉토리 + session-progress 섹션 존재 → exit 0 + FID 헤더 + 이력
T3_FID="20260101-test-feature"
mkdir -p "$TMPDIR_TEST/.specops/$T3_FID"
T3_PROGRESS="$TMPDIR_TEST/.specops/session-progress.md"
printf '## %s · test feature\n\n- 2026-01-01T00:00:00Z /specify 완료 (spec.md)\n' "$T3_FID" > "$T3_PROGRESS"

out=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$T3_FID" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "$T3_FID" && printf '%s' "$out" | grep -q "/specify"; then
  PASS=$((PASS+1)); echo "PASS T3 lifecycle-stages-output"
else
  FAIL=$((FAIL+1)); echo "FAIL T3 (rc=$rc out='$out')"
fi

# T4 — AC-4: spec.md 있음, plan.md 없음 → ✅ / ❌ 표시
T4_FID="20260102-test-artifacts"
mkdir -p "$TMPDIR_TEST/.specops/$T4_FID"
touch "$TMPDIR_TEST/.specops/$T4_FID/spec.md"
printf '## %s\n\n- 2026-01-02T00:00:00Z /specify 완료\n' "$T4_FID" >> "$T3_PROGRESS"

out=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$T4_FID" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qF "✅ spec.md" && printf '%s' "$out" | grep -qF "❌ plan.md"; then
  PASS=$((PASS+1)); echo "PASS T4 artifact-check-display"
else
  FAIL=$((FAIL+1)); echo "FAIL T4 (rc=$rc out='$out')"
fi

# T5 — AC-5: 디렉토리 있지만 session-progress에 섹션 없음 → exit 0 + "(진행 이력 없음)"
T5_FID="20260103-no-history"
mkdir -p "$TMPDIR_TEST/.specops/$T5_FID"

out=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$T5_FID" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "진행 이력 없음"; then
  PASS=$((PASS+1)); echo "PASS T5 no-history"
else
  FAIL=$((FAIL+1)); echo "FAIL T5 (rc=$rc out='$out')"
fi

# T6 — reconcile: session-progress 는 /tasks 인데 dispatch-log(implement) + evidence.md(verify)
#   증거 존재 → DESYNC 경고 + 진짜 frontier 보고 (20260718-status-reconcile, dogfood test1 FR-3)
T6_FID="20260104-stalled"
mkdir -p "$TMPDIR_TEST/.specops/$T6_FID"
printf '## %s · stalled feature\n\n- 2026-01-04T00:00:00Z /tasks 완료 (tasks.md)\n' "$T6_FID" >> "$T3_PROGRESS"
touch "$TMPDIR_TEST/.specops/$T6_FID/spec.md" "$TMPDIR_TEST/.specops/$T6_FID/plan.md" "$TMPDIR_TEST/.specops/$T6_FID/tasks.md"
printf '| 1 | ts | A:T1 | implementer-ko | DONE | x |\n' > "$TMPDIR_TEST/.specops/$T6_FID/dispatch-log.md"
printf 'RUN-VERIFICATION-RESULT: PASS\n' > "$TMPDIR_TEST/.specops/$T6_FID/evidence.md"
out=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$T6_FID" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qiE 'DESYNC|불일치|과소보고' \
   && printf '%s' "$out" | grep -qi 'verify' && printf '%s' "$out" | grep -qi 'tasks'; then
  PASS=$((PASS+1)); echo "PASS T6 reconcile-desync 경고 (기록<증거)"
else
  FAIL=$((FAIL+1)); echo "FAIL T6 (rc=$rc out='$out')"
fi

# T7 — reconcile: 기록 frontier == 증거 frontier → DESYNC 경고 없음 (오탐 0)
T7_FID="20260105-aligned"
mkdir -p "$TMPDIR_TEST/.specops/$T7_FID"
printf '## %s · aligned\n\n- 2026-01-05T00:00:00Z /verify PASS (evidence.md)\n- 2026-01-05T00:00:00Z /implement DONE\n' "$T7_FID" >> "$T3_PROGRESS"
touch "$TMPDIR_TEST/.specops/$T7_FID/spec.md" "$TMPDIR_TEST/.specops/$T7_FID/plan.md" "$TMPDIR_TEST/.specops/$T7_FID/tasks.md"
printf '| 1 | ts | A:T1 | implementer-ko | DONE | x |\n' > "$TMPDIR_TEST/.specops/$T7_FID/dispatch-log.md"
printf 'RUN-VERIFICATION-RESULT: PASS\n' > "$TMPDIR_TEST/.specops/$T7_FID/evidence.md"
out=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$T7_FID" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -qiE 'DESYNC|불일치|과소보고'; then
  PASS=$((PASS+1)); echo "PASS T7 reconcile-정합 (경고 없음)"
else
  FAIL=$((FAIL+1)); echo "FAIL T7 (rc=$rc out='$out')"
fi

# T8 — reconcile: 재개 힌트(다음 단계) 제시
out=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$T6_FID" 2>&1)
if printf '%s' "$out" | grep -qiE '재개|다음|resume|권장'; then
  PASS=$((PASS+1)); echo "PASS T8 reconcile-재개 힌트"
else
  FAIL=$((FAIL+1)); echo "FAIL T8 (out='$out')"
fi

# T9 — 유지보수 흐름: /analyze 단계 인식 (20260718 실측 결함 — dogfood test2 scanner-blockcomment-fix)
#   analyze 완료 + current-state/impact-analysis 산출물만 있는 상태 = 정합(경고 없음).
#   구버전은 사다리에 analyze 부재 → recorded=0·evidence=0 우연정합 + '기록: -' 오라벨.
T9_FID="20260106-maint-analyze"
mkdir -p "$TMPDIR_TEST/.specops/$T9_FID"
printf '## %s · maint\n\n- 2026-01-06T00:00:00Z /analyze 완료 (current-state.md, impact-analysis.md)\n' "$T9_FID" >> "$T3_PROGRESS"
touch "$TMPDIR_TEST/.specops/$T9_FID/current-state.md" "$TMPDIR_TEST/.specops/$T9_FID/impact-analysis.md"
out=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$T9_FID" 2>&1); rc=$?
# reconcile 섹션만 스코프 (상단 이력 echo 의 analyze 로 인한 tautology 차단)
recon=$(printf '%s' "$out" | sed -n '/reconcile/,$p')
if [ "$rc" -eq 0 ] && ! printf '%s' "$recon" | grep -qiE 'DESYNC|과소보고' \
   && printf '%s' "$recon" | grep -qi 'analyze'; then
  PASS=$((PASS+1)); echo "PASS T9 analyze 단계 인식 (유지보수 정합·경고 0)"
else
  FAIL=$((FAIL+1)); echo "FAIL T9 (rc=$rc recon='$recon')"
fi

# T10 — 유지보수 흐름 desync: analyze 기록인데 spec.md 존재(specify 미기록) → DESYNC + 재개 specify
T10_FID="20260107-maint-desync"
mkdir -p "$TMPDIR_TEST/.specops/$T10_FID"
printf '## %s · maint2\n\n- 2026-01-07T00:00:00Z /analyze 완료 (current-state.md)\n' "$T10_FID" >> "$T3_PROGRESS"
touch "$TMPDIR_TEST/.specops/$T10_FID/current-state.md" "$TMPDIR_TEST/.specops/$T10_FID/impact-analysis.md" "$TMPDIR_TEST/.specops/$T10_FID/spec.md"
out=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$T10_FID" 2>&1); rc=$?
recon=$(printf '%s' "$out" | sed -n '/reconcile/,$p')
# 기록 frontier 가 analyze 로 라벨돼야 함 ('기록 frontier: analyze' — 구버전은 '-')
if [ "$rc" -eq 0 ] && printf '%s' "$recon" | grep -qiE 'DESYNC|과소보고' \
   && printf '%s' "$recon" | grep -qiE '기록 frontier: analyze'; then
  PASS=$((PASS+1)); echo "PASS T10 analyze→specify 미기록 desync + 기록 frontier=analyze"
else
  FAIL=$((FAIL+1)); echo "FAIL T10 (rc=$rc recon='$recon')"
fi


# === 단계 소요 표 (20260911-stage-timing-derive) ===
_TS_FID=20260911-tsfix
mkdir -p "$TMPDIR_TEST/.specops/$_TS_FID"
# 원장은 **역순**(최신 우선)으로 쓰인다 — 정렬 없이 계산하면 음수가 나온다.
# 자정 경계(23:59 → 00:09)를 일부러 포함한다 — 직전 FID 에 실재하는 형태다.
cat > "$TMPDIR_TEST/.specops/session-progress.md" <<TSEOF
<!-- active-fid: $_TS_FID -->
## $_TS_FID
- 2026-09-11 00:09 /security-review DONE (x)
- 2026-09-10 23:59 /verify PASS (x)
- 2026-09-10 21:09 /implement DONE (x)
- 2026-09-10 20:12 /implement 진행 (x)
- 2026-09-10 19:12 /specify 완료 (x)
TSEOF
out=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$_TS_FID" 2>&1)

# AC-1: 인접 구간이 나온다 (specify→implement 60m · implement→implement 57m
#       · implement→verify 170m · verify→security-review 10m)
if printf '%s' "$out" | grep -q '/specify' && printf '%s' "$out" | grep -q '/implement'; then
  PASS=$((PASS+1)); echo "PASS T-ts.a 소요 표에 단계 쌍 출력"
else FAIL=$((FAIL+1)); echo "FAIL T-ts.a 단계 쌍 없음"; fi

# AC-5: 자정 경계 — 23:59 → 00:09 는 10m 이어야 한다 (음수·거대값 금지)
if printf '%s' "$out" | grep -qE '/verify +→ +/security-review +10m'; then
  PASS=$((PASS+1)); echo "PASS T-ts.b 자정 경계 10m"
else FAIL=$((FAIL+1)); echo "FAIL T-ts.b 자정 경계: $(printf '%s' "$out" | grep -E '/verify.*security' || echo '(행 없음)')"; fi

# AC-8: 60분 미만 = Nm · 이상 = XhYm
if printf '%s' "$out" | grep -qE '/implement +→ +/implement +57m'; then
  PASS=$((PASS+1)); echo "PASS T-ts.c 60분 미만 = 57m"
else FAIL=$((FAIL+1)); echo "FAIL T-ts.c 57m 표기"; fi
if printf '%s' "$out" | grep -qE '/implement +→ +/verify +2h50m'; then
  PASS=$((PASS+1)); echo "PASS T-ts.d 60분 이상 = 2h50m"
else FAIL=$((FAIL+1)); echo "FAIL T-ts.d 2h50m 표기: $(printf '%s' "$out" | grep -E '/implement.*verify' || echo '(행 없음)')"; fi
# 경계값 정확히 60분 → 1h0m (specify 19:12 → implement 20:12)
if printf '%s' "$out" | grep -qE '/specify +→ +/implement +1h0m'; then
  PASS=$((PASS+1)); echo "PASS T-ts.e 경계 60분 = 1h0m"
else FAIL=$((FAIL+1)); echo "FAIL T-ts.e 1h0m 표기"; fi

# AC-7: 플래그 없이 기본 출력 + 헤더가 측정 기준·해상도·경과시간 단서를 말한다
if printf '%s' "$out" | grep -q '인접 행 차이' \
   && printf '%s' "$out" | grep -q '분 해상도' \
   && printf '%s' "$out" | grep -q '경과 시간'; then
  PASS=$((PASS+1)); echo "PASS T-ts.f 헤더가 측정 기준·해상도·경과시간 명시"
else FAIL=$((FAIL+1)); echo "FAIL T-ts.f 헤더 단서 누락"; fi

# AC-4: 행 1건 → 표 생략 + 사유 1줄 (빈 표 금지)
_TS1=20260911-tsone
mkdir -p "$TMPDIR_TEST/.specops/$_TS1"
cat > "$TMPDIR_TEST/.specops/session-progress.md" <<TS1EOF
## $_TS1
- 2026-09-11 00:09 /analyze 완료 (x)
TS1EOF
out1=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$_TS1" 2>&1)
if printf '%s' "$out1" | grep -q '구간 없음'; then
  PASS=$((PASS+1)); echo "PASS T-ts.g 1행 → 표 생략 + 사유"
else FAIL=$((FAIL+1)); echo "FAIL T-ts.g 1행 처리"; fi
# AC-4 는 "0행·1행 2종" 을 요구한다 — 0행도 잠근다(진행 이력 자체가 없는 FID).
_TS0=20260911-tszero
mkdir -p "$TMPDIR_TEST/.specops/$_TS0"
: > "$TMPDIR_TEST/.specops/session-progress.md"
out0=$(SPECOPS_ROOT="$TMPDIR_TEST/.specops" "$SCRIPT" "$_TS0" 2>&1)
if printf '%s' "$out0" | grep -q '구간 없음'; then
  PASS=$((PASS+1)); echo "PASS T-ts.g0 0행 → 표 생략 + 사유"
else FAIL=$((FAIL+1)); echo "FAIL T-ts.g0 0행 처리"; fi
echo ""
echo "결과: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
