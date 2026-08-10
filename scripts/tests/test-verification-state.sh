#!/usr/bin/env bash
# 단일 검증 상태 머신 — NOT_RUN/PASS/PARTIAL/FAIL/WAIVED + 계산형 STALE
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
STATE="$PLUGIN/scripts/_internal/verification-state.sh"

TD=$(mktemp -d) || exit 1
trap 'rm -rf "$TD"' EXIT
git -C "$TD" init -q
printf 'base\n' > "$TD/app.txt"
git -C "$TD" add app.txt
git -C "$TD" -c user.name=test -c user.email=test@example.com commit -qm init
mkdir -p "$TD/.specops/20260803-state"

# 미실행은 빈 문자열이 아니라 명시적 NOT_RUN이다.
out=$(cd "$TD" && bash "$STATE" current 20260803-state)
[ "$out" = "NOT_RUN" ] && ok "S1 상태 부재 → NOT_RUN" || nope "S1" "out=$out"

# PASS 기록 직후 현재 소스와 일치한다.
(cd "$TD" && bash "$STATE" record 20260803-state PASS --executed 2 --skipped 0 --failed 0 --duration-ms 12)
out=$(cd "$TD" && bash "$STATE" current 20260803-state)
[ "$out" = "PASS" ] && ok "S2 PASS 기록·조회" || nope "S2" "out=$out"

# 검증 뒤 코드 변경은 저장 상태를 덮지 않고 조회 시 STALE로 계산한다.
printf 'changed\n' >> "$TD/app.txt"
out=$(cd "$TD" && bash "$STATE" current 20260803-state)
[ "$out" = "STALE" ] && ok "S3 코드 변경 후 PASS → STALE" || nope "S3" "out=$out"
git -C "$TD" restore app.txt

# 비-PASS 상태는 정규 상태 그대로 보존한다.
for verdict in PARTIAL FAIL NOT_RUN; do
  (cd "$TD" && bash "$STATE" record 20260803-state "$verdict")
  out=$(cd "$TD" && bash "$STATE" current 20260803-state)
  [ "$out" = "$verdict" ] && ok "S4 $verdict 보존" || nope "S4 $verdict" "out=$out"
done

# WAIVED는 승인자·사유·만료가 모두 있어야 한다.
if (cd "$TD" && bash "$STATE" record 20260803-state WAIVED >/dev/null 2>&1); then
  nope "S4 waiver" "승인 메타데이터 없는 WAIVED가 수락됨"
else
  ok "S4 승인 메타데이터 없는 WAIVED 거부"
fi
waiver_recorded=0
# ★ 만료일은 **상대 날짜**로 만든다. 미래 날짜를 하드코딩하면 그 시각이 지나는 순간
#   WAIVED 가 NOT_RUN 으로 계산돼 스위트가 스스로 터진다 — 2026-08-10 실발화:
#   "2026-08-10T00:00:00Z" 가 자정에 만료돼 본 스위트와 test-verdict-board 가 동시에 FAIL 했다.
#   (프로덕션은 정상 — verification-state.sh 가 조회 시점에 만료를 계산하는 게 설계다.)
_future=$(date -u -v+1d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "+1 day" +%Y-%m-%dT%H:%M:%SZ)
(cd "$TD" && bash "$STATE" record 20260803-state WAIVED \
  --waiver-reason "외부 시스템 점검" --waiver-approved-by "owner@example.com" \
  --waiver-expires-at "$_future") && waiver_recorded=1
out=$(cd "$TD" && bash "$STATE" current 20260803-state)
if [ "$waiver_recorded" -eq 1 ] && [ "$out" = "WAIVED" ] \
   && jq -e '.waiver.reason != "" and .waiver.approved_by != "" and .waiver.expires_at != ""' \
    "$TD/.specops/20260803-state/verification-state.json" >/dev/null; then
  ok "S4 승인된 WAIVED 보존"
else
  nope "S4 waiver" "out=$out"
fi

# 허용 상태 외 문자열은 기록할 수 없다.
if (cd "$TD" && bash "$STATE" record 20260803-state SKIP >/dev/null 2>&1); then
  nope "S5" "잘못된 SKIP 상태가 수락됨"
else
  ok "S5 허용하지 않은 상태 거부"
fi

# 기존 FID는 evidence stamp를 읽어 하위 호환한다.
rm -f "$TD/.specops/20260803-state/verification-state.json"
printf 'RUN-VERIFICATION-RESULT: PASS\n' > "$TD/.specops/20260803-state/evidence.md"
out=$(cd "$TD" && bash "$STATE" current 20260803-state)
[ "$out" = "PASS" ] && ok "S6 legacy evidence PASS 호환" || nope "S6" "out=$out"

# 만료된 WAIVED는 저장값을 덮지 않고 조회 시 NOT_RUN으로 계산한다.
(cd "$TD" && bash "$STATE" record 20260803-state WAIVED \
  --waiver-reason "일시 예외" --waiver-approved-by "owner@example.com" \
  --waiver-expires-at "2020-01-01T00:00:00Z")
out=$(cd "$TD" && bash "$STATE" current 20260803-state)
[ "$out" = "NOT_RUN" ] && ok "S7 만료 WAIVED → NOT_RUN" || nope "S7" "out=$out"
stored=$(jq -r '.verdict' "$TD/.specops/20260803-state/verification-state.json")
[ "$stored" = "WAIVED" ] && ok "S7b 저장 verdict는 WAIVED 유지" || nope "S7b" "stored=$stored"

# D-1: 검증된 내용의 순수 커밋은 STALE이 아니다 (false-block → BYPASS 방지).
printf 'verified\n' >> "$TD/app.txt"
(cd "$TD" && bash "$STATE" record 20260803-state PASS)
git -C "$TD" add app.txt
git -C "$TD" -c user.name=test -c user.email=test@example.com commit -qm "verified content"
out=$(cd "$TD" && bash "$STATE" current 20260803-state)
[ "$out" = "PASS" ] && ok "S8 커밋만으로는 STALE 아님" || nope "S8" "out=$out"
git -C "$TD" -c user.name=test -c user.email=test@example.com commit --allow-empty -qm empty
out=$(cd "$TD" && bash "$STATE" current 20260803-state)
[ "$out" = "PASS" ] && ok "S8b 빈 커밋도 STALE 아님" || nope "S8b" "out=$out"

# 커밋 후 새 편집은 STALE이다.
printf 'after-commit\n' >> "$TD/app.txt"
out=$(cd "$TD" && bash "$STATE" current 20260803-state)
[ "$out" = "STALE" ] && ok "S9 커밋 후 새 편집 → STALE" || nope "S9" "out=$out"
git -C "$TD" restore app.txt

# source 호출 시 전역 fid 오염이 경로를 바꾸지 않는다 (SC2318).
source "$STATE"
fid="20260803-polluted"
out=$(cd "$TD" && vs::current 20260803-state)
[ "$out" = "PASS" ] && ok "S10 source 호출 시 fid 오염 무영향" || nope "S10" "out=$out"

# git 없는 디렉토리는 NO_GIT로 STALE이 발생하지 않는다.
NG=$(mktemp -d) || exit 1
mkdir -p "$NG/.specops/20260803-nogit"
(cd "$NG" && SPECOPS_ROOT=.specops bash "$STATE" record 20260803-nogit PASS)
out=$(cd "$NG" && SPECOPS_ROOT=.specops bash "$STATE" current 20260803-nogit)
[ "$out" = "PASS" ] && ok "S11 NO_GIT → STALE 미발생" || nope "S11" "out=$out"
rm -rf "$NG"

finish
