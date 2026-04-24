#!/usr/bin/env bash
# specops-auto-ko governance-capture 공용 함수 라이브러리
# source 로 로드하여 사용. 실행 파일 아님.
#
# Sourced library — strict mode 는 caller 에 위임 (set -u/-e 생략).
# Requires: jq 1.6+, bash 3.2+, coreutils (date, grep, sed, cut, mkdir).

detect_fid() {
  local progress_file=".specops/session-progress.md"
  [ -f "$progress_file" ] || { echo ""; return 0; }
  grep -E '^## [0-9]{8}-[a-z0-9-]+' "$progress_file" \
    | head -1 \
    | sed -E 's/^## ([0-9]{8}-[a-z0-9-]+).*/\1/'
}

# transcript JSONL 에서 최근 N 개 tool_use 이벤트를 추출
# 출력: JSONL, 각 줄 { "index": <0-based>, "tool_name": "...", "input": {...} }
#   index = 필터된 tool_use 이벤트 배열의 0-based 위치 (raw JSONL line 아님)
# NOTE: --slurp 로 JSONL 전체 메모리 로드. v0.1 transcript 크기 (≤1MB 가정) 에서 허용.
# 대형 세션은 `jq -cs '.[-N:]'` → head-cut 선처리 고려 (후속 과제).
# usage: read_recent_tool_events <transcript_path> <max_count>
read_recent_tool_events() {
  local transcript="$1"
  local max="${2:-20}"
  [ -f "$transcript" ] || return 0
  jq -c --slurp --argjson max "$max" '
    [ .[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | { tool_name: .name, input: .input } ]
    | to_entries
    | map({ index: .key, tool_name: .value.tool_name, input: .value.input })
    | .[-$max:][]?
  ' "$transcript"
}

# friction-log append. FID 우선 fallback 전역.
# usage: log_friction <fid_or_empty> <rule_id> <principle> <evidence_snippet> <transcript_offset>
log_friction() {
  local fid="$1" rule_id="$2" principle="$3" snippet="$4" offset="$5"
  if [ -n "$fid" ] && ! printf '%s' "$fid" | grep -Eq '^[0-9]{8}-[a-z0-9-]+$'; then
    echo "log_friction: invalid fid format" >&2
    return 1
  fi
  local target
  if [ -n "$fid" ]; then
    mkdir -p ".specops/$fid"
    target=".specops/$fid/friction-log.jsonl"
  else
    mkdir -p ".specops"
    target=".specops/friction-log.jsonl"
  fi
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local fid_json
  if [ -n "$fid" ]; then
    fid_json="\"$fid\""
  else
    fid_json="null"
  fi
  local safe_snippet
  safe_snippet=$(printf '%s' "$snippet" | cut -c1-200)
  jq -nc \
    --arg ts "$ts" \
    --argjson fid "$fid_json" \
    --arg rule_id "$rule_id" \
    --argjson principle "$principle" \
    --arg snippet "$safe_snippet" \
    --argjson offset "$offset" \
    '{ ts: $ts, fid: $fid, rule_id: $rule_id, principle: $principle, severity: "warn", evidence_snippet: $snippet, transcript_offset: $offset }' \
    >> "$target"
}

# rules.jsonl 에서 matcher + enabled:true 룰만 반환
# usage: load_rules <rules_path> <matcher>
load_rules() {
  local rules_path="$1" matcher="$2"
  [ -f "$rules_path" ] || return 0
  jq -c --arg m "$matcher" 'select(.enabled == true and .matcher == $m)' "$rules_path"
}

# lookback 룰 매처. trigger 일치 + negative_skill_pattern 이 직전 N 이벤트에 없으면 매칭.
# usage: apply_lookback_rule <rule_json> <transcript> <tool_name> <tool_command>
# 출력: 매칭 시 JSON { rule_id, evidence_snippet, offset }, 미매칭 시 빈 문자열
apply_lookback_rule() {
  local rule="$1" transcript="$2" tool_name="$3" tool_cmd="$4"
  local rule_id trigger_tool trigger_pattern lookback neg_pattern
  rule_id=$(echo "$rule" | jq -r '.id')
  trigger_tool=$(echo "$rule" | jq -r '.trigger_tool')
  [ "$tool_name" = "$trigger_tool" ] || return 0
  trigger_pattern=$(echo "$rule" | jq -r '.trigger_pattern')
  printf '%s' "$tool_cmd" | grep -Eq "$trigger_pattern" || return 0
  lookback=$(echo "$rule" | jq -r '.negative_lookback // 20')
  neg_pattern=$(echo "$rule" | jq -r '.negative_skill_pattern')
  local found
  found=$(read_recent_tool_events "$transcript" "$lookback" \
    | jq -c --arg p "$neg_pattern" 'select(.tool_name == "Skill" and (.input.skill // "" | test($p)))' \
    | head -1)
  if [ -z "$found" ]; then
    local offset
    offset=$(grep -c '^' "$transcript")
    jq -nc --arg id "$rule_id" --arg snippet "$tool_cmd" --argjson offset "$offset" \
      '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset }'
  fi
}

# R-3 매처 — Skill 호출 직전 1 assistant 메시지에 선언 부재 확인 (AC-9)
# usage: apply_skill_declaration_rule <transcript> <skill_full_name>
# 선언 = 영문 "Using <short>" 또는 한국어 "<short> (을|를|로|으로)? (사용|호출|진입|이동|넘어감)"
# short = skill_full_name 에서 "specops-auto-ko:" 접두 제거
apply_skill_declaration_rule() {
  local transcript="$1" skill_full="$2"
  [ -f "$transcript" ] || return 0
  local short="${skill_full#specops-auto-ko:}"
  # 포괄 regex: Using|한국어 변형 (대소문자 무시는 grep -i 로 처리)
  local decl_re="([Uu]sing[[:space:]]+${short}|${short}[[:space:]]*(을|를|로|으로)?[[:space:]]*(사용|호출|진입|이동|넘어감))"
  # 전체 transcript 를 순회하면서 "Skill 호출 tool_use" 이벤트 직전의 assistant text 를 유지
  # 여러 Skill 호출이 있을 수 있으나 본 룰은 첫 번째 매칭된 Skill 호출만 검사 (단순화)
  local prev_text=""
  local matched=0
  local offset=0
  while IFS= read -r line; do
    offset=$((offset + 1))
    local ev_type
    ev_type=$(echo "$line" | jq -r '.type' 2>/dev/null)
    [ "$ev_type" = "assistant" ] || continue
    local has_target_skill
    has_target_skill=$(echo "$line" | jq -r --arg s "$skill_full" '.message.content[]? | select(.type == "tool_use" and .name == "Skill" and .input.skill == $s) | .input.skill' 2>/dev/null)
    if [ -n "$has_target_skill" ]; then
      if [ -z "$prev_text" ] || ! printf '%s' "$prev_text" | grep -Eq "$decl_re"; then
        matched=1
      fi
      break
    fi
    local cur_text
    cur_text=$(echo "$line" | jq -r '.message.content[]? | select(.type == "text") | .text' 2>/dev/null)
    if [ -n "$cur_text" ]; then
      prev_text="$cur_text"
    fi
  done < "$transcript"
  if [ "$matched" -eq 1 ]; then
    jq -nc --arg id "R-3" --arg snippet "Skill($skill_full) 호출 전 선언 부재" --argjson offset "$offset" \
      '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset }'
  fi
}

# R-4 매처 — transcript 에 assertion_pattern 존재 + test_runner_pattern 부재 → 매칭
# usage: apply_assertion_without_test_rule <rule_json> <transcript>
# 출력: 매칭 시 JSON { rule_id, evidence_snippet, offset }, 미매칭 시 빈 문자열
apply_assertion_without_test_rule() {
  local rule="$1" transcript="$2"
  [ -f "$transcript" ] || return 0
  local assertion_re test_runner_re
  assertion_re=$(echo "$rule" | jq -r '.assertion_pattern')
  test_runner_re=$(echo "$rule" | jq -r '.test_runner_pattern')
  # assertion 있는가? (assistant text 전수 조사)
  local has_assertion
  has_assertion=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' "$transcript" 2>/dev/null \
    | grep -Eo "$assertion_re" | head -1)
  [ -n "$has_assertion" ] || return 0
  # test runner 실행 있는가? (Bash tool_use input.command 전수 조사)
  local has_runner
  has_runner=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Bash") | .input.command // empty' "$transcript" 2>/dev/null \
    | grep -Eo "$test_runner_re" | head -1)
  if [ -z "$has_runner" ]; then
    local offset
    offset=$(grep -c '^' "$transcript")
    jq -nc --arg id "R-4" --arg snippet "성공 주장 '$has_assertion' + test runner 실행 부재" --argjson offset "$offset" \
      '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset }'
  fi
}

# R-5 매처 — 세션 중 수정된 spec/plan/analysis md 의 Advisor 협의 기록 섹션 검사
# usage: apply_advisor_section_rule <rule_json> <transcript>
# PASS 조건: 섹션 내 data row 1+ 또는 "해당 없음" 문자열 존재 (Q-D 관대)
# 매칭 조건: target_files 중 하나라도 위 PASS 조건 미충족
apply_advisor_section_rule() {
  local rule="$1" transcript="$2"
  [ -f "$transcript" ] || return 0
  local target_files section_re
  target_files=$(echo "$rule" | jq -r '.target_files[]')
  section_re=$(echo "$rule" | jq -r '.advisor_section_pattern')
  # 세션 중 Write/Edit 된 파일 경로 추출
  local modified_files
  modified_files=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and (.name == "Write" or .name == "Edit")) | .input.file_path // empty' "$transcript" 2>/dev/null | sort -u)
  local match_result=""
  local fp bn is_target section_body data_rows has_hae
  for fp in $modified_files; do
    bn=$(basename "$fp")
    is_target=0
    for t in $target_files; do
      [ "$bn" = "$t" ] && is_target=1
    done
    [ "$is_target" -eq 1 ] || continue
    [ -f "$fp" ] || continue
    # Advisor 섹션 본문 추출: section_re 이후 ~ 다음 ## 직전
    section_body=$(awk -v re="$section_re" '
      $0 ~ re { inside=1; next }
      inside && /^## / { exit }
      inside { print }
    ' "$fp")
    if [ -z "$section_body" ]; then
      match_result="섹션 부재: $fp"
      break
    fi
    # data row: | 로 시작, 헤더(`| 일시`)·구분선(`|---` 또는 `| --- |`) 제외
    data_rows=$(printf '%s\n' "$section_body" | grep -E '^\|' | grep -Ev '^\|[[:space:]]*-+' | grep -Ev '^\|[[:space:]]*일시[[:space:]]*\|' | wc -l | tr -d ' ')
    has_hae=$(printf '%s\n' "$section_body" | grep -c '해당 없음' | tr -d ' ')
    if [ "$data_rows" -eq 0 ] && [ "$has_hae" -eq 0 ]; then
      match_result="섹션 미충족: $fp"
      break
    fi
  done
  if [ -n "$match_result" ]; then
    local offset
    offset=$(grep -c '^' "$transcript")
    jq -nc --arg id "R-5" --arg snippet "$match_result" --argjson offset "$offset" \
      '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset }'
  fi
}
