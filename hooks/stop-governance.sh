#!/usr/bin/env bash
# specops-auto-ko governance-capture — Stop entrypoint
# stdin: Claude Code Stop JSON (stop_hook_active 필드 포함)
# stdout: { "continue": true }  (Stop 은 additionalContext 미사용 — append only)
# 실패 내성: 내부 오류 시 exit 0 + stderr. 멱등: stop_hook_active==true 즉시 투과.
set -uo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(dirname "$script_dir")

bash "$plugin_root/scripts/_internal/is-hook-enabled.sh" stop-governance >/dev/null 2>&1 || { echo '{"continue":true}'; exit 0; }

safe_exit() {
  echo "[governance-capture] ERROR: stop hook: $1" >&2
  echo '{"continue":true}'
  exit 0
}

# shellcheck disable=SC1091
source "$script_dir/governance-lib.sh" 2>/dev/null || safe_exit "governance-lib.sh source 실패"

input=$(cat 2>/dev/null || echo "")
if ! echo "$input" | jq -e . >/dev/null 2>&1; then
  safe_exit "stdin JSON parse failed"
fi

# 멱등 가드 (NFR-4)
active=$(echo "$input" | jq -r '.stop_hook_active // false')
if [ "$active" = "true" ]; then
  echo '{"continue":true}'
  exit 0
fi

transcript=$(echo "$input" | jq -r '.transcript_path // empty')
[ -n "$transcript" ] && [ -f "$transcript" ] || { echo '{"continue":true}'; exit 0; }

fid=$(detect_fid)
rules_path="$plugin_root/hooks/rules.jsonl"
[ -f "$rules_path" ] || { echo '{"continue":true}'; exit 0; }

while IFS= read -r rule; do
  [ -z "$rule" ] && continue
  rule_id=$(echo "$rule" | jq -r '.id')
  principle=$(echo "$rule" | jq -r '.principle')
  result=""
  case "$rule_id" in
    R-4) result=$(apply_assertion_without_test_rule "$rule" "$transcript" 2>/dev/null || true) ;;
    R-5) result=$(apply_advisor_section_rule "$rule" "$transcript" 2>/dev/null || true) ;;
    R-6) result=$(apply_gbrain_absence_rule "$rule" "$transcript" 2>/dev/null || true) ;;
  esac
  if [ -n "$result" ]; then
    snippet=$(echo "$result" | jq -r '.evidence_snippet')
    offset=$(echo "$result" | jq -r '.offset')
    log_friction "$fid" "$rule_id" "$principle" "$snippet" "$offset" 2>/dev/null || true
  fi
done < <(load_rules "$rules_path" "stop" 2>/dev/null || true)

echo '{"continue":true}'
