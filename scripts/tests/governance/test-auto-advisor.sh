#!/usr/bin/env bash
# §auto advisor 보조 자문 통합 회귀 — 3 분기 advisor 텍스트 + graceful fallback 문구 가드
# 한계: presence-only(문구 존재만 검증) — 삽입 위치·흐름 통합은 미검증. 본문 리워딩 시 grep 완화 필요.
set -u
PASS=0; FAIL=0
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$PLUGIN/scripts/tests/harness.sh"

# T1: clarifying §auto advisor + fallback + 주권
C="$PLUGIN/skills/clarifying-ko/SKILL.md"
grep -q 'advisor()' "$C" && ok "AC-1 clarify advisor 자문" || nope "AC-1" "advisor 미존재"
grep -q '미연결' "$C" && ok "AC-R-2a clarify fallback" || nope "AC-R-2a" "fallback 미존재"
grep -q 'ASSUMED.*유지' "$C" && ok "AC-R-3a clarify 주권보존" || nope "AC-R-3a" "주권 미존재"

# T2: planning §auto cap advisor + fallback
P="$PLUGIN/skills/planning-ko/SKILL.md"
grep -q 'advisor().*1회 자문' "$P" && ok "AC-3 planning advisor" || nope "AC-3" "advisor 미존재"
grep -q 'graceful fallback' "$P" && ok "AC-R-2b planning fallback" || nope "AC-R-2b" "fallback 미존재"

# T3: verifying §auto fix_loop advisor + fallback
V="$PLUGIN/skills/verifying-evidence-ko/SKILL.md"
grep -q 'advisor().*자문 시도' "$V" && ok "AC-4 verify advisor" || nope "AC-4" "advisor 미존재"
grep -q 'graceful fallback' "$V" && ok "AC-R-2c verify fallback" || nope "AC-R-2c" "fallback 미존재"

# T4: advisor-ko §auto 무인 행 + 주권
A="$PLUGIN/skills/advisor-ko/SKILL.md"
grep -q '§auto 무인' "$A" && ok "AC-5 advisor §auto 행" || nope "AC-5" "§auto 행 미존재"
grep -q '결정 대행 아님' "$A" && ok "AC-R-3b advisor 주권명시" || nope "AC-R-3b" "주권 미존재"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
