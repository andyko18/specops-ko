#!/usr/bin/env bash
# test-propagation-teeth.sh — propagation-env-pin edge 의 판별력 (20260831-propagation-contract-record)
#
# 왜 별도 파일인가: 이 스위트는 `test-propagation.sh` 와 `.githooks/pre-commit` 의 **배선을 변이**해
#   edge 가 실제로 격추되는지 본다. 그런데 잠금 패턴을 **잠금 대상 파일 안에** 쓰면 그 문자열
#   자체가 매치해, 실제 배선을 지워도 edge 가 green 이 된다(자기참조 false-match).
#   **잠금을 시험하는 코드는 잠금 대상 밖에 산다.** `test-hardgate-ratchet.sh` 와 동형.
#   이 파일을 `test-propagation.sh` 로 합치지 마라 — 합치는 순간 아래 전부가 공허해진다.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }

CHK="$PLUGIN/scripts/_internal/check-propagation.sh"
MATRIX="$PLUGIN/scripts/_internal/propagation-matrix.jsonl"
TP="scripts/tests/test-propagation.sh"
HK=".githooks/pre-commit"
[ -f "$CHK" ] || { nope "T0" "checker 부재"; finish; }
[ -f "$MATRIX" ] || { nope "T0" "matrix 부재"; finish; }

bak=$(mktemp) || exit 1

# 변이 → 체커 실행 → 복원. $1=대상(PLUGIN 상대 경로) $2=python 치환 본문
# ★ 중단 안전: 실 트리를 건드리므로 백업 + EXIT 단독 trap
#   (INT/TERM 병기 금지 — handler delay 를 유발한다. 20260809 실측)
_mutate_run() {
  cp "$PLUGIN/$1" "$bak"
  # shellcheck disable=SC2064
  trap "cp '$bak' '$PLUGIN/$1'" EXIT
  python3 - "$PLUGIN/$1" <<PYEOF
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
$2
open(p, 'w', encoding='utf-8').write(s)
PYEOF
  out=$(cd "$PLUGIN" && SPECOPS_PROPAGATION_MATRIX= bash "$CHK" 2>&1); rc=$?
  cp "$bak" "$PLUGIN/$1"
  trap - EXIT
  printf '%s' "$out"
  return "$rc"
}

# 체커 출력은 `echo "PROPAGATION: FAIL [$id] $path missing /$pat/"` 로 **런타임 조립**된다.
#   통짜 리터럴을 grep 하면 사전검사가 dangling-lock 으로 잡으므로 조각만 쓴다.
_faillines() { printf '%s\n' "$1" | grep 'PROPAGATION: FAIL' | grep 'missing'; }

# ── T1.a: pre-commit 핀 제거 → 그 edge 만 격추 ──
m=$(_mutate_run "$HK" 's = s.replace("cp_out=$(SPECOPS_PROPAGATION_MATRIX= bash", "cp_out=$(bash")'); rc=$?
fl=$(_faillines "$m"); n=$(printf '%s\n' "$fl" | grep -c .)
if [ "$rc" -ne 0 ] && [ "${n:-0}" -eq 1 ] && printf '%s' "$fl" | grep -q 'githooks/pre-commit'; then
  ok "T1.a pre-commit 핀 제거 → 해당 edge 만 격추 (AC-2 a)"
else
  nope "T1.a" "rc=$rc n=${n:-0} / $fl"
fi

# ── T1.b: test-propagation P3 핀 제거 → 그 edge 만 격추 ──
m=$(_mutate_run "$TP" 's = s.replace("out=$(SPECOPS_PROPAGATION_MATRIX= bash \"$CHK\"", "out=$(bash \"$CHK\"")'); rc=$?
fl=$(_faillines "$m"); n=$(printf '%s\n' "$fl" | grep -c .)
if [ "$rc" -ne 0 ] && [ "${n:-0}" -eq 1 ] \
   && printf '%s' "$fl" | grep -q 'test-propagation.sh' \
   && printf '%s' "$fl" | grep -q 'SPECOPS_PROPAGATION_MATRIX'; then
  ok "T1.b P3 핀 제거 → 해당 edge 만 격추 (AC-2 b)"
else
  nope "T1.b" "rc=$rc n=${n:-0} / $fl"
fi

# ── T1.c: P10(핀의 이빨) 제거 → 그 edge 격추 ──
#   핀 자체는 남아 있다. 즉 "핀만 잠갔다면 감시자 소실이 무음이었다"가 증명된다.
m=$(_mutate_run "$TP" 's = s.replace("P10_HOOK", "P10_RENAMED_PROBE")'); rc=$?
fl=$(_faillines "$m"); n=$(printf '%s\n' "$fl" | grep -c .)
if [ "$rc" -ne 0 ] && [ "${n:-0}" -eq 1 ] && printf '%s' "$fl" | grep -q 'P10_HOOK'; then
  ok "T1.c P10 이빨 제거 → 격추 (핀만 잠갔다면 무음이었다, AC-2 c)"
else
  nope "T1.c" "rc=$rc n=${n:-0} / $fl"
fi

# ── T1.d: AC-5 방향성 단언 — 절대 건수를 세지 않는다 ──
#   건수는 픽스처 호출이 늘면 stale 이 된다(이 FID 가 지우는 173 하드코딩과 같은 클래스).
#   핀을 지운 사본에서 **채택 패턴은 사라지고 기각 패턴은 살아남는지**만 본다.
mut=$(mktemp) || exit 1
sed 's/^out=\$(SPECOPS_PROPAGATION_MATRIX= bash "\$CHK"/out=$(bash "$CHK"/' "$PLUGIN/$TP" > "$mut"
adopted=$(grep -cE '^out=\$\(SPECOPS_PROPAGATION_MATRIX= bash' "$mut")
rej_plain=$(grep -cE 'SPECOPS_PROPAGATION_MATRIX= bash' "$mut")
rej_wide=$(grep -cE 'out=\$\(SPECOPS_PROPAGATION_MATRIX=' "$mut")
rm -f "$mut"
if [ "${adopted:-1}" -eq 0 ] && [ "${rej_plain:-0}" -ge 1 ] && [ "${rej_wide:-0}" -ge 1 ]; then
  ok "T1.d 핀 제거 시 채택=0 · 기각(평문·광의)≥1 — 기각 패턴이었다면 무음 (AC-5)"
else
  nope "T1.d" "adopted=$adopted rej_plain=$rej_plain rej_wide=$rej_wide"
fi

# ── T1.e: 원장의 핀 패턴이 행두 앵커인가 (FR-2) ──
#   비앵커로 "단순화"하면 cp_out= 이 out= 패턴을 뚫어 두 edge 가 서로를 만족시킨다.
anchored=$(jq -rs 'map(select(.id=="propagation-env-pin").edges[].must_match)
  | map(select(startswith("^"))) | length' "$MATRIX")
if [ "${anchored:-0}" -eq 2 ]; then
  ok "T1.e 핀 edge 2종이 행두 앵커 유지 (FR-2)"
else
  nope "T1.e" "앵커 패턴 ${anchored:-0}건 (기대 2) — 비앵커화는 자기참조 매치를 연다"
fi

rm -f "$bak"
finish
