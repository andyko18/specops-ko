#!/usr/bin/env bash
# mutation-score.sh 하니스 로직 stub 단위 (토큰 0)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck disable=SC1091
source "$PLUGIN/scripts/tests/mutation-score.sh"
ck() { if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS+1)); else echo "FAIL $1 — exp '$3' got '$2'"; FAIL=$((FAIL+1)); fi; }

ck "T1 score 8/2 → 80" "$(mut::score 8 2)" "80"
ck "T2 score 0/0 → 0"  "$(mut::score 0 0)" "0"
ck "T3 score 10/0 → 100" "$(mut::score 10 0)" "100"

n=$(mut::catalog | grep -c .)
if [ "$n" -ge 5 ]; then echo "PASS T4 catalog ≥5 ($n)"; PASS=$((PASS+1)); else echo "FAIL T4 catalog <5 ($n)"; FAIL=$((FAIL+1)); fi

ck "T5 judge fail→killed" "$(mut::judge 'exit 1')" "killed"
ck "T6 judge pass→survived" "$(mut::judge 'exit 0')" "survived"

tmp=$(mktemp -d)
cat > "$tmp/tgt.sh" <<'EOS'
#!/usr/bin/env bash
check() { [ "$1" -eq 0 ] && echo ok || echo no; }
check "$@"
EOS
orig_hash=$(md5 -q "$tmp/tgt.sh" 2>/dev/null || md5sum "$tmp/tgt.sh" | cut -d' ' -f1)
out=$(mut::run_target "$tmp/tgt.sh" "bash $tmp/tgt.sh 0 | grep -q ok" 2>/dev/null)
after_hash=$(md5 -q "$tmp/tgt.sh" 2>/dev/null || md5sum "$tmp/tgt.sh" | cut -d' ' -f1)
ck "T7 복원 무결성 (변형 잔류 0)" "$after_hash" "$orig_hash"
if printf '%s' "$out" | grep -q "MUTATION .*score="; then echo "PASS T8 리포트 형식"; PASS=$((PASS+1)); else echo "FAIL T8 리포트 ($out)"; FAIL=$((FAIL+1)); fi

cat > "$tmp/syn.sh" <<'EOS'
#!/usr/bin/env bash
echo foo
EOS
mut::catalog() { printf 'foo\ts/foo/(/\n'; }
out2=$(mut::run_target "$tmp/syn.sh" "true" 2>/dev/null)
unset -f mut::catalog; source "$PLUGIN/scripts/tests/mutation-score.sh"
if printf '%s' "$out2" | grep -qE "invalid=[1-9]" && printf '%s' "$out2" | grep -q "killed=0 survived=0"; then
  echo "PASS T9 invalid 결정적 집계 (score 분모 제외)"; PASS=$((PASS+1))
else echo "FAIL T9 invalid ($out2)"; FAIL=$((FAIL+1)); fi
rm -rf "$tmp"

out3=$(mut::run_target "/nonexistent/tgt.sh" "true" 2>/dev/null)
if printf '%s' "$out3" | grep -q "SKIP"; then echo "PASS T10 target 부재 SKIP"; PASS=$((PASS+1)); else echo "FAIL T10 SKIP ($out3)"; FAIL=$((FAIL+1)); fi

# T11 equivalent 제외 — config 매칭 (target,line,pattern) 변형은 equivalent 카운트 + 분모 제외
tmpe=$(mktemp -d)
cat > "$tmpe/tgt.sh" <<'EOS'
#!/usr/bin/env bash
f() { [ -f "$1" ] || return 0; echo found; }
f "$@"
EOS
cat > "$tmpe/eqv.conf" <<EOS
$tmpe/tgt.sh|2|return 0|test stub equivalent
EOS
if MUT_EQUIV_CONF="$tmpe/eqv.conf" mut::is_equivalent "$tmpe/tgt.sh" 2 "return 0"; then echo "PASS T11 is_equivalent 매칭"; PASS=$((PASS+1)); else echo "FAIL T11"; FAIL=$((FAIL+1)); fi
if MUT_EQUIV_CONF="$tmpe/eqv.conf" mut::is_equivalent "$tmpe/tgt.sh" 2 "&&"; then echo "FAIL T12 다른 pattern 매칭됨"; FAIL=$((FAIL+1)); else echo "PASS T12 pattern 정밀 미매칭"; PASS=$((PASS+1)); fi
if MUT_EQUIV_CONF="/nonexistent" mut::is_equivalent "$tmpe/tgt.sh" 2 "return 0"; then echo "FAIL T13 config 부재 매칭됨"; FAIL=$((FAIL+1)); else echo "PASS T13 config 부재 graceful"; PASS=$((PASS+1)); fi
out=$(MUT_EQUIV_CONF="$tmpe/eqv.conf" mut::run_target "$tmpe/tgt.sh" "true" 2>/dev/null)
if printf '%s' "$out" | grep -qE "equivalent=[0-9]+"; then echo "PASS T14 리포트 equivalent="; PASS=$((PASS+1)); else echo "FAIL T14 ($out)"; FAIL=$((FAIL+1)); fi
rm -rf "$tmpe"

# threshold + baseline sanity (20260714-mutation-ci-gate) — cron 게이트 로직 회귀 잠금
tmpt=$(mktemp -d)
printf '#!/bin/bash\necho hi\n' > "$tmpt/t.sh"
printf '%s|true\n' "$tmpt/t.sh" > "$tmpt/c.conf"
# T15 MUTATION_MIN_SCORE 미설정 → exit 0 (하위호환 — 측정만)
( bash "$PLUGIN/scripts/tests/mutation-score.sh" "$tmpt/c.conf" >/dev/null 2>&1 ); ck "T15 threshold 미설정 → exit 0" "$?" "0"
# T16 MIN=50, mutant 0 → score 0% < 50 → exit 1 (미달 차단)
( MUTATION_MIN_SCORE=50 bash "$PLUGIN/scripts/tests/mutation-score.sh" "$tmpt/c.conf" >/dev/null 2>&1 ); ck "T16 MIN 미달 → exit 1" "$?" "1"
# T17 ★ baseline sanity — 무변형에서 testcmd 파손(false)이면 MUT_BELOW_MIN=1 (score 거짓통과 차단)
MUT_BELOW_MIN=0
mut::run_target "$tmpt/t.sh" "false" >/dev/null 2>&1
ck "T17 sanity 파손 testcmd → MUT_BELOW_MIN=1" "$MUT_BELOW_MIN" "1"
rm -rf "$tmpt"

# ── T18~T27: conf stale 감지 · 주석 skip (FID 20260827-mutation-conf-stale) ──
tmps=$(mktemp -d); trap 'rm -rf "$tmps"' EXIT

# fixture target: 3줄이 변이 후보 — L3 코드, L4 주석, L5 인라인주석 코드
cat > "$tmps/tgt.sh" <<'FIX'
#!/usr/bin/env bash
f1() {
  [ -n "${1:-}" ] && return 0
  # 주석: [ -z "$x" ] && return 0 — 변이돼선 안 된다
  [ "$2" = "y" ] && return 0  # 인라인 주석 — 이 줄은 코드다
}
FIX

# T18 주석 판정 — 선행 공백 제거 후 첫 문자
mut::is_comment_line '  # foo'      && r1=0 || r1=1
mut::is_comment_line '[ x ] && y # z' && r2=0 || r2=1
if [ "$r1" = 0 ] && [ "$r2" = 1 ]; then
  echo "PASS T18 주석 판정 — 선행공백 주석=참, 인라인#=거짓"; PASS=$((PASS+1))
else echo "FAIL T18 (r1=$r1 r2=$r2)"; FAIL=$((FAIL+1)); fi

# T19 주석 줄은 변이 사이트가 아니다 (AC-2) — L4 의 'return 0' 은 집계 0
out=$(MUT_EQUIV_CONF=/nonexistent mut::run_target "$tmps/tgt.sh" "true" 2>/dev/null)
tot=$(printf '%s' "$out" | sed -n 's/.*killed=\([0-9]*\) survived=\([0-9]*\) invalid=\([0-9]*\) equivalent=\([0-9]*\).*/\1+\2+\3+\4/p')
tot=$(( $(echo "${tot:-0+0+0+0}") ))
# 변이 후보: L3 'return 0'+'&&', L5 'return 0'+'&&' = 4 (L4 주석 2건 제외)
if [ "$tot" = 4 ]; then echo "PASS T19 주석 줄 제외 — 집계 4건 (AC-2)"; PASS=$((PASS+1));
else echo "FAIL T19 집계 $tot (기대 4 — 주석 L4 가 섞였나?)"; FAIL=$((FAIL+1)); fi

# T20 인라인 # 코드 줄은 정상 변이 (AC-3) — L5 를 가리키는 equivalent 가 매칭되면 사이트가 살아 있다는 뜻
printf '%s\n' "$tmps/tgt.sh|5|return 0|inline-comment 코드 줄" > "$tmps/eq-ok.conf"
out=$(MUT_EQUIV_CONF="$tmps/eq-ok.conf" mut::run_target "$tmps/tgt.sh" "true" 2>/dev/null)
if printf '%s' "$out" | grep -q 'equivalent=1'; then
  echo "PASS T20 인라인 # 코드 줄 변이 유지 (AC-3)"; PASS=$((PASS+1))
else echo "FAIL T20 ($out)"; FAIL=$((FAIL+1)); fi

# T21 site_exists — 정상/주석/부재
mut::site_exists "$tmps/tgt.sh" 3 'return 0' && s1=0 || s1=1
mut::site_exists "$tmps/tgt.sh" 4 'return 0' && s2=0 || s2=1
mut::site_exists "$tmps/tgt.sh" 999 'return 0' && s3=0 || s3=1
if [ "$s1" = 0 ] && [ "$s2" = 1 ] && [ "$s3" = 1 ]; then
  echo "PASS T21 site_exists — 코드=참 주석=거짓 범위밖=거짓"; PASS=$((PASS+1))
else echo "FAIL T21 (s1=$s1 s2=$s2 s3=$s3)"; FAIL=$((FAIL+1)); fi

# T22 stale 감지 양성 (AC-4)
printf '%s\n' "$tmps/tgt.sh|1|return 0|stale — L1 은 shebang" > "$tmps/eq-stale.conf"
printf '%s\n' "$tmps/tgt.sh|true" > "$tmps/tg.conf"
err=$(MUT_EQUIV_CONF="$tmps/eq-stale.conf" mut::check_conf "$tmps/tg.conf" 2>&1); rc=$?
if [ "$rc" != 0 ] && printf '%s' "$err" | grep -q 'STALE'; then
  echo "PASS T22 stale 감지 양성 (AC-4)"; PASS=$((PASS+1))
else echo "FAIL T22 rc=$rc out=$err"; FAIL=$((FAIL+1)); fi

# T23 stale 음성 — 정상 conf 는 무발화 (AC-5)
err=$(MUT_EQUIV_CONF="$tmps/eq-ok.conf" mut::check_conf "$tmps/tg.conf" 2>&1); rc=$?
if [ "$rc" = 0 ] && ! printf '%s' "$err" | grep -q 'STALE'; then
  echo "PASS T23 정상 conf 무발화 (AC-5)"; PASS=$((PASS+1))
else echo "FAIL T23 rc=$rc out=$err"; FAIL=$((FAIL+1)); fi

# T24 오발 방지 — conf 에 항목 없는 target (AC-6) + conf 부재 graceful (D-8)
printf '%s\n' "$tmps/other.sh|true" > "$tmps/tg2.conf"
cp "$tmps/tgt.sh" "$tmps/other.sh"
err=$(MUT_EQUIV_CONF="$tmps/eq-stale.conf" mut::check_conf "$tmps/tg2.conf" 2>&1); rc1=$?
# err2 는 stdout·stderr 를 삼켜 리포트를 더럽히지 않기 위한 버림 변수다 — 판정은 rc2 만 쓴다.
# shellcheck disable=SC2034
err2=$(MUT_EQUIV_CONF=/nonexistent mut::check_conf "$tmps/tg.conf" 2>&1); rc2=$?
if [ "$rc1" = 0 ] && [ "$rc2" = 0 ]; then
  echo "PASS T24 무관 target·conf 부재 오발 없음 (AC-6·D-8)"; PASS=$((PASS+1))
else echo "FAIL T24 rc1=$rc1 rc2=$rc2"; FAIL=$((FAIL+1)); fi

# T25 --check-conf 독립 모드 (AC-10) — 실 스크립트 서브프로세스
_MS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mutation-score.sh"
o=$(MUT_EQUIV_CONF="$tmps/eq-ok.conf" bash "$_MS" --check-conf "$tmps/tg.conf" 2>&1); rc=$?
if [ "$rc" = 0 ] && printf '%s' "$o" | grep -q 'CONF-CHECK'; then
  echo "PASS T25 --check-conf 정합 시 rc=0 (AC-10)"; PASS=$((PASS+1))
else echo "FAIL T25 rc=$rc out=$o"; FAIL=$((FAIL+1)); fi

o=$(MUT_EQUIV_CONF="$tmps/eq-stale.conf" bash "$_MS" --check-conf "$tmps/tg.conf" 2>&1); rc=$?
if [ "$rc" != 0 ] && printf '%s' "$o" | grep -q 'STALE'; then
  echo "PASS T26 --check-conf stale 시 rc≠0 (AC-10)"; PASS=$((PASS+1))
else echo "FAIL T26 rc=$rc out=$o"; FAIL=$((FAIL+1)); fi

# T27 fail-fast — stale 이면 채점 줄이 없다 + 5초 이내 (AC-9)
_t0=$SECONDS
o=$(MUT_EQUIV_CONF="$tmps/eq-stale.conf" bash "$_MS" "$tmps/tg.conf" 2>&1); rc=$?
_el=$(( SECONDS - _t0 ))
# ★ ABORT 도 함께 요구한다 — rc≠0 + MUTATION 부재만 보면 stale 무관 실패(러너 문법 파손 등)에도
#   통과해 fail-fast 회귀를 놓친다. AC-9 의 4요건(ABORT·채점줄 부재·rc≠0·5초 이내)을 모두 잠근다.
# ★ 경과시간까지 보는 이유 — "채점 줄 부재" 는 채점이 **끝까지 돌고 마지막에** 막혀도 성립한다.
#   fail-fast 는 judge **앞에서** 끊는 것이므로 시간이 유일한 직접 증거다.
if [ "$rc" != 0 ] && [ "$_el" -lt 5 ] && printf '%s' "$o" | grep -q 'ABORT' && ! printf '%s' "$o" | grep -q '^MUTATION '; then
  echo "PASS T27 fail-fast — ABORT + 채점 미진입 + ${_el}s (AC-9)"; PASS=$((PASS+1))
else echo "FAIL T27 rc=$rc elapsed=${_el}s out=$o"; FAIL=$((FAIL+1)); fi

# T28 빈 pattern 행은 stale 이다 (AC-4 잔여 구멍) — `target|line|` 처럼 pattern 이 비면
#   site_exists 의 `grep -qF -- ""` 가 아무 비어있지 않은 줄에나 매칭해 **건강하다고 오보**한다.
#   그런 행은 is_equivalent 키(`t|l|p|`)에 절대 안 맞는 죽은 항목이므로 stale 로 잡아야 한다.
printf '%s\n' "$tmps/tgt.sh|2|" > "$tmps/eq-empty.conf"
err=$(MUT_EQUIV_CONF="$tmps/eq-empty.conf" mut::check_conf "$tmps/tg.conf" 2>&1); rc=$?
if [ "$rc" != 0 ] && printf '%s' "$err" | grep -q 'STALE'; then
  echo "PASS T28 빈 pattern 행 stale 판정 (AC-4 잔여 구멍)"; PASS=$((PASS+1))
else echo "FAIL T28 rc=$rc out=$err"; FAIL=$((FAIL+1)); fi

echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
