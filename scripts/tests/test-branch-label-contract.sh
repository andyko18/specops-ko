#!/usr/bin/env bash
# 분기 라벨 생산↔소비 정합 회귀 (FID 20260619-branch-label-contract)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
SK="$PLUGIN/skills"
ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
nope() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }

# 소비처 — §batch 소비 grep 보유 SKILL
BATCH_CONSUMERS="decomposing-ko performance-test-ko receiving-code-review-ko structured-artifacts-ko"
# 소비처 — §auto 소비 grep 보유 SKILL
AUTO_CONSUMERS="decomposing-ko performance-test-ko planning-ko implementing-ko clarifying-ko verifying-evidence-ko specifying-ko structured-artifacts-ko"

# AC-1: §batch 소비처가 모두 '\*\*§batch\*\*' 패턴 사용
#   SKILL.md 본문 실측 표기: grep -q '\*\*§batch\*\*' (백슬래시-별표). fixed-string -F 로 견고 매칭.
miss=""
for c in $BATCH_CONSUMERS; do
  f="$SK/$c/SKILL.md"
  grep -F '\*\*§batch\*\*' "$f" >/dev/null || miss="$miss $c"
done
[ -z "$miss" ] && ok "AC-1 §batch 소비 패턴 일관" || nope "AC-1" "불일치:$miss"

# AC-2: §auto 소비처가 모두 '\*\*§auto\*\*' 패턴 사용
miss=""
for c in $AUTO_CONSUMERS; do
  f="$SK/$c/SKILL.md"
  grep -F '\*\*§auto\*\*' "$f" >/dev/null || miss="$miss $c"
done
[ -z "$miss" ] && ok "AC-2 §auto 소비 패턴 일관" || nope "AC-2" "불일치:$miss"

# 3-way 분기 로직 (소비처 동일 패턴 재현)
classify() { if grep -q '\*\*§batch\*\*' "$1"; then echo BATCH; elif grep -q '\*\*§auto\*\*' "$1"; then echo AUTO; else echo SINGLE; fi; }

# AC-3: §batch fixture → BATCH
T=$(mktemp); printf '# spec\n**§batch**: batch-20260619\n' > "$T"
[ "$(classify "$T")" = "BATCH" ] && ok "AC-3 §batch→BATCH" || nope "AC-3" "분기 오판"; rm -f "$T"

# AC-4: §auto fixture → AUTO, 무라벨 → SINGLE
T=$(mktemp); printf '# spec\n**§auto**: true\n' > "$T"
[ "$(classify "$T")" = "AUTO" ] && ok "AC-4a §auto→AUTO" || nope "AC-4a" "분기 오판"; rm -f "$T"
T=$(mktemp); printf '# spec\n**§유형**: 유지보수\n' > "$T"
[ "$(classify "$T")" = "SINGLE" ] && ok "AC-4b 무라벨→SINGLE" || nope "AC-4b" "분기 오판"; rm -f "$T"

# AC-5: specifying-ko 생산 표기 유지
grep -q '\*\*§batch\*\*' "$SK/specifying-ko/SKILL.md" && ok "AC-5a 생산 §batch 표기" || nope "AC-5a" "생산 표기 소실"
grep -q '\*\*§auto\*\*' "$SK/specifying-ko/SKILL.md" && ok "AC-5b 생산 §auto 표기" || nope "AC-5b" "생산 표기 소실"

echo "── test-branch-label-contract: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
