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

# ── 훅 종단용 헬퍼 (B 절 이후가 쓴다) ────────────────────────────────────────
HOOK="$PLUGIN/hooks/pretool-governance.sh"
TR="$PLUGIN/scripts/tests/governance/fixtures/transcripts/pretool-no-verify.jsonl"   # 러너 실행 기록이 없는 transcript
[ -f "$TR" ] || { echo "FATAL: transcript 픽스처 부재 $TR" >&2; exit 1; }
MSG='git commit -m "fix: a (Task: T1)"'
_hook() {  # <sb> <커밋 명령> → ALLOW | DENY: <사유 전문>
  jq -nc --arg c "$2" --arg t "$TR" '{tool_name:"Bash", tool_input:{command:$c}, transcript_path:$t}' \
    | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" 2>/dev/null \
    | jq -r 'if .hookSpecificOutput.permissionDecision == "deny" then "DENY: " + .hookSpecificOutput.permissionDecisionReason else "ALLOW" end'
}
_open_fid() {  # <sb> — FID 폴더와 진행 기록을 손으로 연다(훅이 활성 FID 를 찾는다)
  mkdir -p "$1/.specops/$F"
  printf '<!-- active-fid: %s -->\n## %s\n- 2026-10-10 10:00 /quick-fix 시작\n' "$F" "$F" > "$1/.specops/session-progress.md"
}
# 손으로 만든 영수증 — 봉인 스크립트를 거치지 않아도 커밋에서 걸리는지 보려고 태스크 문서를 직접 쓴다
_hand_receipt() {  # <sb> <outputs — 쉼표 구분>
  printf '# tasks\n\n## 의존 그래프\n\n```yaml\nreview_mode: end-loaded\ntasks:\n  - id: T1\n    depends_on: []\n    inputs: []\n    outputs: [%s]\n    ac: []\n    test_command: "bash tests/t.sh"\n```\n' \
    "$2" > "$1/.specops/$F/tasks.md"
  ( cd "$1" && SPECOPS_ROOT=.specops bash "$PLUGIN/scripts/_internal/record-task-receipt.sh" "$F" T1 ) >/dev/null 2>&1
}

# ── H1 범위 초과 — 영수증이 유효해도 커밋 차단, 사유가 걸린 기준을 말한다 (AC-2) ──
_h_over() {  # <라벨> <기대 사유 조각> <outputs> <준비 명령>
  local s v; s=$(_mk); _SBS="$_SBS $s"; _open_fid "$s"
  ( cd "$s" && eval "$4" ) >/dev/null 2>&1; _review "$s" PASS; _hand_receipt "$s" "$3"
  [ -f "$s/.specops/$F/receipts/T1.json" ] || { nope "$1" "픽스처 — 영수증이 만들어지지 않았다"; return; }
  v=$(_hook "$s" "$MSG")
  printf '%s' "$v" | grep -q '^DENY' && printf '%s' "$v" | grep -qF "quick 범위 초과 — $2" && printf '%s' "$v" | grep -q '/maintain-lite' \
    && ! printf '%s' "$v" | grep -q '기록된 receipt 가 유효하지 않습니다' \
    && ok "$1" || nope "$1" "$(printf '%s' "$v" | tail -6)"
}
_h_over "H1.a ★ 구현 파일 3개 → 차단 · 사유에 기준과 /maintain-lite ('영수증 무효' 라고 말하지 않는다)" '구현 파일 3개 (상한 2개)' \
  'src/a.sh, src/b.sh, src/c.sh' 'printf "echo v2\n" > src/a.sh && _n 3 > src/b.sh && _n 3 > src/c.sh && git add src'
_h_over "H1.b 변경 31줄 → 차단" '변경 31줄 (상한 20줄' 'src/a.sh' '{ echo "echo v2"; _n 29; } > src/a.sh && git add src/a.sh'
_h_over "H1.c 고위험 신호(스키마 파일) → 차단" '고위험 신호: schema' 'src/a.sh, db/001.sql' \
  'printf "echo v2\n" > src/a.sh && mkdir -p db && printf "ADD COLUMN x int;\n" > db/001.sql && git add src db'

# ── H2 리뷰 미충족 — 커밋 차단, 사유는 범위 초과와 다르다 (AC-3) ────────────
sb=$(_mk); _SBS="$_SBS $sb"; _open_fid "$sb"
( cd "$sb" && printf 'echo v2\n' > src/a.sh && git add src/a.sh )
_hand_receipt "$sb" "src/a.sh"; v=$(_hook "$sb" "$MSG")
printf '%s' "$v" | grep -q '^DENY' && printf '%s' "$v" | grep -q 'quick 리뷰 미충족 — 리뷰 보고서가 없다' \
  && ! printf '%s' "$v" | grep -q '범위 초과' \
  && ok "H2.a ★ 리뷰 없이 영수증만 만든 커밋 → 차단, 사유는 리뷰(범위 초과가 아니다)" || nope "H2.a" "$(printf '%s' "$v" | tail -5)"
_review "$sb" FAIL; v=$(_hook "$sb" "$MSG")
printf '%s' "$v" | grep -q '^DENY' && printf '%s' "$v" | grep -q 'quick 리뷰 미충족 — 마지막 리뷰 판정이 통과가 아니다' \
  && ok "H2.b 통과가 아닌 판정 → 차단" || nope "H2.b" "$(printf '%s' "$v" | tail -4)"
touch -t 201901010000 "$sb/.specops/$F/reviews/T1-C-feedback.md"; _review "$sb" PASS; v=$(_hook "$sb" "$MSG")
[ "$v" = "ALLOW" ] && ok "H2.c ★ 같은 영수증에 통과 리뷰가 오면 열린다 (범위 안 + 리뷰 + 영수증 = 통과 · AC-1)" || nope "H2.c" "$(printf '%s' "$v" | tail -4)"
touch -t 202001010000 "$sb/.specops/$F/reviews/T1-C-report.md"; v=$(_hook "$sb" "$MSG")
printf '%s' "$v" | grep -q '^DENY' && printf '%s' "$v" | grep -q 'quick 리뷰 미충족 — 리뷰 뒤에 src/a.sh 가 다시 수정됐다' \
  && ok "H2.d 리뷰가 수정보다 오래됨 → 차단" || nope "H2.d" "$(printf '%s' "$v" | tail -4)"

# ── H3 기존 흐름 불변 (AC-R-1) ──────────────────────────────────────────────
# 명세가 있는 FID(정식 경로) — 범위가 크고 리뷰 보고서가 없어도 영수증만으로 종전처럼 열린다
sb=$(_mk); _SBS="$_SBS $sb"; _open_fid "$sb"; printf '# spec\n' > "$sb/.specops/$F/spec.md"
( cd "$sb" && printf 'echo v2\n' > src/a.sh && _n 30 > src/b.sh && _n 30 > src/c.sh && git add src )
_hand_receipt "$sb" "src/a.sh, src/b.sh, src/c.sh"; v=$(_hook "$sb" "$MSG")
[ "$v" = "ALLOW" ] && ok "H3.a ★ 명세가 있는 FID 는 범위·리뷰 판정을 받지 않는다(정식 영수증 경로 불변)" || nope "H3.a" "$(printf '%s' "$v" | tail -4)"
# 태스크 문서가 없는 FID(자유작업) — quick 문안이 나오지 않는다
sb=$(_mk); _SBS="$_SBS $sb"; _open_fid "$sb"
( cd "$sb" && printf 'echo v2\n' > src/a.sh && _n 30 > src/b.sh && _n 30 > src/c.sh && git add src ); v=$(_hook "$sb" "$MSG")
printf '%s' "$v" | grep -q '^DENY' && ! printf '%s' "$v" | grep -qE 'quick (범위 초과|리뷰 미충족|경로)' \
  && ok "H3.b 태스크 문서가 없는 FID 는 종전 판정 그대로다(quick 문안 없음)" || nope "H3.b" "$(printf '%s' "$v" | head -2)"

# ── H4 원인 매핑 — 영수증 검사기의 종료 코드가 사유 코드로 ──────────────────
c3=$(. "$PLUGIN/hooks/governance-lib.sh" >/dev/null 2>&1; _receipt_cause 3 "$MSG" T1 "$F")
c4=$(. "$PLUGIN/hooks/governance-lib.sh" >/dev/null 2>&1; _receipt_cause 4 "$MSG" T1 "$F")
c1=$(. "$PLUGIN/hooks/governance-lib.sh" >/dev/null 2>&1; _receipt_cause 1 "$MSG" T1 "$F")
[ "$c3" = "quick-over" ] && [ "$c4" = "quick-noreview" ] && [ "$c1" = "open-invalid" ] \
  && ok "H4.a 종료 코드 3 → quick-over · 4 → quick-noreview · 1 → open-invalid(종전)" || nope "H4.a" "c3=$c3 c4=$c4 c1=$c1"
# 판정 불가(스테이징된 변경 없음)는 "범위 초과" 가 아니다 — 문안이 원인을 그대로 말하고 /maintain-lite 로 보내지 않는다
sb=$(_mk); _SBS="$_SBS $sb"; mkdir -p "$sb/.specops/$F"
h=$(cd "$sb" && . "$PLUGIN/hooks/governance-lib.sh" >/dev/null 2>&1; _receipt_hint_extra quick-over "$MSG" "$F")
printf '%s' "$h" | grep -q 'quick 판정 불가 — 스테이징된 변경이 없다' && ! printf '%s' "$h" | grep -qE '범위 초과|/maintain-lite' \
  && ok "H4.b 판정 불가는 범위 초과로 말하지 않는다(원인 그대로 · /maintain-lite 안내 없음)" || nope "H4.b" "$(printf '%s' "$h" | head -3)"

# shellcheck disable=SC2086
rm -rf $_SBS
echo ""
finish
