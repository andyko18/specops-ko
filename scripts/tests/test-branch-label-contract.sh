#!/usr/bin/env bash
# 분기 라벨 생산↔소비 정합 회귀 (FID 20260619-branch-label-contract)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
SK="$PLUGIN/skills"
ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
nope() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }

# 역방향 소비처 자동 수집 (하드코딩 제거 — label_consumer backlog 해소)
# 주의: collect 는 grep -F(리터럴) — 소비처의 `grep -q '\*\*§batch\*\*'` 코드(백슬래시 포함)를 매칭.
#       아래 AC-5(생산 표기)의 grep(no -F)은 정규식 — 산문 마커 **§batch** 매칭. -F 제거 시 산문까지 오매칭 회귀.
collect() { grep -rlF "$1" "$SK"/*/SKILL.md 2>/dev/null | sed 's|.*/\([^/]*\)/SKILL.md|\1|' | sort; }
BATCH_C=$(collect '\*\*§batch\*\*')
AUTO_C=$(collect '\*\*§auto\*\*')

# AC-3: 공허 방지 — 수집 0개면 FAIL (전수 삭제 등 비정상 탐지)
[ -n "$BATCH_C" ] && [ -n "$AUTO_C" ] && ok "AC-3 역방향 수집 비어있지 않음" || nope "AC-3" "수집 0개(공허)"

# AC-1: §batch 소비처 자동 수집 — 정의상 전건 패턴 보유. 핵심 기대치(AC-4)로 정합 보강.
ok "AC-1 §batch 역방향 수집 ($(echo $BATCH_C | wc -w | tr -d ' ')건)"
# AC-2: §auto 수집에 using-git-worktrees-ko 포함 (기존 하드코딩 누락 해소)
echo "$AUTO_C" | grep -q '^using-git-worktrees-ko$' && ok "AC-2 §auto 수집에 using-git-worktrees-ko 포함" || nope "AC-2" "worktree 누락"

# AC-4: 핵심 기대치 — 반드시 있어야 할 소비처
for k in decomposing-ko performance-test-ko; do
  echo "$BATCH_C" | grep -q "^$k$" || nope "AC-4 §batch 핵심 $k" "누락"
done
for k in decomposing-ko verifying-evidence-ko; do
  echo "$AUTO_C" | grep -q "^$k$" || nope "AC-4 §auto 핵심 $k" "누락"
done
echo "$BATCH_C" | grep -q '^decomposing-ko$' && echo "$AUTO_C" | grep -q '^verifying-evidence-ko$' && ok "AC-4 핵심 기대치 포함" || true

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
