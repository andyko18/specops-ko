#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
HOOK="$PLUGIN/hooks/session-start.sh"
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.specops"

# T4.a pending 존재 → additionalContext 에 처리 안내 주입 (AC-4)
printf '%s\n' '{"ts":"2026-06-25T10:00:00Z","files":["foo.sh"],"prompt":"버그 고쳐","type":"fix"}' \
  > "$TMP/.specops/pending-capture.jsonl"
out=$(cd "$TMP" && echo '{}' | bash "$HOOK" 2>/dev/null)
if echo "$out" | grep -q '미기록 자유작업'; then
  PASS=$((PASS+1)); echo "PASS T4.a pending 주입"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.a (out=$out)"
fi

# T4.b pending 없으면 안내 미주입 + additionalContext 유지 (회귀 — 기존 동작 무변화)
rm -f "$TMP/.specops/pending-capture.jsonl"
out=$(cd "$TMP" && echo '{}' | bash "$HOOK" 2>/dev/null)
if ! echo "$out" | grep -q '미기록 자유작업' && echo "$out" | grep -q 'additionalContext'; then
  PASS=$((PASS+1)); echo "PASS T4.b pending 없음 무영향"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.b (out=$out)"
fi
echo "---"; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
