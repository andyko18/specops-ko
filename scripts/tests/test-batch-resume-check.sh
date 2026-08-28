#!/usr/bin/env bash
# test-batch-resume-check.sh — 미완 batch 자동 표면화 (FID 20260828-batch-resume-teeth)
#
# 계기: argus batch-20260729 실측. FR 31건이 IMPL_DONE 에서 멈췄고 Phase 3 완료(batch
#   보안·통합·성능 → batch PR)가 실행되지 않은 채 방치됐다. `ACTIVE` 마커는 재개 키인데
#   읽는 곳이 `/start-all` 재호출·PR 게이트뿐이라 **사용자가 먼저 물어야만** 알 수 있었다.
#   `/status`·`reconcile-check` 는 batch 를 아예 모른다(batch 참조 0건).
#   → 재개 키도 주입 경로도 이미 있는데 둘을 잇는 판독기만 없었다.
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SCRIPT="$PLUGIN/scripts/_internal/batch-resume-check.sh"
PASS=0; FAIL=0
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

mk_batch() {  # <dir> <ACTIVE 여부: yes|no> <IMPL_DONE 수> <PENDING 수>
  local d="$1" active="$2" done_n="$3" pend_n="$4" i
  mkdir -p "$d/.specops/batch-20260828-0900"
  {
    printf '| FR-ID | FID | 설명 | Status |\n|---|---|---|---|\n'
    # ★ `seq 1 0` 은 BSD(macOS) 에서 역순으로 "1 0" 을 낸다(GNU 는 빈 출력) — 0 가드 필수.
    [ "$done_n" -gt 0 ] && for i in $(seq 1 "$done_n"); do printf '| FR-%s | 20260101-d%s | done%s | IMPL_DONE |\n' "$i" "$i" "$i"; done
    [ "$pend_n" -gt 0 ] && for i in $(seq 1 "$pend_n"); do printf '| FR-p%s | TBD | pend%s | PENDING |\n' "$i" "$i"; done
  } > "$d/.specops/batch-20260828-0900/queue.md"
  [ "$active" = yes ] && : > "$d/.specops/batch-20260828-0900/ACTIVE"
  return 0
}

# ── T1 ACTIVE 없음 → 무출력 exit 0 (batch 미사용 repo 월권 0) ──
rm -rf "$TMP/t1"; mkdir -p "$TMP/t1/.specops"
out=$(cd "$TMP/t1" && bash "$SCRIPT" --hook 2>&1); code=$?
if [ "$code" -eq 0 ] && [ -z "$out" ]; then
  ok "T1 ACTIVE 부재 → 무출력 exit 0"
else
  nope "T1 무관 repo 월권" "exit=$code out=$out"
fi

# ── T2 .specops 자체가 없음 → 무출력 (specops 미사용 repo) ──
rm -rf "$TMP/t2"; mkdir -p "$TMP/t2"
out=$(cd "$TMP/t2" && bash "$SCRIPT" --hook 2>&1); code=$?
[ "$code" -eq 0 ] && [ -z "$out" ] && ok "T2 .specops 부재 → 무출력" \
  || nope "T2 specops 미사용 repo 월권" "exit=$code out=$out"

# ── T3 진행 중 batch (일부 완료) → 진행률 보고 ──
#    이게 핵심이다. 사용자가 묻지 않아도 "미완 batch 가 있다" 를 말해야 한다.
rm -rf "$TMP/t3"; mk_batch "$TMP/t3" yes 3 2
out=$(cd "$TMP/t3" && bash "$SCRIPT" --hook 2>&1); code=$?
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q 'batch-20260828-0900' \
   && printf '%s' "$out" | grep -qE '3/5'; then
  ok "T3 진행 중 batch 진행률 보고 (3/5)"
else
  nope "T3 미완 batch 미표면화" "exit=$code out=$(printf '%s' "$out" | tr '\n' ' ')"
fi

# ── T4 전건 완료인데 ACTIVE 잔존 → Phase 3 완료 미실행을 지목 ──
#    argus 가 정확히 이 상태였다. 전건 IMPL_DONE 인데 batch PR 이 안 나갔다.
#    "완료됐다" 가 아니라 "다음 단계가 안 돌았다" 를 말해야 재개가 된다.
rm -rf "$TMP/t4"; mk_batch "$TMP/t4" yes 5 0
out=$(cd "$TMP/t4" && bash "$SCRIPT" --hook 2>&1); code=$?
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q 'Phase 3'; then
  ok "T4 전건 완료 + ACTIVE 잔존 → Phase 3 완료 미실행 지목"
else
  nope "T4 재개점 미제시" "exit=$code out=$(printf '%s' "$out" | tr '\n' ' ')"
fi

# ── T5 ACTIVE 제거됨(= PR 완료) → 무출력 ──
#    Step D 가 PR 성공 후 마커를 지운다. 끝난 batch 를 매 세션 떠들면 잡음이다.
rm -rf "$TMP/t5"; mk_batch "$TMP/t5" no 5 0
out=$(cd "$TMP/t5" && bash "$SCRIPT" --hook 2>&1); code=$?
[ "$code" -eq 0 ] && [ -z "$out" ] && ok "T5 완료 batch(ACTIVE 제거) → 무출력" \
  || nope "T5 끝난 batch 잡음" "exit=$code out=$out"

# ── T6 queue.md 부재 → 무출력 (판정 불가는 조용히) ──
rm -rf "$TMP/t6"; mkdir -p "$TMP/t6/.specops/batch-x"; : > "$TMP/t6/.specops/batch-x/ACTIVE"
out=$(cd "$TMP/t6" && bash "$SCRIPT" --hook 2>&1); code=$?
[ "$code" -eq 0 ] && [ -z "$out" ] && ok "T6 queue.md 부재 → 무출력 (판정 불가)" \
  || nope "T6 판정 불가인데 단정" "exit=$code out=$out"

# ── T7 라벨 장식 흡수 — queue-lib 정규화를 쓴다 ──
#    선행 FID(20260828-queue-label-drift)가 고친 것과 같은 유입 경로다. 여기서
#    자기 정규식을 새로 쓰면 그 드리프트가 이 판독기에서 재발한다.
rm -rf "$TMP/t7"; mk_batch "$TMP/t7" yes 0 0
{
  printf '| FR-ID | FID | 설명 | Status |\n|---|---|---|---|\n'
  printf '| FR-1 | 20260101-a | one | **IMPL_DONE** |\n'
  printf '| FR-2 | 20260101-b | two | PENDING |\n'
} > "$TMP/t7/.specops/batch-20260828-0900/queue.md"
out=$(cd "$TMP/t7" && bash "$SCRIPT" --hook 2>&1); code=$?
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -qE '1/2'; then
  ok "T7 굵게 표기 흡수 (queue-lib 재사용)"
else
  nope "T7 라벨 드리프트 재발" "exit=$code out=$(printf '%s' "$out" | tr '\n' ' ')"
fi

# ── T8 SKIP 은 분모에서 뺀다 — 시드·공통부는 batch 대상이 아니다 ──
rm -rf "$TMP/t8"; mk_batch "$TMP/t8" yes 2 0
printf '| FR-9 | — | seed | SKIP |\n' >> "$TMP/t8/.specops/batch-20260828-0900/queue.md"
out=$(cd "$TMP/t8" && bash "$SCRIPT" --hook 2>&1); code=$?
if [ "$code" -eq 0 ] && printf '%s' "$out" | grep -qE '2/2'; then
  ok "T8 SKIP 분모 제외 (2/2)"
else
  nope "T8 SKIP 분모 오염" "exit=$code out=$(printf '%s' "$out" | tr '\n' ' ')"
fi

# ── T9 session-start 배선 — 판독기만 있고 부르는 곳이 없으면 그대로다 ──
if grep -q 'batch-resume-check' "$PLUGIN/hooks/session-start.sh"; then
  ok "T9 session-start.sh 배선"
else
  nope "T9 배선 누락 — 판독기가 호출되지 않는다"
fi

finish
