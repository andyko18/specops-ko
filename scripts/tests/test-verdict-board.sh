#!/usr/bin/env bash
# test-verdict-board — AC-1~5 검증 (매트릭스·기호·재활용·읽기전용)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
VB="$PLUGIN/scripts/verdict-board.sh"
TD=$(mktemp -d); trap 'rm -rf "$TD"' EXIT

mkdir -p "$TD/20260615-alpha" "$TD/20260101-beta" "$TD/memory"
cat > "$TD/20260615-alpha/evidence.md" <<'EOF'
## /verify — 2026-06-15T10:00:00Z
**결과**: PASS — AC 충족
## /integration-test — 2026-06-15T10:01:00Z
**결과**: SKIP
## /performance-test — 2026-06-15T10:02:00Z
**결과**: FAIL — 임계값 초과
EOF
# 20260101-beta: evidence.md 없음 (미실행)

out=$(bash "$VB" "$TD")

# T1.a AC-1/2: alpha verify=✅ integ=⏭ perf=❌
if echo "$out" | grep "20260615-alpha" | grep -q "✅" \
   && echo "$out" | grep "20260615-alpha" | grep -q "⏭" \
   && echo "$out" | grep "20260615-alpha" | grep -q "❌"; then
  PASS=$((PASS+1)); echo "PASS T1.a AC-1/2 alpha 매트릭스(✅⏭❌)"
else FAIL=$((FAIL+1)); echo "FAIL T1.a ($(echo "$out" | grep alpha))"; fi

# T1.b AC-2: beta(evidence 없음) → 미실행(verdict 기호 없음) — I-1 반영
if echo "$out" | grep -q "20260101-beta" && ! echo "$out" | grep "20260101-beta" | grep -qE "✅|⏭|❌"; then
  PASS=$((PASS+1)); echo "PASS T1.b AC-2 beta 미실행(verdict 없음)"
else FAIL=$((FAIL+1)); echo "FAIL T1.b ($(echo "$out" | grep beta))"; fi

# T1.c AC-4: 날짜순 최신 위 (alpha 20260615 > beta 20260101)
alpha_ln=$(echo "$out" | grep -n "20260615-alpha" | cut -d: -f1)
beta_ln=$(echo "$out" | grep -n "20260101-beta" | cut -d: -f1)
if [ -n "$alpha_ln" ] && [ -n "$beta_ln" ] && [ "$alpha_ln" -lt "$beta_ln" ]; then
  PASS=$((PASS+1)); echo "PASS T1.c AC-4 날짜순 최신 위"
else FAIL=$((FAIL+1)); echo "FAIL T1.c (alpha=$alpha_ln beta=$beta_ln)"; fi

# T1.d AC-4: memory 디렉토리(FID 형식 아님) skip
if ! echo "$out" | grep -q "^memory"; then
  PASS=$((PASS+1)); echo "PASS T1.d AC-4 비-FID 디렉토리 skip"
else FAIL=$((FAIL+1)); echo "FAIL T1.d memory 포함됨"; fi

# T1.e AC-5/AC-R-1: 읽기전용 + exit 0 (skip-tracker md5 불변)
m1=$(md5 -q "$PLUGIN/scripts/skip-tracker.sh"); bash "$VB" "$TD" >/dev/null; rc=$?; m2=$(md5 -q "$PLUGIN/scripts/skip-tracker.sh")
if [ $rc -eq 0 ] && [ "$m1" = "$m2" ]; then
  PASS=$((PASS+1)); echo "PASS T1.e AC-5/R-1 읽기전용 exit 0(skip-tracker 무손상)"
else FAIL=$((FAIL+1)); echo "FAIL T1.e (rc=$rc md5 $m1/$m2)"; fi

# T1.f AC-5: 빈 .specops graceful
empty=$(mktemp -d)
out2=$(bash "$VB" "$empty"); rc=$?
if [ $rc -eq 0 ] && echo "$out2" | grep -q "FID"; then
  PASS=$((PASS+1)); echo "PASS T1.f AC-5 빈 디렉토리 graceful(헤더만)"
else FAIL=$((FAIL+1)); echo "FAIL T1.f (rc=$rc)"; fi
rm -rf "$empty"

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
