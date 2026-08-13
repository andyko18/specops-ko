#!/usr/bin/env bash
# specops-ko governance-capture — PostToolUse entrypoint
# stdin: Claude Code PostToolUse JSON
# stdout: { "continue": true, "additionalContext"?: "..." }
# 실패 내성: 내부 오류 시 exit 0 + stderr 로그. tool 흐름 무중단.
set -uo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(dirname "$script_dir")

# config guard — disabled 시 조용히 continue
bash "$plugin_root/scripts/_internal/is-hook-enabled.sh" posttool-governance >/dev/null 2>&1 || { echo '{"continue":true}'; exit 0; }

# 실패 시 stderr + 투과
safe_exit() {
  echo "[governance-capture] ERROR: posttool hook: $1" >&2
  echo '{"continue":true}'
  exit 0
}

# shellcheck disable=SC1091
source "$script_dir/governance-lib.sh" 2>/dev/null || safe_exit "governance-lib.sh source 실패"

# CWD 앵커링 — subdir/worktree 에서 기동돼도 .specops 상대경로(detect_fid·R-5·R-6 trivial-skip)가
# 프로젝트 루트 기준으로 동작. env 부재 시 기존 CWD 유지 (테스트 fixture 호환).
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR:-}" ]; then
  cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || true
fi

input=$(cat 2>/dev/null || echo "")
if ! echo "$input" | jq -e . >/dev/null 2>&1; then
  safe_exit "stdin JSON parse 실패"
fi

transcript=$(echo "$input" | jq -r '.transcript_path // empty')
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
tool_cmd=$(echo "$input" | jq -r '.tool_input.command // .tool_input.skill // empty')

[ -n "$transcript" ] && [ -f "$transcript" ] || { echo '{"continue":true}'; exit 0; }

fid=$(detect_fid)
rules_path="$plugin_root/hooks/rules.jsonl"
[ -f "$rules_path" ] || { echo '{"continue":true}'; exit 0; }

matches=""
while IFS= read -r rule; do
  [ -z "$rule" ] && continue
  local_id=$(echo "$rule" | jq -r '.id')
  desc=$(echo "$rule" | jq -r '.description')
  principle=$(echo "$rule" | jq -r '.principle')
  result=""
  case "$local_id" in
    R-1|R-2)
      # 감사 스코프 = 방금 일어난 액션의 범위 (R-1: HEAD~1..HEAD, R-2: base...HEAD) —
      # working-tree 기준(is_docs_only_change)은 커밋 직후 .specops 잔여 dirty 에 걸려 감사 침묵 (T8.e)
      if ! is_docs_only_audit_scope "$local_id"; then
        result=$(apply_lookback_rule "$rule" "$transcript" "$tool_name" "$tool_cmd" 2>/dev/null || true)
      fi
      ;;
    R-3)
      # R8: trigger 패턴을 rules.jsonl R-3.trigger_skill_pattern 단일소스에서 읽음
      #   (하드코딩 drift 제거 — rules 만 바꿔도 동작 따라감). 값 부재 시 안전 fallback.
      skill_pat=$(echo "$rule" | jq -r '.trigger_skill_pattern // "^specops-ko:"')
      if [ "$tool_name" = "Skill" ] && printf '%s' "$tool_cmd" | grep -Eq "$skill_pat"; then
        result=$(apply_skill_declaration_rule "$transcript" "$tool_cmd" 2>/dev/null || true)
      fi
      ;;
  esac
  if [ -n "$result" ]; then
    snippet=$(echo "$result" | jq -r '.evidence_snippet')
    offset=$(echo "$result" | jq -r '.offset')
    # scope_class = 방금 감사한 액션의 커밋 범위 (20260814-friction-scope-posttool).
    #   R-3 등 커밋 범위 축이 없는 규칙은 _audit_scope_class 가 무출력 → 필드 자체가 생략된다.
    #   posttool 은 면제(docs-only) 시 애초에 여기 도달하지 않으므로 실제 값은 code|empty|무출력이다.
    log_friction "$fid" "$local_id" "$principle" "$snippet" "$offset" \
      "$(_audit_scope_class "$local_id")" 2>/dev/null || true
    matches="${matches}[governance] ${local_id}: ${desc}"$'\n'
  fi
done < <(load_rules "$rules_path" "posttool" 2>/dev/null || true)

if [ -n "$matches" ]; then
  # 300자 제한
  context=$(printf '%s' "$matches" | cut -c1-300)
  jq -nc --arg c "$context" '{ continue: true, additionalContext: $c }'
else
  echo '{"continue":true}'
fi
