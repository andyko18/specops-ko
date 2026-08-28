#!/usr/bin/env bash
# batch 레벨 게이트(Step A/B/C) verdict 전파 — 20260806 /start-all 정밀분석
#
# 결함: Phase 3 완료 Step A/B/C(security·integration·performance)는 batch 전체를 **1회**
#   실행하고, 각 skill 은 `.specops/<FID>/evidence.md` — 즉 **호출된 대표 FID 1곳** — 에만
#   verdict 를 append 한다. 그런데 v1.60 RELEASE_READY 는 `gh pr create` 시 ACTIVE batch 의
#   **전 IMPL_DONE FID** 각각에 security/integration/performance = PASS|SKIP 을 요구한다
#   (하나라도 MISSING → NOT_READY → **hard deny**, 인라인 BYPASS 불가).
#   → 정직한 /start-all 완주가 구조적으로 batch PR 에서 막힌다 (F1 과 동류의 설계 간 충돌).
# 수정: record-batch-gate.sh 가 batch verdict 를 전 IMPL_DONE FID 의 evidence.md 로 전파.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
REC="$PLUGIN/scripts/_internal/record-batch-gate.sh"
RR="$PLUGIN/scripts/_internal/release-ready.sh"
STATE="$PLUGIN/scripts/_internal/verification-state.sh"

_mk_batch() {  # $1=dir — batch(2 FID IMPL_DONE) + 대표 FID1 에만 게이트 기록된 정직한 흐름
  local d="$1"
  mkdir -p "$d/.specops/batch-20260806-0900" "$d/src"
  printf 'x\n' > "$d/src/a.sh"
  (cd "$d" && git init -q && git add src && git -c user.name=t -c user.email=t@e.com commit -qm init)
  cat > "$d/.specops/batch-20260806-0900/queue.md" <<'EOF'
| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
| FR-1 | 20260806-fr-one | one | IMPL_DONE |
| FR-2 | 20260806-fr-two | two | IMPL_DONE |
EOF
  : > "$d/.specops/batch-20260806-0900/ACTIVE"
  local fid
  for fid in 20260806-fr-one 20260806-fr-two; do
    mkdir -p "$d/.specops/$fid/reviews"
    printf '# tasks\n' > "$d/.specops/$fid/tasks.md"
    printf 'RUN-VERIFICATION-RESULT: PASS\n' > "$d/.specops/$fid/evidence.md"
    cat > "$d/.specops/$fid/dispatch-log.md" <<'DL'
| # | 시각 | Phase | agent | 결과 | feedback |
|---|---|---|---|---|---|
| 1 | ts | B:T1 | spec-reviewer-ko | PASS | reviews/T1-B-report.md |
| 2 | ts | C:T1 | code-reviewer-ko | PASS | reviews/T1-C-report.md |
DL
    printf '# B\nREADY_TO_MERGE\n' > "$d/.specops/$fid/reviews/T1-B-report.md"
    printf '# C\nREADY_TO_MERGE\n' > "$d/.specops/$fid/reviews/T1-C-report.md"
    printf 'end-loaded: covered\n' > "$d/.specops/$fid/review-skip.md"
    (cd "$d" && bash "$STATE" record "$fid" PASS --executed 1) >/dev/null
  done
  # 실제 Phase 3 흐름과 동일한 진행 줄 — requesting-code-review-ko 가 /request-review 를 남긴다
  # (없으면 reconcile 이 증거 frontier(review-skip.md) > 기록 frontier 로 DESYNC 를 낸다)
  printf '<!-- active-fid: 20260806-fr-two -->\n## 20260806-fr-one\n- 2026-08-06 10:00 /verify PASS\n- 2026-08-06 10:05 /request-review 완료 "review-skip.md (end-loaded)"\n## 20260806-fr-two\n- 2026-08-06 11:00 /verify PASS\n- 2026-08-06 11:05 /request-review 완료 "review-skip.md (end-loaded)"\n' \
    > "$d/.specops/session-progress.md"
  # 대표 FID(fr-one)에만 batch 게이트 3종 기록 — 현행 Step A/B/C 실동작
  cat >> "$d/.specops/20260806-fr-one/evidence.md" <<'EOF'

## /security-review PASS
**결과**: PASS

## /integration-test PASS
**결과**: PASS

## /performance-test SKIP
**결과**: SKIP
EOF
}

# T1: ★ 버그 실증 — 대표 아닌 FID(fr-two)는 게이트 MISSING → NOT_READY
TD=$(mktemp -d); _mk_batch "$TD"
out=$(cd "$TD" && bash "$RR" 20260806-fr-two 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'security=MISSING' \
  && ok "T1 배경 실증 — 비대표 FID NOT_READY(security=MISSING)" || nope "T1" "rc=$rc out=$out"
rm -rf "$TD"

# T2: record-batch-gate — batch verdict 를 전 IMPL_DONE FID 로 전파
TD=$(mktemp -d); _mk_batch "$TD"
(cd "$TD" && bash "$REC" ".specops/batch-20260806-0900" security PASS) >/dev/null 2>&1
(cd "$TD" && bash "$REC" ".specops/batch-20260806-0900" integration PASS) >/dev/null 2>&1
(cd "$TD" && bash "$REC" ".specops/batch-20260806-0900" performance SKIP "NFR 없음 §requirements L1") >/dev/null 2>&1
out=$(cd "$TD" && bash "$RR" 20260806-fr-two 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'RELEASE_READY: OK' \
  && ok "T2 전파 후 비대표 FID READY" || nope "T2" "rc=$rc out=$out"
rm -rf "$TD"

# T3: 멱등 — 재실행해도 섹션 중복 없음
TD=$(mktemp -d); _mk_batch "$TD"
(cd "$TD" && bash "$REC" ".specops/batch-20260806-0900" security PASS) >/dev/null 2>&1
(cd "$TD" && bash "$REC" ".specops/batch-20260806-0900" security PASS) >/dev/null 2>&1
n=$(grep -c '^## /security-review' "$TD/.specops/20260806-fr-two/evidence.md")
[ "$n" -eq 1 ] && ok "T3 멱등 — 중복 섹션 없음" || nope "T3" "n=$n"
rm -rf "$TD"

# T4: 대표 FID(이미 기록됨)는 건드리지 않음 — 기존 섹션 보존 + 중복 없음
TD=$(mktemp -d); _mk_batch "$TD"
(cd "$TD" && bash "$REC" ".specops/batch-20260806-0900" security PASS) >/dev/null 2>&1
n=$(grep -c '^## /security-review' "$TD/.specops/20260806-fr-one/evidence.md")
[ "$n" -eq 1 ] && ok "T4 대표 FID 기존 기록 보존(중복 0)" || nope "T4" "n=$n"
rm -rf "$TD"

# T5: FAIL verdict 는 전파 거부 — FAIL 은 systematic-debugging 후 재실행이 정도이지
#     전 FID 로 낙인 찍는 것이 아니다 (사용 오류 방지)
TD=$(mktemp -d); _mk_batch "$TD"
(cd "$TD" && bash "$REC" ".specops/batch-20260806-0900" security FAIL) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ! grep -q 'security-review FAIL' "$TD/.specops/20260806-fr-two/evidence.md" \
  && ok "T5 FAIL 전파 거부" || nope "T5" "rc=$rc"
rm -rf "$TD"

# T6: SKIP 은 근거 필수 (skip-tracker CITED 규약 정합)
TD=$(mktemp -d); _mk_batch "$TD"
(cd "$TD" && bash "$REC" ".specops/batch-20260806-0900" performance SKIP) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "T6 SKIP 무근거 거부" || nope "T6" "rc=$rc"
rm -rf "$TD"

# T7: queue 부재·IMPL_DONE 0건 → 오류 (조용한 no-op 금지)
TD=$(mktemp -d); mkdir -p "$TD/.specops/batch-x"
(cd "$TD" && bash "$REC" ".specops/batch-x" security PASS) >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "T7 queue 부재 → 오류" || nope "T7" "rc=$rc"
rm -rf "$TD"

# T8: start-all.md 배선 — Step A/B/C 가 전파 스크립트를 지시 (게이트 3종 각각)
_t8=0
for g in security integration performance; do
  grep -E "record-batch-gate\.sh .* $g " "$PLUGIN/commands/start-all.md" >/dev/null 2>&1 || _t8=1
done
[ "$_t8" -eq 0 ] && ok "T8 start-all Step A/B/C 배선(게이트 3종)" || nope "T8" "게이트별 배선 누락"

# ── T9: Status 라벨 장식 흡수 (FID 20260828-queue-label-drift) ──
#   계기: argus batch-20260729 — 모델이 `**IMPL_DONE**` 로 손편집하자 이 스크립트의
#   `|IMPL_DONE|` 리터럴 매칭이 전건 불일치 → "IMPL_DONE FID 0건" exit 1.
#   Step A/B/C 를 정상 수행해도 verdict 전파가 실패해 batch PR 이 막힌다.
TN=$(mktemp -d); trap 'rm -rf "$TN"' EXIT
_mk_batch "$TN"
# Status 를 굵게 표기로 오염시킨다 (모델 손편집 재현)
sed -i.bak 's/| IMPL_DONE |/| **IMPL_DONE** |/' "$TN/.specops/batch-20260806-0900/queue.md"
out=$(cd "$TN" && bash "$REC" ".specops/batch-20260806-0900" security PASS 2>&1); rc=$?
if [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -q 'IMPL_DONE FID 0건'; then
  ok "T9 **IMPL_DONE** 손편집에도 전 FID 전파 (정규화)"
else
  nope "T9 라벨 장식 미흡수" "rc=$rc out=$(printf '%s' "$out" | tr '\n' ' ')"
fi
# 전파가 실제로 됐는지 — 두 FID evidence 모두에 기록돼야 한다 (0건 무음 통과 구분)
_t9b=0
for fid in 20260806-fr-one 20260806-fr-two; do
  grep -q 'security' "$TN/.specops/$fid/evidence.md" 2>/dev/null || _t9b=1
done
[ "$_t9b" -eq 0 ] && ok "T9.b 전파 실측 — 2 FID evidence 모두 기록" \
  || nope "T9.b 전파 누락" "대상 0건 무음 통과 의심"

finish
