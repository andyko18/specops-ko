#!/usr/bin/env bash
# /quick-fix 경로 (FID 20261010-quick-fix-path) — 명세 없는 1-태스크 FID 의 범위 상한·리뷰·영수증.
#
# 왜 필요한가: "태스크 문서는 있고 명세는 없는 FID" 는 영수증만 유효하면 커밋이 열렸다 — 문서도 리뷰도 크기 상한도 없이.
#   실사용 0건이라 드러나지 않았을 뿐인 통로다. 그 통로를 quick 경로로 정식화하면서 범위·리뷰를 커밋 시점에 강제한다.
#   판정은 판정기 한 곳(quick-scope.sh)이 하고, 훅이 부르는 영수증 검사기와 봉인 스크립트가 같이 쓴다.
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
PASS=0; FAIL=0
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE   # 훅 환경에서 돌아도 픽스처가 실 저장소를 건드리지 않게

QS="$PLUGIN/scripts/_internal/quick-scope.sh"
F=20261010-q1
_SBS=""

# 격리 저장소 — 구현 1파일·테스트 1파일이 커밋돼 있고 .specops 가 있다(specops 관할)
_mk() {
  local sb; sb=$(mktemp -d) || return 1
  ( cd "$sb" && git init -q && git checkout -q -b work && mkdir -p src tests .specops \
      && printf 'echo v1\n' > src/a.sh \
      && printf '#!/usr/bin/env bash\ngrep -q v2 src/a.sh\n' > tests/t.sh \
      && git add src tests && git -c user.name=t -c user.email=t@e.com commit -qm init ) >/dev/null 2>&1 || return 1
  printf '%s' "$sb"
}
# 리뷰 보고서 — 저장 훅(save-review-report.sh)의 파일 규약 그대로: 통과가 아니면 feedback 을 함께 쓴다
_review() {  # <sb> <PASS|FAIL>
  mkdir -p "$1/.specops/$F/reviews"
  printf '# 코드 품질 리뷰\n' > "$1/.specops/$F/reviews/T1-C-report.md"
  [ "$2" = PASS ] || cp "$1/.specops/$F/reviews/T1-C-report.md" "$1/.specops/$F/reviews/T1-C-feedback.md"
}
_scope() { ( cd "$1" && bash "$QS" "$F" T1 2>&1 ); }                       # <sb> → 판정 줄 · rc
_n() { local i=0; while [ "$i" -lt "$1" ]; do echo "echo line$i"; i=$((i+1)); done; }   # <N> → N줄
# ── Q1 범위 안 — 판정기 ──────────────────────────────────────────────────────
sb=$(_mk); _SBS="$_SBS $sb"; mkdir -p "$sb/.specops/$F"
( cd "$sb" && printf 'echo v2\n' > src/a.sh && git add src/a.sh ); _review "$sb" PASS
out=$(_scope "$sb"); rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^QUICK-SCOPE: OK 구현 파일 1개 · 2줄' \
  && ok "Q1.a 구현 1파일·2줄 + 통과 리뷰 → OK" || nope "Q1.a" "rc=$rc out=$out"

# ── Q2 경계값 — 파일 수·줄 수, 테스트·문서 제외 (AC-2) ──────────────────────
( cd "$sb" && _n 10 > src/b.sh && git add src/b.sh ); _review "$sb" PASS      # 구현 2파일 · 2+10=12줄
out=$(_scope "$sb"); rc=$?
[ "$rc" = 0 ] && ok "Q2.a 구현 파일 2개(상한) → OK" || nope "Q2.a" "rc=$rc out=$out"
( cd "$sb" && _n 1 > src/inspect.sh && git add src/inspect.sh )                # 이름에 spec 이 든 **구현** 파일
out=$(_scope "$sb"); rc=$?
[ "$rc" = 3 ] && printf '%s' "$out" | grep -q 'OVER 구현 파일 3개 (상한 2개)' \
  && ok "Q2.b 구현 파일 3개 → OVER (inspect.sh 는 테스트가 아니다)" || nope "Q2.b" "rc=$rc out=$out"
( cd "$sb" && git rm -q --cached src/inspect.sh && rm -f src/inspect.sh && _n 18 > src/b.sh && git add src/b.sh ); _review "$sb" PASS   # 2+18=20줄
out=$(_scope "$sb"); rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '· 20줄' && ok "Q2.c 변경 20줄(상한) → OK" || nope "Q2.c" "rc=$rc out=$out"
( cd "$sb" && _n 19 > src/b.sh && git add src/b.sh )                           # 2+19=21줄
out=$(_scope "$sb"); rc=$?
[ "$rc" = 3 ] && printf '%s' "$out" | grep -q 'OVER 변경 21줄 (상한 20줄' \
  && ok "Q2.d 변경 21줄 → OVER" || nope "Q2.d" "rc=$rc out=$out"
( cd "$sb" && _n 18 > src/b.sh && _n 200 > tests/t_big.sh && _n 300 > NOTES.md && _n 50 > src/util_test.go \
    && git add src/b.sh tests/t_big.sh NOTES.md src/util_test.go ); _review "$sb" PASS
out=$(_scope "$sb"); rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '구현 파일 2개 · 20줄' \
  && ok "Q2.e 테스트(tests/ · *_test.go)·문서는 파일 수·줄 수에 넣지 않는다" || nope "Q2.e" "rc=$rc out=$out"

# ── Q3 고위험 신호 — 작아도 quick 이 아니다 (AC-2) ──────────────────────────
_sig() {  # <라벨> <기대 신호> <준비 명령(샌드박스 안에서 실행)>
  local s o r; s=$(_mk); _SBS="$_SBS $s"; mkdir -p "$s/.specops/$F"
  ( cd "$s" && eval "$3" ) >/dev/null 2>&1; _review "$s" PASS
  o=$(_scope "$s"); r=$?
  [ "$r" = 3 ] && printf '%s' "$o" | grep -q "OVER 고위험 신호:.*$2" && ok "$1" || nope "$1" "rc=$r out=$o"
}
_sig "Q3.a 경로에 auth → 고위험(auth)" 'auth' 'printf "echo x\n" > src/auth.sh && git add src/auth.sh'
_sig "Q3.b 변경 줄에 ALTER TABLE → 고위험(db_migration)" 'db_migration' 'printf "echo \"ALTER TABLE t ADD c int\"\n" > src/a.sh && git add src/a.sh'
_sig "Q3.c 화면 문서를 함께 고침 → 고위험(ui_if)" 'ui_if' 'mkdir -p screens && printf "<p>x</p>\n" > screens/list.html && printf "echo v2\n" > src/a.sh && git add screens src/a.sh'
_sig "Q3.d 플러그인 저장소의 훅 수정 → 고위험(plugin_runtime)" 'plugin_runtime' 'mkdir -p .claude-plugin hooks && printf "{}\n" > .claude-plugin/plugin.json && git add .claude-plugin && git -c user.name=t -c user.email=t@e.com commit -qm p && printf "echo h\n" > hooks/x.sh && git add hooks/x.sh'
_sig "Q3.g 스키마 정의 파일(schema.prisma)에 필드 한 줄 → 고위험(schema)" 'schema' 'mkdir -p prisma && printf "model U {\n  id Int\n}\n" > prisma/schema.prisma && git add prisma'
_sig "Q3.h .sql 의 ADD COLUMN(TABLE 키워드 없음) → 고위험(schema)" 'schema' 'mkdir -p db && printf "ADD COLUMN email text;\n" > db/001.sql && git add db'
_sig "Q3.i 한글 경로의 변경 줄에 ALTER TABLE → 고위험(db_migration) — 비ASCII 경로도 내용을 본다" 'db_migration' 'printf "echo \"ALTER TABLE t ADD c int\"\n" > src/한글.sh && git add src/한글.sh'
# 대조 — 변경하지 않은 줄(문맥)의 낱말은 신호가 아니다
sb2=$(_mk); _SBS="$_SBS $sb2"; mkdir -p "$sb2/.specops/$F"
( cd "$sb2" && printf '# permission 검사는 다른 곳에서 한다\necho v1\n' > src/a.sh && git add src/a.sh \
    && git -c user.name=t -c user.email=t@e.com commit -qm c && printf '# permission 검사는 다른 곳에서 한다\necho v2\n' > src/a.sh && git add src/a.sh ) >/dev/null 2>&1
_review "$sb2" PASS; out=$(_scope "$sb2"); rc=$?
[ "$rc" = 0 ] && ok "Q3.e 바뀌지 않은 줄의 낱말은 신호가 아니다(변경 줄만 본다)" || nope "Q3.e" "rc=$rc out=$out"
# 바이너리
sb3=$(_mk); _SBS="$_SBS $sb3"; mkdir -p "$sb3/.specops/$F"
( cd "$sb3" && printf '\000\001\002\003' > src/blob.bin && git add src/blob.bin ); _review "$sb3" PASS
out=$(_scope "$sb3"); rc=$?
[ "$rc" = 3 ] && printf '%s' "$out" | grep -q 'OVER 바이너리 파일 변경' && ok "Q3.f 바이너리 변경 → OVER (줄 수를 셀 수 없다)" || nope "Q3.f" "rc=$rc out=$out"

# ── Q4 리뷰 — 없음 · 불통과 · 수정보다 오래됨 (AC-3) ────────────────────────
sb=$(_mk); _SBS="$_SBS $sb"; mkdir -p "$sb/.specops/$F"
( cd "$sb" && printf 'echo v2\n' > src/a.sh && git add src/a.sh )
out=$(_scope "$sb"); rc=$?
[ "$rc" = 4 ] && printf '%s' "$out" | grep -q 'NOREVIEW 리뷰 보고서가 없다' && ok "Q4.a 리뷰 보고서 없음 → NOREVIEW(4)" || nope "Q4.a" "rc=$rc out=$out"
_review "$sb" FAIL; out=$(_scope "$sb"); rc=$?
[ "$rc" = 4 ] && printf '%s' "$out" | grep -q 'NOREVIEW 마지막 리뷰 판정이 통과가 아니다' && ok "Q4.b 통과가 아닌 판정 → NOREVIEW(4)" || nope "Q4.b" "rc=$rc out=$out"
touch -t 202001010000 "$sb/.specops/$F/reviews/T1-C-feedback.md"; _review "$sb" PASS   # 옛 불통과 뒤에 통과 판정이 새로 왔다
out=$(_scope "$sb"); rc=$?
[ "$rc" = 0 ] && ok "Q4.c 옛 feedback 이 남아 있어도 마지막 판정이 통과면 OK" || nope "Q4.c" "rc=$rc out=$out"
touch -t 201901010000 "$sb/.specops/$F/reviews/T1-C-feedback.md"                      # (feedback 은 report 보다 더 오래된 채로 둔다)
touch -t 202001010000 "$sb/.specops/$F/reviews/T1-C-report.md"                        # 리뷰가 수정보다 오래됐다
out=$(_scope "$sb"); rc=$?
[ "$rc" = 4 ] && printf '%s' "$out" | grep -q 'NOREVIEW 리뷰 뒤에 src/a.sh 가 다시 수정됐다' \
  && ok "Q4.d 리뷰 뒤에 코드를 다시 고침 → NOREVIEW(4)" || nope "Q4.d" "rc=$rc out=$out"
# 한글 경로도 신선도를 본다 — git 의 경로 이스케이프 때문에 파일을 못 찾아 비교를 건너뛰면 안 된다
sbk=$(_mk); _SBS="$_SBS $sbk"; mkdir -p "$sbk/.specops/$F"
( cd "$sbk" && printf 'echo k\n' > src/한글.sh && git add src/한글.sh ); _review "$sbk" PASS
touch -t 202001010000 "$sbk/.specops/$F/reviews/T1-C-report.md"
out=$(_scope "$sbk"); rc=$?
[ "$rc" = 4 ] && printf '%s' "$out" | grep -q 'NOREVIEW 리뷰 뒤에 src/한글.sh 가 다시 수정됐다' \
  && ok "Q4.g 한글 경로 — 리뷰 뒤 수정을 놓치지 않는다" || nope "Q4.g" "rc=$rc out=$out"
# 범위와 리뷰가 둘 다 걸리면 범위를 먼저 말한다(리뷰를 받아도 소용없으므로)
( cd "$sb" && _n 30 > src/a.sh && git add src/a.sh ); out=$(_scope "$sb"); rc=$?
[ "$rc" = 3 ] && ok "Q4.e 범위 초과 + 리뷰 미충족 → 범위 초과(3)를 먼저 말한다" || nope "Q4.e" "rc=$rc out=$out"
exp=$(cd "$sb" && bash "$QS" "$F" T1 --explain 2>/dev/null)
[ "$exp" = "변경 31줄 (상한 20줄 · 테스트·문서 제외)" ] && ok "Q4.f --explain 은 접두 없이 사유만 낸다" || nope "Q4.f" "out=$exp"

# ── Q5 판정 불가는 막는 쪽이다 (NFR-3) ──────────────────────────────────────
sbn=$(_mk); _SBS="$_SBS $sbn"; mkdir -p "$sbn/.specops/$F"; _review "$sbn" PASS
out=$(_scope "$sbn"); rc=$?
[ "$rc" = 3 ] && printf '%s' "$out" | grep -q 'OVER 판정 불가 — 스테이징된 변경이 없다' \
  && ok "Q5.a 스테이징된 변경이 없으면 판정 불가 → 3 (통과가 아니다)" || nope "Q5.a" "rc=$rc out=$out"
nog=$(mktemp -d); _SBS="$_SBS $nog"            # 임시 폴더가 어떤 저장소 안에 있어도 위로 올라가 찾지 않게 한다
out=$(cd "$nog" && GIT_CEILING_DIRECTORIES="$(dirname "$nog")" bash "$QS" "$F" T1 2>&1); rc=$?
[ "$rc" = 3 ] && printf '%s' "$out" | grep -q 'OVER 판정 불가 — git 저장소가 아니다' \
  && ok "Q5.b git 저장소 밖 → 판정 불가 → 3" || nope "Q5.b" "rc=$rc out=$out"

# shellcheck disable=SC2086
rm -rf $_SBS
echo ""
finish
