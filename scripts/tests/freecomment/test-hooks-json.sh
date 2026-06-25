#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
HOOKS_JSON="$PLUGIN/hooks/hooks.json"

# T3.a hooks.json 유효 + Stop 에 freecomment-capture 등록
if jq -e '.hooks.Stop' "$HOOKS_JSON" >/dev/null 2>&1 && \
   grep -q 'freecomment-capture.sh' "$HOOKS_JSON"; then
  PASS=$((PASS+1)); echo "PASS T3.a freecomment-capture Stop 등록"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.a"
fi
echo "---"; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
