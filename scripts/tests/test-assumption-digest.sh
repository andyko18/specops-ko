#!/usr/bin/env bash
# 가정 다이제스트 결정론적 집계 — 20260806 /start-all-auto 분석
#
# 배경: `/start-all-auto` 는 clarify BLOCKING 을 best-guess 로 자동 답하고 `status: ASSUMED`
#   로 기록한다. 사용자가 그 가정들을 보는 **유일한 지점이 batch PR 게이트의 다이제스트**다
#   (다른 모든 확인은 자동 통과). 그런데 집계가 **모델 재량**이라 누락·과소보고를 잡는 층이 0곳
#   이었다 — 누락되면 사용자는 무엇이 자기 대신 결정됐는지 모른 채 batch PR 을 승인한다.
#   무인 모드를 수용 가능하게 만드는 단 하나의 게이트가 내용을 잃는다(5원칙 4 주권).
# 해법: 집계를 스크립트로 옮겨 **과소보고를 구조적으로 불가능**하게 만든다.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
COL="$PLUGIN/scripts/_internal/collect-assumptions.sh"

_batch() {  # $1=dir — IMPL_DONE 2 FID
  mkdir -p "$1/.specops/batch-20260806-0900"
  cat > "$1/.specops/batch-20260806-0900/queue.md" <<'EOF'
| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
| FR-1 | 20260806-fr-one | one | IMPL_DONE |
| FR-2 | 20260806-fr-two | two | IMPL_DONE |
| FR-3 | 20260806-fr-thr | three | PLAN_DONE |
EOF
  local f
  for f in 20260806-fr-one 20260806-fr-two 20260806-fr-thr; do
    mkdir -p "$1/.specops/$f"
    printf '**§유형**: 신규\n**§auto**: true\n' > "$1/.specops/$f/spec.md"
  done
}

# T1: ★ 전 IMPL_DONE FID 의 ASSUMED 를 빠짐없이 집계
TD=$(mktemp -d); _batch "$TD"
printf '## Q1 · 저장소 · BLOCKING\nstatus: ASSUMED\n**가정 근거**: 기본값\n\n## Q2 · 포맷 · BLOCKING\nstatus: ASSUMED\n**가정 근거**: 관례\n' \
  > "$TD/.specops/20260806-fr-one/clarifications.md"
printf '## Q1 · 인증 · BLOCKING\nstatus: ASSUMED\n**가정 근거**: 세션\n' \
  > "$TD/.specops/20260806-fr-two/clarifications.md"
out=$(cd "$TD" && bash "$COL" .specops/batch-20260806-0900 2>&1); rc=$?
n=$(printf '%s' "$out" | grep -c 'ASSUMED' || true)
[ "$rc" -eq 0 ] && [ "${n:-0}" -ge 3 ] \
  && ok "T1 전 IMPL_DONE ASSUMED 집계 (${n}건)" || nope "T1" "rc=$rc n=$n"
rm -rf "$TD"

# T2: ★ IMPL_DONE 아닌 FID 는 제외 (batch 범위 밖)
TD=$(mktemp -d); _batch "$TD"
printf '## Q1 · 제외대상 · BLOCKING\nstatus: ASSUMED\n**가정 근거**: x\n' \
  > "$TD/.specops/20260806-fr-thr/clarifications.md"
out=$(cd "$TD" && bash "$COL" .specops/batch-20260806-0900 2>&1)
! printf '%s' "$out" | grep -q '제외대상' \
  && ok "T2 비-IMPL_DONE FID 제외" || nope "T2" "out=$out"
rm -rf "$TD"

# T3: RESOLVED 는 가정이 아니다 (집계 제외)
TD=$(mktemp -d); _batch "$TD"
printf '## Q1 · 확정건 · BLOCKING\nstatus: RESOLVED\n**답변**: 사용자가 정함\n' \
  > "$TD/.specops/20260806-fr-one/clarifications.md"
out=$(cd "$TD" && bash "$COL" .specops/batch-20260806-0900 2>&1)
! printf '%s' "$out" | grep -q '확정건' \
  && ok "T3 RESOLVED 제외" || nope "T3" "out=$out"
rm -rf "$TD"

# T4: 자동 결정 화면·인터페이스도 집계 (spec.md §1 — 사용자 미확인 결정)
TD=$(mktemp -d); _batch "$TD"
printf '**§유형**: 신규\n**§auto**: true\n**자동 결정 화면**: login, dashboard\n**자동 결정 인터페이스**: POST /auth\n' \
  > "$TD/.specops/20260806-fr-one/spec.md"
out=$(cd "$TD" && bash "$COL" .specops/batch-20260806-0900 2>&1)
{ printf '%s' "$out" | grep -q '자동 결정 화면' && printf '%s' "$out" | grep -q '자동 결정 인터페이스'; } \
  && ok "T4 자동 결정 화면·IF 집계" || nope "T4" "out=$out"
rm -rf "$TD"

# T5: 가정 0건 → 명시적으로 0 보고 (침묵 금지 — 0 과 미집계는 다르다)
TD=$(mktemp -d); _batch "$TD"
out=$(cd "$TD" && bash "$COL" .specops/batch-20260806-0900 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qE '0건|없음' \
  && ok "T5 가정 0건 → 명시 보고" || nope "T5" "rc=$rc out=$out"
rm -rf "$TD"

# T6: queue 부재 → 오류 (조용한 빈 다이제스트 금지)
TD=$(mktemp -d); mkdir -p "$TD/.specops/batch-x"
(cd "$TD" && bash "$COL" .specops/batch-x >/dev/null 2>&1); rc=$?
[ "$rc" -ne 0 ] && ok "T6 queue 부재 → 오류" || nope "T6" "rc=$rc"
rm -rf "$TD"

# T7: start-all-auto 가 집계기를 지시 (모델 수기 집계 금지)
grep -q 'collect-assumptions.sh' "$PLUGIN/commands/start-all-auto.md" \
  && ok "T7 start-all-auto 배선" || nope "T7" "미배선 — 수기 집계 잔존"

# T8: /start-all 도 §auto 가 아니어도 화면·IF 자동결정 집계 경로를 공유
grep -q 'collect-assumptions.sh' "$PLUGIN/commands/start-all.md" \
  && ok "T8 start-all 배선(공유)" || nope "T8" "미배선"

finish
