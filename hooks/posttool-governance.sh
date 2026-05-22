#!/usr/bin/env bash
# specops-auto-ko governance-capture — PostToolUse entrypoint
# stdin: Claude Code PostToolUse JSON
# stdout: { "continue": true, "additionalContext"?: "..." }
# 실패 내성: 내부 오류 시 exit 0 + stderr 로그. tool 흐름 무중단.
set -u

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

input=$(cat 2>/dev/null || echo "")
if ! echo "$input" | jq -e . >/dev/null 2>&1; then
  safe_exit "stdin JSON parse failed"
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
      result=$(apply_lookback_rule "$rule" "$transcript" "$tool_name" "$tool_cmd" 2>/dev/null || true)
      ;;
    R-3)
      if [ "$tool_name" = "Skill" ] && printf '%s' "$tool_cmd" | grep -Eq '^specops-auto-ko:'; then
        result=$(apply_skill_declaration_rule "$transcript" "$tool_cmd" 2>/dev/null || true)
      fi
      ;;
  esac
  if [ -n "$result" ]; then
    snippet=$(echo "$result" | jq -r '.evidence_snippet')
    offset=$(echo "$result" | jq -r '.offset')
    log_friction "$fid" "$local_id" "$principle" "$snippet" "$offset" 2>/dev/null || true
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
