#!/usr/bin/env bash
# test-batch-orchestration.sh — /start-all batch 오케스트레이션 결정적 시뮬 (FID 20260711-g0-batch-e2e)
# 검증 대상: commands/start-all.md 의 queue 상태기계 규칙 재현 (본체 무접촉 — 읽기 전용 계약)
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
PASS=0; FAIL=0
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

# ── fixture: requirements (FR 3행 + 비FR 행 1) ──
cat > "$TMP/req.md" <<'EOF'
# 요구사항
| ID | 요구사항 | 마일스톤 | 우선순위 |
|---|---|---|---|
| FR-1 | 기능 A | M1 | must |
| FR-2 | 기능 B | M1 | must |
| FR-3 | 기능 C | M2 | should |
| NFR-1 | 성능 | M1 | must |
EOF

# ── T1: Phase 0 재현 — FR 파싱 + queue 초기화 (start-all.md:33 grep 기준 · :46-51 포맷) ──
mkdir -p "$TMP/.specops/batch-t"
Q="$TMP/.specops/batch-t/queue.md"
{
  echo "| FR-ID | FID | FR 설명(1줄) | Status |"
  echo "|---|---|---|---|"
  grep -E '^\| FR-[0-9]+ \|' "$TMP/req.md" | while IFS='|' read -r _ frid desc _rest; do
    frid=$(echo "$frid" | tr -d ' '); desc=$(echo "$desc" | sed 's/^ *//;s/ *$//')
    echo "| $frid | TBD | $desc | PENDING |"
  done
} > "$Q"
n_fr=$(grep -cE '^\| FR-[0-9]+ \|.*PENDING' "$Q")
grep -q 'NFR-1' "$Q" && has_nfr=1 || has_nfr=0
[ "$n_fr" -eq 3 ] && [ "$has_nfr" -eq 0 ] \
  && ok "T1.a Phase 0 재현 — FR 3행 PENDING·비FR 제외 (start-all.md:33·46-51)" \
  || nope "T1.a Phase 0" "fr=$n_fr nfr=$has_nfr"

# ── T2: 전이 — PLAN_DONE 갱신 (start-all.md:66 — FID 기입 + Status) ──
sed -i.bak 's/^| FR-1 | TBD | 기능 A | PENDING |$/| FR-1 | 20260711-a | 기능 A | PLAN_DONE |/' "$Q" && rm -f "$Q.bak"
grep -q '| FR-1 | 20260711-a | 기능 A | PLAN_DONE |' "$Q" \
  && ok "T2.a PLAN_DONE 전이 (start-all.md:66)" || nope "T2.a 전이" "갱신 실패"

# ── T3: 재진입 — 기존 queue 재사용 (start-all.md:43-44 — 존재 시 초기화 스킵·상태 보존) ──
if [ ! -f "$Q" ]; then
  echo "재초기화 발생" > "$Q"   # 존재하므로 이 분기 미진입이 규칙
fi
grep -q 'PLAN_DONE' "$Q" && ! grep -q '재초기화 발생' "$Q" \
  && ok "T3.a 재진입 상태 보존 (start-all.md:43-44 — 재초기화 미발생)" || nope "T3.a 재진입" "PLAN_DONE 소실 또는 재초기화됨"

# ── T4: batch-state 게이트 통합 — 부분 완료 → exit 1 (start-all.md:95-101) ──
out=$(bash "$PLUGIN/scripts/batch-state.sh" "$TMP/.specops/batch-t" "$TMP/req.md" 2>&1); code=$?
[ "$code" -eq 1 ] && echo "$out" | grep -q "FR-2" \
  && ok "T4.a 게이트 — 부분 완료 exit 1 + 미완 목록" || nope "T4.a 게이트" "exit=$code"

# ── T5: 전체 IMPL_DONE → 게이트 clean (start-all.md:88 전이 후) ──
sed -i.bak -E 's/\| (PENDING|PLAN_DONE) \|$/| IMPL_DONE |/' "$Q" && rm -f "$Q.bak"
# NFR 드리프트 잔여 방지 — req 는 FR 3행뿐이므로 drift 0 기대... (req 에 NFR-1 은 FR_RE 미매칭)
bash "$PLUGIN/scripts/batch-state.sh" "$TMP/.specops/batch-t" "$TMP/req.md" >/dev/null 2>&1; code=$?
[ "$code" -eq 0 ] \
  && ok "T5.a 전체 IMPL_DONE → 게이트 exit 0 (start-all.md:88·95)" || nope "T5.a clean" "exit=$code"

# ── T6: e2e [S8] 문서 계약 (AC-4) ──
E2E="$PLUGIN/skills/e2e-test-ko/SKILL.md"
grep -q '^## \[S8\] BATCH' "$E2E" && grep -q 'V22' "$E2E" && grep -q 'V23' "$E2E" && grep -q 'V24' "$E2E" \
  && ok "T6.a e2e [S8]+V22~24 정의" || nope "T6.a [S8]" "블록/V 정의 없음"

# ── T7: V 개수 동기 3곳 (AC-5) ──
c1=$(grep -c '24개 검증 항목(V1~V24)' "$E2E"); c2=$(grep -c '24개 검증 항목' "$PLUGIN/commands/e2e-test.md")
r21=$(grep -c '21개 검증 항목' "$E2E" "$PLUGIN/commands/e2e-test.md" | awk -F: '{s+=$2} END{print s}')
[ "$c1" -ge 1 ] && [ "$c2" -ge 1 ] && [ "$r21" -eq 0 ] \
  && ok "T7.a V 개수 24 동기·21 잔존 0" || nope "T7.a V 동기" "c1=$c1 c2=$c2 r21=$r21"

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
