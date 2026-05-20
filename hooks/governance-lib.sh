#!/usr/bin/env bash
# specops-auto-ko governance-capture 공용 함수 라이브러리
# source 로 로드하여 사용. 실행 파일 아님.
#
# Sourced library — strict mode 는 caller 에 위임 (set -u/-e 생략).
# Requires: jq 1.6+, bash 3.2+, coreutils (date, grep, sed, cut, mkdir).

detect_fid() {
  # U8: 다중 FID 환경에서 first-only 버그 회피
  #   1순위: <!-- active-fid: <FID> --> 마커 (사용자/도구가 명시적으로 active 표시)
  #   2순위: 첫 '## <FID>' 헤더 (기존 동작, 단일 FID 환경 fallback)
  local progress_file=".specops/session-progress.md"
  [ -f "$progress_file" ] || { echo ""; return 0; }
  # 1순위: active-fid 마커 (any line)
  local marker_fid
  marker_fid=$(grep -m1 -E '<!--[[:space:]]*active-fid:[[:space:]]*[0-9]{8}-[a-z0-9-]+[[:space:]]*-->' "$progress_file" \
    | sed -E 's/.*active-fid:[[:space:]]*([0-9]{8}-[a-z0-9-]+).*/\1/')
  if [ -n "$marker_fid" ]; then
    echo "$marker_fid"
    return 0
  fi
  # 2순위: 첫 ## 헤더 (single-FID fallback)
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
  # dedup: 같은 rule_id + evidence_snippet 조합이 이미 존재하면 skip (stop hook 중복 실행 방지)
  if [ -f "$target" ] && jq -e --arg r "$rule_id" --arg s "$safe_snippet" \
       'select(.rule_id == $r and .evidence_snippet == $s)' "$target" >/dev/null 2>&1; then
    return 0
  fi
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
    # triggering Bash tool_use 이벤트의 transcript 라인 번호 (0-based)
    # PostToolUse 는 현재 triggering 이벤트 직후 발화 → 마지막 매칭이 현재 이벤트
    local offset=-1 line_no=0
    while IFS= read -r line; do
      if echo "$line" | jq -e --arg t "$trigger_tool" --arg pat "$trigger_pattern" \
           '(.type == "assistant") and (any(.message.content[]?; .type == "tool_use" and .name == $t and ((.input.command // "") | test($pat))))' \
           >/dev/null 2>&1; then
        offset=$line_no
      fi
      line_no=$((line_no + 1))
    done < "$transcript"
    [ "$offset" -lt 0 ] && offset=$line_no
    jq -nc --arg id "$rule_id" --arg snippet "$tool_cmd" --argjson offset "$offset" \
      '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset }'
  fi
}

# R-3 매처 — Skill 호출 직전 N assistant 메시지에 선언 부재 확인 (AC-9, v0.4-pre W1 확장)
# usage: apply_skill_declaration_rule <transcript> <skill_full_name>
<<<<<<< HEAD
# 선언 = 영문 "[Using|Invoking|Calling|Switching to] <short|full>" 또는
=======
# 선언 = 영문 "[Using|Invoking|Calling|Switching to] <short>" 또는
>>>>>>> origin/feat/20260425-slug-cli
#        한국어 "<short> (을|를|로|으로)? (사용|호출|진입|이동|넘어감|시작|진행|발동|들어감|넘어가|개시)"
# short = skill_full_name 에서 "specops-auto-ko:" 접두 제거
# v0.4-pre W1 변경 (마스터 plan §6 v0.4-pre):
# 1. 동사군 확장 (한국어 6 → 12, 영문 1 → 4)
# 2. lookback N=1 → N=3 assistant 메시지
# 3. user turn 첫 진입 예외 (직전 user 메시지에 /start 또는 트리거 키워드 있으면 면제)
<<<<<<< HEAD
# v0.4b W1 변경: full name (specops-auto-ko:<short>) 패턴 추가 (cvt+b64 7건 회귀 원인)
# v0.5 W1 변경: lifecycle chain auto-call exempt — 직전 tool_use가 Skill(specops-auto-ko:*)이면 면제
=======
>>>>>>> origin/feat/20260425-slug-cli
apply_skill_declaration_rule() {
  local transcript="$1" skill_full="$2"
  [ -f "$transcript" ] || return 0
  local short="${skill_full#specops-auto-ko:}"
<<<<<<< HEAD
  # full name = specops-auto-ko:<short>, short name = <short> — 둘 다 허용
  local name_re="(specops-auto-ko:)?${short}"
  local decl_re="([Uu]sing[[:space:]]+${name_re}|[Ii]nvoking[[:space:]]+${name_re}|[Cc]alling[[:space:]]+${name_re}|[Ss]witching[[:space:]]+to[[:space:]]+${name_re}|${short}[[:space:]]*(을|를|로|으로)?[[:space:]]*(사용|호출|진입|이동|넘어감|시작|진행|발동|들어감|넘어가|개시))"
=======
  local decl_re="([Uu]sing[[:space:]]+${short}|[Ii]nvoking[[:space:]]+${short}|[Cc]alling[[:space:]]+${short}|[Ss]witching[[:space:]]+to[[:space:]]+${short}|${short}[[:space:]]*(을|를|로|으로)?[[:space:]]*(사용|호출|진입|이동|넘어감|시작|진행|발동|들어감|넘어가|개시))"
>>>>>>> origin/feat/20260425-slug-cli
  # user turn 첫 진입 예외 트리거 (사용자 입력에 이 패턴이 있으면 첫 Skill 호출은 면제)
  local trigger_re='(/start|/quick|/free|만들[고어]|구현|추가|수정|fix|feature)'
  # 직전 N=3 assistant text 메시지를 ring buffer로 유지
  local prev_text_1="" prev_text_2="" prev_text_3=""
  local last_user_text=""
<<<<<<< HEAD
  # v0.5: lifecycle chain 추적 — 직전 Skill(specops-auto-ko:*) 호출 저장
  local prev_lifecycle_skill=""
=======
>>>>>>> origin/feat/20260425-slug-cli
  local matched=0
  local offset=0
  while IFS= read -r line; do
    offset=$((offset + 1))
    local ev_type
    ev_type=$(echo "$line" | jq -r '.type' 2>/dev/null)
    if [ "$ev_type" = "user" ]; then
      # user turn 직후 — 마지막 user text 갱신, assistant ring buffer 초기화 안 함 (lookback 보존)
      last_user_text=$(echo "$line" | jq -r '.message.content // empty | if type == "string" then . else (.[]? | select(.type == "text") | .text) // "" end' 2>/dev/null | head -1)
      continue
    fi
    [ "$ev_type" = "assistant" ] || continue
    local has_target_skill
    has_target_skill=$(echo "$line" | jq -r --arg s "$skill_full" '.message.content[]? | select(.type == "tool_use" and .name == "Skill" and .input.skill == $s) | .input.skill' 2>/dev/null)
    if [ -n "$has_target_skill" ]; then
<<<<<<< HEAD
      # 직전 3개 assistant text 또는 user trigger 또는 lifecycle chain 검사
      local combined="${prev_text_1}\n${prev_text_2}\n${prev_text_3}"
      if [ -n "$prev_lifecycle_skill" ]; then
        matched=0  # lifecycle chain 자동 호출 → 면제 (v0.5 W1)
      elif printf '%s' "$combined" | grep -Eq "$decl_re"; then
=======
      # 직전 3개 assistant text 또는 user trigger 검사
      local combined="${prev_text_1}\n${prev_text_2}\n${prev_text_3}"
      if printf '%s' "$combined" | grep -Eq "$decl_re"; then
>>>>>>> origin/feat/20260425-slug-cli
        matched=0  # 선언 발견 → 미매칭
      elif [ -n "$last_user_text" ] && printf '%s' "$last_user_text" | grep -Eq "$trigger_re"; then
        matched=0  # user turn trigger 직후 첫 Skill 호출 → 면제
      else
        matched=1  # 선언도 없고 trigger 면제도 없음 → 매칭
      fi
      break
    fi
    # v0.5: lifecycle chain 추적 — 현재 라인의 Skill(specops-auto-ko:*) 호출 저장
    local cur_lifecycle_skill
    cur_lifecycle_skill=$(echo "$line" | jq -r '.message.content[]? | select(.type == "tool_use" and .name == "Skill") | .input.skill // empty' 2>/dev/null \
      | grep -E '^specops-auto-ko:' | head -1)
    [ -n "$cur_lifecycle_skill" ] && prev_lifecycle_skill="$cur_lifecycle_skill"
    local cur_text
    cur_text=$(echo "$line" | jq -r '.message.content[]? | select(.type == "text") | .text' 2>/dev/null)
    if [ -n "$cur_text" ]; then
      # ring buffer shift (가장 오래된 것 폐기, 새로운 것 push)
      prev_text_3="$prev_text_2"
      prev_text_2="$prev_text_1"
      prev_text_1="$cur_text"
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
    # assertion 매칭된 가장 마지막 assistant text 이벤트의 라인 번호 (0-based)
    # Stop hook 이므로 최근 주장이 증거로 더 적합
    local offset=-1 line_no=0
    while IFS= read -r line; do
      local txt
      txt=$(echo "$line" | jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null)
      if [ -n "$txt" ] && printf '%s' "$txt" | grep -Eq "$assertion_re"; then
        offset=$line_no
      fi
      line_no=$((line_no + 1))
    done < "$transcript"
    [ "$offset" -lt 0 ] && offset=$line_no
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
  # 세션 중 Edit/MultiEdit 된 파일 경로 추출 (Write는 신규 생성 — Advisor 섹션 불필요)
  local modified_files
  modified_files=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and (.name == "Edit" or .name == "MultiEdit")) | .input.file_path // empty' "$transcript" 2>/dev/null | sort -u)
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
    # U1 R-5 trivial-skip: 동일 FID 의 spec.md §유형 라벨이 trivial 이면 본 파일 skip
    # specifying-ko 가 §1 개요에 자동 부여한 라벨 사용 (신규/유지보수/trivial).
    # spec.md 부재 시 보수적으로 기존 로직 진입 (false positive < silent pass).
    local _dir _spec _type_label
    _dir=$(dirname "$fp")
    _spec="$_dir/spec.md"
    if [ -f "$_spec" ]; then
      _type_label=$(grep -m1 '^\*\*§유형\*\*:' "$_spec" 2>/dev/null | sed 's/.*:[[:space:]]*//' | tr -d '[:space:]')
      if [ "$_type_label" = "trivial" ]; then
        continue
      fi
    fi
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
    # match_result 에 해당하는 파일 경로 추출 ("섹션 부재: <fp>" 또는 "섹션 미충족: <fp>")
    local matched_file=""
    if [[ "$match_result" == *": "* ]]; then
      matched_file="${match_result##*: }"
    fi
    # 첫 Edit/MultiEdit 이벤트 (target file 대상) 의 transcript 라인 번호 (0-based)
    local offset=-1 line_no=0
    if [ -n "$matched_file" ]; then
      while IFS= read -r line; do
        local fp_hit
        fp_hit=$(echo "$line" | jq -r --arg p "$matched_file" 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and (.name == "Edit" or .name == "MultiEdit") and .input.file_path == $p) | .input.file_path' 2>/dev/null)
        if [ -n "$fp_hit" ]; then
          offset=$line_no
          break
        fi
        line_no=$((line_no + 1))
      done < "$transcript"
    fi
    [ "$offset" -lt 0 ] && offset=$line_no
    jq -nc --arg id "R-5" --arg snippet "$match_result" --argjson offset "$offset" \
      '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset }'
  fi
}
