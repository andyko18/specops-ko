#!/usr/bin/env bash
# specops-ko save-review-report — SubagentStop 훅 (matcher: spec-reviewer-ko|code-reviewer-ko).
# 리뷰어 최종 메시지의 <<<REVIEW …>>> ~ <<<END>>> 블록을 .specops/<FID>/reviews/<tid>-<phase>-report.md 로
#   tid 별 저장하고(통과 판정이 아니면 -feedback.md 병기) exit 2 로 요약 재종료를 지시한다.
# stdin: SubagentStop JSON (cwd · stop_hook_active · last_assistant_message)
# Exit: 2 = 전 블록 저장 + 요약 지시(stderr → 서브에이전트) · 0 = 무동작 fail-open(전문이 그대로 부모에게 간다)
# 전부 아니면 무 (clarify Q1): 블록 하나라도 형식 오류면 어떤 파일도 쓰지 않는다 — 요약을 요구하면 그 전문이 소실된다.
# 본문은 자르거나 고치지 않고 옮긴다 — release-ready.sh 가 report 본문의 🔴 절·판정 메뉴를 읽는다.
set -uo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(dirname "$script_dir")

bash "$plugin_root/scripts/_internal/is-hook-enabled.sh" save-review-report >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat 2>/dev/null || true)
active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || true)
[ "$active" = "true" ] && exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
msg=$(printf '%s' "$input" | jq -r '.last_assistant_message // empty' 2>/dev/null || true)
{ [ -n "$cwd" ] && [ -n "$msg" ]; } || exit 0

work=$(mktemp -d 2>/dev/null) || exit 0
trap 'rm -rf "$work"' EXIT

# 블록 분리 — <n>.meta(속성) · <n>.body(본문). 출력: 블록 수 또는 BAD(중첩·짝 없음)
count=$(printf '%s\n' "$msg" | awk -v dir="$work" '
  BEGIN { n = 0; inb = 0; bad = 0 }
  /^<<<REVIEW .*>>>[[:space:]]*$/ {
    if (inb) bad = 1
    n++; inb = 1
    hdr = $0; sub(/^<<<REVIEW /, "", hdr); sub(/>>>[[:space:]]*$/, "", hdr)
    print hdr > (dir "/" n ".meta"); close(dir "/" n ".meta")
    printf "" > (dir "/" n ".body")
    next
  }
  /^<<<END>>>[[:space:]]*$/ {
    if (!inb) bad = 1; else close(dir "/" n ".body")
    inb = 0; next
  }
  inb { print > (dir "/" n ".body") }
  END { if (inb) bad = 1; print (bad ? "BAD" : n) }')
case "$count" in ''|BAD|0) exit 0 ;; esac

# 검증 — 속성 정규식 · 단일 FID · tid-phase 중복 · 빈 본문 (하나라도 걸리면 exit 0)
re='^fid=([0-9]{8}-[a-z0-9-]+) tid=(T[0-9]+) phase=([BC]) verdict=(PASS|READY_TO_MERGE|NEEDS_FIX|NEEDS_DISCUSSION)$'
fid=""; seen=" "; i=1
while [ "$i" -le "$count" ]; do
  meta=$(cat "$work/$i.meta")
  [[ "$meta" =~ $re ]] || exit 0
  b_fid=${BASH_REMATCH[1]}; b_tid=${BASH_REMATCH[2]}; b_phase=${BASH_REMATCH[3]}; b_verdict=${BASH_REMATCH[4]}
  [ -n "$fid" ] || fid=$b_fid
  [ "$b_fid" = "$fid" ] || exit 0
  case "$seen" in *" $b_tid-$b_phase "*) exit 0 ;; esac
  seen="$seen$b_tid-$b_phase "
  [ -s "$work/$i.body" ] || exit 0
  printf '%s %s %s\n' "$b_tid" "$b_phase" "$b_verdict" > "$work/$i.key"
  i=$((i+1))
done

[ -d "$cwd/.specops/$fid" ] || exit 0
reviews="$cwd/.specops/$fid/reviews"
mkdir -p "$reviews" 2>/dev/null || exit 0

# 1단계: 임시 파일에 전부 쓴다 — 하나라도 실패하면 기존 파일 무접촉으로 종료
staged=""; i=1
while [ "$i" -le "$count" ]; do
  read -r tid phase verdict < "$work/$i.key"
  names="$tid-$phase-report.md"
  case "$verdict" in PASS|READY_TO_MERGE) ;; *) names="$names $tid-$phase-feedback.md" ;; esac
  for name in $names; do
    if ! cp "$work/$i.body" "$reviews/.$name.tmp.$$" 2>/dev/null; then
      rm -f "$reviews"/.*.tmp.$$ 2>/dev/null
      exit 0
    fi
    staged="$staged $name"
  done
  i=$((i+1))
done

# 2단계: 같은 디렉토리 안 이동(rename). 하나라도 실패하면 요약을 요구하지 않고 exit 0 —
#   리뷰어 전문이 그대로 부모에게 가서, report 가 없는 tid 를 부모가 fallback 저장한다.
#   (요약을 요구하면 옮기지 못한 tid 의 전문이 어디에도 남지 않는다)
saved=""; moved_all=1
for name in $staged; do
  if ! mv -f "$reviews/.$name.tmp.$$" "$reviews/$name" 2>/dev/null; then
    rm -f "$reviews/.$name.tmp.$$" 2>/dev/null; moved_all=0; continue
  fi
  saved="$saved
- .specops/$fid/reviews/$name"
done
{ [ "$moved_all" = 1 ] && [ -n "$saved" ]; } || exit 0

cat >&2 <<EOF
리뷰 보고서 전문을 저장했다:$saved

이제 부모에게 돌려줄 요약만 출력하고 끝내라. 보고서 본문을 다시 쓰지 말고 300토큰 이내로:
판정: <tid·phase 별 verdict>
Critical: <항목 1줄씩, 없으면 없음>
Important: <항목 1줄씩, 없으면 없음>
저장: <위 경로>
EOF
exit 2
