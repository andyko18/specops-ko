#!/usr/bin/env bash
# skip-tracker.sh 집계 로직 stub 단위 (토큰 0)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck disable=SC1091
source "$PLUGIN/scripts/skip-tracker.sh"
ck() { if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS+1)); else echo "FAIL $1 — exp '$3' got '$2'"; FAIL=$((FAIL+1)); fi; }

ck "T1 rate 3/4 → 75" "$(skip::rate 3 4)" "75"
ck "T2 rate 0/0 → 0"  "$(skip::rate 0 0)" "0"
ck "T3 rate 7/10 → 70" "$(skip::rate 7 10)" "70"

tmp=$(mktemp -d)
mkdir -p "$tmp/fid-a" "$tmp/fid-b" "$tmp/fid-c"
printf '## /integration-test — 2026-06-14\n**결과**: SKIP\n## /performance-test — 2026-06-14\n**결과**: PASS\n' > "$tmp/fid-a/evidence.md"
printf '## /integration-test — SKIP (인프라)\n## /performance-test — SKIP (NFR 없음)\n' > "$tmp/fid-b/evidence.md"
printf '## /integration-test — 2026-06-13\n**결과**: FAIL\n' > "$tmp/fid-c/evidence.md"

ck "T4 integration count" "$(skip::count "$tmp" integration)" "0 2 1"
ck "T5 performance count" "$(skip::count "$tmp" performance)" "1 1 0"
ck "T6 verdicts 구조형" "$(skip::verdicts "$tmp/fid-a/evidence.md" integration)" "SKIP"
ck "T7 verdicts 인라인형" "$(skip::verdicts "$tmp/fid-b/evidence.md" integration)" "SKIP"

out=$(SKIP_TRACKER_THRESHOLD=50 skip::report "$tmp" 2>/dev/null)
if printf '%s' "$out" | grep -qE "integration: total=3 PASS=0 SKIP=2 FAIL=1"; then echo "PASS T8 report 형식"; PASS=$((PASS+1)); else echo "FAIL T8 report ($out)"; FAIL=$((FAIL+1)); fi
if printf '%s' "$out" | grep -q "⚠️"; then echo "PASS T9 임계 advisory ⚠️"; PASS=$((PASS+1)); else echo "FAIL T9 ⚠️ ($out)"; FAIL=$((FAIL+1)); fi
rm -rf "$tmp"

out2=$(skip::report "/nonexistent" 2>/dev/null); rc=$?
if printf '%s' "$out2" | grep -q "evidence 없음" && [ "$rc" -eq 0 ]; then echo "PASS T10 graceful"; PASS=$((PASS+1)); else echo "FAIL T10 graceful (rc=$rc $out2)"; FAIL=$((FAIL+1)); fi

# T11 인접 헤더 오연관 차단 — integration 헤더(결과 없음) 직후 performance **결과**: SKIP 가 integration 으로 오집계되면 안 됨
tmp2=$(mktemp -d)
printf '## /integration-test — 2026-06-14\n## /performance-test — 2026-06-14\n**결과**: SKIP\n' > "$tmp2/evidence.md"
ck "T11 인접 헤더 오연관 차단 (integration verdict 없음)" "$(skip::verdicts "$tmp2/evidence.md" integration)" ""
rm -rf "$tmp2"

echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
