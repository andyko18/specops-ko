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

echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
