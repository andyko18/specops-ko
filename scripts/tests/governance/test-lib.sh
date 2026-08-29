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

# T-cls.a~h: _commit_scope_class 분류 (20260813-friction-staged-record)
_cls_case() {  # $1 expect  $2 label  $3 files(인자, 생략 시 무인자 호출)
  local got
  if [ "$#" -ge 3 ]; then got=$( ( source "$PLUGIN/hooks/governance-lib.sh"; _commit_scope_class "$3" ) )
  else got=$( ( source "$PLUGIN/hooks/governance-lib.sh"; _commit_scope_class ) ); fi
  if [ "$got" = "$1" ]; then PASS=$((PASS+1)); echo "PASS $2 ($got)"
  else FAIL=$((FAIL+1)); echo "FAIL $2 got=$got 기대=$1"; fi
}
_cls_case docs-only "T-cls.a .md 단독"        "README.md"
_cls_case code      "T-cls.b .md+.sh 혼합"    "$(printf 'README.md\napp.sh')"
_cls_case empty     "T-cls.c 빈 목록"          ""
_cls_case docs-only "T-cls.d .specops/* 면제"  ".specops/x/friction-log.jsonl"
_cls_case docs-only "T-cls.e screens/*.html"   "screens/a.html"
_cls_case code      "T-cls.f src/*.html 비면제" "src/a.html"

# T-cls.g~h: 무인자 자체 계산 (sandbox)
_cls_sandbox() {  # $1 expect  $2 label  $3 staged(docs|code|none)
  # ★ bash 3.2 파서 버그 회피: `$( … case … docs) … )` 는 3.2.57 에서 `;;` syntax error 다(실측).
  #   패턴을 괄호형 `(docs)` 로 쓰면 통과하지만, 더 안전하게 case 를 $() **밖**으로 뺀다.
  local td got; td=$(mktemp -d)
  ( cd "$td" && git init -q && echo x > seed.md && git add seed.md \
    && git -c user.email=e@t -c user.name=t commit -q -m init ) >/dev/null 2>&1
  case "$3" in
    (docs) echo y > "$td/README.md"; git -C "$td" add README.md ;;
    (code) echo y > "$td/app.sh";    git -C "$td" add app.sh ;;
    (*) : ;;
  esac
  got=$( cd "$td" && source "$PLUGIN/hooks/governance-lib.sh" && _commit_scope_class )
  rm -rf "$td"
  if [ "$got" = "$1" ]; then PASS=$((PASS+1)); echo "PASS $2 ($got)"
  else FAIL=$((FAIL+1)); echo "FAIL $2 got=$got 기대=$1"; fi
}
_cls_sandbox docs-only "T-cls.g 무인자 staged=docs" docs
_cls_sandbox code      "T-cls.h 무인자 staged=code" code
_cls_sandbox empty     "T-cls.i 무인자 staged=none" none

# T-acls.a~h: _audit_scope_class — posttool 감사 스코프 분류 (20260814-friction-scope-posttool)
#   ★ is_docs_only_audit_scope 와 **같은 범위**(R-1 HEAD~1..HEAD / R-2 base...HEAD)를 쓰되
#     boolean 이 아니라 분류를 낸다. _commit_scope_class(staged 기준)는 posttool 이 커밋 **후**
#     발화하므로 쓸 수 없다 — --cached 가 비어 empty 로 오분류된다.
#   ★ 기대값 "" 는 **무출력 = 판정불가**다. 'empty'(커밋 범위가 실제로 빔)와 다른 축이다.
_acls_case() {  # $1 expect(""=무출력)  $2 label  $3 rule_id  $4 setup-eval
  local td got
  td=$(mktemp -d) || { FAIL=$((FAIL+1)); echo "FAIL $2 mktemp"; return; }
  ( cd "$td" && eval "$4" ) >/dev/null 2>&1
  got=$( cd "$td" && source "$PLUGIN/hooks/governance-lib.sh" && _audit_scope_class "$3" )
  rm -rf "$td"
  if [ "$got" = "$1" ]; then PASS=$((PASS+1)); echo "PASS $2 (${got:-<무출력>})"
  else FAIL=$((FAIL+1)); echo "FAIL $2 got=${got:-<무출력>} 기대=${1:-<무출력>}"; fi
}
_GC='-c user.email=e@t -c user.name=t'
_acls_case code "T-acls.a R-1 코드 커밋" R-1 \
  "git init -q; echo x > seed.md; git add seed.md; git $_GC commit -q -m init; \
   echo y > a.sh; git add a.sh; git $_GC commit -q -m code"
_acls_case docs-only "T-acls.b R-1 docs-only 커밋" R-1 \
  "git init -q; echo x > seed.md; git add seed.md; git $_GC commit -q -m init; \
   echo y > R.md; git add R.md; git $_GC commit -q -m docs"
_acls_case code "T-acls.c R-1 working-tree dirt 무영향" R-1 \
  "git init -q; echo x > seed.md; git add seed.md; git $_GC commit -q -m init; \
   echo y > a.sh; git add a.sh; git $_GC commit -q -m code; echo z > b.md"
_acls_case "" "T-acls.d R-1 최초 커밋(HEAD~1 부재) → 판정불가" R-1 \
  "git init -q; echo x > a.sh; git add a.sh; git $_GC commit -q -m init"
_acls_case empty "T-acls.e R-1 빈 커밋 → empty(판정불가 아님)" R-1 \
  "git init -q; echo x > seed.md; git add seed.md; git $_GC commit -q -m init; \
   git $_GC commit -q --allow-empty -m nothing"
_acls_case code "T-acls.f R-2 base...HEAD 코드" R-2 \
  "git init -q; git checkout -q -b main 2>/dev/null; echo b > b.md; git add b.md; \
   git $_GC commit -q -m init; git checkout -q -b feat; echo c > c.sh; git add c.sh; \
   git $_GC commit -q -m feat"
_acls_case "" "T-acls.g R-2 base 부재 → 판정불가" R-2 \
  "git init -q; git checkout -q -b solo 2>/dev/null; echo b > b.md; git add b.md; \
   git $_GC commit -q -m init"
_acls_case "" "T-acls.h 미지원 rule_id(R-3) → 판정불가" R-3 \
  "git init -q; echo x > a.sh; git add a.sh; git $_GC commit -q -m init"

# T-cls.j~m: log_friction_sev scope_class 선택 인자 (AC-5·AC-6)
_td=$(mktemp -d)
( cd "$_td" && mkdir -p .specops
  source "$PLUGIN/hooks/governance-lib.sh"
  log_friction_sev "20260101-cls" "R-1" 5 "snip-a" 7 "block" "code"
  log_friction_sev "20260101-cls" "R-1" 5 "snip-b" 7 "block" )
_L="$_td/.specops/20260101-cls/friction-log.jsonl"
# j: 7번째 인자 전달 시 기록
if jq -e 'select(.evidence_snippet=="snip-a" and .scope_class=="code")' "$_L" >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "PASS T-cls.j scope_class 기록"
else FAIL=$((FAIL+1)); echo "FAIL T-cls.j scope_class 미기록"; fi
# k: 인자 부재 시 필드 자체가 없어야 한다 (빈 문자열 기록 금지 — AC-6)
if jq -e 'select(.evidence_snippet=="snip-b" and (has("scope_class")|not))' "$_L" >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "PASS T-cls.k 인자 부재 → 필드 생략"
else FAIL=$((FAIL+1)); echo "FAIL T-cls.k 필드 생략 안 됨"; fi
# l: 기존 7필드 불변 (AC-5)
if [ "$(jq -r 'select(.evidence_snippet=="snip-b")|keys|join(",")' "$_L")" \
     = "evidence_snippet,fid,principle,rule_id,severity,transcript_offset,ts" ]; then
  PASS=$((PASS+1)); echo "PASS T-cls.l 기존 7필드 불변"
else FAIL=$((FAIL+1)); echo "FAIL T-cls.l 필드 구성 변경됨"; fi
rm -rf "$_td"

# m: dedup 키 불변 — scope_class 만 달라도 중복 제거 (AC-5)
_td=$(mktemp -d)
( cd "$_td" && mkdir -p .specops
  source "$PLUGIN/hooks/governance-lib.sh"
  log_friction_sev "20260101-dd" "R-1" 5 "same" 7 "block" "code"
  log_friction_sev "20260101-dd" "R-1" 5 "same" 7 "block" "docs-only" )
_n=$(grep -c . "$_td/.specops/20260101-dd/friction-log.jsonl" 2>/dev/null || echo 0)
rm -rf "$_td"
if [ "$_n" -eq 1 ]; then PASS=$((PASS+1)); echo "PASS T-cls.m dedup 키 불변 (1행)"
else FAIL=$((FAIL+1)); echo "FAIL T-cls.m dedup 깨짐 (${_n}행)"; fi

# T-cls.n2: log_friction(6번째 인자) 도 동일 동작 + 전역 fallback 보존 (AC-5·AC-7)
_td=$(mktemp -d)
( cd "$_td" && mkdir -p .specops
  source "$PLUGIN/hooks/governance-lib.sh"
  log_friction ""             "BYPASS-ENV" 1 "glob-a" 0 "docs-only"   # fid 빈값 → 전역 파일
  log_friction "20260101-lf"  "BYPASS-ENV" 1 "fid-a"  0 )             # 인자 부재 → 필드 생략
if jq -e 'select(.evidence_snippet=="glob-a" and .scope_class=="docs-only")' \
     "$_td/.specops/friction-log.jsonl" >/dev/null 2>&1 \
   && jq -e 'select(.evidence_snippet=="fid-a" and (has("scope_class")|not))' \
     "$_td/.specops/20260101-lf/friction-log.jsonl" >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "PASS T-cls.n2 log_friction 선택 인자 + 전역 fallback 보존"
else FAIL=$((FAIL+1)); echo "FAIL T-cls.n2 log_friction 확장 실패"; fi
rm -rf "$_td"

# T-cls.o: 분류 불가(git 아님) 상황에서도 기록은 성립하고 필드만 생략된다 (AC-6)
_td=$(mktemp -d)   # git init 하지 않음 → git diff 실패
( cd "$_td" && mkdir -p .specops
  source "$PLUGIN/hooks/governance-lib.sh"
  log_friction "20260101-ng" "BYPASS-ENV" 1 "no-git" 0 "$(_commit_scope_class)" ) 2>/dev/null
# ★ git 실패 = 판정 불가 → 필드 **생략**(빈 문자열 기록 금지). 'empty'(빈 커밋범위)와 구별된다.
#   기록 자체는 성립해야 한다 — 분류 실패가 감사 기록을 막지 않는다.
if jq -e 'select(.evidence_snippet=="no-git" and (has("scope_class")|not))' "$_td/.specops/20260101-ng/friction-log.jsonl" >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "PASS T-cls.o git 부재 → 필드 생략 + 기록 성립 (AC-6)"
else FAIL=$((FAIL+1)); echo "FAIL T-cls.o git 부재 처리 실패 (empty 로 뭉갰거나 미기록)"; fi
rm -rf "$_td"

# T-cls.p: 계측 전역이 이른 반환 경로에서 stale 로 남지 않는다 (Phase C Important 회귀 락)
#   선행 무인자 호출(batch 게이트)이 working-tree 목록으로 전역을 채운 뒤, staged 폼 본판정이
#   이른 반환하면 deny 경로가 **직전 목록**을 분류하던 결함. 실측: staged 빈데 code 로 기록됐다.
_td=$(mktemp -d)
_got=$( cd "$_td" && git init -q \
  && echo "echo orig" > app.sh && git add app.sh \
  && git -c user.email=e@t -c user.name=t commit -q -m init \
  && echo "echo changed" > app.sh \
  && ( source "$PLUGIN/hooks/governance-lib.sh"
       is_docs_only_change >/dev/null 2>&1                  # ① batch 게이트 = 무인자
       is_docs_only_change "$_G $_C -m x" >/dev/null 2>&1    # ② 본판정 = 이른 반환
       _commit_scope_class "${_SPECOPS_SCOPE_FILES:-}" ) )   # ③ deny 경로 분류
rm -rf "$_td"
if [ "$_got" = "empty" ]; then
  PASS=$((PASS+1)); echo "PASS T-cls.p 이른 반환 후 전역 stale 없음 ($_got)"
else
  FAIL=$((FAIL+1)); echo "FAIL T-cls.p stale 오염 — got=$_got 기대=empty"
fi

# T-cls.n: is_docs_only_change 가 판정 대상 목록을 노출한다
_td=$(mktemp -d)
_got=$( cd "$_td" && git init -q \
  && echo x > a.md && echo y > b.sh && git add a.md b.sh \
  && ( source "$PLUGIN/hooks/governance-lib.sh"; is_docs_only_change >/dev/null 2>&1
       printf '%s' "${_SPECOPS_SCOPE_FILES:-MISSING}" | tr '\n' ',' ) )
rm -rf "$_td"
case "$_got" in
  *a.md*|*b.sh*) PASS=$((PASS+1)); echo "PASS T-cls.n 목록 노출 ($_got)" ;;
  *) FAIL=$((FAIL+1)); echo "FAIL T-cls.n 목록 미노출 ($_got)" ;;
esac

# ── T-plug.a~k: 플러그인 런타임 .md 는 문서가 아니다 (FID 20260828-md-runtime-scope) ──
# 왜: 이 플러그인의 **실행 로직은 산문**이다(skills/*/SKILL.md·commands/*.md·agents/*.md).
#   `*.md` 를 무조건 문서로 보면 verify 강제가 제품 본체에서 통째로 면제된다 — 실측으로
#   최근 60커밋 중 41건이 면제 클래스였고 그중 22건이 실제 행동 변경이었다(릴리즈 스탬프 19 제외).
#   §auto 자기발급 면제표(v1.45.0 제거)보다 넓다 — 모델이 라벨을 쓸 필요조차 없었다.
# ★ 왜 플러그인 repo 조건을 다는가: 이 경로 지식은 Claude Code **플러그인 규약**이지 앱 규약이
#   아니다. 조건 없이 걸면 하류 앱 repo 의 `templates/email.md`·`docs/agents/x.md` 가 문서 커밋에서
#   차단되고, false-deny 는 정확히 BYPASS 관성을 만든다(마찰로그 24건/30일이 그 증거다).
#   `.claude-plugin/plugin.json` 존재 = "이 repo 에서 .md 는 런타임" 의 기계 판정이다.
# plugin.json 은 **먼저 커밋**한다 — staged 에 남기면 비-.md 파일이라 그것만으로 비면제가 되어
#   아래 케이스가 무엇을 증명하는지 알 수 없게 된다(초안에서 실제로 그렇게 새 PASS 가 났다).
_plug='mkdir -p .claude-plugin; echo "{}" > .claude-plugin/plugin.json; git add .claude-plugin; git "$C" -q -m plug;'
_docs_case 1 "T-plug.a 플러그인 repo skills/*/SKILL.md 비면제" \
  "git init -q; $_plug mkdir -p skills/foo; echo x>skills/foo/SKILL.md; git add skills"
_docs_case 1 "T-plug.b 플러그인 repo commands/*.md 비면제" \
  "git init -q; $_plug mkdir -p commands; echo x>commands/start.md; git add commands"
_docs_case 1 "T-plug.c 플러그인 repo agents/*.md 비면제" \
  "git init -q; $_plug mkdir -p agents; echo x>agents/r.md; git add agents"
_docs_case 1 "T-plug.d 플러그인 repo templates/*.md 비면제(하류로 배포되는 산출물)" \
  "git init -q; $_plug mkdir -p templates; echo x>templates/spec.md; git add templates"
_docs_case 1 "T-plug.e 플러그인 repo .claude-plugin/* 비면제" \
  "git init -q; mkdir -p .claude-plugin; echo '{}'>.claude-plugin/plugin.json; git add .claude-plugin"
# 면제 유지 축 — 진짜 문서까지 막으면 BYPASS 관성이 생긴다
_docs_case 0 "T-plug.f 플러그인 repo docs/*.md 면제 유지" \
  "git init -q; $_plug mkdir -p docs; echo x>docs/a.md; git add docs"
_docs_case 0 "T-plug.g 플러그인 repo 루트 README/CHANGELOG/CLAUDE 면제 유지" \
  "git init -q; $_plug echo x>README.md; echo y>CHANGELOG.md; echo z>CLAUDE.md; git add README.md CHANGELOG.md CLAUDE.md"
_docs_case 0 "T-plug.h 플러그인 repo skills/*/README.md 면제(SKILL.md 만 런타임)" \
  "git init -q; $_plug mkdir -p skills/foo; echo x>skills/foo/README.md; git add skills"
# ★ 하류 오차단 방지 축 — plugin.json 없으면 종전과 동일하게 동작한다
_docs_case 0 "T-plug.i 비플러그인 repo templates/*.md 면제(하류 오차단 방지)" \
  "git init -q; mkdir -p templates; echo x>templates/email.md; git add templates"
_docs_case 0 "T-plug.j 비플러그인 repo skills/*/SKILL.md 면제(경로 지식 미주입)" \
  "git init -q; mkdir -p skills/foo; echo x>skills/foo/SKILL.md; git add skills"
# ★ 면제 클래스 ≡ 분류 클래스 불변식 (governance-lib.sh:481) — posttool 계측 축도 함께 움직여야 한다
_td=$(mktemp -d)
_got=$( cd "$_td" && git init -q && mkdir -p .claude-plugin skills/foo \
  && echo '{}' > .claude-plugin/plugin.json && git add .claude-plugin \
  && git -c user.email=t@e -c user.name=t commit -q -m plug \
  && echo x > skills/foo/SKILL.md && git add skills \
  && ( source "$PLUGIN/hooks/governance-lib.sh"; _commit_scope_class ) )
rm -rf "$_td"
if [ "$_got" = "code" ]; then PASS=$((PASS+1)); echo "PASS T-plug.k _commit_scope_class 도 code (면제≡분류 불변식)"
else FAIL=$((FAIL+1)); echo "FAIL T-plug.k 분류=$_got 기대=code (계측이 면제 클래스와 어긋남)"; fi

# ── T-fx.a~e: 테스트 fixture FID 는 활성 FID 후보에서 제외한다 (FID 20260829-fixture-fid-hijack) ──
# 왜: /e2e-test 는 session-progress 에 fixture FID 섹션을 **prepend** 하고, detect_fid 의 2순위
#   fallback 은 "첫 ## <FID> 헤더" 다. 그래서 e2e 를 한 번 돌리면 fixture 가 repo 의 활성 FID 가
#   되고, **이후 모든 커밋이 fixture 의 verify 상태를 대신 answer** 해야 한다(R-1 ②앵커).
#   게다가 fixture 테스트는 `.specops/<FID>/*.sh` 라 run-verification 실행 whitelist 밖이어서
#   구조적으로 PASS 를 낼 수 없다 → 빠져나갈 정직 경로가 없다(이번 세션 BYPASS 3건의 원인).
# 판별자는 `.specops/<FID>/.fixture` 마커 파일이다 — 산문·헤더 파싱이 아니라 파일 존재라서
#   섹션 포맷 변화에 영향받지 않고, 후보당 test 1회라 hot path 비용이 없다.
# ★ 1순위 active-fid 마커는 건드리지 않는다: 사용자가 fixture 를 **명시적으로** 지목했다면
#   그건 의도다(주권). 제외는 "아무도 지목 안 했을 때의 추측"인 2순위에만 적용한다.
_fid_case() {  # $1 expect $2 label $3 setup
  local exp="$1" label="$2" setup="$3" got
  got=$( sb=$(mktemp -d) && cd "$sb" && eval "$setup" \
         && ( source "$PLUGIN/hooks/governance-lib.sh"; detect_fid ) ; cd /; rm -rf "$sb" )
  if [ "$got" = "$exp" ]; then PASS=$((PASS+1)); echo "PASS $label"
  else FAIL=$((FAIL+1)); echo "FAIL $label — got='$got' 기대='$exp'"; fi
}

_sp() {  # 섹션 헤더들을 순서대로 써 넣는다
  mkdir -p .specops
  : > .specops/session-progress.md
  for f in "$@"; do
    printf '## %s\n\n- 2026-01-01 10:00 /verify PASS\n\n' "$f" >> .specops/session-progress.md
  done
}

_fid_case 20260101-real "T-fx.a fixture 마커 없으면 종전대로 첫 헤더" \
  '_sp 20260101-real 20260102-other; mkdir -p .specops/20260101-real'

_fid_case 20260102-real "T-fx.b ★ 선두가 fixture 면 건너뛰고 다음 실작업 FID" \
  '_sp 20260101-e2e 20260102-real; mkdir -p .specops/20260101-e2e .specops/20260102-real; : > .specops/20260101-e2e/.fixture'

_fid_case "" "T-fx.c 전부 fixture 면 빈 값 (없는 FID 를 지어내지 않는다)" \
  '_sp 20260101-e2e 20260102-e2e; mkdir -p .specops/20260101-e2e .specops/20260102-e2e; : > .specops/20260101-e2e/.fixture; : > .specops/20260102-e2e/.fixture'

_fid_case 20260101-e2e "T-fx.d 명시 active-fid 마커는 fixture 라도 존중 (주권)" \
  '_sp 20260102-real; mkdir -p .specops/20260101-e2e; : > .specops/20260101-e2e/.fixture; printf "<!-- active-fid: 20260101-e2e -->\n%s" "$(cat .specops/session-progress.md)" > .specops/session-progress.md'

_fid_case 20260101-real "T-fx.e .specops/<FID> 디렉토리 부재는 fixture 아님 (오탐 차단)" \
  '_sp 20260101-real 20260102-other'

echo
echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
