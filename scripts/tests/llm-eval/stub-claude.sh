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
# model 필드가 있으면 claude 의 system init 이벤트(모델 ID) 를 먼저 낸다 — 채점 모델 기록 테스트용. 없으면 종전 출력 그대로
model=$(printf '%s' "$line" | jq -r '.model // empty')
[ -z "$model" ] || jq -cn --arg m "$model" '{type:"system",subtype:"init",model:$m}'
# 다중 Skill 호출(skills 배열) — 활성화 eval 의 "두 번째 이후 호출" 재현용. 없으면 아래 기존 경로 그대로
skills=$(printf '%s' "$line" | jq -c '.skills // empty')
if [ -n "$skills" ]; then
  printf '%s' "$skills" | jq -c '.[] | {type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:.,args:""}}]}}'
  jq -cn --argjson c "$(printf '%s' "$line" | jq -r '.cost // 0')" '{type:"result",subtype:"success",total_cost_usd:$c}'
  exit 0
fi
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
