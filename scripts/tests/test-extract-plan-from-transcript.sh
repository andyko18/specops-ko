#!/usr/bin/env bash
# test-extract-plan-from-transcript.sh — plan 추출기 계약 (FID 20260820-plan-mode-prd-source)
# 실 ~/.claude 미접근 — fixture transcript + 가짜 HOME 격리로 결정적 검증.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SCRIPT="$PLUGIN/scripts/_internal/extract-plan-from-transcript.sh"

command -v jq >/dev/null 2>&1 || { ok "T1 (SKIP — jq 미설치)"; finish; exit; }

TD=$(mktemp -d) || exit 1
trap 'rm -rf "$TD"' EXIT

# fixture 세계 구성: 가짜 HOME + cwd 슬러그 디렉토리
WORK="$TD/work"; mkdir -p "$WORK"
WORK_ABS=$(cd "$WORK" && pwd)
SLUG=$(printf '%s' "$WORK_ABS" | sed 's/[/.]/-/g')
FHOME="$TD/home"; TDIR="$FHOME/.claude/projects/$SLUG"; mkdir -p "$TDIR"

_run() { (cd "$WORK_ABS" && HOME="$FHOME" bash "$SCRIPT" "$@") ; }
_ts()  { jq -rn --argjson off "$1" 'now - $off | todateiso8601'; }   # $1=초 전
_plan_line() {  # $1=timestamp $2=plan 파일
  jq -nc --arg ts "$1" --rawfile plan "$2" \
    '{type:"assistant",timestamp:$ts,message:{content:[{type:"tool_use",name:"ExitPlanMode",input:{plan:$plan}}]}}'
}
_decoy_line() {  # 에이전트 도구 목록 문구 — grep 오탐 유발원
  jq -nc '{type:"assistant",timestamp:"2026-01-01T00:00:00Z",message:{content:[{type:"text",
    text:"- Explore: (Tools: All tools except Agent, Artifact, ExitPlanMode, Edit, Write, NotebookEdit)"}]}}'
}
_reset() { rm -f "$TDIR"/*.jsonl; }

# 기준 plan 본문 (바이트 비교 대조군)
printf '# 도메인 복제 기능\n\n## Context\n기존 도메인을 복사해 신규 등록한다.\n' > "$TD/p1.md"

# ── T1.a: 정상 추출 — exit 0 + stdout 바이트 동일 + stderr 출처 (AC-1) ──
_reset; { _plan_line "$(_ts 3600)" "$TD/p1.md"; } > "$TDIR/s1.jsonl"
_run > "$TD/out.md" 2> "$TD/err.txt"; rc=$?
cmp -s "$TD/out.md" "$TD/p1.md"; same=$?          # if 조건 안에서 잡으면 $? 가 뭉개진다
if [ "$rc" -eq 0 ] && [ "$same" -eq 0 ] && grep -q '^PLAN-SOURCE:' "$TD/err.txt"; then
  ok "T1.a 정상 추출 — exit 0 · stdout 바이트 동일 · PLAN-SOURCE"
else
  nope "T1.a" "rc=$rc cmp=$same err=$(head -1 "$TD/err.txt")"
fi

# ── T1.b: 오탐 차단 — decoy 만 있으면 exit 1 (AC-2, 핵심) ──
_reset; { _decoy_line; } > "$TDIR/s1.jsonl"
out=$(_run 2>/dev/null); rc=$?
grep_hits=$(grep -c 'ExitPlanMode' "$TDIR/s1.jsonl")
if [ "$rc" -eq 1 ] && [ -z "$out" ] && [ "$grep_hits" -ge 1 ]; then
  ok "T1.b 오탐 차단 — grep 은 ${grep_hits}건 매칭하나 추출은 exit 1"
else
  nope "T1.b" "rc=$rc out_len=${#out} grep=$grep_hits (grep 구현이면 여기서 통과해버린다)"
fi

# ── T1.c: 시간 창 초과 → exit 1 (AC-3) ──
_reset; { _plan_line "$(_ts 360000)" "$TD/p1.md"; } > "$TDIR/s1.jsonl"   # 100시간 전
_run >/dev/null 2>&1; rc_over=$?
_run --max-age-hours 200 >/dev/null 2>&1; rc_wide=$?
if [ "$rc_over" -eq 1 ] && [ "$rc_wide" -eq 0 ]; then
  ok "T1.c 시간 창 판정 — 기본 초과=1, --max-age-hours 200=0 (창이 실제로 쓰인다)"
else
  nope "T1.c" "over=$rc_over wide=$rc_wide"
fi

# ── T1.d: 복수 plan → 최신 1건 (AC-4) ──
printf '# 예전 플랜\n' > "$TD/old.md"
_reset
{ _plan_line "$(_ts 7200)" "$TD/old.md"; _plan_line "$(_ts 3600)" "$TD/p1.md"; } > "$TDIR/s1.jsonl"
out=$(_run 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '도메인 복제' && ! printf '%s' "$out" | grep -q '예전 플랜'; then
  ok "T1.d 복수 plan — 최신 1건만 (이전 plan 미노출)"
else
  nope "T1.d" "rc=$rc out_head=$(printf '%s' "$out" | head -1)"
fi

# ── T1.e: 파일 간 전역 최신 선택 (A4 — mtime 순서와 무관) ──
_reset
{ _plan_line "$(_ts 3600)" "$TD/p1.md"; }  > "$TDIR/older-mtime.jsonl"
{ _plan_line "$(_ts 7200)" "$TD/old.md"; } > "$TDIR/newer-mtime.jsonl"   # 나중 생성 = mtime 최신, plan 은 더 오래됨
out=$(_run 2>/dev/null); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '도메인 복제'; then
  ok "T1.e 전역 최신 선택 — mtime 최신 파일의 오래된 plan 을 고르지 않는다"
else
  nope "T1.e" "rc=$rc out_head=$(printf '%s' "$out" | head -1) (mtime 순 첫 발견 구현이면 실패)"
fi

# ── T1.f: 부재 경로 graceful (AC-5) ──
_reset
_run >/dev/null 2>&1; rc_empty=$?                       # jsonl 0건
rm -rf "$TDIR"
_run >/dev/null 2>&1; rc_nodir=$?                       # 디렉토리 부재
mkdir -p "$TDIR"
if [ "$rc_empty" -eq 1 ] && [ "$rc_nodir" -eq 1 ]; then
  ok "T1.f 부재 graceful — jsonl 0건=1, 디렉토리 부재=1"
else
  nope "T1.f" "empty=$rc_empty nodir=$rc_nodir"
fi

# ── T1.g: 빈 plan 제외 + 제목 표기 (AC-7, AC-8) ──
printf '   \n  \n' > "$TD/blank.md"
_reset
{ _plan_line "$(_ts 3600)" "$TD/p1.md"; _plan_line "$(_ts 60)" "$TD/blank.md"; } > "$TDIR/s1.jsonl"
out=$(_run 2> "$TD/err.txt"); rc=$?
# 제목은 fixture 에서 파생한다 — 하드코딩하면 fixture 를 고칠 때 어서션이 조용히 낡는다
want_title=$(head -1 "$TD/p1.md")
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '도메인 복제' \
   && grep -qxF "PLAN-TITLE: $want_title" "$TD/err.txt"; then
  ok "T1.g 빈 plan 제외(최신이어도) + PLAN-TITLE 표기"
else
  nope "T1.g" "rc=$rc want='$want_title' got=$(grep '^PLAN-TITLE' "$TD/err.txt")"
fi

# 빈 plan 만 있으면 exit 1
_reset; { _plan_line "$(_ts 60)" "$TD/blank.md"; } > "$TDIR/s1.jsonl"
_run >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] && ok "T1.g2 빈 plan 단독 → exit 1" || nope "T1.g2" "rc=$rc"

# ── T1.h: jq 부재 → exit 2 (AC-5) ──
# ★ PATH=/usr/bin:/bin 로는 안 벗겨진다 — 이 머신 jq 는 /usr/bin/jq 다(실측).
#   빈 디렉토리만 PATH 에 두고 bash 는 절대경로로 부른다(그러지 않으면 bash 자체를 못 찾는다).
_reset; { _plan_line "$(_ts 3600)" "$TD/p1.md"; } > "$TDIR/s1.jsonl"
mkdir -p "$TD/nobin"
(cd "$WORK_ABS" && env -i PATH="$TD/nobin" HOME="$FHOME" /bin/bash "$SCRIPT") >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "T1.h jq 부재 → exit 2" || nope "T1.h" "rc=$rc"

# ── T1.i: 잘못된 시간 창 → 기본값 fallback + 경고 (AC-9) ──
_reset; { _plan_line "$(_ts 3600)" "$TD/p1.md"; } > "$TDIR/s1.jsonl"
out=$( (cd "$WORK_ABS" && HOME="$FHOME" SPECOPS_PLAN_MAX_AGE_HOURS=abc bash "$SCRIPT") 2> "$TD/err.txt" ); rc=$?
rc_neg=$( (cd "$WORK_ABS" && HOME="$FHOME" SPECOPS_PLAN_MAX_AGE_HOURS=-5 bash "$SCRIPT") >/dev/null 2>&1; echo $? )
if [ "$rc" -eq 0 ] && [ "$rc_neg" -eq 0 ] && grep -qi '시간 창' "$TD/err.txt"; then
  ok "T1.i 잘못된 창(abc·-5) → 기본 24 fallback + 경고"
else
  nope "T1.i" "rc=$rc neg=$rc_neg warn=$(grep -i '시간 창' "$TD/err.txt")"
fi

# ── T1.j: read-only — transcript 미변경 (AC-5) ──
# 주의: RED 단계에선 스크립트가 실행되지 않아 공허 통과한다. GREEN 에서만 의미가 있다.
_reset; { _plan_line "$(_ts 3600)" "$TD/p1.md"; } > "$TDIR/s1.jsonl"
before=$(shasum "$TDIR/s1.jsonl" | awk '{print $1}')
_run >/dev/null 2>&1
after=$(shasum "$TDIR/s1.jsonl" | awk '{print $1}')
[ "$before" = "$after" ] && ok "T1.j read-only — transcript 무변경" || nope "T1.j" "sha 변경됨"

# ── T1.k: init-project Phase 0 배선 상시 잠금 (AC-6) ──
# T3 Step 3 의 grep/awk 는 1회성 수동 확인이라 run-all 에 남지 않는다 — 이후 편집이 0-b2 를
# 지워도 아무도 못 잡는다. test-doc-stamp-sync.sh 가 문서 계약을 상시 grep 으로 잠그는 선례를 따른다.
IP="$PLUGIN/commands/init-project.md"
wired=$(grep -c 'extract-plan-from-transcript' "$IP" 2>/dev/null || true)
# 종료 앵커는 bullet 제목까지 붙여 좁힌다 — '/0-c\./' 만 쓰면 0-b2 본문에 '0-c.' 가
# 한 번이라도 들어가는 순간 범위가 조기 종결돼 배선이 있어도 FAIL 한다(외부 critic 지적)
slot=$(awk '/0-b\. 브레인스토밍/,/0-c\. 기존 기획/' "$IP" 2>/dev/null | grep -c '0-b2' || true)
if [ "${wired:-0}" -ge 1 ] && [ "${slot:-0}" -ge 1 ]; then
  ok "T1.k init-project Phase 0 배선 — 스크립트 참조 + 0-b/0-c 사이 0-b2"
else
  nope "T1.k" "wired=$wired slot=$slot (0-b2 슬롯이 0-b·0-c 사이에 있어야 한다)"
fi

finish
