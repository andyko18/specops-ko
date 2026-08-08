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

# ─────────────────────────────────────────────────────────────
# T18~T26: progress 아카이브 분리 (FID 20260808-doctor-progress-archive)
#   판정 3분류 — 디렉터리 부재=아카이브 / 디렉터리 있음+evidence 부재=불일치 / 정상
#   ⚠️ T1~T17 은 건드리지 않는다 (AC-R-1 — diff 가 +N/-0 여야 한다)
# ─────────────────────────────────────────────────────────────

# T18 (AC-1): 디렉터리 자체가 없는 FID 는 불일치가 아니다 → ✅
R="$TMP/r18"; _mkrepo "$R"
printf '# Session Progress\n\n## 20260101-archived\n\n- 2026-01-01 10:00 /verify PASS\n' \
  > "$R/.specops/session-progress.md"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| progress ' | grep -q '✅' \
  && ! printf '%s' "$_OUT" | grep -E '^\| progress ' | grep -q '20260101-archived' \
  && ok "T18 아카이브 FID → ✅ · 미지목" || nope "T18" "out=$_OUT"

# T19 (AC-2): 디렉터리 있음 + evidence.md 부재 → 여전히 ⚠️ + 지목
#   (T5 와 같은 축이나, 아카이브 분기 도입 후에도 살아있음을 명시 고정한다)
R="$TMP/r19"; _mkrepo "$R"
mkdir -p "$R/.specops/20260202-real"; printf '# spec\n' > "$R/.specops/20260202-real/spec.md"
printf '# Session Progress\n\n## 20260202-real\n\n- 2026-02-02 10:00 /verify PASS\n' \
  > "$R/.specops/session-progress.md"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| progress ' | grep -q '⚠️' \
  && printf '%s' "$_OUT" | grep -q '20260202-real' \
  && ok "T19 dir 존재 + evidence 부재 → ⚠️ 유지" || nope "T19" "out=$_OUT"

# T21 (AC-5): 혼재 — 불일치가 아카이브에 가려지지 않는다
#   카운트는 dir-exists 만, 지목도 dir-exists 만, 아카이브 FID 이름은 안 나온다
R="$TMP/r21"; _mkrepo "$R"
mkdir -p "$R/.specops/20260202-real"; printf '# spec\n' > "$R/.specops/20260202-real/spec.md"
printf '# Session Progress\n\n## 20260101-archived\n\n- 2026-01-01 10:00 /verify PASS\n\n## 20260202-real\n\n- 2026-02-02 10:00 /verify PASS\n' \
  > "$R/.specops/session-progress.md"
_run "$R"
_row=$(printf '%s' "$_OUT" | grep -E '^\| progress ')
printf '%s' "$_row" | grep -q '⚠️' \
  && printf '%s' "$_row" | grep -q '1건 불일치' \
  && printf '%s' "$_row" | grep -q '20260202-real' \
  && ! printf '%s' "$_row" | grep -q '20260101-archived' \
  && printf '%s' "$_row" | grep -q '아카이브 1건' \
  && ok "T21 혼재 → 불일치 1건만 카운트·지목 + 아카이브 건수 표기" || nope "T21" "row=$_row"

# T20 (AC-3): 아카이브 건수가 ✅ 경로에도 명시된다
R="$TMP/r20"; _mkrepo "$R"
printf '# Session Progress\n\n## 20260101-a\n\n- 2026-01-01 10:00 /verify PASS\n\n## 20260101-b\n\n- 2026-01-01 11:00 /verify PASS\n' \
  > "$R/.specops/session-progress.md"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| progress ' | grep -q '✅' \
  && printf '%s' "$_OUT" | grep -E '^\| progress ' | grep -q '아카이브 2건 제외' \
  && ok "T20 ✅ 경로에 아카이브 건수 명시" || nope "T20" "out=$_OUT"

# T22 (AC-4): 아카이브 0건이면 그 문구가 아예 없다 (잡음 금지)
#   경고 포화를 고치면서 새 잡음을 만들지 않는다는 것이 이 FID 의 절반이다.
R="$TMP/r22"; _mkrepo "$R"
mkdir -p "$R/.specops/20260303-done"
printf '# spec\n' > "$R/.specops/20260303-done/spec.md"
printf '# evidence\n' > "$R/.specops/20260303-done/evidence.md"
printf '# Session Progress\n\n## 20260303-done\n\n- 2026-03-03 10:00 /verify PASS\n' \
  > "$R/.specops/session-progress.md"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| progress ' | grep -q '✅' \
  && ! printf '%s' "$_OUT" | grep -E '^\| progress ' | grep -q '아카이브' \
  && ok "T22 아카이브 0건 → 문구 없음" || nope "T22" "out=$_OUT"

# T26 (AC-3 하위 · dedup 대칭): 같은 FID 헤더가 두 번이어도 아카이브는 1건
#   기존 bad 는 dedup 하는데 arch 만 안 하면 건수가 부풀고, 그걸 잡는 어서션이 없다.
R="$TMP/r26"; _mkrepo "$R"
printf '# Session Progress\n\n## 20260101-dup\n\n- 2026-01-01 10:00 /verify PASS\n\n## 20260101-dup\n\n- 2026-01-02 10:00 /verify PASS\n' \
  > "$R/.specops/session-progress.md"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| progress ' | grep -q '아카이브 1건' \
  && ok "T26 중복 헤더 → 아카이브 dedup (1건)" || nope "T26" "out=$_OUT"

# T24 (AC-7): 판정 의미가 문서에 기술됐는가 — 계약서가 지정한 ID 다
grep -q '아카이브' "$PLUGIN/commands/doctor.md" \
  && ok "T24 doctor.md 에 아카이브 판정 기술" || nope "T24" "commands/doctor.md 아카이브 문구 부재"

# T25 (AC-10): 원 AC-5 승계 명시 + 원 FID 계약서 무수정
#   계약서 AC-10 의 두 번째 절("git diff 에 원 FID 경로 부재")은 .gitignore:5 가 .specops/* 를
#   통째로 제외해 **구조상 영원히 통과**한다(vacuous — plan §4.3 실측). 의도(원 FID 아티팩트
#   무수정)를 실제로 검증하는 형태로 읽는다 — 원 계약서에 승계 문구가 들어가지 않았음을 확인.
grep -q 'AC-5' "$PLUGIN/commands/doctor.md" && t25_doc=1 || t25_doc=0
_OLD_AC="$PLUGIN/.specops/20260807-specops-doctor/acceptance-criteria.md"
if [ -f "$_OLD_AC" ]; then
  grep -qE 'supersede|20260808' "$_OLD_AC" && t25_old=0 || t25_old=1
else
  t25_old=1   # .specops/* 는 gitignore — 신규 clone·CI 에는 없다 (GH-8 선례의 SKIP 동형)
fi
[ "$t25_doc" -eq 1 ] && [ "$t25_old" -eq 1 ] \
  && ok "T25 승계 명시 + 원 FID 계약서 무수정" \
  || nope "T25" "doc=$t25_doc old_untouched=$t25_old"

# T23 (AC-6): 아카이브 상태에서도 --json 스키마 불변 (checks 4건 · schema_version 1 · warn_count 정합)
R="$TMP/r23"; _mkrepo "$R"
mkdir -p "$R/.specops/20260202-real"; printf '# spec\n' > "$R/.specops/20260202-real/spec.md"
printf '# Session Progress\n\n## 20260101-archived\n\n- 2026-01-01 10:00 /verify PASS\n\n## 20260202-real\n\n- 2026-02-02 10:00 /verify PASS\n' \
  > "$R/.specops/session-progress.md"
_run "$R" --json
_n=$(printf '%s' "$_OUT" | jq -r '.checks|length' 2>/dev/null)
_sv=$(printf '%s' "$_OUT" | jq -r '.schema_version' 2>/dev/null)
_wc=$(printf '%s' "$_OUT" | jq -r '.warn_count' 2>/dev/null)
_actual=$(printf '%s' "$_OUT" | jq -r '[.checks[]|select(.status=="warn" or .status=="unknown")]|length' 2>/dev/null)
[ "$_n" = "4" ] && [ "$_sv" = "1" ] && [ "$_wc" = "$_actual" ] \
  && ok "T23 아카이브 상태에서 --json 스키마 불변 (checks=4 · warn_count=$_wc)" \
  || nope "T23" "n=$_n sv=$_sv wc=$_wc actual=$_actual"

# T27 (Phase C Important 2): CRLF 헤더에서도 dir 존재 판정이 어긋나지 않는다
#   `\r` 가 FID 문자열에 남으면 `[ -d ]` 가 실패해 **존재하는 dir 이 아카이브로 오분류**된다.
#   main 에서 ⚠️ 로 시끄럽던 진짜 결함이 ✅ 로 조용해지는 **실패 방향 반전** — 가장 위험한 형태다.
R="$TMP/r27"; _mkrepo "$R"
mkdir -p "$R/.specops/20260202-crlf"; printf '# spec\n' > "$R/.specops/20260202-crlf/spec.md"
printf '# Session Progress\r\n\r\n## 20260202-crlf\r\n\r\n- 2026-02-02 10:00 /verify PASS\r\n' \
  > "$R/.specops/session-progress.md"
_run "$R"
printf '%s' "$_OUT" | grep -E '^\| progress ' | grep -q '⚠️' \
  && printf '%s' "$_OUT" | grep -q '20260202-crlf' \
  && ok "T27 CRLF 헤더 → dir 존재 인식 유지 (아카이브 오분류 없음)" || nope "T27" "out=$_OUT"

finish
