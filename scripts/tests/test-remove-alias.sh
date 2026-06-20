#!/usr/bin/env bash
# deprecated alias 제거 검증 (FID 20260620-remove-deprecated-alias)
set -u
PASS=0; FAIL=0
P=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
nope() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }

# AC-1: alias 2파일 부재
[ ! -f "$P/commands/start-project.md" ] && [ ! -f "$P/commands/start-batch.md" ] \
  && ok "AC-1 alias 2건 삭제" || nope "AC-1" "alias 파일 잔존"
# AC-2: baseline commands 14
grep -q '"category":"commands","glob":"commands/\*.md","count":14' "$P/scripts/_internal/.structure-baseline" \
  && ok "AC-2 baseline commands 14" || nope "AC-2" "baseline 미갱신"
# AC-3: stale 문구 정리 — "deprecated alias 보존"·"(구 /start-batch)" 부재
! grep -q 'deprecated alias 보존' "$P/commands/init-project.md" && ! grep -q '(구 /start-batch)' "$P/commands/start-all.md" \
  && ok "AC-3 stale 문구 정리" || nope "AC-3" "stale 문구 잔존"
# AC-R-3: 오케스트레이터·런타임토큰 보존
[ -f "$P/scripts/_internal/start-project.sh" ] && grep -q '/start-project' "$P/templates/api-spec.md" \
  && ok "AC-R-3 오케스트레이터·런타임토큰 보존" || nope "AC-R-3" "보존 대상 소실"

echo "── test-remove-alias: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
