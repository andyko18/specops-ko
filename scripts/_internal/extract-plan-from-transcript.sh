#!/usr/bin/env bash
# extract-plan-from-transcript.sh — cwd 프로젝트 transcript 에서 최신 plan 1건 추출
#
# 계기: /init-project 는 PRD 초안 근거를 3경로(명시 경로·브레인스토밍 메모·문서 auto-discovery)에서
#       찾는데, plan 모드 산출물은 파일로 남지 않아 어디에도 닿지 않았다. 그러나 plan 은
#       ExitPlanMode **도구 호출**이라 transcript 의 tool_use.input.plan 에 전문이 남는다.
#
# 계약: read-only(transcript 미변경) · stdout=plan 전문(바이트 동일) · stderr=출처+제목
#       exit 0=발견 · 1=없음(디렉토리 부재·jsonl 0건·plan 0건·빈 plan·창 초과) · 2=jq 부재
# 환경변수: SPECOPS_PLAN_MAX_AGE_HOURS (기본 24) — 비정수·음수면 기본값 fallback + 경고
set -uo pipefail

DEFAULT_MAX_AGE=24
max_age="${SPECOPS_PLAN_MAX_AGE_HOURS:-$DEFAULT_MAX_AGE}"

while [ $# -gt 0 ]; do
  case "$1" in
    --max-age-hours) max_age="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    # 오타 플래그(--max-age-hour 등)를 조용히 삼키면 사용자가 창이 안 먹은 걸 모른다 (AC-9 정신)
    *) printf "extract-plan: 알 수 없는 인자 '%s' — 무시\n" "$1" >&2; shift ;;
  esac
done

# 잘못된 창 → 기본값 fallback + 경고. 대원칙은 "/init-project 를 막지 않는다" 이므로
# env 오타로 죽이지 않는다. 다만 조용히 무시하면 오타를 영영 모르므로 경고는 낸다.
# ('-5' 는 '-' 가 비숫자라 아래 패턴에 걸린다 — 음수도 같은 경로)
case "$max_age" in
  ''|*[!0-9]*)
    printf "extract-plan: 잘못된 시간 창 '%s' — 기본 %s시간 적용\n" "$max_age" "$DEFAULT_MAX_AGE" >&2
    max_age=$DEFAULT_MAX_AGE ;;
esac

# jq 는 선택 의존 (check-ci-status.sh 패턴 승계)
command -v jq >/dev/null 2>&1 || { echo "extract-plan: jq 미설치 — plan 추출 skip" >&2; exit 2; }

# cwd → Claude Code transcript 슬러그 ('/'·'.' → '-'). 실측 규칙이지 공개 계약이 아니다 —
# 규칙이 바뀌면 디렉토리 부재로 판정돼 graceful skip 된다(실패 방향 안전).
slug=$(pwd | sed 's/[/.]/-/g')
dir="$HOME/.claude/projects/$slug"
[ -d "$dir" ] || exit 1

# ★ grep 'ExitPlanMode' 금지 — 에이전트 도구 목록 문구("All tools except ... ExitPlanMode ...")에
#   걸린다(실측: decoy 전용 fixture 에 grep 1건 매칭, 실호출 0건). jq 필드 필터만 쓴다.
# ★ 전수 스캔 후 전역 최신 선택 — mtime 순 첫 발견은 틀릴 수 있다(오래 전 시작해 최근까지 이어진
#   세션은 mtime 최신이나 그 안의 plan 은 더 오래됐을 수 있다). 실측 40파일/117MB 전수 1초.
best=$(
  for f in "$dir"/*.jsonl; do
    [ -f "$f" ] || continue
    jq -rs --arg src "$(basename "$f")" '
      [ .[]
        | select(.message.content != null)
        | . as $e
        | .message.content[]?
        | select(.type == "tool_use" and .name == "ExitPlanMode")
        | select(((.input.plan // "") | gsub("^[[:space:]]+|[[:space:]]+$"; "")) != "")
        | { ts: $e.timestamp, src: $src, plan: .input.plan }
      ] | .[] | @json
    ' "$f" 2>/dev/null
  done | jq -rs 'if length == 0 then empty else (max_by(.ts) | @json) end' 2>/dev/null
)
[ -n "$best" ] || exit 1

# 경과 시간은 파일 mtime 이 아니라 plan 라인의 .timestamp 로 계산한다 —
# mtime 은 세션 마지막 활동 시각이라 stale 판정이 무력해진다.
# jq 내부 산술이라 date(1) 의 BSD/GNU 차이를 타지 않는다.
age=$(printf '%s' "$best" | jq -r '
  (.ts | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) as $t
  | ((now - $t) / 3600 | floor)' 2>/dev/null)
case "$age" in ''|*[!0-9-]*) exit 1 ;; esac
[ "$age" -le "$max_age" ] || exit 1

src=$(printf '%s' "$best" | jq -r '.src')
printf 'PLAN-SOURCE: %s (%s시간 전)\n' "$src" "$age" >&2

# 제목은 있으면 표기, 없으면 생략(실패 아님) — 사용자가 어떤 plan 인지 알고 y/n 하게 한다
title=$(printf '%s' "$best" | jq -j '.plan' | grep -m1 '^# ' || true)
[ -n "$title" ] && printf 'PLAN-TITLE: %s\n' "$title" >&2

# -j = 개행 미추가. stdout 은 input.plan 과 바이트 동일해야 한다(AC-1).
printf '%s' "$best" | jq -j '.plan'
exit 0
