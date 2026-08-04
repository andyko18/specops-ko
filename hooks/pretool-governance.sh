#!/usr/bin/env bash
# specops-ko governance — PreToolUse entrypoint (강제 차단)
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
# heredoc 본문 제거 후 검사 (20260713-heredoc-false-block): grep -E 는 줄 단위라, 멀티라인 command 의
#   heredoc **본문**에 쓴 git 예시(문서·테스트 작성)가 실제 명령으로 오인돼 정직한 작업을 차단했다.
#   정규식은 그대로 두고 **입력만** 전처리한다 — 정규식을 손대면 evasion 방어(PR #84·#112)가 흔들린다.
#   `bash <<EOF`(셸 실행자) 본문은 제외하지 않는다(실제 실행됨 → F-3 표면 불변). 실패 시 원본 = 차단 우세.
#   $tool_cmd 원본은 아래 apply_lookback_rule·deny 메시지에서 그대로 쓴다 — 덮어쓰기 금지.
tool_cmd_scan=$(_strip_heredoc_bodies "$tool_cmd")
tool_cmd_scan=$(_strip_quoted_strings "$tool_cmd_scan")
# prefilter 정규식은 rules.jsonl R-1/R-2 trigger_pattern 동적 로드 (T-H1 single-source — 구버전은 literal
#   복제 + 정합 테스트였으나, VAR=val 인용값 클래스 도입(20260716-batch-dogfood widening: `FOO='a b' git commit`
#   이 prefix 체인을 끊어 트리거를 통째로 비껴감 — 인식 확대 = deny-superset = 차단 우세라 evasion 방어
#   PR #84·#112 불변식 유지)으로 literal 에 quote-splice 가 생겨 복제 유지비 > 동적 로드 비용이 됐다.
#   R-3 의 posttool trigger_skill_pattern 동적 참조(T-R8)와 동형. 로드 실패 = 판정 불가 → fail-open.
rules_path="$plugin_root/hooks/rules.jsonl"
[ -f "$rules_path" ] || safe_exit "rules.jsonl 부재 — trigger 로드 불가"
trigger_re=$(jq -rs '[.[]|select(.id=="R-1" or .id=="R-2")|.trigger_pattern|select(.!=null)]|join("|")' "$rules_path" 2>/dev/null)
[ -n "$trigger_re" ] || safe_exit "trigger_pattern 로드 실패"
printf '%s' "$tool_cmd_scan" | grep -Eq "$trigger_re" || allow

# 세션-env 우회 = 사용자 주권(막지 않음). 단 무기록 우회는 감사 공백(상한 3호) → 기록 후 allow.
#   .specops 有일 때만 기록 — 부재(비-specops repo)면 log_friction 이 .specops 를 생성해 월권(M2 관할 가드 철학).
#   principle=1(숫자, 5원칙 1 투명성)·offset=0(숫자) 은 log_friction 이 --argjson 으로 소비 → 유효 JSON 필수.
if [ "${SPECOPS_GOVERNANCE_BYPASS:-}" = "1" ]; then
  if [ -d ".specops" ]; then
    _bypass_fid=$(detect_fid 2>/dev/null || echo "")
    log_friction "$_bypass_fid" "BYPASS-ENV" 1 "session-env SPECOPS_GOVERNANCE_BYPASS: ${tool_cmd:0:120}" 0 2>/dev/null || true
    _record_bypass_metric "$_bypass_fid"
  fi
  allow
fi

# ── batch PR 뭉개짐 게이트 (20260721-batch-pr-teeth) ─────────────────────────
# dogfood test1: 무인 batch 가 7개 per-FR FID 를 BATCH_ID 하나로 뭉갠 채 PR 을 냈다.
#   teeth(scripts/batch-state.sh)는 commands/start-all.md:114 **산문**에만 있어 아무도 호출하지 않았고,
#   R-2 훅은 verify 만 보므로 통과했다. 산문 teeth 를 훅으로 옮긴다.
#
# 배치 순서가 의미를 갖는다 — 세션 env BYPASS(위 줄) **뒤**, 인라인 BYPASS(아래) **앞**:
#   · 세션 env = 사용자가 켠 것 = 주권(5원칙 4) → 인정
#   · 인라인 = 모델 자기발급 → **불인정**. batch PR 은 비가역이고, 뭉개진 채 나가면 되돌리기 비싸다.
#     security Critical/High 를 "§auto여도 자동통과 금지"로 둔 선례와 동급(start-all-auto.md:56).
#     이 순서가 아니면 test1 이 한 그대로(#421) 사유 한 줄로 우회된다.
#
# 대상은 PR 뿐이다. **중간 커밋은 검사하지 않는다** — chain 상 verify 보다 앞서는 것이 정상이고
#   (아래 L97-101 참조) 여기서 막으면 정직한 태스크별 커밋이 전부 걸린다.
_batch_pr_gate() {
  printf '%s' "$tool_cmd_scan" | grep -Eq "gh[[:space:]]+pr[[:space:]]+create" || return 0
  # ★ 진행 중(ACTIVE 마커) batch 만 판정한다. glob-latest 는 쓰지 않는다.
  #   `.specops/*` 는 gitignore 라 뭉개진 batch 디렉토리가 디스크에 무기한 남는다. 아무 batch 나
  #   집으면 그것과 **무관한** 단일 FID 작업의 PR 이 과거 라벨 오염으로 차단된다 (실측 재현:
  #   specops-test1 의 무관한 PR 이 batch-20260721b 의 `DONE` 때문에 deny 됐다). 이 게이트는
  #   인라인 BYPASS 앞이라, 그런 false-block 의 탈출구는 "세션 전체 거버넌스 해제"뿐이 된다 —
  #   보호를 끄는 것이 유일한 출구인 형태는 게이트를 의례로 만든다.
  #   마커는 start-all Phase 0 이 queue.md 와 함께 만들고, batch PR 성공 후 지운다.
  #
  #   한계(5원칙 5): 마커는 오케스트레이터가 쓰는 것이라, 마커를 안 만들면 게이트도 안 열린다
  #   (자기보고 의존). 그럼에도 이 설계를 택한 이유는 **놓치는 비용 < 오차단 비용** 이기 때문이다 —
  #   false-block 은 사용자를 도구 밖으로 밀어내는 완주율 킬러이고, 미발화는 기존 상태로의 복귀일 뿐이다.
  #
  #   ★ 마커만으로는 부족하다. 마커는 "batch 가 진행 중인가"에 답할 뿐, 게이트가 필요한 답은
  #   "**이 PR 이 그 batch 의 PR 인가**"다. 특히 중단된 batch 가 치명적이다 — 마커는 PR 성공
  #   (Step D)에서만 지워지는데, 이 게이트의 목적이 뭉개진 batch 를 막는 것이라 막힌 batch 는
  #   Step D 에 도달하지 못한다. 마커가 영구히 남아 이후 모든 무관한 PR 을 차단한다.
  #   게이트가 잘 막을수록 오염 마커가 쌓이는 역설이다.
  #   판별자는 브랜치다 — batch PR 은 feat/<BATCH_ID> 에서 난다(start-all.md Phase 0).
  #   불일치·판정 불가(git 부재·detached)는 skip — false-block 회피가 옳은 오류 방향이다.
  local queue m d branch
  # symbolic-ref: 커밋 0건(unborn HEAD)에서도 브랜치명을 준다. rev-parse 는 unborn 에서 실패해
  #   갓 만든 batch(첫 커밋 전) 가 통째로 skip 된다 — 게이트가 가장 필요한 시점에 침묵한다.
  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return 0
  [ -n "$branch" ] || return 0
  queue=""
  for m in .specops/batch-*/ACTIVE; do
    [ -f "$m" ] || continue
    d=$(dirname "$m")
    [ "$branch" = "feat/$(basename "$d")" ] || continue
    [ -f "$d/queue.md" ] && queue="$d/queue.md" && break
  done
  [ -n "$queue" ] || return 0
  is_docs_only_change && return 0
  local gout grc
  gout=$(bash "$plugin_root/scripts/batch-state.sh" --gate "$(dirname "$queue")" 2>&1); grc=$?
  # 0=뭉개짐 없음 · 2=판정 불가(queue/requirements 파싱 실패) → fail-open. 1 만 차단.
  [ "$grc" -eq 1 ] || return 0
  local reason
  reason="batch PR 차단 — per-FR 산출물·진행기록이 뭉개졌습니다 (BATCH-GATE).

$gout

batch 는 FR 마다 개별 FID 로 verify·review 를 남겨야 합니다 (commands/start-all.md:93).
FR 하나를 BATCH_ID 디렉토리에 통합해 돌리면 per-FR 근거가 사라지고, 그 상태의 PR 은 되돌리기 비쌉니다.
해법: 누락된 FID 의 verify·review 를 개별 실행한 뒤 queue.md Status 를 IMPL_DONE 으로 갱신하고 재시도하세요.
이 차단은 인라인 SPECOPS_GOVERNANCE_BYPASS 로 열리지 않습니다 (비가역 불변식 — security Critical/High 와 동급).
사용자가 의도적으로 넘기려면 세션 환경변수로 지정하세요: export SPECOPS_GOVERNANCE_BYPASS=1"
  jq -nc --arg r "$reason" \
    '{ hookSpecificOutput: { hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$r }, decision:"block", reason:$r }'
  exit 0
}
_batch_pr_gate

# 인라인 BYPASS 는 사유(SPECOPS_BYPASS_REASON) 병기 필수 (20260716-batch-dogfood: 첫 deny 후 모델이
#   무사유 BYPASS 를 커밋 3회+PR 생성에 관성 사용 — 사유 없는 friction-log 는 우회 횟수만 남는 무정보 감사
#   기록이 된다. 사유는 명령 원문째 friction-log evidence_snippet 에 남는다). 세션 env(위 줄)는 사용자 전용
#   탈출구라 사유 불요(주권). REASON 선행/후행 순서 모두 인정 — 형식 함정 false-deny 금지.
#   선행자는 트리거와 동일 클래스([;&|({`] + 줄시작) — dogfood 20260717 test2: `git add x && BYPASS=1
#   REASON='...' git commit`(compound)·`B() { BYPASS=1 ...; }`(wrapper) 가 ^줄시작 앵커에 걸려 사유까지
#   정직 병기한 우회가 false-deny 됐다. 단순 공백 선행(메시지 내 토큰 언급, T37)은 여전히 불인정.
_reason_val="('[^']*'|\"[^\"]*\"|[^[:space:]]+)"
if printf '%s' "$tool_cmd" | grep -Eq "(^|[;&|({\`])[[:space:]]*(SPECOPS_BYPASS_REASON=${_reason_val}[[:space:]]+)?SPECOPS_GOVERNANCE_BYPASS=1[[:space:]]"; then
  # 메시지 오염 가드 (dogfood 20260717 test2 61f9e0d "BYPASS fix: ..."): 우회 표식이 git 히스토리에
  #   유입되면 conventional commit(릴리즈 노트·검색)이 훼손된다. 우회 기록은 REASON+friction-log 담당.
  if printf '%s' "$tool_cmd" | grep -Eq -- "-m[[:space:]]+[\"']?BYPASS"; then
    reason="커밋 메시지에 BYPASS 표식을 넣지 마세요 — 우회 기록은 SPECOPS_BYPASS_REASON 과 friction-log 가 담당합니다.
메시지는 conventional commit(fix:/feat:/test:/…)으로 정상 작성 후 재시도하세요."
    jq -nc --arg r "$reason" \
      '{ hookSpecificOutput: { hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$r }, decision:"block", reason:$r }'
    exit 0
  fi
  if printf '%s' "$tool_cmd" | grep -Eq "(^|[[:space:]])SPECOPS_BYPASS_REASON=[^[:space:]]"; then
    # 인라인 우회도 수율 계측에 남긴다(사유 원문은 friction-log / 명령 원문 쪽).
    if [ -d ".specops" ]; then
      _bypass_fid=$(detect_fid 2>/dev/null || echo "")
      _record_bypass_metric "$_bypass_fid"
    fi
    allow
  fi
  reason="SPECOPS_GOVERNANCE_BYPASS 인라인 우회에는 사유 병기가 필수입니다 (friction-log 감사 기록에 명령 원문째 남습니다).
형식: SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON='<한 줄 사유>' <명령>
우회 전 정직한 해법 우선: bash scripts/_internal/run-verification.sh <FID> 를 이 세션에서 실행하면 우회 없이 열립니다."
  jq -nc --arg r "$reason" \
    '{ hookSpecificOutput: { hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$r }, decision:"block", reason:$r }'
  exit 0
fi
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
#   남기고 그대로 통과한다. 무인 중 정당한 우회는 명시적 SPECOPS_GOVERNANCE_BYPASS=1 + SPECOPS_BYPASS_REASON 을 쓴다
#   (감사 로그에 사유째 남으므로 암묵 면제보다 정직하다).
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
  # ★ 면제 조건은 **두 겹**이다 (governance-lib.sh apply_lookback_rule L481-500):
  #     ① 실행 증거 — transcript 의 러너 tool_result 에 `VERIFY: PASS` (필요조건)
  #     ② FID-scoped 앵커 — session-progress `## <FID>` 섹션의 `/verify PASS` 줄, 또는 해당 FID 의
  #        evidence.md 스탬프, 또는 verify Skill 호출 이벤트 (①이 있어야 인정되는 보조 신호)
  #   구 문안은 ①만 안내해, 지시대로 러너를 재실행하고도 ②가 없어 또 막힌 모델을 BYPASS 로 몰았다
  #   (dogfood 20260721 test1 #418→#419→#420: 안내 이행 후 동일 메시지로 재차단 → #421 BYPASS).
  #   $fid 가 비어 있으면 그 자체가 진단이다 — session-progress 에 FID 섹션이 없다는 뜻.
  _anchor_hint=""   # 메인 흐름(함수 밖) — local 불가
  if [ -z "${fid:-}" ]; then
    _anchor_hint="② 진행 기록 앵커가 없습니다 — .specops/session-progress.md 에 \`## <FID>\` 섹션이 하나도 없습니다.
   FID 는 YYYYMMDD-kebab-slug 형식이어야 합니다(batch-<날짜> 같은 BATCH_ID 는 인식되지 않습니다).
   bash scripts/session-progress-append.sh <FID> /verify PASS 로 기록하세요."
  else
    _anchor_hint="② 진행 기록 앵커: .specops/session-progress.md 의 \`## ${fid}\` 섹션에 \`- <날짜> <시각> /verify PASS\` 줄,
   또는 .specops/${fid}/evidence.md 의 RUN-VERIFICATION-RESULT 스탬프가 필요합니다."
  fi
  # Wave C: compound `git add … && git commit` deny 시 add도 취소됨 → 분리 안내 (트리거/부분실행은 불변)
  _compound_hint=""
  if [ "$violation" = "R-1" ] \
     && printf '%s' "$tool_cmd_scan" | grep -Eq '(^|[[:space:];&|({`])git[[:space:]]+add([[:space:]]|$)' ; then
    _compound_hint="

⚠️ compound 안내: 이 명령에 \`git add\` 와 \`git commit\` 이 함께 있습니다.
   PreToolUse deny 시 add 도 함께 취소됩니다 — \`git add\` 와 \`git commit\` 을 **별도 Bash 호출**로 분리 실행하세요."
  fi
  reason="$act 차단 — verify 면제 조건 2가지 중 최소 하나가 미충족입니다.

① 실행 증거: 이 세션에 러너 실행 기록이 없습니다(이전 세션의 verify 는 transcript 가 세션별이라 인정되지 않고, stale 위험도 있습니다).
   bash scripts/_internal/run-verification.sh ${fid:-<FID>} 를 이 세션에서 실행하세요.
   (플러그인 자기 repo self-maintenance 는 bash scripts/tests/run-all.sh 전체 스위트 통과도 인정됩니다.)
$_anchor_hint

implement 중간 커밋 대안(R-1): 태스크 테스트 PASS 후
   bash scripts/_internal/record-task-receipt.sh ${fid:-<FID>} <T#>
   로 receipt를 남기고, 커밋 메시지에 T#/Task: T# 를 넣으면 FID 전체 verify 없이 열릴 수 있습니다
   (staged ⊆ task outputs, receipt 이후 코드 변경 없음).

①은 필요조건입니다 — ② 만으로는 열리지 않습니다(모델 자기보고라 위조 가능). 둘 다 갖춰야 통과합니다.
우회(사유 병기 필수): SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON='<한 줄 사유>' <명령>${_compound_hint}"
  jq -nc --arg r "$reason" \
    '{ hookSpecificOutput: { hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$r }, decision:"block", reason:$r }'
  exit 0
fi

# ── P0-3 RELEASE_READY (R-2 / gh pr create 전용) — Wave B limited hard ──────
# strict FID 또는 ACTIVE batch(브랜치 일치) PR: NOT_READY → hard deny.
# 그 외: warn-only. UNKNOWN(rc=2)은 fail-open. R-1·docs-only·BYPASS·batch-state·verify lookback 은 위에서 처리됨.
_release_ready_gate() {
  printf '%s' "$tool_cmd_scan" | grep -Eq 'gh[[:space:]]+pr[[:space:]]+create' || return 0
  [ -f "$plugin_root/scripts/_internal/release-ready.sh" ] || return 0

  local hard=0 hard_why="" fids="" f branch m d qdir qfile eff line
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)

  # batch 스코프 — ACTIVE + feat/<BATCH_ID> ( _batch_pr_gate 와 동일 판별 )
  if [ -n "$branch" ]; then
    for m in .specops/batch-*/ACTIVE; do
      [ -f "$m" ] || continue
      d=$(dirname "$m")
      [ "$branch" = "feat/$(basename "$d")" ] || continue
      qfile="$d/queue.md"
      [ -f "$qfile" ] || continue
      hard=1
      hard_why=batch
      qdir="$d"
      # IMPL_DONE FID 전부
      while IFS= read -r line; do
        f=$(printf '%s' "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')
        printf '%s' "$f" | grep -qE '^[0-9]{8}-[a-z0-9-]+$' || continue
        fids="${fids}${fids:+ }$f"
      done < <(grep -E '\|[[:space:]]*IMPL_DONE[[:space:]]*\|' "$qfile" 2>/dev/null || true)
      break
    done
  fi

  # detect_fid / active-fid fallback + strict 프로파일
  local _rr_fid="${fid:-}"
  [ -n "$_rr_fid" ] || _rr_fid=$(detect_fid 2>/dev/null || echo "")
  if [ -z "$fids" ] && [ -n "$_rr_fid" ]; then
    fids="$_rr_fid"
  fi
  if [ -n "$_rr_fid" ] && [ -f ".specops/$_rr_fid/risk-profile.json" ]; then
    eff=$(jq -r '.effective // empty' ".specops/$_rr_fid/risk-profile.json" 2>/dev/null || true)
    if [ "$eff" = "strict" ]; then
      hard=1
      [ "$hard_why" = "batch" ] || hard_why=strict
      case " $fids " in *" $_rr_fid "*) ;; *) fids="${fids}${fids:+ }$_rr_fid" ;; esac
    fi
  fi

  [ -n "$fids" ] || return 0

  local any_not_ready=0 agg="" rc out
  for f in $fids; do
    # || true 금지 — $? 가 항상 0 이 되어 NOT_READY 를 못 본다
    out=$(bash "$plugin_root/scripts/_internal/release-ready.sh" "$f" 2>&1)
    rc=$?
    if [ "$rc" -eq 1 ]; then
      any_not_ready=1
      if [ -n "$agg" ]; then
        agg="$agg

--- FID $f ---
$out"
      else
        agg="--- FID $f ---
$out"
      fi
    fi
    # rc=2 UNKNOWN → 해당 FID는 무시(fail-open)
  done

  [ "$any_not_ready" -eq 1 ] || return 0

  if [ "$hard" -eq 1 ]; then
    local reason
    reason="RELEASE_READY 차단 — PR 품질 축 미충족 (${hard_why}).

$agg

해법: 해당 FID에서 verify·review·security/integration/performance·reconcile 축을 충족한 뒤 재시도하세요.
우회(사유 병기 필수): SPECOPS_GOVERNANCE_BYPASS=1 SPECOPS_BYPASS_REASON='<한 줄 사유>' <명령>"
    log_friction_sev "${_rr_fid:-$f}" "RELEASE_READY" 1 "$(printf '%s' "$agg" | tr '\n' ' ' | cut -c1-200)" 0 block 2>/dev/null || true
    jq -nc --arg r "$reason" \
      '{ hookSpecificOutput: { hookEventName:"PreToolUse", permissionDecision:"deny", permissionDecisionReason:$r }, decision:"block", reason:$r }'
    exit 0
  fi

  echo "RELEASE_READY warn (PR 차단 아님): $agg" >&2
  log_friction "${_rr_fid:-unknown}" "RELEASE_READY" 1 "$(printf '%s' "$agg" | tr '\n' ' ' | cut -c1-200)" 0 2>/dev/null || true
}
_release_ready_gate

allow
