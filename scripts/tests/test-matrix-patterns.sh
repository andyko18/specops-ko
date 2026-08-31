#!/usr/bin/env bash
# test-matrix-patterns.sh — check-matrix-patterns.sh 의 판별력 (20260831-matrix-pattern-lint)
#
# 왜 별도 파일인가: lint 를 시험하려면 **위반이 있는 원장**이 필요한데, 그걸 실 원장에 넣으면
#   전 커밋이 막힌다. 픽스처 원장(아래 heredoc)으로 lint 를 돌린다 — 픽스처는 이 파일 안에
#   있고 이 파일은 lint 의 **검사 대상이 아니다**(lint 는 원장의 edge 가 가리키는 파일을 본다).
#   즉 자기참조 false-match 가 구조적으로 불가능하다.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }

LINT="$PLUGIN/scripts/_internal/check-matrix-patterns.sh"
[ -f "$LINT" ] || { nope "M0" "lint 부재"; finish; }

tmp=$(mktemp -d) || exit 1
# shellcheck disable=SC2064
trap "rm -rf '$tmp'" EXIT   # ★ EXIT 단독 (INT/TERM 병기 금지 — handler delay, 20260809 실측)

_lint_run() {  # $1=픽스처 경로 → stdout=출력, return=rc
  local out rc
  out=$(cd "$PLUGIN" && bash "$LINT" "$1" 2>&1); rc=$?
  printf '%s' "$out"
  return "$rc"
}

# ── M1: 주석 전용 패턴 → 위반으로 잡는다 (AC-1) ──
#   governance-lib.sh 의 `task receipt 필수` 는 L989 주석 1줄에만 있다(실측).
printf '%s\n' '{"id":"fx-comment-only","edges":[{"path":"hooks/governance-lib.sh","must_match":"task receipt 필수"}]}' > "$tmp/comment-only.jsonl"
m1=$(_lint_run "$tmp/comment-only.jsonl"); m1_rc=$?
if [ "$m1_rc" -ne 0 ] \
   && printf '%s' "$m1" | grep -q 'fx-comment-only' \
   && printf '%s' "$m1" | grep -q 'governance-lib.sh'; then
  ok "M1 주석 전용 패턴 → 위반 (id·경로 노출, AC-1)"
else
  nope "M1" "rc=$m1_rc / $m1"
fi

# ── M2: 실코드 매치 패턴 → 통과 (AC-1 음성 대조) ──
printf '%s\n' '{"id":"fx-code","edges":[{"path":"hooks/governance-lib.sh","must_match":"_CHECK_TASK_RECEIPT_SH"}]}' > "$tmp/code.jsonl"
m2=$(_lint_run "$tmp/code.jsonl"); m2_rc=$?
if [ "$m2_rc" -eq 0 ] && printf '%s' "$m2" | grep -q 'MATRIX-PATTERN: OK'; then
  ok "M2 실코드 매치 → 통과 (음성 대조)"
else
  nope "M2" "rc=$m2_rc / $m2"
fi

# ── M3: 주석 앵커는 선언으로 인정 (AC-3) ──
#   M1 과 **같은 파일·같은 문구**인데 앵커만 붙였다 — 인정 여부가 패턴 형태로만 갈린다.
printf '%s\n' '{"id":"fx-anchored","edges":[{"path":"hooks/governance-lib.sh","must_match":"^[[:space:]]*#.*task receipt 필수"}]}' > "$tmp/anchored.jsonl"
m3=$(_lint_run "$tmp/anchored.jsonl"); m3_rc=$?
if [ "$m3_rc" -eq 0 ] && printf '%s' "$m3" | grep -q 'MATRIX-PATTERN: OK'; then
  ok "M3 주석 앵커 → 선언으로 인정 (면제 필드 없이, AC-3)"
else
  nope "M3" "rc=$m3_rc / $m3"
fi

# ── M4: 산문(.md) skip + 건수 노출 (AC-2) ──
#   .md 는 전체가 산문이라 "주석 전용" 판정이 정의되지 않는다. 조용히 빼지 않고 숫자로 낸다.
printf '%s\n' '{"id":"fx-md","edges":[{"path":"scripts/README.md","must_match":"propagation-matrix"}]}' > "$tmp/md.jsonl"
#   어서션은 **숫자를 파싱해 비교**한다 — 출력 문구는 런타임 조립이라 통짜 리터럴을 grep 하면
#   사전검사가 dangling-lock 으로 잡는다(그 문자열은 repo 어디에도 없다).
m4=$(_lint_run "$tmp/md.jsonl"); m4_rc=$?
m4_chk=$(printf '%s' "$m4" | sed -n 's/.*검사 \([0-9]*\) .*/\1/p')
m4_skp=$(printf '%s' "$m4" | sed -n 's/.*skip \([0-9]*\).*/\1/p')
if [ "$m4_rc" -eq 0 ] && [ "${m4_chk:-x}" -eq 0 ] 2>/dev/null && [ "${m4_skp:-0}" -eq 1 ] 2>/dev/null; then
  ok "M4 산문(.md) 은 검사 0 · skip 1 — 조용히 빼지 않고 숫자로 낸다 (AC-2)"
else
  nope "M4" "rc=$m4_rc 검사=${m4_chk:-미파싱} skip=${m4_skp:-미파싱} / $m4"
fi

# ── M5: 실 원장이 위반 0 (AC-4 — 무음 2건이 교체됐다) ──
m5=$(_lint_run "$PLUGIN/scripts/_internal/propagation-matrix.jsonl"); m5_rc=$?
if [ "$m5_rc" -eq 0 ] && printf '%s' "$m5" | grep -q 'MATRIX-PATTERN: OK'; then
  ok "M5 실 원장 위반 0 (AC-4)"
else
  nope "M5" "rc=$m5_rc / $m5"
fi

# ── M6: 게이팅 계약 — 실 원장의 검사/skip 건수가 실측 분포와 일치 (AC-2) ──
#   숫자를 박지 않는다(원장이 늘면 stale). **검사+skip = 전체 edge 수** 항등만 단언한다.
tot=$(jq -rs 'map(.edges|length)|add' "$PLUGIN/scripts/_internal/propagation-matrix.jsonl")
n_chk=$(printf '%s' "$m5" | sed -n 's/.*검사 \([0-9]*\) .*/\1/p')
n_skp=$(printf '%s' "$m5" | sed -n 's/.*skip \([0-9]*\).*/\1/p')
if [ -n "${n_chk:-}" ] && [ -n "${n_skp:-}" ] && [ $((n_chk + n_skp)) -eq "${tot:-0}" ]; then
  ok "M6 검사+skip = 전체 edge 수 ($n_chk + $n_skp = $tot) — 조용히 빠뜨린 edge 0 (AC-2)"
else
  nope "M6" "검사=$n_chk skip=$n_skp 전체=$tot — 합이 안 맞으면 어딘가 조용히 누락됐다"
fi

finish
