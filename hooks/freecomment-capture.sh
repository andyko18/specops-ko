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

lu_full=$(jq -rs '[.[] | select(.type=="user") | .message.content] | last
      | if type=="array" then (.[] | select(.type=="text") | .text) else . end' \
      "$transcript" 2>/dev/null)
lu=$(printf '%s\n' "$lu_full" | tail -1)   # type 분류 전용 — 메모리 안에서만 쓰고 저장하지 않는다
lu=${lu:-""}

type="fix"
case "$lu" in
  *설계*|*변경*|*리팩터*|*구조*) type="design-change" ;;
  *고쳐*|*수정*|*버그*|*오류*|*fix*) type="fix" ;;
  *\?*|*뭐*|*어떻게*|*왜*) type="question" ;;
esac

# 저장 직전 마스킹(fail-closed) — 줄 자르기보다 앞서 전체 텍스트를 마스킹한 뒤 마지막 줄·2000자만 남긴다.
#   rc≠0(패턴 부재·redact.sh 부재 127 포함)이면 프롬프트를 버리고 redact_failed 로 표시한다. 정규식 마스킹은 완전 보장이 아니다.
redact_failed=false
# 총 상한 2000자(AC-4, 표식 포함). redact.sh --max N 은 본문 N자 + 표식 "…[TRUNCATED]"(12자)를 내므로 표식 길이를 뺀다.
#   12 는 redact.sh 의 표식 문자열 길이와 연동 — 표식을 바꾸면 이 값도 바꾼다.
prompt_max=2000; trunc_mark_len=12
if lu_r=$(printf '%s\n' "$lu_full" | bash "$plugin_root/scripts/_internal/redact.sh" --last-line --max $((prompt_max - trunc_mark_len)) 2>/dev/null); then
  lu="$lu_r"
else
  lu=""; redact_failed=true
fi

# symlink 가드 (#144 log_friction 대칭) — 악성 repo 가 .specops 또는 pending 파일을
# 외부 dir symlink 로 심으면 write-through path-escape. 훅 자기 cwd 가 아닌 $cwd 기준이라 인라인 검사.
[ ! -L "$cwd/.specops" ] || safe_exit
[ ! -L "$cwd/.specops/pending-capture.jsonl" ] || safe_exit
mkdir -p "$cwd/.specops"
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
files_json=$(printf '%s\n' "${real_files[@]}" | jq -R . | jq -cs .)   # quote 배열 — glob/공백 안전
fid=$(cd "$cwd" && detect_fid 2>/dev/null || echo "")
jq -cn --arg ts "$ts" --argjson files "$files_json" --arg p "$lu" --arg t "$type" --arg fid "$fid" --argjson rf "$redact_failed" \
  '{ts:$ts, files:$files, prompt:$p, type:$t, fid:$fid} + (if $rf then {redact_failed:true} else {} end)' >> "$cwd/.specops/pending-capture.jsonl" 2>/dev/null
# 실패 건수 로그 — 시각·출처만(원문·프롬프트 일부 금지). 로그 파일 symlink 는 write-through 거부(#144 대칭)
if [ "$redact_failed" = true ] && [ ! -L "$cwd/.specops/redact-failures.log" ]; then
  printf '%s freecomment-capture\n' "$ts" >> "$cwd/.specops/redact-failures.log" 2>/dev/null
fi
safe_exit
