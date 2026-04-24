#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
HOOKS_JSON="$PLUGIN/hooks/hooks.json"

# T12.a hooks.json: PostToolUse 배열 + posttool-governance 항목
if jq -e '.hooks.PostToolUse[] | .hooks[] | select(.command | contains("posttool-governance.sh"))' "$HOOKS_JSON" >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "PASS T12.a PostToolUse posttool-governance 등록"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.a"
fi

# T12.b hooks.json: Stop 배열에 stop-governance 항목
if jq -e '.hooks.Stop[] | .hooks[] | select(.command | contains("stop-governance.sh"))' "$HOOKS_JSON" >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "PASS T12.b Stop stop-governance 등록"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.b"
fi

# T12.c hooks.json: SessionStart session-start.sh · Stop ensure-session-progress.sh 기존 항목 보존
if jq -e '.hooks.SessionStart[] | .hooks[] | select(.command | contains("session-start.sh"))' "$HOOKS_JSON" >/dev/null 2>&1 \
   && jq -e '.hooks.Stop[] | .hooks[] | select(.command | contains("ensure-session-progress.sh"))' "$HOOKS_JSON" >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "PASS T12.c 기존 hook 보존"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.c"
fi

# T12.d is-hook-enabled: posttool-governance / stop-governance 기본 enabled (exit 0)
run_hook_enabled() { bash "$PLUGIN/scripts/is-hook-enabled.sh" "$1" >/dev/null 2>&1; }
if run_hook_enabled posttool-governance; then
  PASS=$((PASS+1)); echo "PASS T12.d posttool-governance 기본 enabled"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.d"
fi
if run_hook_enabled stop-governance; then
  PASS=$((PASS+1)); echo "PASS T12.e stop-governance 기본 enabled"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.e"
fi

# T12.f hooks.json JSON 유효성
if jq -e . "$HOOKS_JSON" >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "PASS T12.f JSON 유효"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.f"
fi

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
