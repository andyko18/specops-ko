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
run_hook_enabled() { bash "$PLUGIN/scripts/_internal/is-hook-enabled.sh" "$1" >/dev/null 2>&1; }
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

# T12.g hooks.json: PreToolUse 배열 + pretool-governance 항목 배선
if jq -e '.hooks.PreToolUse[] | .hooks[] | select(.command | contains("pretool-governance.sh"))' "$HOOKS_JSON" >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "PASS T12.g PreToolUse pretool-governance 배선"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.g PreToolUse pretool-governance 배선"
fi

# T12.h ★ PostToolUse matcher 가 모든 posttool 규칙의 trigger_tool 을 덮는다 (20260911-posttool-matcher-narrow)
#   matcher 를 좁히면 새 결합이 생긴다 — 규칙이 새 trigger_tool 을 쓰는데 matcher 를 안 넓히면
#   그 규칙은 **켜져도 안 돈다**(에러 없이 기록만 0). enabled 무관 — 나중에 켜질 규칙도 덮는다.
RULES_JSONL="$PLUGIN/hooks/rules.jsonl"
post_matcher=$(jq -r '[.hooks.PostToolUse[] | select(any(.hooks[]; .command | contains("posttool-governance.sh"))) | (.matcher // "")] | first // ""' "$HOOKS_JSON" 2>/dev/null)
trigger_tools=$(jq -r 'select(.matcher == "posttool") | .trigger_tool // empty' "$RULES_JSONL" 2>/dev/null | sort -u)
missing=""
for t in $trigger_tools; do
  printf '%s\n' "$post_matcher" | tr '|,' '\n\n' | sed 's/^ *//; s/ *$//' | grep -qxF -- "$t" || missing="$missing $t"
done
# 공허 가드: trigger_tool 을 하나도 못 읽었으면 "빠진 것 없음" 은 아무것도 증명하지 않는다
if [ -n "$trigger_tools" ] && [ -z "$missing" ]; then
  PASS=$((PASS+1)); echo "PASS T12.h PostToolUse matcher('$post_matcher') ⊇ trigger_tool($(printf '%s' "$trigger_tools" | tr '\n' ' '))"
else
  FAIL=$((FAIL+1)); echo "FAIL T12.h matcher='$post_matcher' 누락=[${missing# }] trigger_tools=[$(printf '%s' "$trigger_tools" | tr '\n' ' ')]"
fi

# T12.i PostToolUse matcher 는 와일드카드가 아니다 (clarify Q1 — 사용자 결정 2026-09-11)
#   `*`·빈값·생략은 모든 도구 호출마다 posttool 을 띄운다 — 판정에 기여하지 않는 호출이 약 1/7.
#   되돌리려면 이 케이스를 고치는 명시적 결정이 필요하게 한다(성능 개선의 무음 회귀 차단).
case "$post_matcher" in
  ''|'*')
    FAIL=$((FAIL+1)); echo "FAIL T12.i PostToolUse matcher 가 와일드카드('$post_matcher')" ;;
  *)
    PASS=$((PASS+1)); echo "PASS T12.i PostToolUse matcher 명시 목록('$post_matcher')" ;;
esac

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
