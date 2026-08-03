#!/usr/bin/env bash
# test-reconcile-check.sh — reconcile-check.sh (재개 desync 자동표면화 공유 로직) 단위 테스트
# 배경: show-fid-status FR-6 reconcile 로직을 공유 스크립트로 추출 → show-fid-status·SessionStart 훅 공용.
#   default 모드 = 기존 reconcile 블록(show-fid-status 위임, 출력 동일), --hook 모드 = DESYNC 시 간결 경고/정합 시 무출력.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/_internal/reconcile-check.sh"

TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

# ── fixture 헬퍼 ──
# desync FID: session-progress=/tasks, 증거=implement(dispatch DONE)+verify(evidence.md) → evidence>recorded
mk_desync() {
  local fid="$1" root="$TMP/.specops"
  mkdir -p "$root/$fid"
  printf '## %s · stalled\n\n- 2026-01-04T00:00:00Z /tasks 완료 (tasks.md)\n' "$fid" >> "$root/session-progress.md"
  touch "$root/$fid/spec.md" "$root/$fid/plan.md" "$root/$fid/tasks.md"
  printf '| 1 | ts | A:T1 | implementer-ko | DONE | x |\n' > "$root/$fid/dispatch-log.md"
  printf 'RUN-VERIFICATION-RESULT: PASS\n' > "$root/$fid/evidence.md"
}
# in-sync FID: session-progress=/specify, 증거=spec.md → recorded==evidence
mk_sync() {
  local fid="$1" root="$TMP/.specops"
  mkdir -p "$root/$fid"
  printf '## %s · ok\n\n- 2026-01-05T00:00:00Z /specify 완료 (spec.md)\n' "$fid" >> "$root/session-progress.md"
  touch "$root/$fid/spec.md"
}

ok() { PASS=$((PASS+1)); echo "PASS $1"; }
no() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }

# R1 — default 모드 DESYNC: reconcile 블록 헤더 + DESYNC + 재개점 힌트
mk_desync "20260104-desync"
out=$(SPECOPS_ROOT="$TMP/.specops" bash "$SCRIPT" "20260104-desync" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qF '실제 진행 대조 (reconcile)' \
   && printf '%s' "$out" | grep -qiE 'DESYNC|과소보고' \
   && printf '%s' "$out" | grep -qi '재개점'; then
  ok "R1 default-desync 블록+재개점"
else no "R1" "rc=$rc out=[$out]"; fi

# R2 — default 모드 정합: DESYNC 없음, '정합' 표기
mk_sync "20260105-sync"
out=$(SPECOPS_ROOT="$TMP/.specops" bash "$SCRIPT" "20260105-sync" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -qiE 'DESYNC|과소보고' \
   && printf '%s' "$out" | grep -qi '정합'; then
  ok "R2 default-정합 (경고 0)"
else no "R2" "rc=$rc out=[$out]"; fi

# R3 — --hook 모드 DESYNC: 비어있지 않음 + DESYNC + 재개점, exit 0
out=$(SPECOPS_ROOT="$TMP/.specops" bash "$SCRIPT" "20260104-desync" --hook 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -n "$out" ] \
   && printf '%s' "$out" | grep -qiE 'DESYNC|과소보고' \
   && printf '%s' "$out" | grep -qi '재개점'; then
  ok "R3 hook-desync 간결경고"
else no "R3" "rc=$rc out=[$out]"; fi

# R4 — --hook 모드 정합: 무출력, exit 0 (훅 노이즈 0)
out=$(SPECOPS_ROOT="$TMP/.specops" bash "$SCRIPT" "20260105-sync" --hook 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
  ok "R4 hook-정합 무출력"
else no "R4" "rc=$rc out=[$out]"; fi

# R5 — --hook 잘못된 FID 형식: 무출력 + exit 0 (훅 오염 금지 — silent)
out=$(SPECOPS_ROOT="$TMP/.specops" bash "$SCRIPT" "invalid_fid" --hook 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
  ok "R5 hook-invalid-fid silent"
else no "R5" "rc=$rc out=[$out]"; fi

# R6 — --hook FID 디렉토리 없음: 무출력 + exit 0
out=$(SPECOPS_ROOT="$TMP/.specops" bash "$SCRIPT" "20991231-nonexistent" --hook 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
  ok "R6 hook-missing-dir silent"
else no "R6" "rc=$rc out=[$out]"; fi

# R7 — evidence 파일 존재만으로 verify 완료로 보지 않는다. 구조화 FAIL이면 implement frontier 유지.
fid="20260803-failed-verify"; root="$TMP/.specops"
mkdir -p "$root/$fid"
printf '## %s\n- 2026-08-03 10:00 /implement DONE\n' "$fid" >> "$root/session-progress.md"
touch "$root/$fid/spec.md" "$root/$fid/tasks.md"
printf 'RUN-VERIFICATION-RESULT: FAIL\n' > "$root/$fid/evidence.md"
printf '| 1 | ts | A:T1 | implementer-ko | DONE | x |\n' > "$root/$fid/dispatch-log.md"
SPECOPS_ROOT="$root" bash "$PLUGIN/scripts/_internal/verification-state.sh" record "$fid" FAIL
out=$(SPECOPS_ROOT="$root" bash "$SCRIPT" "$fid" --hook 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
  ok "R7 구조화 FAIL은 verify frontier 아님"
else no "R7" "rc=$rc out=[$out]"; fi

echo "── test-reconcile-check: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
