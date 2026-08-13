#!/usr/bin/env bash
# specops-ko governance-capture 공용 함수 라이브러리 테스트
# source hooks/governance-lib.sh 후 detect_fid / read_recent_tool_events / log_friction / load_rules 검증
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
FIXTURES="$PLUGIN/scripts/tests/governance/fixtures"

# T1.a detect_fid: 최신 FID 헤더 반환
tmp=$(mktemp -d); cd "$tmp"; mkdir -p .specops
cp "$FIXTURES/session-progress-basic.md" .specops/session-progress.md
source "$PLUGIN/hooks/governance-lib.sh"
out=$(detect_fid); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "20260424-newest-feature" ]; then
  PASS=$((PASS+1)); echo "PASS T1.a detect_fid 최신 헤더"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.a (rc=$rc out=$out)"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T1.b detect_fid: session-progress.md 부재 시 빈 문자열
tmp=$(mktemp -d); cd "$tmp"
out=$(detect_fid); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T1.b 부재 시 빈 문자열"
else
  FAIL=$((FAIL+1)); echo "FAIL T1.b (rc=$rc out=[$out])"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T2.a read_recent_tool_events: 최근 3 개 tool_use
out=$(read_recent_tool_events "$FIXTURES/transcripts/basic-tools.jsonl" 3); rc=$?
count=$(echo "$out" | grep -c '^{')
last_has_skill=$(echo "$out" | tail -1 | grep -c '"tool_name":"Skill"')
if [ "$rc" -eq 0 ] && [ "$count" -eq 3 ] && [ "$last_has_skill" -eq 1 ]; then
  PASS=$((PASS+1)); echo "PASS T2.a read_recent_tool_events 3건 + Skill 마지막"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.a (rc=$rc count=$count skill=$last_has_skill)"
fi

# T3.a log_friction: FID 제공 → .specops/<FID>/friction-log.jsonl
tmp=$(mktemp -d); cd "$tmp"
source "$PLUGIN/hooks/governance-lib.sh"
log_friction "20260424-x" "R-1" 5 "git commit" 7
log_path=".specops/20260424-x/friction-log.jsonl"
if [ -f "$log_path" ] && jq -e '.rule_id == "R-1" and .principle == 5 and .fid == "20260424-x"' "$log_path" >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T3.a log_friction FID 스코프"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.a"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T3.b log_friction: FID 빈 문자열 → .specops/friction-log.jsonl, fid=null
tmp=$(mktemp -d); cd "$tmp"
source "$PLUGIN/hooks/governance-lib.sh"
log_friction "" "R-2" 5 "gh pr create" 3
if [ -f ".specops/friction-log.jsonl" ] && jq -e '.fid == null and .rule_id == "R-2"' ".specops/friction-log.jsonl" >/dev/null; then
  PASS=$((PASS+1)); echo "PASS T3.b log_friction 전역 fallback"
else
  FAIL=$((FAIL+1)); echo "FAIL T3.b"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T4.a load_rules: matcher + enabled 필터
out=$(load_rules "$FIXTURES/rules-test.jsonl" "posttool"); rc=$?
count=$(echo "$out" | grep -c '^{')
has_ra=$(echo "$out" | jq -e 'select(.id == "R-A")' >/dev/null 2>&1 && echo 1 || echo 0)
if [ "$rc" -eq 0 ] && [ "$count" -eq 1 ] && [ "$has_ra" -eq 1 ]; then
  PASS=$((PASS+1)); echo "PASS T4.a load_rules 필터"
else
  FAIL=$((FAIL+1)); echo "FAIL T4.a (rc=$rc count=$count has_ra=$has_ra)"
fi

# T-M1 log_friction: 잘못된 FID → rc=1, 파일 생성 없음
tmp=$(mktemp -d); cd "$tmp"
source "$PLUGIN/hooks/governance-lib.sh"
log_friction "../evil" "R-X" 5 "x" 0 2>/dev/null; rc=$?
if [ "$rc" -eq 1 ] && [ ! -e "../evil" ] && [ ! -d ".specops/../evil" ]; then
  PASS=$((PASS+1)); echo "PASS T-M1 FID 경로 탈출 가드"
else
  FAIL=$((FAIL+1)); echo "FAIL T-M1 (rc=$rc)"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T-M2 log_friction: 공백·특수문자 FID → rc=1
tmp=$(mktemp -d); cd "$tmp"
source "$PLUGIN/hooks/governance-lib.sh"
log_friction "bad fid" "R-X" 5 "x" 0 2>/dev/null; rc=$?
if [ "$rc" -eq 1 ]; then
  PASS=$((PASS+1)); echo "PASS T-M2 공백 FID 거부"
else
  FAIL=$((FAIL+1)); echo "FAIL T-M2 (rc=$rc)"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T-M3 log_friction: 유효 FID (20260424-x) → rc=0 + 파일 생성 (회귀 방지)
tmp=$(mktemp -d); cd "$tmp"
source "$PLUGIN/hooks/governance-lib.sh"
log_friction "20260424-valid" "R-X" 5 "x" 0; rc=$?
if [ "$rc" -eq 0 ] && [ -f ".specops/20260424-valid/friction-log.jsonl" ]; then
  PASS=$((PASS+1)); echo "PASS T-M3 유효 FID 수용"
else
  FAIL=$((FAIL+1)); echo "FAIL T-M3 (rc=$rc)"
fi
cd "$PLUGIN"; rm -rf "$tmp"

# T-docs.a is_docs_only_change: .md만 staged → 면제(0)
td=$(mktemp -d); ( cd "$td" && git init -q && echo x > a.md && git add a.md
  source "$PLUGIN/hooks/governance-lib.sh"; is_docs_only_change ); rc=$?
if [ "$rc" -eq 0 ]; then PASS=$((PASS+1)); echo "PASS T-docs.a .md-only 면제"; else FAIL=$((FAIL+1)); echo "FAIL T-docs.a"; fi
rm -rf "$td"
# T-docs.b 코드 혼합 → 비면제(1) [보안 불변식]
td=$(mktemp -d); ( cd "$td" && git init -q && echo x > a.md && echo y > b.sh && git add a.md b.sh
  source "$PLUGIN/hooks/governance-lib.sh"; is_docs_only_change ); rc=$?
if [ "$rc" -eq 1 ]; then PASS=$((PASS+1)); echo "PASS T-docs.b 코드혼합 비면제"; else FAIL=$((FAIL+1)); echo "FAIL T-docs.b 보안회귀!"; fi
rm -rf "$td"
# T-docs.c 빈 목록(변경 없음) → 비면제(1) [fail-safe]
td=$(mktemp -d); ( cd "$td" && git init -q && git commit -q --allow-empty -m init
  source "$PLUGIN/hooks/governance-lib.sh"; is_docs_only_change ); rc=$?
if [ "$rc" -eq 1 ]; then PASS=$((PASS+1)); echo "PASS T-docs.c 빈목록 fail-safe"; else FAIL=$((FAIL+1)); echo "FAIL T-docs.c"; fi
rm -rf "$td"
# T-docs.d staged=docs + unstaged tracked 코드 → 비면제(1) [git commit -am 우회 차단]
td=$(mktemp -d); ( cd "$td" && git init -q && echo "echo orig" > tracked.sh && git add tracked.sh && git commit -q -m init
  echo doc > README.md && git add README.md && echo "echo changed" > tracked.sh
  source "$PLUGIN/hooks/governance-lib.sh"; is_docs_only_change ); rc=$?
if [ "$rc" -eq 1 ]; then PASS=$((PASS+1)); echo "PASS T-docs.d staged-docs+unstaged-code 비면제(commit -am 우회 차단)"; else FAIL=$((FAIL+1)); echo "FAIL T-docs.d 보안우회!"; fi
rm -rf "$td"

# T-docs.e~i: is_docs_only_change PR-범위 fallback (R-2 비대칭 해소) — sandbox 함수 단위
_docs_case() {  # $1 expect_rc(0=allow/1=deny) $2 label $3 setup-eval
  local exp="$1" label="$2" setup="$3" rc
  ( source "$PLUGIN/hooks/governance-lib.sh"; C=commit
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@e GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@e
    sb=$(mktemp -d) || exit 2; cd "$sb" || exit 2
    eval "$setup"
    is_docs_only_change; rc=$?
    cd /; rm -rf "$sb"; exit $rc )
  rc=$?
  if [ "$rc" -eq "$exp" ]; then PASS=$((PASS+1)); echo "PASS $label"; else FAIL=$((FAIL+1)); echo "FAIL $label (rc=$rc exp=$exp)"; fi
}
_docs_case 0 "T-docs.e docs-only PR(커밋완료) 면제" 'git init -q; git checkout -q -b main 2>/dev/null; echo b>b.md; git add b.md; git "$C" -q -m i; git checkout -q -b feat; echo c>CHANGELOG.md; git add CHANGELOG.md; git "$C" -q -m d'
_docs_case 1 "T-docs.f 코드혼합 PR 차단" 'git init -q; git checkout -q -b main 2>/dev/null; echo b>b.md; git add b.md; git "$C" -q -m i; git checkout -q -b feat; echo c>CHANGELOG.md; git add CHANGELOG.md; echo x>s.sh; git add s.sh; git "$C" -q -m m'
_docs_case 1 "T-docs.g base없음 안전측 차단" 'git init -q; git checkout -q -b odd 2>/dev/null; echo d>d.md; git add d.md; git "$C" -q -m i; git checkout -q -b f2; echo e>e.md; git add e.md; git "$C" -q -m m'
_docs_case 0 "T-docs.h R-1 staged docs 면제" 'git init -q; echo m>m.md; git add m.md'
_docs_case 1 "T-docs.i R-1 코드혼합 차단" 'git init -q; echo m>m.md; git add m.md; echo y>c.sh; git add c.sh'
# T-docs.j~m: rename 우회 차단 (--no-renames — code→docs rename 을 docs-only 로 오인면제 차단)
_docs_case 1 "T-docs.j code→docs rename 차단(불변식)" 'git init -q; echo x>a.sh; git add a.sh; git "$C" -q -m i; git mv a.sh a.md'
_docs_case 0 "T-docs.k docs→docs rename 무회귀" 'git init -q; echo x>a.md; git add a.md; git "$C" -q -m i; git mv a.md b.md'
_docs_case 1 "T-docs.l docs→code rename 유지" 'git init -q; echo x>a.md; git add a.md; git "$C" -q -m i; git mv a.md a.sh'
_docs_case 1 "T-docs.m PR범위 code→docs rename 차단" 'git init -q; git checkout -q -b main 2>/dev/null; echo x>a.sh; git add a.sh; git "$C" -q -m i; git checkout -q -b feat; git mv a.sh a.md; git "$C" -q -m r'
# T-docs.n~q: design/아티팩트 면제 확장 (dogfood 20260716 — Phase 2.5 design 커밋(screens/*.html)이
#   .md 한정 whitelist 에 걸려 false-block → BYPASS 남발 유발. screens/ 미리보기·.specops/ 아티팩트는 실행 코드 아님)
_docs_case 0 "T-docs.n screens/*.html 설계 미리보기 면제" 'git init -q; mkdir screens; echo x>screens/login.html; echo s>screens/login.md; git add screens'
_docs_case 1 "T-docs.o screens/ 밖 .html 비면제(앱 코드 가능)" 'git init -q; mkdir src; echo x>src/index.html; git add src'
_docs_case 1 "T-docs.p screens/*.html + 코드 혼합 차단(불변식)" 'git init -q; mkdir screens; echo x>screens/a.html; echo y>b.sh; git add screens b.sh'
_docs_case 0 "T-docs.q .specops/ 아티팩트(비 .md 포함) 면제" 'git init -q; mkdir -p .specops/20260101-x; echo sha>.specops/20260101-x/review-base.sha; git add .specops'

# T-docs.r~: _commit_scope_is_staged 분류 (20260813-r1-docs-only-scope)
#   실행 명령에 git+commit 리터럴을 직접 쓰면 R-1 훅이 프로브 자체를 차단하므로 변수로 조립한다.
#   헬퍼명은 `_clsf_case` 다 — 아래 `_scope_case`(:은 is_docs_only_audit_scope 용 4인자)와 이름이
#   겹치면 정의 순서에 기대는 그림자(shadowing)가 생겨, 이후 누가 케이스를 추가할 때 조용히 깨진다.
_G=$(printf 'g%sit' ''); _C=$(printf 'c%sommit' '')
_clsf_case() {  # $1 expect_rc  $2 label  $3 cmd
  ( source "$PLUGIN/hooks/governance-lib.sh"; _commit_scope_is_staged "$3" ); local rc=$?
  if [ "$rc" -eq "$1" ]; then PASS=$((PASS+1)); echo "PASS $2 (rc=$rc)"
  else FAIL=$((FAIL+1)); echo "FAIL $2 rc=$rc 기대=$1"; fi
}
_clsf_case 0 "T-docs.r plain -m 축소"        "$_G $_C -m 'docs: x'"
_clsf_case 0 "T-docs.s -q -m 축소"           "$_G $_C -q -m 'x'"
_clsf_case 0 "T-docs.t --message= 축소"      "$_G $_C --message=x"
_clsf_case 1 "T-docs.u -am 보수"             "$_G $_C -am 'x'"
_clsf_case 1 "T-docs.v -a -m 보수"           "$_G $_C -a -m 'x'"
_clsf_case 1 "T-docs.w --all 보수"           "$_G $_C --all -m 'x'"
_clsf_case 0 "T-docs.t2 -q -F - heredoc 축소(AC-7)" "$_G $_C -q -F - <<'HD'
docs: x
HD"
_clsf_case 1 "T-docs.x compound && 보수"     "$_G add -A && $_G $_C -m 'x'"
_clsf_case 1 "T-docs.y compound ; 보수"      "$_G add -A ; $_G $_C -m 'x'"
_clsf_case 1 "T-docs.y2 compound | 보수"     "$_G log | $_G $_C -m 'x'"
_clsf_case 1 "T-docs.y3 compound || 보수"    "$_G add -A || $_G $_C -m 'x'"
_clsf_case 1 "T-docs.z 경로인자 보수"        "$_G $_C README.md"
_clsf_case 1 "T-docs.aa --amend 보수"        "$_G $_C --amend -m 'x'"
_clsf_case 1 "T-docs.ab git -c 보수"         "$_G -c user.email=a@b $_C -m 'x'"
_clsf_case 1 "T-docs.ac --only 보수"         "$_G $_C --only README.md"
_clsf_case 1 "T-docs.ad -s signoff 보수"     "$_G $_C -s -m 'x'"
_clsf_case 1 "T-docs.ae env 접두 보수"       "FOO=1 $_G $_C -m 'x'"
_clsf_case 1 "T-docs.af gh pr create 보수"   "gh pr create --title x"
_clsf_case 1 "T-docs.ag 빈 문자열 보수"      ""
# T-docs.am~as: 개행 분리 compound (Phase B false-allow — 개행은 `;` 와 동등한 명령 분리자다.
#   첫 줄만 보고 잔여 줄을 무검증 폐기하면 C1·C2 가 둘째 줄부터 적용되지 않는다)
_clsf_case 1 "T-docs.am 개행 compound(첫줄 안전형) 보수" "$_G $_C -m 'docs'
$_G add -A
$_G $_C -am 'code'"
_clsf_case 1 "T-docs.an 개행 compound(첫줄 add) 보수"    "$_G add -A
$_G $_C -m 'x'"
_clsf_case 1 "T-docs.ao 첫줄 << 없는 2줄 보수"           "$_G $_C -m 'x'
ls"
_clsf_case 1 "T-docs.ap heredoc 종결자 뒤 추가명령 보수" "$_G $_C -q -F - <<'HD'
docs: x
HD
$_G add -A"
_clsf_case 0 "T-docs.aq 후행 개행만 축소 유지"           "$_G $_C -m 'x'
"
_clsf_case 0 "T-docs.ar heredoc <<- 탭 종결자 축소"      "$_G $_C -q -F - <<-HD
	docs: x
	HD"
_clsf_case 0 "T-docs.as 멀티라인 인용 -m 축소(false-block 방지)" "$_G $_C -m 'feat: x

body'"

# T-docs.ah~ak: is_docs_only_change 스코프 분기 (sandbox — staged=docs + unstaged 코드)
_scope_sandbox() {  # $1 expect_rc  $2 label  $3 cmd(빈 문자열이면 무인자 호출)
  local td rc; td=$(mktemp -d)
  ( cd "$td" && git init -q \
    && echo "echo orig" > tracked.sh && git add tracked.sh \
    && git -c user.email=e@t -c user.name=t commit -q -m init \
    && echo doc > README.md && git add README.md \
    && echo "echo changed" > tracked.sh \
    && source "$PLUGIN/hooks/governance-lib.sh" \
    && if [ -n "$3" ]; then is_docs_only_change "$3"; else is_docs_only_change; fi ); rc=$?
  rm -rf "$td"
  if [ "$rc" -eq "$1" ]; then PASS=$((PASS+1)); echo "PASS $2 (rc=$rc)"
  else FAIL=$((FAIL+1)); echo "FAIL $2 rc=$rc 기대=$1"; fi
}
_scope_sandbox 0 "T-docs.ah plain 커밋 → 면제(AC-1)"   "$_G $_C -m 'docs'"
_scope_sandbox 1 "T-docs.ai -am → 비면제(AC-2)"        "$_G $_C -am 'x'"
_scope_sandbox 1 "T-docs.aj compound → 비면제(AC-3)"   "$_G add -A && $_G $_C -m 'x'"
_scope_sandbox 1 "T-docs.ak 무인자 → 현행 보존(AC-5)"  ""
# AC-3 은 개행 분리 compound 도 포함한다 — 연산자 4변형(`&&`·`;`·`|`·`||`)만 잠그면 개행이 뚫린다.
# T-docs.au~aw: 명령치환 토큰 보수화 (Phase C Important-2 — 20260813)
#   _strip_quoted_strings 는 `$(`·백틱을 "실제 실행됨" 이유로 보존하는데, C3 의 skip 이 그 보존을
#   무검사 소비하던 구멍. 치환은 커밋 前 실행이라 staged 를 바꿀 수 있다.
_clsf_case 1 "T-docs.au 단일토큰 명령치환 -m 보수"   "$_G $_C -m \"\$(ga)\""
_clsf_case 1 "T-docs.av 백틱 치환 -m 보수"           "$_G $_C -m \"\`ga\`\""
_clsf_case 1 "T-docs.aw --file= 치환 보수"           "$_G $_C --file=\"\$(f)\""

_scope_sandbox 1 "T-docs.at 개행 compound → 비면제(AC-3)" "$_G $_C -m 'docs'
$_G add -A
$_G $_C -am 'code'"

# T-docs.al: staged 에 코드 혼합이면 형태 무관 비면제 (AC-6 — 매처 불변식)
_td=$(mktemp -d)
( cd "$_td" && git init -q && echo x > a.md && echo y > b.sh && git add a.md b.sh
  source "$PLUGIN/hooks/governance-lib.sh"; is_docs_only_change "$_G $_C -m 'x'" ); _rc=$?
rm -rf "$_td"
if [ "$_rc" -eq 1 ]; then PASS=$((PASS+1)); echo "PASS T-docs.al staged 코드혼합 비면제(AC-6)"
else FAIL=$((FAIL+1)); echo "FAIL T-docs.al 보안회귀! rc=$_rc"; fi

# T-scope.a~d: is_docs_only_audit_scope — posttool 감사 스코프 (방금 액션 범위, 20260718-posttool-audit-silence)
_scope_case() {  # $1 expect_rc $2 label $3 rule_id $4 setup-eval
  local exp="$1" label="$2" rid="$3" setup="$4" rc
  ( source "$PLUGIN/hooks/governance-lib.sh"; C=commit
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@e GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@e
    sb=$(mktemp -d) || exit 3; cd "$sb" || exit 3
    eval "$setup"
    is_docs_only_audit_scope "$rid"; rc=$?
    cd /; rm -rf "$sb"; exit $rc )
  rc=$?
  if [ "$rc" -eq "$exp" ]; then PASS=$((PASS+1)); echo "PASS $label"; else FAIL=$((FAIL+1)); echo "FAIL $label (rc=$rc exp=$exp)"; fi
}
_scope_case 1 "T-scope.a R-1 코드 커밋 + .specops 잔여 dirty → 비면제(감사)" R-1 \
  'git init -q; mkdir .specops; echo p>.specops/session-progress.md; echo x>a.sh; git add -A; git "$C" -q -m i; echo y>a.sh; git add a.sh; git "$C" -q -m c; echo d>>.specops/session-progress.md'
_scope_case 0 "T-scope.b R-1 docs-only 커밋 + 코드 dirt → 면제(커밋 기준)" R-1 \
  'git init -q; echo x>a.sh; git add -A; git "$C" -q -m i; echo d>R.md; git add R.md; git "$C" -q -m d; echo z>b.sh'
_scope_case 1 "T-scope.c R-1 최초 커밋(HEAD~1 부재) → 비면제(fail-safe)" R-1 \
  'git init -q; echo x>a.sh; git add -A; git "$C" -q -m i'
_scope_case 1 "T-scope.d R-2 base...HEAD 코드 포함 → 비면제(감사)" R-2 \
  'git init -q; git checkout -q -b main 2>/dev/null; echo b>b.md; git add b.md; git "$C" -q -m i; git checkout -q -b feat; echo c>c.sh; git add c.sh; git "$C" -q -m f; echo d>>b.md'

# T-base.a~c: _detect_base_branch 직접 단위 (main 우선 / master 차선 / 둘 다 부재 실패) [code-review Minor]
_base_case() {  # $1 expect_out("" = 실패) $2 label $3 setup-eval
  local exp="$1" label="$2" setup="$3" out
  out=$( ( source "$PLUGIN/hooks/governance-lib.sh"; C=commit
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@e GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@e
    sb=$(mktemp -d) || exit 2; cd "$sb" || exit 2
    eval "$setup"
    _detect_base_branch 2>/dev/null
    cd /; rm -rf "$sb" ) )
  if [ "$out" = "$exp" ]; then PASS=$((PASS+1)); echo "PASS $label"; else FAIL=$((FAIL+1)); echo "FAIL $label (out='$out' exp='$exp')"; fi
}
_base_case "main"   "T-base.a main 우선"      'git init -q; git checkout -q -b main 2>/dev/null; echo a>a.md; git add a.md; git "$C" -q -m i'
_base_case "master" "T-base.b master 차선"    'git init -q; git checkout -q -b master 2>/dev/null; echo a>a.md; git add a.md; git "$C" -q -m i'
_base_case ""       "T-base.c 둘 다 부재 실패" 'git init -q; git checkout -q -b dev 2>/dev/null; echo a>a.md; git add a.md; git "$C" -q -m i'

# T-symlink: log_friction — .specops 가 symlink 면 쓰기 거부 (path-escape 차단)
tmp=$(mktemp -d); real=$(mktemp -d); cd "$tmp"; ln -s "$real" .specops
log_friction "20260424-sl" "R-1" 5 "x" 7 2>/dev/null
if [ ! -e "$real/20260424-sl/friction-log.jsonl" ]; then
  PASS=$((PASS+1)); echo "PASS T-symlink log_friction symlink 거부"
else
  FAIL=$((FAIL+1)); echo "FAIL T-symlink (REAL 타겟 write-through 누출)"
fi
cd "$PLUGIN"; rm -rf "$tmp" "$real"

# T-symlink-file: friction-log.jsonl *파일* 자체가 symlink 면 append 거부.
# 디렉토리(.specops/<fid>)는 정상이라 _specops_fid_dir_safe 통과 — 파일 symlink 는 별개 표면.
# 악성 repo clone 후 .specops/<fid>/friction-log.jsonl → 외부 파일 symlink 시 >> 따라감 차단.
tmp=$(mktemp -d); real=$(mktemp -d); cd "$tmp"
mkdir -p ".specops/20260630-fsl"
ln -s "$real/leak.jsonl" ".specops/20260630-fsl/friction-log.jsonl"
log_friction "20260630-fsl" "R-1" 5 "x" 7 2>/dev/null
log_friction_sev "20260630-fsl" "R-1" 5 "x" 7 "block" 2>/dev/null
if [ ! -e "$real/leak.jsonl" ]; then
  PASS=$((PASS+1)); echo "PASS T-symlink-file friction-log 파일 symlink 거부"
else
  FAIL=$((FAIL+1)); echo "FAIL T-symlink-file (파일 symlink write-through 누출)"
fi
cd "$PLUGIN"; rm -rf "$tmp" "$real"

# T-hd _strip_heredoc_bodies 단위 (20260713-heredoc-false-block)
#   문자열 in/out 대조 — heredoc **본문만** 제거되는가. 정규식은 무변경, **입력만 전처리**한다.
cd "$PLUGIN" || exit 1
source "$PLUGIN/hooks/governance-lib.sh"

# T-hd.1 (AC-2) 본문만 제거 — 시작 줄·종료 줄·종료 후 명령은 유지
_in=$'cat > f.md <<EOF\ngit commit -m x\nEOF\nls -la'
_exp=$'cat > f.md <<EOF\nEOF\nls -la'
_got=$(_strip_heredoc_bodies "$_in")
if [ "$_got" = "$_exp" ]; then
  PASS=$((PASS+1)); echo "PASS T-hd.1 (AC-2) heredoc 본문만 제거"
else
  FAIL=$((FAIL+1)); echo "FAIL T-hd.1 (AC-2) — got: $(printf '%s' "$_got" | tr '\n' '|')"
fi

# T-hd.2 (AC-R-1 identity) heredoc 없는 입력은 **바이트 동일** — 기존 51 케이스 보호의 근거
_in='cd /tmp && git commit -m x'
_got=$(_strip_heredoc_bodies "$_in")
if [ "$_got" = "$_in" ]; then
  PASS=$((PASS+1)); echo "PASS T-hd.2 (AC-R-1) heredoc 부재 입력 무변경(identity)"
else
  FAIL=$((FAIL+1)); echo "FAIL T-hd.2 identity 깨짐 — got: $_got"
fi

# T-hd.3 (AC-5) 셸 실행자 heredoc → 본문 **제외 안 함**(passthrough). F-3 표면 불변.
_in=$'bash <<EOF\ngit commit -m x\nEOF'
_got=$(_strip_heredoc_bodies "$_in")
if [ "$_got" = "$_in" ]; then
  PASS=$((PASS+1)); echo "PASS T-hd.3 (AC-5) bash <<EOF 본문 유지(passthrough)"
else
  FAIL=$((FAIL+1)); echo "FAIL T-hd.3 (AC-5) 실행자 본문이 제거됨 — got: $(printf '%s' "$_got" | tr '\n' '|')"
fi

# T-hd.4 (AC-8 fail-safe) 미종료 heredoc → **원본 반환**(차단 우세로 후퇴)
_in=$'cat > f.md <<EOF\ngit commit -m x'
_got=$(_strip_heredoc_bodies "$_in")
if [ "$_got" = "$_in" ]; then
  PASS=$((PASS+1)); echo "PASS T-hd.4 (AC-8) 미종료 heredoc → 원본 반환(fail-safe)"
else
  FAIL=$((FAIL+1)); echo "FAIL T-hd.4 (AC-8) 미종료 heredoc 본문이 제거됨 — got: $(printf '%s' "$_got" | tr '\n' '|')"
fi

# T-hd.5 (AC-6) python3 heredoc → 본문 제외 (셸 명령 아님)
_in=$'python3 <<EOF\ngit commit -m x\nEOF'
_exp=$'python3 <<EOF\nEOF'
_got=$(_strip_heredoc_bodies "$_in")
if [ "$_got" = "$_exp" ]; then
  PASS=$((PASS+1)); echo "PASS T-hd.5 (AC-6) python3 본문 제외"
else
  FAIL=$((FAIL+1)); echo "FAIL T-hd.5 (AC-6) — got: $(printf '%s' "$_got" | tr '\n' '|')"
fi

# ── T-task.* : _infer_commit_task 명시 선언 우선 (20260807 실사용 검증 12호) ──
# 구 구현은 `Task:...|T[0-9]+` 교대를 한 번에 스캔해 **문서 순서상 먼저 나온 쪽**을 집었다.
#   제목 "출력층 (T1~T4 집약)" + 본문 `Task: T4` 인 커밋이 T1 으로 오인돼,
#   훅이 deny 메시지로 안내한 **receipt 탈출구가 실제로는 열리지 않았다**.
#   FID 20260807-specops-doctor 실사용 중 실측 — 합성 픽스처로는 안 나온 결함.
_infer_case() {  # $1=라벨 $2=커밋메시지 $3=기대
  local got; got=$(_infer_commit_task "$2")
  if [ "$got" = "$3" ]; then
    PASS=$((PASS+1)); echo "PASS $1"
  else
    FAIL=$((FAIL+1)); echo "FAIL $1 — got '$got' want '$3'"
  fi
}
_infer_case "T-task.1 명시 Task: 가 제목 산문보다 우선" $'feat: 출력층 (T1~T4 집약)\n\nTask: T4' T4
_infer_case "T-task.2 명시 선언 단독" $'fix: something\n\nTask: T7' T7
_infer_case "T-task.3 산문 T# fallback 보존" 'feat: T3 구현' T3
_infer_case "T-task.4 선언·산문 모두 없으면 빈값" 'feat: 그냥 커밋' ''

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
