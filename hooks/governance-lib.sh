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

# F-1(5c): session-progress 의 FID 섹션에서 /verify PASS 가 최신 코드변경보다 뒤(위)면 0(verify유효), 아니면 1.
# 코드변경 = /implement(항상) | /receive-review + (fix [1-9]|수용). /specify·/plan·/tasks·/clarify·/analyze 제외(.md).
#
# 한계(20260626 분석, WON'T-FIX): session-progress 는 self-reported — verify 후 lifecycle 밖
#   수동 변경(Edit·핫픽스·직접 git add, /implement 줄 미기록)은 감지 못 함(false-allow). self-report
#   에게 un-self-reported 변경 탐지는 범주 오류 = honesty-failure / out-of-band 2차 방어 클래스.
#   1차 방어는 pretool is_docs_only_change(git-authoritative, verify shortcut 前 실행)가 담당.
#   설계안 A(tree해시 자가오염)·B(수동변경 transcript 無로 우회)·C(detect_fid 무력화 회귀) 전수 기각.
_verify_passed_in_progress() {
  local fid="$1"
  local progress=".specops/session-progress.md"
  [ -f "$progress" ] || return 1
  local section
  section=$(awk -v f="## $fid" '
    $0 ~ "^"f"( |$)" {insec=1; next}
    insec && /^## / {exit}
    insec {print}
  ' "$progress")
  [ -n "$section" ] || return 1
  # I-2: 명령 필드 앵커(시각 HH:MM + 명령) — memo 자유텍스트의 명령 언급(괄호 안) 무매칭 → false-block 자기모순 차단.
  # session-progress 줄 포맷 `- YYYY-MM-DD HH:MM /command ...` 의 시각 선행 패턴 의존.
  # ★ 불변식 의존: FID 섹션 내 줄은 "최신=상단(작은 줄번호, prepend)" 이어야 한다(L54 vline<cline 비교 전제).
  #   정본: templates/session-progress.md(prepend/내림차순) + skills/context-resets-ko(줄순서 불변식).
  #   writer 가 오름차순(최신=하단)으로 작성하면 verify-후-재구현을 verify 유효로 오판 → R-1/R-2 false-allow.
  local vline cline
  vline=$(printf '%s\n' "$section" | grep -nE '[0-9][0-9]:[0-9][0-9] /verify PASS' | head -1 | cut -d: -f1)
  cline=$(printf '%s\n' "$section" | grep -nE '[0-9][0-9]:[0-9][0-9] /implement|[0-9][0-9]:[0-9][0-9] /receive-review.*(fix [1-9]|수용)' | head -1 | cut -d: -f1)
  [ -z "$vline" ] && return 1            # verify 없음
  [ -z "$cline" ] && return 0            # 코드변경 없음 → verify 유효
  [ "$vline" -lt "$cline" ] && return 0 || return 1   # verify 가 위(최신)면 유효
}

# staged ∪ unstaged-tracked 합집합 변경이 전부 docs 확장자면 0(면제), 아니면 1(비면제).
# git diff HEAD = working tree vs HEAD = staged + unstaged tracked 전부 포함 (commit -a 우회 차단).
# base branch 자동감지 — main 우선, master 차선, 없으면 실패(안전측 차단).
_detect_base_branch() {
  local b
  for b in main master; do
    git show-ref --verify --quiet "refs/heads/$b" && { printf '%s' "$b"; return 0; }
  done
  return 1
}

# 신규 repo(HEAD 없음) → --cached fallback. working tree·staged 빈(=PR 맥락, 커밋 완료) → base...HEAD PR-범위 diff.
# 빈 목록·git 실패·base 결정 불가 → 1 (fail-safe — 판정 불가 시 차단 보존). fail-open(hook 에러 allow)과 구분.
is_docs_only_change() {
  # --no-renames: rename 을 delete(old)+add(new) 2줄로 분해 → 코드파일 .md rename 위장
  #   (tool.sh→tool.md)이 원본 .sh 를 숨겨 docs-only 오인면제되던 표면 차단. 출력포맷(--name-only) 무변경.
  local files
  files=$(git diff HEAD --name-only --no-renames 2>/dev/null)
  [ -z "$files" ] && files=$(git diff --cached --name-only --no-renames 2>/dev/null)
  if [ -z "$files" ]; then
    local base
    base=$(_detect_base_branch) || return 1
    files=$(git diff "$base"...HEAD --name-only --no-renames 2>/dev/null)
  fi
  [ -z "$files" ] && return 1
  local f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      *.md|*.txt|*.rst) ;;
      *) return 1 ;;
    esac
  done <<EOF
$files
EOF
  return 0
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

# .specops 가 symlink 면 비정상(악성 repo clone 시 외부 dir 로 write-through path-escape) — 쓰기 거부.
# fail-safe: symlink 면 1(거부), 정상 dir·부재(곧 mkdir)면 0.
_specops_dir_safe() { [ ! -L ".specops" ]; }

# friction-log append. FID 우선 fallback 전역.
# usage: log_friction <fid_or_empty> <rule_id> <principle> <evidence_snippet> <transcript_offset>
log_friction() {
  local fid="$1" rule_id="$2" principle="$3" snippet="$4" offset="$5"
  _specops_dir_safe || { echo "log_friction: .specops 가 symlink — 쓰기 거부(path-escape 차단)" >&2; return 1; }
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

# log_friction 의 severity 파라미터화 변형 (기존 log_friction 무변경 — append).
# usage: log_friction_sev <fid> <rule_id> <principle> <snippet> <offset> <severity>
log_friction_sev() {
  local fid="$1" rule_id="$2" principle="$3" snippet="$4" offset="$5" severity="${6:-warn}"
  _specops_dir_safe || { echo "log_friction_sev: .specops 가 symlink — 쓰기 거부(path-escape 차단)" >&2; return 1; }
  local target=".specops/$fid/friction-log.jsonl"
  [ -n "$fid" ] || return 0
  mkdir -p ".specops/$fid" 2>/dev/null || return 0
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local fid_json; fid_json=$(printf '%s' "$fid" | jq -R .)
  local safe_snippet; safe_snippet=$(printf '%s' "$snippet" | cut -c1-200)
  # dedup 비대칭(의도): block 항목끼리만 비교 — 기존 warn 줄(log_friction, severity 무시)과 공존 허용.
  # 정상 흐름(pretool deny → posttool 미실행 / bypass → block 미기록)에선 동일 snippet 에 둘이 안 생긴다.
  # 집계 로직이 severity 별 카운트 시 엣지에서 동일 snippet 이중계상 가능 — block 강제 기록 우선.
  if [ -f "$target" ] && jq -e --arg r "$rule_id" --arg s "$safe_snippet" \
       'select(.rule_id == $r and .evidence_snippet == $s and .severity == "block")' "$target" >/dev/null 2>&1; then
    return 0
  fi
  jq -nc --arg ts "$ts" --argjson fid "$fid_json" --arg rule_id "$rule_id" \
    --argjson principle "$principle" --arg snippet "$safe_snippet" \
    --argjson offset "$offset" --arg sev "$severity" \
    '{ ts:$ts, fid:$fid, rule_id:$rule_id, principle:$principle, severity:$sev, evidence_snippet:$snippet, transcript_offset:$offset }' \
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
  # F-1(5c): session-progress verify 우선 — transcript lookback false-block 회피
  local _fid
  _fid=$(detect_fid)
  if [ -n "$_fid" ] && _verify_passed_in_progress "$_fid"; then
    return 0   # verify 유효 → 위반 아님 (transcript lookback skip)
  fi
  local found
  found=$(read_recent_tool_events "$transcript" "$lookback" \
    | jq -c --arg p "$neg_pattern" 'select(.tool_name == "Skill" and (.input.skill // "" | test($p)))' \
    | head -1)
  if [ -z "$found" ]; then
    # triggering Bash tool_use 이벤트의 transcript 라인 번호 (0-based)
    # PostToolUse 는 현재 triggering 이벤트 직후 발화 → 마지막 매칭이 현재 이벤트
    # perf: 단일 jq 패스 — 줄단위 echo|jq fork 루프 제거 (2000줄 기준 수 초 → 수십 ms)
    local offset
    offset=$(jq -n --arg t "$trigger_tool" --arg pat "$trigger_pattern" '
      [inputs] as $all
      | ([ $all | to_entries[]
           | select(.value.type == "assistant")
           | select([.value.message.content[]? | select(.type == "tool_use" and .name == $t and ((.input.command // "") | test($pat)))] | any)
           | .key ] | last) // ($all | length)
    ' "$transcript" 2>/dev/null)
    [ -z "$offset" ] && offset=0
    jq -nc --arg id "$rule_id" --arg snippet "$tool_cmd" --argjson offset "$offset" \
      '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset }'
  fi
}

# R-3 매처 — Skill 호출 직전 N assistant 메시지에 선언 부재 확인 (AC-9, v0.4-pre W1 확장)
# usage: apply_skill_declaration_rule <transcript> <skill_full_name>
# 선언 = 영문 "[Using|Invoking|Calling|Switching to] <short|full>" 또는
#        한국어 "<short> (을|를|로|으로)? (사용|호출|진입|이동|넘어감|시작|진행|발동|들어감|넘어가|개시)"
# short = skill_full_name 에서 "specops-auto-ko:" 접두 제거
# v0.4-pre W1 변경 (마스터 plan §6 v0.4-pre):
# 1. 동사군 확장 (한국어 6 → 12, 영문 1 → 4)
# 2. lookback N=1 → N=3 assistant 메시지
# 3. user turn 첫 진입 예외 (직전 user 메시지에 /start 또는 트리거 키워드 있으면 면제)
# v0.4b W1 변경: full name (specops-auto-ko:<short>) 패턴 추가 (cvt+b64 7건 회귀 원인)
# v0.5 W1 변경: lifecycle chain auto-call exempt — 직전 tool_use가 Skill(specops-auto-ko:*)이면 면제
apply_skill_declaration_rule() {
  local transcript="$1" skill_full="$2"
  [ -f "$transcript" ] || return 0
  local short="${skill_full#specops-auto-ko:}"
  # full name = specops-auto-ko:<short>, short name = <short> — 둘 다 허용
  local name_re="(specops-auto-ko:)?${short}"
  local decl_re="([Uu]sing[[:space:]]+${name_re}|[Ii]nvoking[[:space:]]+${name_re}|[Cc]alling[[:space:]]+${name_re}|[Ss]witching[[:space:]]+to[[:space:]]+${name_re}|${short}[[:space:]]*(을|를|로|으로)?[[:space:]]*(사용|호출|진입|이동|넘어감|시작|진행|발동|들어감|넘어가|개시))"
  # user turn 첫 진입 예외 트리거 (사용자 입력에 이 패턴이 있으면 첫 Skill 호출은 면제)
  local trigger_re='(/start|/quick|/free|만들[고어]|구현|추가|수정|fix|feature)'
  # perf: 단일 jq reduce 패스 — 줄단위 echo|jq fork ×4 루프 제거.
  # 상태: p1~p3(assistant text ring buffer, p1=최신), lu(마지막 user text),
  #       plc(직전 lifecycle skill — v0.5 chain 면제), matched/done/offset.
  # combined 구분자는 원 구현의 bash 리터럴 "\n"(역슬래시+n) 을 jq "\\n" 으로 보존.
  local res
  res=$(jq -nc --arg s "$skill_full" --arg decl "$decl_re" --arg trig "$trigger_re" '
    def utext: [.message.content // "" | if type == "string" then . else (.[]? | select(.type == "text") | .text) end] | first // "";
    def atext: [.message.content[]? | select(.type == "text") | .text] | join("\n");
    def has_target($s): [.message.content[]? | select(.type == "tool_use" and .name == "Skill" and .input.skill == $s)] | length > 0;
    def lc_skill: [.message.content[]? | select(.type == "tool_use" and .name == "Skill") | (.input.skill // "") | select(startswith("specops-auto-ko:"))] | first // "";
    [inputs] as $all
    | reduce range(0; $all | length) as $i (
        {p1: "", p2: "", p3: "", lu: "", plc: "", matched: false, done: false, offset: 0};
        if .done then .
        else $all[$i] as $e
        | if ($e.type // "") == "user" then
            .lu = ($e | utext)
          elif ($e.type // "") != "assistant" then
            .
          elif ($e | has_target($s)) then
            .offset = ($i + 1)
            | .done = true
            | .matched = (
                if .plc != "" then false
                elif ((.p1 + "\\n" + .p2 + "\\n" + .p3) | test($decl)) then false
                elif (.lu != "" and (.lu | test($trig))) then false
                else true
                end)
          else
            (($e | lc_skill) as $l | if $l != "" then .plc = $l else . end)
            | (($e | atext) as $t
               | if $t != "" then .p3 = .p2 | .p2 = .p1 | .p1 = $t else . end)
          end
        end)
    | { matched, offset }
  ' "$transcript" 2>/dev/null)
  local matched offset
  matched=$(printf '%s' "$res" | jq -r '.matched' 2>/dev/null)
  offset=$(printf '%s' "$res" | jq -r '.offset' 2>/dev/null)
  [ -z "$offset" ] && offset=0
  if [ "$matched" = "true" ]; then
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
    # perf: 단일 jq 패스 — 줄단위 echo|jq fork 루프 제거 (Stop 훅 매 발화 경로)
    local offset
    offset=$(jq -n --arg re "$assertion_re" '
      [inputs] as $all
      | ([ $all | to_entries[]
           | select(.value.type == "assistant")
           | select([.value.message.content[]? | select(.type == "text") | .text | test($re)] | any)
           | .key ] | last) // ($all | length)
    ' "$transcript" 2>/dev/null)
    [ -z "$offset" ] && offset=0
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
  # while-read — 공백 포함 경로 안전 (unquoted word-split 제거)
  while IFS= read -r fp; do
    [ -z "$fp" ] && continue
    bn=$(basename "$fp")
    is_target=0
    while IFS= read -r t; do
      [ "$bn" = "$t" ] && is_target=1
    done <<EOF_T
$target_files
EOF_T
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
  done <<EOF_M
$modified_files
EOF_M
  if [ -n "$match_result" ]; then
    # match_result 에 해당하는 파일 경로 추출 ("섹션 부재: <fp>" 또는 "섹션 미충족: <fp>")
    local matched_file=""
    if [[ "$match_result" == *": "* ]]; then
      matched_file="${match_result##*: }"
    fi
    # 첫 Edit/MultiEdit 이벤트 (target file 대상) 의 transcript 라인 번호 (0-based)
    # perf: 단일 jq 패스 — 줄단위 echo|jq fork 루프 제거.
    # 원 동작 보존: matched_file 비면 0, 매칭 파일은 있으나 이벤트 미발견이면 전체 라인 수.
    local offset=0
    if [ -n "$matched_file" ]; then
      offset=$(jq -n --arg p "$matched_file" '
        [inputs] as $all
        | ([ $all | to_entries[]
             | select(.value.type == "assistant")
             | select([.value.message.content[]? | select(.type == "tool_use" and (.name == "Edit" or .name == "MultiEdit") and .input.file_path == $p)] | any)
             | .key ] | first) // ($all | length)
      ' "$transcript" 2>/dev/null)
      [ -z "$offset" ] && offset=0
    fi
    jq -nc --arg id "R-5" --arg snippet "$match_result" --argjson offset "$offset" \
      '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset }'
  fi
}

# R-6 매처 — transcript 에 verify skill + evidence.md Write 있고 gbrain-append 부재 시 매칭
# usage: apply_gbrain_absence_rule <rule_json> <transcript>
# 출력: 매칭 시 JSON { rule_id, evidence_snippet, offset, fid }, 미매칭 시 빈 문자열
# 매칭 알고리즘:
#   1. verify skill 호출 흔적 (전수 조사) 없으면 skip
#   2. 가장 최근 evidence.md Write 의 line 위치 추출 (last_evi_line). 없으면 skip
#   3. last_evi_line 이후 gbrain runner 호출 있는가? 있으면 PASS (skip)
#      — FR-6: multi-verify 환경에서도 가장 최근 evidence 이후만 본다
#   4. trivial-skip: evidence path 의 .specops/<FID>/spec.md 의 §유형 = trivial 이면 skip
#   5. FID 추출 + evidence_snippet 빌드 + JSON 반환
# 한계: trivial-skip(step 4) 의 spec.md lookup 은 transcript 에서 파생된 evidence path
#   (대개 상대경로 .specops/<FID>/evidence.md) 의 dirname 기준이라 **CWD 의존**이다.
#   훅이 plugin repo root 가 아닌 CWD 에서 실행되면 spec.md 를 못 찾아 trivial 판정이
#   누락(= 매칭 유지)될 수 있다. Stop 훅은 항상 repo root 에서 기동되므로 실사용엔 무해.
apply_gbrain_absence_rule() {
  local rule="$1" transcript="$2"
  [ -f "$transcript" ] || return 0
  local verify_skill_re evidence_path_re gbrain_runner_re
  verify_skill_re=$(echo "$rule" | jq -r '.verify_skill_pattern')
  evidence_path_re=$(echo "$rule" | jq -r '.evidence_path_pattern')
  gbrain_runner_re=$(echo "$rule" | jq -r '.gbrain_runner_pattern')

  # 1. verify skill 호출 흔적
  local has_verify
  has_verify=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Skill") | .input.skill // empty' "$transcript" 2>/dev/null \
    | grep -E "$verify_skill_re" | head -1)
  [ -n "$has_verify" ] || return 0

  # 2.+3. 가장 최근 evidence.md Write/Edit/Bash-invocation 위치 + 그 이후 gbrain runner 존재 여부
  # Edit 도 포함 — Claude 가 run-verification.sh append 후 헤더/AC 매핑 추가할 때 Edit 사용 (외부 review 후속 fix)
  # Bash 분기 — dogfood 경로 (bash scripts/_internal/run-verification.sh <FID>) invocation 도 evidence 의도 인정
  # perf: 단일 jq 패스 — transcript 2회 완주 + 줄단위 fork 루프 제거.
  # same-turn Write+Bash 의 Bash-우선 순서 (T-R6.17) 는 라인 내 bsynth 우선 평가로 보존.
  local res
  res=$(jq -nc --arg evire "$evidence_path_re" --arg grun "$gbrain_runner_re" '
    def wpath: [.message.content[]? | select(.type == "tool_use" and (.name == "Write" or .name == "Edit")) | (.input.file_path // "") | select(test($evire))] | first // "";
    def bsynth: [.message.content[]? | select(.type == "tool_use" and .name == "Bash") | (.input.command // "")
                 | (capture("bash[[:space:]]+(?:.*/)?run-verification\\.sh[[:space:]]+(?<fid>[^[:space:]]+)")? // empty)
                 | ".specops/" + .fid + "/evidence.md"
                 | select(test($evire))] | first // "";
    def grunner: [.message.content[]? | select(.type == "tool_use" and (.name == "Bash" or .name == "Skill")) | (.input.command // .input.skill // "") | select(test($grun))] | length > 0;
    [inputs] as $all
    | ($all | to_entries | map(select(.value.type == "assistant"))) as $ents
    | ([ $ents[] | { i: .key, p: ((.value | bsynth) as $b | if $b != "" then $b else (.value | wpath) end) } | select(.p != "") ] | last) as $evi
    | if $evi == null then { evi: -1, path: "", gb: false }
      else { evi: $evi.i, path: $evi.p, gb: ([ $ents[] | select(.key > $evi.i) | select(.value | grunner) ] | length > 0) }
      end
  ' "$transcript" 2>/dev/null)
  local last_evi_line last_evi_path has_gbrain_after
  last_evi_line=$(printf '%s' "$res" | jq -r '.evi' 2>/dev/null)
  last_evi_path=$(printf '%s' "$res" | jq -r '.path' 2>/dev/null)
  has_gbrain_after=$(printf '%s' "$res" | jq -r '.gb' 2>/dev/null)
  if [ -z "$last_evi_line" ] || [ "$last_evi_line" -lt 0 ]; then
    return 0
  fi
  [ "$has_gbrain_after" = "true" ] && return 0  # PASS — gbrain 호출 있음

  # 4. trivial-skip — evidence path 의 spec.md §유형 = trivial 이면 skip
  local fid_dir spec_path type_label
  fid_dir=$(dirname "$last_evi_path")
  spec_path="$fid_dir/spec.md"
  if [ -f "$spec_path" ]; then
    type_label=$(grep -m1 '^\*\*§유형\*\*:' "$spec_path" 2>/dev/null | sed 's/.*:[[:space:]]*//' | tr -d '[:space:]')
    [ "$type_label" = "trivial" ] && return 0
  fi

  # 5. FID 추출 (.specops/<FID>/evidence.md 패턴)
  local fid
  fid=$(echo "$last_evi_path" | sed -E 's|.*\.specops/([^/]+)/evidence\.md$|\1|')

  local snippet="lifecycle 완주 후 gbrain-append 호출 부재 — 1줄 인사이트 작성 권장: bash scripts/gbrain-append.sh '<insight>' --fid $fid"
  jq -nc --arg id "R-6" --arg snippet "$snippet" --argjson offset "$last_evi_line" --arg fid "$fid" \
    '{ rule_id: $id, evidence_snippet: $snippet, offset: $offset, fid: $fid }'
}
