#!/usr/bin/env bash
# test-queue-set-status.sh — queue.md Status 기계 갱신 검증 (FID 20260828-queue-label-drift)
#
# 계기: argus batch-20260729 실측. 종전 갱신 경로는 start-all.md 산문 지시를 받은
#   **모델 손편집**뿐이었고, 모델이 `**IMPL_DONE**` 로 적자 소비자 3곳이 전건 불일치해
#   산출물·review-skip 검사가 **대상 0건으로 조용히 통과**했다(FR 31건 무검증).
#   읽는 쪽 정규화(queue-lib)가 사후 방어라면, 이 스크립트는 유입 자체를 끊는다.
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SCRIPT="$PLUGIN/scripts/_internal/queue-set-status.sh"
LIB="$PLUGIN/scripts/_internal/queue-lib.sh"
PASS=0; FAIL=0
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

mk_queue() {  # <path>
  cat > "$1" <<'EOF'
# batch queue

| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
| FR-1 | 20260101-a | 종목 마스터 동기화 — KOSPI200 + KOSDAQ150 | PENDING |
| FR-2 | 20260101-b | 캔들 수집 | **IMPL_DONE** |
| FR-3 | 20260101-c | 지표 | SKIP |
EOF
}

_status_of() {  # <queue> <FR-ID> → 정규화 라벨
  . "$LIB"
  awk -F'|' -v want="$2" "$QUEUE_AWK_QNORM"'
    /^[[:space:]]*\|/ {
      if (qnorm($2) == want) {
        for (i = NF; i >= 1; i--) if (qnorm($i) != "") { print qnorm($i); exit }
      }
    }' "$1"
}

# ── T1 정상 갱신 ──
Q="$TMP/t1.md"; mk_queue "$Q"
out=$(bash "$SCRIPT" "$Q" FR-1 IMPL_DONE 2>&1); code=$?
if [ "$code" -eq 0 ] && [ "$(_status_of "$Q" FR-1)" = "IMPL_DONE" ]; then
  ok "T1 PENDING → IMPL_DONE 갱신"
else
  nope "T1 갱신 실패" "exit=$code out=$out"
fi

# ── T2 다른 행 무손상 ── (같은 파일 계속 사용)
if [ "$(_status_of "$Q" FR-3)" = "SKIP" ]; then
  ok "T2 무관 행 무손상"
else
  nope "T2 무관 행 오염" "FR-3=$(_status_of "$Q" FR-3)"
fi

# ── T3 설명 컬럼 보존 — 한국어·em dash 가 살아남아야 한다 ──
#    행 재조립 방식이면 설명의 특수문자가 깨질 수 있다. 실제 내용으로 잠근다.
if grep -q '종목 마스터 동기화 — KOSPI200 + KOSDAQ150' "$Q"; then
  ok "T3 설명 컬럼 원문 보존 (em dash·한국어)"
else
  nope "T3 설명 컬럼 손상" "$(grep -m1 'FR-1' "$Q")"
fi

# ── T4 굵게 표기 행도 갱신되고 장식이 벗겨진다 ──
out=$(bash "$SCRIPT" "$Q" FR-2 MERGED 2>&1); code=$?
if [ "$code" -eq 0 ] && [ "$(_status_of "$Q" FR-2)" = "MERGED" ] && ! grep -q '\*\*' "$Q"; then
  ok "T4 **IMPL_DONE** 행 갱신 + 장식 제거"
else
  nope "T4 장식 잔존" "exit=$code line=$(grep -m1 'FR-2' "$Q")"
fi

# ── T5 알 수 없는 라벨 거부 ──
#    이게 없으면 기계화의 의미가 없다 — 통과한 값이 소비자 인식 라벨임을 보장해야 한다.
Q5="$TMP/t5.md"; mk_queue "$Q5"
out=$(bash "$SCRIPT" "$Q5" FR-1 DONE 2>&1); code=$?
if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '알 수 없는 라벨'; then
  ok "T5 알 수 없는 라벨(DONE) 거부"
else
  nope "T5 라벨 검증 부재" "exit=$code out=$out"
fi
[ "$(_status_of "$Q5" FR-1)" = "PENDING" ] && ok "T5.b 거부 시 파일 무변경" \
  || nope "T5.b 거부인데 파일 변경됨" "FR-1=$(_status_of "$Q5" FR-1)"

# ── T6 FR-ID 미발견 거부 ──
out=$(bash "$SCRIPT" "$Q5" FR-99 SKIP 2>&1); code=$?
[ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '미발견' \
  && ok "T6 미발견 FR-ID 거부" || nope "T6 미발견 미거부" "exit=$code out=$out"

# ── T7 FR-ID 중복 거부 ──
#    어느 행을 고칠지 모르는 채 하나를 고르면 조용히 틀린 행을 갱신한다.
Q7="$TMP/t7.md"; mk_queue "$Q7"
printf '| FR-1 | 20260101-dup | 중복 행 | PENDING |\n' >> "$Q7"
out=$(bash "$SCRIPT" "$Q7" FR-1 IMPL_DONE 2>&1); code=$?
if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q '중복'; then
  ok "T7 FR-ID 중복 거부"
else
  nope "T7 중복 미거부 — 틀린 행 갱신 위험" "exit=$code out=$out"
fi

# ── T8 멱등 — 같은 값 재적용이 깨지지 않는다 ──
Q8="$TMP/t8.md"; mk_queue "$Q8"
bash "$SCRIPT" "$Q8" FR-3 SKIP >/dev/null 2>&1
out=$(bash "$SCRIPT" "$Q8" FR-3 SKIP 2>&1); code=$?
if [ "$code" -eq 0 ] && [ "$(_status_of "$Q8" FR-3)" = "SKIP" ]; then
  ok "T8 멱등 — 같은 값 재적용 안전"
else
  nope "T8 멱등 실패" "exit=$code"
fi

# ── T9 행 수 불변 ──
#    표가 깨지면 소비자 전체가 오작동한다. 행 수는 최소한의 구조 지표다.
Q9="$TMP/t9.md"; mk_queue "$Q9"
before=$(wc -l < "$Q9")
bash "$SCRIPT" "$Q9" FR-1 WIP >/dev/null 2>&1
after=$(wc -l < "$Q9")
[ "$before" = "$after" ] && ok "T9 행 수 불변 ($before)" \
  || nope "T9 행 수 변동" "$before → $after"

# ── T10 파일 부재 → 사용 오류(exit 2) ──
bash "$SCRIPT" "$TMP/nope.md" FR-1 SKIP >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && ok "T10 파일 부재 exit 2" || nope "T10 exit code" "exit=$code (기대 2)"

# ── T11 인자 부족 → 사용 오류(exit 2) ──
bash "$SCRIPT" "$Q9" FR-1 >/dev/null 2>&1; code=$?
[ "$code" -eq 2 ] && ok "T11 인자 부족 exit 2" || nope "T11 exit code" "exit=$code (기대 2)"

# ── T12 queue-lib 정규화 규칙 단위 검증 ──
#    소비자 4곳이 이 함수 하나에 의존하므로 규칙 자체를 직접 잠근다.
. "$LIB"
_qn_ok=0
[ "$(queue::qnorm '**IMPL_DONE**')" = "IMPL_DONE" ] || _qn_ok=1
[ "$(queue::qnorm '  `SKIP`  ')" = "SKIP" ] || _qn_ok=1
[ "$(queue::qnorm '_PENDING_')" = "PENDING" ] || _qn_ok=1
[ "$(queue::qnorm 'IMPL_DONE')" = "IMPL_DONE" ] || _qn_ok=1
[ "$_qn_ok" -eq 0 ] && ok "T12 queue::qnorm 장식 흡수 (굵게·백틱·기울임·평문)" \
  || nope "T12 qnorm 규칙 불일치"

# T12.b 과잉 정규화 금지 — 라벨 자체를 바꾸면 미완이 완료가 된다
if [ "$(queue::qnorm '**PLAN_DONE**')" = "PLAN_DONE" ] && [ "$(queue::qnorm 'DONE')" = "DONE" ]; then
  ok "T12.b 과잉 정규화 없음 — 라벨 내용 불변"
else
  nope "T12.b 과잉 정규화" "PLAN_DONE=$(queue::qnorm '**PLAN_DONE**') DONE=$(queue::qnorm 'DONE')"
fi

# ── T13 start-all 배선 — 산문 손편집 지시로 되돌아가지 않게 잠근다 ──
#    스크립트만 있고 호출하는 곳이 없으면 유입이 그대로다.
SA="$PLUGIN/commands/start-all.md"
n=$(grep -c 'queue-set-status\.sh' "$SA" 2>/dev/null || echo 0)
if [ "$n" -ge 2 ]; then
  ok "T13 start-all Phase 1·3 Status 갱신이 스크립트 배선 (${n}곳)"
else
  nope "T13 배선 누락" "queue-set-status.sh 참조 ${n}곳 (기대 ≥2)"
fi

# ── T14 소비자 4곳이 정규화 단일 출처를 쓴다 ──
#    한 곳이라도 자기 정규식을 따로 쓰면 이 FID 가 고친 드리프트가 재발한다.
_t14=0
for f in scripts/batch-state.sh scripts/_internal/collect-assumptions.sh scripts/_internal/record-batch-gate.sh; do
  grep -q 'queue-lib\.sh' "$PLUGIN/$f" || { _t14=1; echo "  (미배선: $f)"; }
done
[ "$_t14" -eq 0 ] && ok "T14 소비자 3곳 queue-lib 단일 출처 사용" \
  || nope "T14 정규화 규칙 분산 — 드리프트 재발 위험"

finish
