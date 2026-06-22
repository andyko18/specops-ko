#!/usr/bin/env bash
# 테스트 전용 stub claude — STUB_PLAN(jsonl) 의 호출 N번째 줄 기반 canned stream-json 출력
# STUB_STATE: 호출 카운터 파일. CLI 인자는 무시 (runner 판정 로직 검증 목적, 실 토큰 0)
set -u
[ "${1:-}" = "--version" ] && { echo "stub-claude 0.0.1"; exit 0; }
n=0
[ -f "${STUB_STATE:?STUB_STATE 필요}" ] && n=$(cat "$STUB_STATE")
n=$((n+1)); printf '%s' "$n" > "$STUB_STATE"
line=$(sed -n "${n}p" "${STUB_PLAN:?STUB_PLAN 필요}")
[ -z "$line" ] && line=$(tail -1 "$STUB_PLAN")
skill=$(printf '%s' "$line" | jq -r '.skill // empty')
args=$(printf '%s' "$line" | jq -r '.args // ""')
text=$(printf '%s' "$line" | jq -r '.text // empty')
cost=$(printf '%s' "$line" | jq -r '.cost // 0')
if [ -n "$skill" ]; then
  jq -cn --arg s "$skill" --arg a "$args" \
    '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s,args:$a}}]}}'
elif [ -n "$text" ]; then
  jq -cn --arg t "$text" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'
else
  jq -cn '{type:"assistant",message:{content:[{type:"text",text:"일반 응답"}]}}'
fi
jq -cn --argjson c "$cost" '{type:"result",subtype:"success",total_cost_usd:$c}'
