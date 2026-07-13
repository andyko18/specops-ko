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
# M2 관할 가드: .specops 부재 = specops 미사용 repo → verify-before-commit 강제 면제 (5원칙 4 주권 — 플러그인은
#   자기 관할 repo 만 통제, 무관 repo 월권 금지). lifecycle 진행 중(.specops 존재)이면 그대로 강제 — 보호 손실 0.
[ -d ".specops" ] || allow
is_docs_only_change && allow

# $fid 는 아래 log_friction_sev(위반 기록)·deny 메시지에서 재사용된다 — 삭제 금지.
#   set -uo pipefail 하에서 unbound "$fid" 는 스크립트를 즉사시켜 deny 경로가 JSON 을 못 뱉는다(무출력 = fail-open).
fid=$(detect_fid)

# §auto 무조건 면제는 여기 없다 — 의도적으로 제거했다 (20260713-verify-exec-gate).
#   구버전은 spec.md 의 `**§auto**: true` 라벨만 보고 실행-근거 검사에 **도달하기도 전에** allow 했다.
#   그 라벨은 모델이 spec.md 에 쓰는 것이라 사실상 자기발급 면제표였고, 무인 진입(/start-auto·/start-all-auto)이면
#   게이트가 통째로 무효화됐다. §auto 의 의미는 "가역 게이트 자동 통과"(사용자 확인 생략)이지 "검증 면제"가 아니다.
#   무인 모드도 chain 에 verifying-evidence-ko 가 있어 verify 를 실제 실행하므로, 정직한 무인 흐름은 실행 증거를
#   남기고 그대로 통과한다. 무인 중 정당한 우회는 명시적 SPECOPS_GOVERNANCE_BYPASS=1 을 쓴다
#   (감사 로그에 남으므로 암묵 면제보다 정직하다).
#
#   단 위 문장을 "무인이면 늘 통과한다" 로 읽지 말 것 — /implement 의 **태스크별 중간 커밋**은 chain 상
#   verify 보다 **앞서므로** 실행 증거가 아직 없다. 즉 정직한 흐름이어도 중간 커밋은 deny 되고
#   SPECOPS_GOVERNANCE_BYPASS=1 경로를 타며 friction-log 에 R-1 warn 이 남는다 (본 FID 의 T1~T4 커밋이 전부 그랬다).
#   이는 설계된 비용이다: "커밋 시점에 verify 실행 증거" 라는 불변식을 지키려면 verify 이전 커밋은 명시적
#   BYPASS 로만 통과해야 한다 (암묵 면제 = 게이트 무효화). 태스크별 커밋을 상시 면제하고 싶다면 그건 별도 설계 결정이다.

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
  # 세션 경계 한계 고백(5원칙 5): 실행 증거는 transcript(세션별 파일)에만 존재한다 → 이전 세션에서 정직하게 verify 를
  #   마쳤어도 새 세션에서는 증거가 보이지 않아 deny 된다. 이는 의도된 동작 — 세션 넘긴 verify 는 stale 위험(#120).
  #   따라서 메시지는 "verify 미실행"(단정·거짓 가능)이 아니라 "이 세션에 실행 증거 없음"으로 진술하고,
  #   실제로 게이트를 여는 유일한 행동(run-verification.sh 재실행)을 안내한다. Skill 호출 안내는 틀린 해법(T2b 가 차단).
  # $fid 는 L44 에서 bind 됨(빈 값 가능 — session-progress 부재 시) → ${fid:-<FID>} 로 dangling 방지.
  reason="$act 차단 — 이 세션에 verify 실행 증거가 없습니다(이전 세션의 verify 는 transcript 가 세션별이라 인정되지 않고, stale 위험도 있습니다).
해법: bash scripts/_internal/run-verification.sh ${fid:-<FID>} 를 이 세션에서 실행한 뒤 재시도하세요.
Skill 호출·evidence.md 스탬프만으로는 열리지 않습니다 — 모델 자기보고라 위조 가능, 하네스가 남긴 실행 기록만 인정합니다.
우회: SPECOPS_GOVERNANCE_BYPASS=1"
  jq -nc --arg r "$reason" \
    '{ hookSpecificOutput: { hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$r }, decision:"block", reason:$r }'
  exit 0
fi
allow
