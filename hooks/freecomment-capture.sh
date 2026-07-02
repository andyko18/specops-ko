#!/usr/bin/env bash
# Stop 훅 — lifecycle 밖 자유작업 감지 → pending-capture.jsonl stub
set -u

plugin_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
. "$plugin_root/hooks/governance-lib.sh" 2>/dev/null || true

safe_exit() { echo '{"continue":true}'; exit 0; }

input=$(cat 2>/dev/null) || safe_exit
[ "$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && safe_exit

cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd" ] || safe_exit
transcript=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
[ -n "$transcript" ] && [ -f "$transcript" ] || safe_exit

changed=$(cd "$cwd" && git diff HEAD --name-only 2>/dev/null)
[ -z "$changed" ] && safe_exit

edits=$(read_recent_tool_events "$transcript" 50 2>/dev/null \
  | jq -r 'select(.tool_name=="Edit" or .tool_name=="Write") | .input.file_path // empty' 2>/dev/null \
  | grep -v '/\.specops/' | grep -v '^\.specops/' || true)
[ -z "$edits" ] && safe_exit

real_files=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  rel="${f#"$cwd"/}"                       # 절대경로면 cwd 제거 → repo-상대
  if printf '%s\n' "$changed" | grep -qxF "$rel"; then   # -x 전체줄 정확매칭
    real_files+=("$rel")
  fi
done <<< "$edits"
[ "${#real_files[@]}" -eq 0 ] && safe_exit  # 빈 배열 먼저 exit (bash 3.2 unbound 가드)

lu=$(jq -rs '[.[] | select(.type=="user") | .message.content] | last
      | if type=="array" then (.[] | select(.type=="text") | .text) else . end' \
      "$transcript" 2>/dev/null | tail -1)
lu=${lu:-""}

type="fix"
case "$lu" in
  *설계*|*변경*|*리팩터*|*구조*) type="design-change" ;;
  *고쳐*|*수정*|*버그*|*오류*|*fix*) type="fix" ;;
  *\?*|*뭐*|*어떻게*|*왜*) type="question" ;;
esac

# symlink 가드 (#144 log_friction 대칭) — 악성 repo 가 .specops 또는 pending 파일을
# 외부 dir symlink 로 심으면 write-through path-escape. 훅 자기 cwd 가 아닌 $cwd 기준이라 인라인 검사.
[ ! -L "$cwd/.specops" ] || safe_exit
[ ! -L "$cwd/.specops/pending-capture.jsonl" ] || safe_exit
mkdir -p "$cwd/.specops"
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
files_json=$(printf '%s\n' "${real_files[@]}" | jq -R . | jq -cs .)   # quote 배열 — glob/공백 안전
fid=$(cd "$cwd" && detect_fid 2>/dev/null || echo "")
jq -cn --arg ts "$ts" --argjson files "$files_json" --arg p "$lu" --arg t "$type" --arg fid "$fid" \
  '{ts:$ts, files:$files, prompt:$p, type:$t, fid:$fid}' >> "$cwd/.specops/pending-capture.jsonl" 2>/dev/null
safe_exit
