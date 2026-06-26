#!/usr/bin/env bash
# specops-auto-ko governance — PreToolUse entrypoint (강제 차단)
# stdin: Claude Code PreToolUse JSON
# stdout: allow={"continue":true} · deny=hookSpecificOutput permissionDecision:deny
# 실패 내성: fail-open — 내부 오류 시 allow. 차단은 verify 누락 판정 시에만.
set -uo pipefail
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(dirname "$script_dir")

bash "$plugin_root/scripts/_internal/is-hook-enabled.sh" pretool-governance >/dev/null 2>&1 \
  || { echo '{"continue":true}'; exit 0; }

allow() { echo '{"continue":true}'; exit 0; }
safe_exit() { echo "[governance] pretool: $1" >&2; echo '{"continue":true}'; exit 0; }

# shellcheck disable=SC1091
source "$script_dir/governance-lib.sh" 2>/dev/null || safe_exit "lib source 실패"

if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -d "${CLAUDE_PROJECT_DIR:-}" ]; then
  cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || true
fi

input=$(cat 2>/dev/null || echo "")
echo "$input" | jq -e . >/dev/null 2>&1 || safe_exit "stdin JSON parse 실패"

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
tool_cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')

[ "$tool_name" = "Bash" ] || allow
# 의도적 범위 경계(F-3, WON'T-FIX): 선행자는 쉘 메타문자([;&|({`])·줄시작·VAR=val/env 접두만 인식.
#   wrapper-class(sh -c·bash -c·eval·perl -e·python -c·xargs·find -exec…)는 미차단 — 정규식으로 무한확장 닫기 불가(두더지잡기).
#   본 게이트는 적대적 경계가 아닌 Claude 자기정직 스캐폴드(공식 우회 SPECOPS_GOVERNANCE_BYPASS=1 제공). honest Claude 가
#   자기 commit 을 wrapper 난독화할 동기 0 = honest-mistake 경로 부재. 보안 1차방어는 is_docs_only_change(git-authoritative, wrapper-agnostic).
printf '%s' "$tool_cmd" | grep -Eq '(^|[;&|({`])[[:space:]]*(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+|env)[[:space:]]+)*git[[:space:]]+((-C|-c|--git-dir|--work-tree|--namespace|--super-prefix|--exec-path|--config-env)[[:space:]]+[^[:space:]]+[[:space:]]+|((--no-pager|-p|--paginate|--bare|--no-replace-objects|--literal-pathspecs|--glob-pathspecs|--noglob-pathspecs|--icase-pathspecs|--no-optional-locks|--no-advice|-P)|--[^[:space:]=]+=[^[:space:]]+)[[:space:]]+)*commit($|[^-[:alnum:]])|(^|[;&|({`])[[:space:]]*(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+|env)[[:space:]]+)*gh[[:space:]]+pr[[:space:]]+create\b' || allow

[ "${SPECOPS_GOVERNANCE_BYPASS:-}" = "1" ] && allow
printf '%s' "$tool_cmd" | grep -Eq '^[[:space:]]*SPECOPS_GOVERNANCE_BYPASS=1[[:space:]]' && allow
is_docs_only_change && allow

fid=$(detect_fid)
if [ -n "$fid" ] && [ -f ".specops/$fid/spec.md" ] && grep -qE '^\*\*§auto\*\*:[[:space:]]*true' ".specops/$fid/spec.md" 2>/dev/null; then
  allow
fi

[ -n "$transcript" ] && [ -f "$transcript" ] || allow

rules_path="$plugin_root/hooks/rules.jsonl"
[ -f "$rules_path" ] || allow
violation=""
while IFS= read -r rule; do
  [ -z "$rule" ] && continue
  rid=$(echo "$rule" | jq -r '.id')
  case "$rid" in
    R-1|R-2)
      res=$(apply_lookback_rule "$rule" "$transcript" "$tool_name" "$tool_cmd" 2>/dev/null || true)
      if [ -n "$res" ]; then
        violation="$rid"
        principle=$(echo "$rule" | jq -r '.principle')
        snippet=$(echo "$res" | jq -r '.evidence_snippet')
        offset=$(echo "$res" | jq -r '.offset')
        log_friction_sev "$fid" "$rid" "$principle" "$snippet" "$offset" block 2>/dev/null || true
        break
      fi
      ;;
  esac
done < <(load_rules "$rules_path" "posttool" 2>/dev/null || true)

if [ -n "$violation" ]; then
  case "$violation" in
    R-1) act="git commit" ;;
    R-2) act="gh pr create" ;;
    *)   act="이 작업" ;;
  esac
  reason="$act 차단 — verify 미실행. verifying-evidence-ko 선행 필요. 우회: SPECOPS_GOVERNANCE_BYPASS=1"
  jq -nc --arg r "$reason" \
    '{ hookSpecificOutput: { hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$r }, decision:"block", reason:$r }'
  exit 0
fi
allow
