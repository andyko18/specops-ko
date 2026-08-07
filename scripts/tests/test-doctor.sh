#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SH="$PLUGIN/scripts/doctor.sh"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

_mkrepo() {  # $1=repo 경로 — git init + .specops 생성
  mkdir -p "$1/.specops"
  git -C "$1" init -q 2>/dev/null
  git -C "$1" config user.email t@t.io; git -C "$1" config user.name t
}
_hooks_ok() {  # $1=repo — 2단 hook 완비
  mkdir -p "$1/.githooks"
  printf '#!/bin/sh\nexit 0\n' > "$1/.githooks/pre-commit"
  printf '#!/bin/sh\nexit 0\n' > "$1/.githooks/pre-push"
  chmod +x "$1/.githooks/pre-commit" "$1/.githooks/pre-push"
  git -C "$1" config core.hooksPath .githooks
}
_run() { _OUT=$(cd "$1" && SPECOPS_ROOT=".specops" bash "$SH" "${@:2}" 2>&1); _RC=$?; }

# T1 (AC-1): hooksPath 미설정 → git hook ⚠️ + 조치 명령
R="$TMP/r1"; _mkrepo "$R"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| git_hooks ' | grep -q '⚠️' \
  && printf '%s' "$_OUT" | grep -q 'install-git-hooks.sh' \
  && ok "T1 hook 미설치 → ⚠️ + 조치" || nope "T1" "out=$_OUT"

# T2 (AC-2): 2단 hook 완비 → ✅
R="$TMP/r2"; _mkrepo "$R"; _hooks_ok "$R"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| git_hooks ' | grep -q '✅' \
  && ok "T2 hook 완비 → ✅" || nope "T2" "out=$_OUT"

# T12 (AC-12): pre-push 만 누락 → ⚠️ + pre-push 지목
R="$TMP/r12"; _mkrepo "$R"; _hooks_ok "$R"; rm -f "$R/.githooks/pre-push"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| git_hooks ' | grep -q '⚠️' \
  && printf '%s' "$_OUT" | grep -q 'pre-push' \
  && ok "T12 pre-push 누락 검출" || nope "T12" "out=$_OUT"

# T3 (AC-3): memory 에 placeholder 잔존 → ⚠️
R="$TMP/r3"; _mkrepo "$R"; mkdir -p "$R/.specops/memory"
printf '# IF 설계서\n\n- **버전**: <버전>\n' > "$R/.specops/memory/api-spec.md"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| memory ' | grep -q '⚠️' \
  && ok "T3 memory placeholder 검출" || nope "T3" "out=$_OUT"

# T3b (AC-3): 판정은 scan-enrich-placeholders.sh 호출로 재사용 — 중복 로직 금지
grep -q 'scan-enrich-placeholders\.sh' "$SH" \
  && ok "T3b scan-enrich-placeholders 재사용 배선" \
  || nope "T3b" "doctor.sh 내부 중복 판정 로직 — 드리프트 위험"

# T4 (AC-4): spec 만 있고 tasks·evidence 없는 FID 2건 → ⚠️ 2건 + 이름 노출
R="$TMP/r4"; _mkrepo "$R"
for f in 20260101-alpha 20260102-beta; do
  mkdir -p "$R/.specops/$f"; printf '# spec\n' > "$R/.specops/$f/spec.md"
done
mkdir -p "$R/.specops/20260103-done"
printf '# spec\n' > "$R/.specops/20260103-done/spec.md"
printf '# tasks\n' > "$R/.specops/20260103-done/tasks.md"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| orphan_fid ' | grep -q '2건' \
  && printf '%s' "$_OUT" | grep -q '20260101-alpha' \
  && ok "T4 고아 FID 2건 검출 + 이름" || nope "T4" "out=$_OUT"

# T5 (AC-5): /verify PASS 기록인데 evidence.md 부재 → ⚠️ + FID 지목
R="$TMP/r5"; _mkrepo "$R"
mkdir -p "$R/.specops/20260201-gap"
printf '# spec\n' > "$R/.specops/20260201-gap/spec.md"
printf '# tasks\n' > "$R/.specops/20260201-gap/tasks.md"
printf '# Session Progress\n\n## 20260201-gap\n\n- 2026-02-01 10:00 /verify PASS\n' \
  > "$R/.specops/session-progress.md"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| progress ' | grep -q '⚠️' \
  && printf '%s' "$_OUT" | grep -q '20260201-gap' \
  && ok "T5 progress 불일치 검출" || nope "T5" "out=$_OUT"

# T6 (AC-6): 최악 상태(4항목 전부 ⚠️)에서도 exit 0
# 픽스처가 Given 을 실제로 재현해야 한다 — 고아 FID 가 없으면 orphan_fid 가 ✅ 라 4항목 ⚠️ 가 아니다.
R="$TMP/r6"; _mkrepo "$R"
mkdir -p "$R/.specops/20260101-orphan"; printf '# spec\n' > "$R/.specops/20260101-orphan/spec.md"
mkdir -p "$R/.specops/memory"; printf '# doc\n\n- **버전**: <버전>\n' > "$R/.specops/memory/x.md"
printf '# Session Progress\n\n## 20260101-orphan\n\n- 2026-01-01 10:00 /verify PASS\n' \
  > "$R/.specops/session-progress.md"
_run "$R"
# 픽스처 재현과 본 단언을 **한 어서션**으로 묶는다 — 분리하면 미재현 시 총 개수가 12→13 으로 흔들린다.
warns=$(printf '%s' "$_OUT" | grep -c '⚠️')
[ "$_RC" -eq 0 ] && [ "${warns:-0}" -eq 4 ] \
  && ok "T6 4항목 전부 ⚠️ 인 최악 상태에서도 exit 0" || nope "T6" "rc=$_RC warns=$warns"

# T7 (AC-7): .specops 부재 → 안내 + exit 0
R="$TMP/r7"; mkdir -p "$R"; git -C "$R" init -q 2>/dev/null
_run "$R"
[ "$_RC" -eq 0 ] && printf '%s' "$_OUT" | grep -q 'specops 미사용' \
  && ok "T7 비-specops repo 면제" || nope "T7" "rc=$_RC out=$_OUT"

# T8 (AC-8): --json 4항목 status
R="$TMP/r8"; _mkrepo "$R"
_OUT=$(cd "$R" && SPECOPS_ROOT=".specops" bash "$SH" --json 2>&1); _RC=$?
if [ "$_RC" -eq 0 ] && printf '%s' "$_OUT" | jq -e '(.checks|length)==4 and all(.checks[]; has("status"))' >/dev/null 2>&1; then
  ok "T8 --json 스키마"
else
  nope "T8" "rc=$_RC out=$_OUT"
fi

# T9 (AC-9): read-only — 실행 전후 파일 스냅샷 동일
R="$TMP/r9"; _mkrepo "$R"; mkdir -p "$R/.specops/20260101-x"
printf '# spec\n' > "$R/.specops/20260101-x/spec.md"
_snap() {  # $1=repo → 파일별 **내용** 해시. 목록만 해시하면 in-place 수정을 놓친다(리뷰 지적).
  #   `A || cd B && C` 는 (A||B)&&C 로 파싱돼 macOS 에서 두 해시기가 모두 실행된다(리뷰 실측)
  #   → command -v 분기로 명시한다.
  local h
  if command -v md5sum >/dev/null 2>&1; then h=md5sum; else h=md5; fi
  (cd "$1" && find . -not -path './.git/*' -type f | sort | xargs "$h" 2>/dev/null)
}
before=$(_snap "$R")
_run "$R"
after=$(_snap "$R")
[ "$before" = "$after" ] && ok "T9 read-only 보장" || nope "T9" "파일 변경 발생"

# T10 (AC-10): /doctor 슬래시 진입점 — frontmatter + 스크립트 호출 명시
CMD="$PLUGIN/commands/doctor.md"
if [ -f "$CMD" ] \
   && grep -q '^name: doctor' "$CMD" \
   && grep -q '^description:' "$CMD" \
   && grep -q 'scripts/doctor\.sh' "$CMD"; then
  ok "T10 /doctor 진입점"
else
  nope "T10" "commands/doctor.md 누락·필드 미비"
fi

# T11 (AC-11): 정상 상태에서도 4행 전부 출력
R="$TMP/r11"; _mkrepo "$R"; _hooks_ok "$R"
mkdir -p "$R/.specops/memory"; printf '# doc\n\n실제 내용\n' > "$R/.specops/memory/x.md"
printf '# Session Progress\n' > "$R/.specops/session-progress.md"
_run "$R"
rows=$(printf '%s' "$_OUT" | grep -cE '^\| (git_hooks|memory|orphan_fid|progress) ')
oks=$(printf '%s' "$_OUT" | grep -c '✅')
# AC-11 Then 은 2절이다 — "4행 출력" AND "각 행이 ✅". 행 수만 세면 ⚠️ 4행도 통과한다.
[ "${rows:-0}" -eq 4 ] && [ "${oks:-0}" -eq 4 ] \
  && ok "T11 정상 상태 4행 전부 ✅" || nope "T11" "rows=$rows oks=$oks out=$_OUT"

# ── Phase C 수습 (리뷰 T3-C / T4-C) ─────────────────────────────────────────

# T13 (Important 1 · 변이 M5): "/verify FAIL — PASSWORD" 오탐 금지
#   실측 근거: 실 repo session-progress.md 는 "/verify.*PASS" 113줄 = "/verify PASS" 113줄
#   (loose-only 0줄) — 패턴을 조여도 실데이터 검출력 손실이 없다.
#   이 픽스처는 변이 M5(패턴에서 "/verify" 삭제 → *PASS*)도 함께 격추한다.
R="$TMP/r13"; _mkrepo "$R"
mkdir -p "$R/.specops/20260302-falsepos"
printf '# spec\n' > "$R/.specops/20260302-falsepos/spec.md"
printf '# tasks\n' > "$R/.specops/20260302-falsepos/tasks.md"
printf '# Session Progress\n\n## 20260302-falsepos\n\n- 2026-03-02 11:00 /verify FAIL — PASSWORD 마스킹 회귀\n' \
  > "$R/.specops/session-progress.md"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| progress ' | grep -q '✅' \
  && ! printf '%s' "$_OUT" | grep -q '20260302-falsepos' \
  && ok "T13 /verify FAIL — PASSWORD 는 불일치 아님 (부분문자열 오탐 차단)" \
  || nope "T13" "out=$_OUT"

# T14 (Important 2): 디렉토리명의 파이프가 표·JSON 필드를 밀지 못한다
#   --json 은 schema_version 있는 기계 계약 — fix 필드 오염은 소비자 오동작.
R="$TMP/r14"; _mkrepo "$R"
mkdir -p "$R/.specops/20260401-a|b|c"; printf '# spec\n' > "$R/.specops/20260401-a|b|c/spec.md"
_OUT=$(cd "$R" && SPECOPS_ROOT=".specops" bash "$SH" --json 2>&1); _RC=$?
if [ "$_RC" -eq 0 ] && printf '%s' "$_OUT" \
   | jq -e '(.checks|length)==4
            and ((.checks[]|select(.id=="orphan_fid")|.fix)=="진행하거나 정리하세요")' >/dev/null 2>&1; then
  ok "T14 파이프 인젝션에도 JSON 필드 정합 유지 (fix 문구 무손실)"
else
  nope "T14" "rc=$_RC out=$_OUT"
fi

# T14b (Important 2 동일 근원): 디렉토리명의 개행이 행 자체를 위조하지 못한다
NLDIR=$(printf '20260402-x\ny')
R="$TMP/r14b"; _mkrepo "$R"
mkdir -p "$R/.specops/$NLDIR"; printf '# spec\n' > "$R/.specops/$NLDIR/spec.md"
_OUT=$(cd "$R" && SPECOPS_ROOT=".specops" bash "$SH" --json 2>&1); _RC=$?
# 행 수만 세면 mkdir 실패로 픽스처가 재현 안 돼도 4행이라 헛통과한다 — 고아 검출까지 함께 고정.
if [ "$_RC" -eq 0 ] && printf '%s' "$_OUT" \
   | jq -e '(.checks|length)==4
            and ((.checks[]|select(.id=="orphan_fid")|.status)=="warn")
            and ((.checks[]|select(.id=="orphan_fid")|.detail)|test("20260402-x"))' >/dev/null 2>&1; then
  ok "T14b 개행 포함 FID 에도 행 위조 없음 (checks 4행 고정)"
else
  nope "T14b" "rc=$_RC out=$_OUT"
fi

# T8b (Important 3 · 변이 M2): warn_count 가 실제 ⚠️ 개수와 일치
#   픽스처: git_hooks=warn · memory=unknown · orphan_fid=ok · progress=unknown → 3
R="$TMP/r8b"; _mkrepo "$R"
_run "$R"                                   # 표 렌더 — ⚠️ 실개수
warns8=$(printf '%s' "$_OUT" | grep -c '⚠️')
wc8=$(cd "$R" && SPECOPS_ROOT=".specops" bash "$SH" --json 2>&1 | jq -r '.warn_count' 2>/dev/null)
[ "${wc8:-x}" = "3" ] && [ "${wc8:-x}" = "${warns8:-0}" ] \
  && ok "T8b --json warn_count == 표 ⚠️ 개수 (3)" || nope "T8b" "warn_count=$wc8 warns=$warns8"

# T16 (Minor 4): "## ../../outside-fid" 헤더가 .specops 밖을 프로브하지 않는다
R="$TMP/r16"; _mkrepo "$R"
printf '# Session Progress\n\n## ../../outside-fid\n\n- 2026-03-03 10:00 /verify PASS\n' \
  > "$R/.specops/session-progress.md"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| progress ' | grep -q '✅' \
  && ! printf '%s' "$_OUT" | grep -q 'outside-fid' \
  && ok "T16 경로 이탈 FID 헤더 무시" || nope "T16" "out=$_OUT"

# T17 (Minor 5 · 변이 M3): unknown 상태는 ⚠️ 로 렌더된다
#   git repo 아닌 디렉터리 → git_hooks=unknown. JSON status 도 함께 고정해야
#   (환경이 git repo 로 바뀌어 warn 이 돼도) 단언이 헛통과하지 않는다.
R="$TMP/r17"; mkdir -p "$R/.specops"
_OUT=$(cd "$R" && SPECOPS_ROOT=".specops" bash "$SH" --json 2>&1)
json_unknown=0
printf '%s' "$_OUT" | jq -e '(.checks[]|select(.id=="git_hooks")|.status)=="unknown"' >/dev/null 2>&1 \
  && json_unknown=1
_run "$R"
[ "$json_unknown" -eq 1 ] \
  && printf '%s' "$_OUT" | grep -E '^\| git_hooks ' | grep -q '⚠️' \
  && ok "T17 unknown → JSON status unknown + 표 ⚠️" || nope "T17" "json_unknown=$json_unknown out=$_OUT"

finish
