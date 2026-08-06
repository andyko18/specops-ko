#!/usr/bin/env bash
# FR 표 placeholder 가드 — 20260806 templates 전수 스캔
#
# 결함: `/start-all` Phase 0 는 `grep -E '^\| FR-[0-9]+ \|'` 로 FR 을 **기계 파싱**하고
#   "FR 행 0건이면 중단" 만 검사한다. 그런데 `templates/requirements.md` 는
#   `| FR-1 | <한 줄> | M1 | must | (TBD) |` **placeholder 행 3건**을 담고 배포되고,
#   init 의 `_seed_fr_row` 는 PRD 마일스톤이 비면 이 행을 그대로 둔다.
#   → 사용자가 FR 을 하나도 안 썼는데 `/start-all` 이 **3개 기능을 구현하겠다며 진입**하고,
#     Phase 1 이 specifying-ko 에 넘기는 "FR 원문" 은 `<한 줄>` 이다.
#   기존 가드("0건이면 중단")는 **비어 있음** 은 잡지만 **의미 없음** 은 못 잡는다.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
CHK="$PLUGIN/scripts/_internal/check-fr-table.sh"

_req() { mkdir -p "$(dirname "$1")"; cat > "$1"; }

# T1: ★ placeholder FR 만 있는 요구사항 → 실 FR 0건 판정(FAIL)
TD=$(mktemp -d)
_req "$TD/.specops/memory/requirements.md" <<'EOF'
| ID | 요구사항 | 마일스톤 | 우선순위 | 상태 |
|---|---|---|---|---|
| FR-1 | <한 줄> | M1 | must | (TBD) |
| FR-2 | <한 줄> | M2 | should | (TBD) |
EOF
out=$(cd "$TD" && bash "$CHK" 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'placeholder' \
  && ok "T1 placeholder FR 만 → 실 FR 0건 FAIL" || nope "T1" "rc=$rc out=$out"
rm -rf "$TD"

# T2: 실제 FR → PASS + 개수 보고
TD=$(mktemp -d)
_req "$TD/.specops/memory/requirements.md" <<'EOF'
| ID | 요구사항 | 마일스톤 | 우선순위 | 상태 |
|---|---|---|---|---|
| FR-1 | 사용자 로그인 | M1 | must | (TBD) |
| FR-2 | 일정 목록 조회 | M1 | must | (TBD) |
EOF
out=$(cd "$TD" && bash "$CHK" 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '2' \
  && ok "T2 실 FR 2건 → PASS" || nope "T2" "rc=$rc out=$out"
rm -rf "$TD"

# T3: 혼재 — 실 FR 1 + placeholder 2 → PASS 하되 placeholder 를 경고로 지목
TD=$(mktemp -d)
_req "$TD/.specops/memory/requirements.md" <<'EOF'
| ID | 요구사항 | 마일스톤 | 우선순위 | 상태 |
|---|---|---|---|---|
| FR-1 | 사용자 로그인 | M1 | must | (TBD) |
| FR-2 | <한 줄> | M2 | should | (TBD) |
| FR-3 | <한 줄> | M3 | nice | (TBD) |
EOF
out=$(cd "$TD" && bash "$CHK" 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qE 'FR-2.*FR-3|placeholder 2' \
  && ok "T3 혼재 → PASS + placeholder 지목" || nope "T3" "rc=$rc out=$out"
rm -rf "$TD"

# T4: 무정보 값(TBD·미정)도 실 FR 아님
TD=$(mktemp -d)
_req "$TD/.specops/memory/requirements.md" <<'EOF'
| ID | 요구사항 | 마일스톤 | 우선순위 | 상태 |
|---|---|---|---|---|
| FR-1 | TBD | M1 | must | (TBD) |
| FR-2 | (미정) | M2 | should | (TBD) |
EOF
(cd "$TD" && bash "$CHK" >/dev/null 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T4 TBD·(미정) → 실 FR 아님" || nope "T4" "rc=$rc"
rm -rf "$TD"

# T5: 루트 requirements.md fallback (탐색 순서 memory → 루트)
TD=$(mktemp -d)
_req "$TD/requirements.md" <<'EOF'
| ID | 요구사항 | 마일스톤 | 우선순위 | 상태 |
|---|---|---|---|---|
| FR-1 | 알림 발송 | M1 | must | (TBD) |
EOF
(cd "$TD" && bash "$CHK" >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T5 루트 fallback 탐색" || nope "T5" "rc=$rc"
rm -rf "$TD"

# T6: requirements.md 부재 → 별도 코드(2) — Phase 0 의 기존 '없음' 안내와 구분
TD=$(mktemp -d)
(cd "$TD" && bash "$CHK" >/dev/null 2>&1); rc=$?
[ "$rc" -eq 2 ] && ok "T6 파일 부재 → rc=2 (구분)" || nope "T6" "rc=$rc"
rm -rf "$TD"

# T7: start-all Phase 0 배선 — 기계 파싱 직후 가드 호출
grep -q 'check-fr-table.sh' "$PLUGIN/commands/start-all.md" \
  && ok "T7 start-all Phase 0 배선" || nope "T7" "미배선"

# T8: start-all-auto 도 동일 Phase 0 을 쓰므로 문서 정합
grep -qE 'check-fr-table|Phase 0.*동일' "$PLUGIN/commands/start-all-auto.md" \
  && ok "T8 start-all-auto Phase 0 승계 명시" || nope "T8" "승계 불명"

finish
