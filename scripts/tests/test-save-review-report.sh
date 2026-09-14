#!/usr/bin/env bash
# test-save-review-report — SubagentStop 리뷰 저장 훅 (AC-1~5·9~11) + hooks.json 배선 (AC-6)
# FID 20260914-review-return-summary
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "FATAL: jq 필요" >&2; exit 1; }
HOOK="$PLUGIN/hooks/save-review-report.sh"
# 전용 루트 아래에 작업 디렉토리를 둔다 — T1.g 가 $TD 상위 목록을 비교하므로 상위가 공유 $TMPDIR 이면 동시 실행 프로세스 때문에 오탐한다
TDROOT=$(mktemp -d); TD="$TDROOT/w"; mkdir -p "$TD"; trap 'rm -rf "$TDROOT"' EXIT
FID=20260914-demo
R="$TD/.specops/$FID/reviews"

_reset() { rm -rf "$TD/.specops"; mkdir -p "$R"; }
# $1=tid $2=phase $3=verdict $4=body
_block() { printf '<<<REVIEW fid=%s tid=%s phase=%s verdict=%s>>>\n%s\n<<<END>>>\n' "$FID" "$1" "$2" "$3" "$4"; }
# $1=message $2=true|false → RC, ERR
_run() {
  local json
  json=$(jq -n --arg cwd "$TD" --arg m "$1" --argjson a "$2" \
    '{hook_event_name:"SubagentStop",agent_type:"specops-ko:code-reviewer-ko",cwd:$cwd,stop_hook_active:$a,last_assistant_message:$m}')
  ERR=$(printf '%s' "$json" | env -u SPECOPS_GOVERNANCE_PROFILE PATH="${RUN_PATH:-$PATH}" SPECOPS_CONFIG="$TD/none.yaml" bash "$HOOK" 2>&1 >/dev/null)
  RC=$?
}
_files() { (cd "$TD" && find . -type f | LC_ALL=C sort); }
_leftover() { ls -A "$R" | grep -E '\.(tmp|bak)\.' ; }  # 이번 실행의 임시·백업 파일 잔존

# ── T1.a AC-1 다중 tid 분할 저장 ──
_reset
msg="요약 전 전문
$(_block T1 C READY_TO_MERGE '# T1 본문
## 🔴 Critical
없음')
$(_block T2 C READY_TO_MERGE '# T2 본문')
$(_block T3 C READY_TO_MERGE '# T3 본문')"
_run "$msg" false
if [ "$(cat "$R/T1-C-report.md" 2>/dev/null)" = "$(printf '# T1 본문\n## 🔴 Critical\n없음')" ] \
   && [ "$(cat "$R/T2-C-report.md" 2>/dev/null)" = "# T2 본문" ] \
   && [ "$(cat "$R/T3-C-report.md" 2>/dev/null)" = "# T3 본문" ]; then
  ok "T1.a AC-1 tid 3개 분할 저장 · 본문 혼입 0"
else nope "T1.a AC-1" "rc=$RC $(ls "$R" 2>/dev/null | tr '\n' ' ')"; fi
if ! ls "$R"/*-feedback.md >/dev/null 2>&1; then ok "T1.b AC-1 통과 판정 → feedback 미생성"
else nope "T1.b AC-1" "feedback 생성됨"; fi

# ── T1.c AC-3 2단 종료 신호 (첫 실행 exit 2 + 경로·요약 지시) ──
if [ "$RC" -eq 2 ] && echo "$ERR" | grep -qF ".specops/$FID/reviews/T1-C-report.md" \
   && echo "$ERR" | grep -qF ".specops/$FID/reviews/T3-C-report.md" && echo "$ERR" | grep -qF "요약만 출력"; then
  ok "T1.c AC-3 exit 2 + 저장 경로 + 요약 지시"
else nope "T1.c AC-3" "rc=$RC err=$ERR"; fi

# ── T1.d AC-3 재발화(stop_hook_active=true) → exit 0 · 내용·mtime 불변 ──
before=$(cd "$R" && cksum *.md)
touch "$TD/stamp"; sleep 1
_run "$(_block T1 C NEEDS_FIX '다른 본문')" true
after=$(cd "$R" && cksum *.md)
newer=$(find "$R" -type f -newer "$TD/stamp")
if [ "$RC" -eq 0 ] && [ "$before" = "$after" ] && [ -z "$newer" ] && [ ! -f "$R/T1-C-feedback.md" ]; then
  ok "T1.d AC-3 stop_hook_active=true → exit 0 내용·mtime 불변"
else nope "T1.d AC-3" "rc=$RC"; fi

# ── T1.e AC-2 비통과 판정 feedback 병기 ──
_reset
_run "$(_block T2 B NEEDS_FIX '# B 지적')
$(_block T3 C NEEDS_DISCUSSION '# C 논의')" false
if [ "$RC" -eq 2 ] && cmp -s "$R/T2-B-report.md" "$R/T2-B-feedback.md" \
   && cmp -s "$R/T3-C-report.md" "$R/T3-C-feedback.md" && [ "$(cat "$R/T2-B-feedback.md")" = "# B 지적" ]; then
  ok "T1.e AC-2 NEEDS_FIX·NEEDS_DISCUSSION → report+feedback 동일 본문"
else nope "T1.e AC-2" "rc=$RC $(ls "$R" | tr '\n' ' ')"; fi

# ── T1.f AC-4 fail-open 4경우 (기존 파일 보존 · 신규 0) ──
_fail_open() {  # $1=desc $2=message $3=runner(선택: jq-less)
  _reset; printf 'X\n' > "$R/T1-C-report.md"; local pre; pre=$(_files)
  if [ "${3:-}" = "nojq" ]; then
    mkdir -p "$TD/bin"
    for t in cat dirname mktemp awk cp mv rm mkdir bash env; do ln -sf "$(command -v $t)" "$TD/bin/$t"; done
    json=$(jq -n --arg cwd "$TD" --arg m "$2" '{cwd:$cwd,stop_hook_active:false,last_assistant_message:$m}')
    ERR=$(printf '%s' "$json" | PATH="$TD/bin" SPECOPS_CONFIG="$TD/none.yaml" "$BASH" "$HOOK" 2>&1 >/dev/null); RC=$?
    rm -rf "$TD/bin"
  else
    _run "$2" false
  fi
  if [ "$RC" -eq 0 ] && [ "$(cat "$R/T1-C-report.md")" = "X" ] && [ "$(_files)" = "$pre" ]; then ok "$1"
  else nope "$1" "rc=$RC files=$(_files | tr '\n' ' ')"; fi
}
_fail_open "T1.f1 AC-4 마커 0개" "그냥 보고서 텍스트"
_fail_open "T1.f2 AC-4 END 없는 미완 블록" "$(printf '<<<REVIEW fid=%s tid=T1 phase=C verdict=READY_TO_MERGE>>>\n본문' "$FID")"
_fail_open "T1.f3 AC-4 jq 부재" "$(_block T1 C READY_TO_MERGE '본문')" nojq
_fail_open "T1.f4 AC-4 FID 디렉토리 부재" "$(printf '<<<REVIEW fid=20260101-nope tid=T1 phase=C verdict=READY_TO_MERGE>>>\n본문\n<<<END>>>')"

# ── T1.g AC-5 경로 안전 — 비정상 값은 전부 무생성 ──
for bad in 'fid=../../etc tid=T1 phase=C verdict=PASS' \
           "fid=$FID tid=T1/../x phase=C verdict=PASS" \
           "fid=$FID tid=T1a phase=C verdict=PASS" \
           "fid=$FID tid=T1 phase=D verdict=PASS" \
           "fid=$FID tid=T1 phase=C verdict=OK"; do
  # 이탈 목표가 실제로 존재해야 이빨이 선다 — 없으면 정규식이 없어도 디렉토리 검사·cp 실패가 대신 막는다
  #   fid=../../etc → $TD/.specops/../../etc = $TDROOT/etc · tid=T1/../x → 임시 $R/.T1/.. · 목적지 $R/T1/..
  _reset; mkdir -p "$TDROOT/etc" "$R/.T1" "$R/T1"
  up_pre=$(cd "$TDROOT" && find . -type f | LC_ALL=C sort)
  _run "$(printf '<<<REVIEW %s>>>\n본문\n<<<END>>>' "$bad")" false
  if [ "$RC" -eq 0 ] && [ "$(cd "$TDROOT" && find . -type f | LC_ALL=C sort)" = "$up_pre" ]; then ok "T1.g AC-5 거부: $bad"
  else nope "T1.g AC-5 $bad" "rc=$RC files=$(_files | tr '\n' ' ')"; fi
done
rm -rf "$TDROOT/etc"
_reset
_run "$(_block T1 B PASS '# B 통과')
$(_block T1 C READY_TO_MERGE '# C 통과')" false
if [ "$RC" -eq 2 ] && [ -f "$R/T1-B-report.md" ] && [ -f "$R/T1-C-report.md" ] && ! ls "$R"/*-feedback.md >/dev/null 2>&1; then
  ok "T1.h AC-5 정상 PASS·READY_TO_MERGE → report 만"
else nope "T1.h AC-5" "rc=$RC $(ls "$R" | tr '\n' ' ')"; fi

# ── T1.i AC-9 부분 유효 → 전부 포기 ──
_reset; printf 'X\n' > "$R/T1-C-report.md"; pre=$(_files)
_run "$(_block T1 C READY_TO_MERGE '새 T1')
$(_block T2 C READY_TO_MERGE '새 T2')
$(printf '<<<REVIEW fid=%s tid=T3 phase=C verdict=READY_TO_MERGE>>>\n끝 없음' "$FID")" false
if [ "$RC" -eq 0 ] && [ "$(cat "$R/T1-C-report.md")" = "X" ] && [ "$(_files)" = "$pre" ]; then
  ok "T1.i AC-9 블록 1개 오류 → 전체 무저장 exit 0"
else nope "T1.i AC-9" "rc=$RC files=$(_files | tr '\n' ' ')"; fi
_reset; pre=$(_files)
_run "$(_block T1 C READY_TO_MERGE '정상')
$(printf '<<<REVIEW fid=%s tid=T2 phase=C verdict=OK>>>\n본문\n<<<END>>>' "$FID")" false
if [ "$RC" -eq 0 ] && [ "$(_files)" = "$pre" ]; then ok "T1.j AC-9 허용값 밖 속성 섞임 → 전체 무저장"
else nope "T1.j AC-9" "rc=$RC"; fi

# ── T1.k AC-10 동일 tid·phase 중복 ──
_reset; pre=$(_files)
_run "$(_block T1 C READY_TO_MERGE '첫째')
$(_block T1 C READY_TO_MERGE '둘째')" false
if [ "$RC" -eq 0 ] && [ "$(_files)" = "$pre" ]; then ok "T1.k AC-10 중복 tid·phase → 무저장"
else nope "T1.k AC-10" "rc=$RC"; fi
_reset
_run "$(_block T1 B PASS 'B')
$(_block T1 C READY_TO_MERGE 'C')" false
if [ "$RC" -eq 2 ] && [ -f "$R/T1-B-report.md" ] && [ -f "$R/T1-C-report.md" ]; then ok "T1.l AC-10 같은 tid 다른 phase → 둘 다 저장"
else nope "T1.l AC-10" "rc=$RC"; fi

# ── T1.m AC-11 재리뷰 덮어쓰기 · feedback 보존 ──
_reset; printf 'A\n' > "$R/T2-C-report.md"; printf 'A\n' > "$R/T2-C-feedback.md"
_run "$(_block T2 C READY_TO_MERGE 'B')" false
if [ "$RC" -eq 2 ] && [ "$(cat "$R/T2-C-report.md")" = "B" ] && [ "$(cat "$R/T2-C-feedback.md")" = "A" ] \
   && [ -z "$(_leftover)" ]; then
  ok "T1.m AC-11 report 덮어쓰기 · 이전 feedback 보존 · 임시·백업 파일 잔존 0"
else nope "T1.m AC-11" "rc=$RC report=$(cat "$R/T2-C-report.md") $(ls -A "$R" | tr '\n' ' ')"; fi

# ── T1.n AC-9 2단계 이동 부분 실패 → 전부 되돌림 · exit 0 · stderr 없음 ──
# 이동 실패 주입: PATH 앞 가짜 mv (목적지가 *-C-report.md 일 때만 무음 실패) — chflags 는 macOS 전용
REALMV=$(command -v mv)
FAKEBIN=$(mktemp -d); trap 'rm -rf "$TDROOT" "$FAKEBIN"' EXIT
cat > "$FAKEBIN/mv" <<EOF
#!/usr/bin/env bash
for last in "\$@"; do :; done
case "\$last" in *-C-report.md) exit 1 ;; esac
exec "$REALMV" "\$@"
EOF
chmod +x "$FAKEBIN/mv"
_reset; printf 'OLD\n' > "$R/T1-C-report.md"; pre=$(_files)
RUN_PATH="$FAKEBIN:$PATH" _run "$(_block T1 C NEEDS_FIX 'NEW')" false
if [ "$RC" -eq 0 ] && [ -z "$ERR" ] && [ "$(cat "$R/T1-C-report.md")" = "OLD" ] && [ ! -e "$R/T1-C-feedback.md" ] \
   && [ "$(_files)" = "$pre" ] && [ -z "$(_leftover)" ]; then
  ok "T1.n1 AC-9 이동 실패 → 기존 report 보존 · feedback 미생성 · 임시·백업 잔존 0"
else nope "T1.n1 AC-9" "rc=$RC err=$ERR report=$(cat "$R/T1-C-report.md" 2>/dev/null) $(ls -A "$R" | tr '\n' ' ')"; fi
# 앞 블록 이동 성공 후 뒤 블록 실패 — 기존 파일은 백업에서 복원, 새로 생긴 파일은 제거
_reset; printf 'OLD-B\n' > "$R/T2-B-report.md"; pre=$(_files)
RUN_PATH="$FAKEBIN:$PATH" _run "$(_block T2 B NEEDS_FIX 'NEW-B')
$(_block T3 B PASS 'NEW-T3')
$(_block T1 C NEEDS_FIX 'NEW-C')" false
if [ "$RC" -eq 0 ] && [ -z "$ERR" ] && [ "$(cat "$R/T2-B-report.md")" = "OLD-B" ] \
   && [ ! -e "$R/T2-B-feedback.md" ] && [ ! -e "$R/T3-B-report.md" ] && [ "$(_files)" = "$pre" ] && [ -z "$(_leftover)" ]; then
  ok "T1.n2 AC-9 뒤 블록 이동 실패 → 옮긴 파일 복원(기존)·제거(신규) · 잔존 0"
else nope "T1.n2 AC-9" "rc=$RC err=$ERR files=$(_files | tr '\n' ' ') $(ls -A "$R" | tr '\n' ' ')"; fi

# ── T1.o AC-9 공백만 있는 본문 → 전체 무저장 ──
_reset; pre=$(_files)
_run "$(_block T1 C READY_TO_MERGE 'ok')
$(printf '<<<REVIEW fid=%s tid=T2 phase=C verdict=NEEDS_FIX>>>\n   \n\t\n\n<<<END>>>' "$FID")" false
if [ "$RC" -eq 0 ] && [ "$(_files)" = "$pre" ]; then ok "T1.o AC-9 공백만 있는 본문 → 전체 무저장 exit 0"
else nope "T1.o AC-9" "rc=$RC files=$(_files | tr '\n' ' ')"; fi

# ── T1.p AC-9 대상 경로가 일반 파일 아님(디렉토리) → 전체 무저장 · 거짓 보고 없음 ──
_reset; mkdir -p "$R/T2-C-report.md"; pre=$(cd "$TD" && find . | LC_ALL=C sort)
_run "$(_block T1 C READY_TO_MERGE 'T1')
$(_block T2 C READY_TO_MERGE 'T2')" false
if [ "$RC" -eq 0 ] && [ -z "$ERR" ] && [ "$(cd "$TD" && find . | LC_ALL=C sort)" = "$pre" ]; then
  ok "T1.p AC-9 대상이 디렉토리 → 전체 무저장 exit 0 · 저장 보고 없음"
else nope "T1.p AC-9" "rc=$RC err=$ERR tree=$(cd "$TD" && find . | tr '\n' ' ')"; fi

# ── T1.q AC-9 FID 혼합 → 전체 무저장 (두 FID 모두 실재 · tid 달리해 중복 검사와 분리) ──
FID2=20260914-other
_reset; mkdir -p "$TD/.specops/$FID2"; pre=$(cd "$TD" && find . | LC_ALL=C sort)
_run "$(_block T1 C READY_TO_MERGE 'A')
$(printf '<<<REVIEW fid=%s tid=T2 phase=C verdict=READY_TO_MERGE>>>\nB\n<<<END>>>' "$FID2")" false
if [ "$RC" -eq 0 ] && [ "$(cd "$TD" && find . | LC_ALL=C sort)" = "$pre" ]; then ok "T1.q AC-9 FID 혼합 → 전체 무저장 exit 0"
else nope "T1.q AC-9" "rc=$RC tree=$(cd "$TD" && find . | tr '\n' ' ')"; fi

# ── T2.a AC-6 hooks.json SubagentStop 배선 ──
HJ="$PLUGIN/hooks/hooks.json"
m=$(jq -r '.hooks.SubagentStop[0].matcher // empty' "$HJ")
c=$(jq -r '.hooks.SubagentStop[0].hooks[0].command // empty' "$HJ")
a=$(jq -r '.hooks.SubagentStop[0].hooks[0].async' "$HJ")
if [ "$m" = "specops-ko:spec-reviewer-ko|specops-ko:code-reviewer-ko" ]; then ok "T2.a AC-6 matcher = 네임스페이스 포함 두 리뷰어"
else nope "T2.a AC-6 matcher" "'$m'"; fi
if printf '%s' "$c" | grep -qF '${CLAUDE_PLUGIN_ROOT}/hooks/save-review-report.sh'; then ok "T2.b AC-6 command 경로"
else nope "T2.b AC-6 command" "'$c'"; fi
if [ "$a" = "false" ]; then ok "T2.c AC-6 async=false (stderr 가 서브에이전트에 닿아야 한다)"
else nope "T2.c AC-6 async" "'$a'"; fi
if [ "$(jq -r '.hooks.SubagentStop | length' "$HJ")" = "1" ]; then ok "T2.d AC-6 SubagentStop 항목 1개"
else nope "T2.d AC-6 항목 수"; fi

finish
