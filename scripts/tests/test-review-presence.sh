#!/usr/bin/env bash
# Phase B/C 수행 존재 관측 (warn-only) — 20260806 패턴 A 스캔
#
# 배경: skill 은 "Phase B/C 생략 금지" 를 여러 곳에서 HARD 로 선언한다
#   (§lite 불변 · risk-profile allowlist · implementing-ko:165). 그런데
#   `check-review-audit.sh` 는 **정합 검사**(reviews ↔ dispatch-log)지 **존재 검사**가 아니라,
#   리뷰를 0회 하면 검사 대상 자체가 없어 `SKIP` rc=0 으로 통과한다(실측).
#
# 왜 warn 인가: 이 fail-open 은 의도된 설계다("산출물 부재는 SKIP — 무관 repo·초기 FID 월권 0").
#   presence 를 즉시 하드 차단하면 본 repo 기존 FID 20건 중 **7건(35%)이 소급 FAIL** 한다(실측).
#   그래서 1단계는 **관측만** — friction-log 에 남기고 chain 은 통과시킨다. 빈도를 본 뒤 전환 판단.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
CHK="$PLUGIN/scripts/_internal/check-review-presence.sh"

_fid() {  # $1=dir $2=fid  — 구현 도달(tasks.md 보유) FID
  mkdir -p "$1/.specops/$2"
  printf '**§유형**: 신규\n' > "$1/.specops/$2/spec.md"
  printf '# tasks\n' > "$1/.specops/$2/tasks.md"
}

# T1: ★ 구현 도달 + Phase B/C 0회 → WARN (rc=0 — chain 비차단)
TD=$(mktemp -d); _fid "$TD" 20260806-p
out=$(cd "$TD" && bash "$CHK" 20260806-p 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'WARN' \
  && ok "T1 B/C 0회 → WARN + rc=0(비차단)" || nope "T1" "rc=$rc out=$out"
rm -rf "$TD"

# T2: B·C 리포트 모두 존재 → OK (무경고)
TD=$(mktemp -d); _fid "$TD" 20260806-p
mkdir -p "$TD/.specops/20260806-p/reviews"
: > "$TD/.specops/20260806-p/reviews/T1-B-report.md"
: > "$TD/.specops/20260806-p/reviews/T1-C-report.md"
out=$(cd "$TD" && bash "$CHK" 20260806-p 2>&1); rc=$?
[ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -q 'WARN' \
  && ok "T2 B/C 존재 → 무경고" || nope "T2" "rc=$rc out=$out"
rm -rf "$TD"

# T3: B 만 있고 C 없음 → WARN (한쪽만 수행도 생략)
TD=$(mktemp -d); _fid "$TD" 20260806-p
mkdir -p "$TD/.specops/20260806-p/reviews"
: > "$TD/.specops/20260806-p/reviews/T1-B-report.md"
out=$(cd "$TD" && bash "$CHK" 20260806-p 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qE 'C.*미수행|Phase C' \
  && ok "T3 C 누락 → WARN" || nope "T3" "rc=$rc out=$out"
rm -rf "$TD"

# T3b: C 만 있고 B 없음 → WARN — B 축 **격리** 검사.
#   T1(둘 다 없음)·T3(C 없음)만 있으면 B 판정을 무력화해도 C 가 miss 를 채워
#   전부 통과한다(실측 — mutation 으로 적발한 공허 통과). 축마다 단독 케이스가 필요하다.
TD=$(mktemp -d); _fid "$TD" 20260806-p
mkdir -p "$TD/.specops/20260806-p/reviews"
: > "$TD/.specops/20260806-p/reviews/T1-C-report.md"
out=$(cd "$TD" && bash "$CHK" 20260806-p 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qE 'B.*미수행|Phase B' \
  && ok "T3b B 누락 단독 → WARN(B 축 격리)" || nope "T3b" "rc=$rc out=$out"
rm -rf "$TD"

# T4: feedback 파일도 수행 증거로 인정 (FAIL 라운드 산출 — implementing 규약)
TD=$(mktemp -d); _fid "$TD" 20260806-p
mkdir -p "$TD/.specops/20260806-p/reviews"
: > "$TD/.specops/20260806-p/reviews/T1-B-feedback.md"
: > "$TD/.specops/20260806-p/reviews/T1-C-report.md"
out=$(cd "$TD" && bash "$CHK" 20260806-p 2>&1); rc=$?
[ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -q 'WARN' \
  && ok "T4 feedback 도 수행 증거" || nope "T4" "rc=$rc out=$out"
rm -rf "$TD"

# T5: tasks.md 부재(구현 미도달) → 관측 대상 아님 (초기 FID 월권 금지)
TD=$(mktemp -d); mkdir -p "$TD/.specops/20260806-p"
printf '**§유형**: 신규\n' > "$TD/.specops/20260806-p/spec.md"
out=$(cd "$TD" && bash "$CHK" 20260806-p 2>&1); rc=$?
[ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -q 'WARN' \
  && ok "T5 구현 미도달 → 관측 제외" || nope "T5" "rc=$rc out=$out"
rm -rf "$TD"

# T6: FID 디렉토리 부재 → 조용히 통과 (무관 repo 월권 0)
TD=$(mktemp -d)
(cd "$TD" && bash "$CHK" 20260806-none >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T6 FID 부재 → 통과" || nope "T6" "rc=$rc"
rm -rf "$TD"

# T7: friction-log 기록 — 관측이 남아야 빈도 판단이 가능
TD=$(mktemp -d); _fid "$TD" 20260806-p
(cd "$TD" && bash "$CHK" 20260806-p >/dev/null 2>&1)
[ -f "$TD/.specops/20260806-p/friction-log.jsonl" ] \
  && grep -q 'REVIEW-PRESENCE' "$TD/.specops/20260806-p/friction-log.jsonl" \
  && ok "T7 friction-log 관측 기록" || nope "T7" "기록 없음"
rm -rf "$TD"

# T8: run-verification 배선 (VERIFY 관문에서 관측 — 차단은 안 함)
grep -q 'check-review-presence.sh' "$PLUGIN/scripts/_internal/run-verification.sh" \
  && ok "T8 run-verification 배선" || nope "T8" "미배선"

# T9: 차단하지 않음을 스크립트가 명시 (전환 시점에 이 계약을 바꾼다)
grep -qE 'warn-only|비차단' "$CHK" \
  && ok "T9 warn-only 계약 명시" || nope "T9" "계약 불명"

finish
