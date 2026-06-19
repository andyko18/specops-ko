#!/usr/bin/env bash
# start-all rename 검증 (FID 20260619-rename-start-all)
set -u
PASS=0; FAIL=0
P=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
nope() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }

# AC-1: start-all.md 신설 + name + trigger + 3-Phase 오케스트레이터
SA="$P/commands/start-all.md"
[ -f "$SA" ] && grep -q '^name: start-all' "$SA" && grep -q '"/start-all"' "$SA" && grep -q 'Phase 1' "$SA" \
  && ok "AC-1 start-all.md 신설" || nope "AC-1" "start-all.md 결함"
# AC-2: start-batch.md deprecated stub
SB="$P/commands/start-batch.md"
grep -qi 'deprecated' "$SB" && grep -q '/start-all' "$SB" \
  && ok "AC-2 start-batch deprecated stub" || nope "AC-2" "stub 결함"
# AC-3: 사용자 슬래시 갱신 — /init-project 류 마스킹 후 /start-batch(슬래시) 잔존 0
#   (.md 파일명·§batch·batch-id·BATCH- 신호어 제외)
miss=""
for f in README.md skills/specifying-ko/SKILL.md skills/integration-test-ko/SKILL.md skills/performance-test-ko/SKILL.md skills/receiving-code-review-ko/SKILL.md skills/decomposing-ko/SKILL.md; do
  grep -q '/start-all' "$P/$f" || miss="$miss $f(no-all)"
  # start-batch.md(파일명) 마스킹 후 /start-batch(슬래시) 잔존 검사
  sed -E 's#start-batch\.md#XMASKX#g' "$P/$f" | grep -q '/start-batch' && miss="$miss $f(stale-batch)"
done
[ -z "$miss" ] && ok "AC-3 슬래시 갱신" || nope "AC-3" "$miss"
# AC-R-1: §batch 신호어 보존 (소비처 grep 건수 — 분기 라벨 무변경)
for sig in '\*\*§batch\*\*' 'BATCH-PHASE1-DONE' 'batch-id'; do
  c=$(grep -rl "$sig" "$P/skills" 2>/dev/null | wc -l | tr -d ' ')
  [ "$c" -gt 0 ] || nope "AC-R-1 $sig" "신호어 소실"
done
[ "$FAIL" -eq 0 ] && ok "AC-R-1 §batch 신호어 보존" || true

echo "── test-rename-start-all: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
