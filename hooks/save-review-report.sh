#!/usr/bin/env bash
# specops-ko save-review-report — SubagentStop 훅 (matcher: spec-reviewer-ko|code-reviewer-ko).
# 리뷰어 최종 메시지의 <<<REVIEW …>>> ~ <<<END>>> 블록을 .specops/<FID>/reviews/<tid>-<phase>-report.md 로
#   tid 별 저장하고(통과 판정이 아니면 -feedback.md 병기) exit 2 로 요약 재종료를 지시한다.
# stdin: SubagentStop JSON (cwd · stop_hook_active · last_assistant_message)
# Exit: 2 = 전 블록 저장 + 요약 지시(stderr → 서브에이전트) · 0 = 무동작 fail-open(전문이 그대로 부모에게 간다 · stderr 없음)
# 전부 아니면 무 (clarify Q1): 블록 하나라도 형식 오류 · 대상 경로가 일반 파일 아님 · 임시 쓰기 실패 · 이동 실패면
#   reviews/ 를 실행 전 상태로 되돌리고(이동 실패는 백업 복원) exit 0 — 요약을 요구하면 그 전문이 소실된다.
#   단 복원 cp 까지 실패한 파일은 되돌리지 못한다: 대상에는 이번 본문이 남고 옛 내용은 백업
#   (.<name>.bak.<pid>)으로 reviews/ 에 남긴다(지우지 않음).
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

# 검증 — 속성 정규식 · 단일 FID · tid-phase 중복 · 빈(공백만) 본문 (하나라도 걸리면 exit 0)
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
  body=$(<"$work/$i.body")
  [ -n "${body//[[:space:]]/}" ] || exit 0
  printf '%s %s %s\n' "$b_tid" "$b_phase" "$b_verdict" > "$work/$i.key"
  i=$((i+1))
done

[ -d "$cwd/.specops/$fid" ] || exit 0
reviews="$cwd/.specops/$fid/reviews"
mkdir -p "$reviews" 2>/dev/null || exit 0

# 0단계: 저장 대상 이름 목록 + 대상 경로 검사 — 일반 파일이 아닌 기존 경로(디렉토리 등)면 mv 가 그 안으로
#   옮겨 거짓 "저장" 보고가 되므로 아무것도 쓰기 전에 전부 포기한다
names=""; i=1
while [ "$i" -le "$count" ]; do
  read -r tid phase verdict < "$work/$i.key"
  printf '%s %s\n' "$i" "$tid-$phase-report.md" >> "$work/plan"
  case "$verdict" in PASS|READY_TO_MERGE) ;; *) printf '%s %s\n' "$i" "$tid-$phase-feedback.md" >> "$work/plan" ;; esac
  i=$((i+1))
done
while read -r i name; do
  if [ -e "$reviews/$name" ] || [ -L "$reviews/$name" ]; then
    [ -f "$reviews/$name" ] || exit 0
  fi
  names="$names $name"
done < "$work/plan"

# 정리 — 이번 실행($$)의 임시·백업 파일만 지운다 (이름 목록 기준, glob 아님)
#   $1 = 백업을 남길 이름 목록(공백 구분 · 복원 실패분) — 그 이름의 임시 파일은 지운다
_cleanup() {
  local n keep=" ${1:-} "
  for n in $names; do
    rm -f "$reviews/.$n.tmp.$$" 2>/dev/null
    case "$keep" in *" $n "*) ;; *) rm -f "$reviews/.$n.bak.$$" 2>/dev/null ;; esac
  done
}

# 1단계: 임시 파일에 전부 쓰고, 기존 대상은 cp 로 백업한다 — 하나라도 실패하면 기존 파일 무접촉으로 종료
#   (백업·복원은 cp 만 쓴다: 복원 경로가 실패한 mv 와 같은 목적지라 mv 로 되돌리면 같은 이유로 또 실패할 수 있다)
while read -r i name; do
  if ! cp "$work/$i.body" "$reviews/.$name.tmp.$$" 2>/dev/null; then _cleanup; exit 0; fi
  if [ -f "$reviews/$name" ] && ! cp -p "$reviews/$name" "$reviews/.$name.bak.$$" 2>/dev/null; then _cleanup; exit 0; fi
done < "$work/plan"

# 2단계: 같은 디렉토리 안 이동(rename). 한 건이라도 실패하면 이미 옮긴 파일을 되돌리고(백업 있으면 복원 ·
#   없던 파일은 삭제) 요약을 요구하지 않고 exit 0 — 리뷰어 전문이 그대로 부모에게 가서 부모가 fallback 저장한다.
#   (되돌리지 않으면 옛 판정 report 가 남아 부모 fallback 이 발동하지 않는다)
saved=""; moved=""
for name in $names; do
  if ! mv -f "$reviews/.$name.tmp.$$" "$reviews/$name" 2>/dev/null; then
    keep=""
    for m in $moved $name; do
      if [ -f "$reviews/.$m.bak.$$" ]; then
        # 복원까지 실패하면 옛 내용은 그 백업에만 있다 — 지우지 않고 남긴다
        cp -p "$reviews/.$m.bak.$$" "$reviews/$m" 2>/dev/null || keep="$keep $m"
      elif [ "$m" != "$name" ]; then
        rm -f "$reviews/$m" 2>/dev/null
      fi
    done
    _cleanup "$keep"; exit 0
  fi
  moved="$moved $name"
  saved="$saved
- .specops/$fid/reviews/$name"
done
_cleanup
[ -n "$saved" ] || exit 0

cat >&2 <<EOF
리뷰 보고서 전문을 저장했다:$saved

이제 부모에게 돌려줄 요약만 출력하고 끝내라. 보고서 본문을 다시 쓰지 말고 300토큰 이내로:
판정: <tid·phase 별 verdict>
Critical: <항목 1줄씩, 없으면 없음>
Important: <항목 1줄씩, 없으면 없음>
저장: <위 경로>
EOF
exit 2
