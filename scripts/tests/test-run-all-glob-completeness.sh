#!/usr/bin/env bash
# test-run-all-glob-completeness.sh — run-all glob 완결성 계약 (FID 20260712-runall-glob-completeness)
# 실제 test 보유 subdir ⊆ run-all for-루프 커버. SoT = run-all.sh for 루프(L4 주석 아님, Q5)
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
PASS=0; FAIL=0
RA="$PLUGIN/scripts/tests/run-all.sh"

# subdir 정규화: PLUGIN 상대 → 루트는 ".", 서브는 dirname
_actual() {
  find "$PLUGIN/scripts/tests" -name 'test-*.sh' -not -path '*/fixtures/*' 2>/dev/null \
    | sed -E "s#^$PLUGIN/scripts/tests##; s#/test-[^/]*\$##; s#^/##; s#^\$#.#" | sort -u
}
# run-all for-루프 glob 라인만 파싱 (L4 주석 brace 형태는 미매치 — SoT 단일)
_cover() {
  grep -oE '"\$PLUGIN"/scripts/tests/[a-z0-9-]*/?test-\*\.sh' "$RA" \
    | sed -E 's#"\$PLUGIN"/scripts/tests##; s#/?test-\*\.sh##; s#^/##; s#^$#.#' | sort -u
}

# ── T1: 실제 ⊆ 커버 (AC-1) ──
missing=$(comm -23 <(_actual) <(_cover))
[ -z "$missing" ] && ok "T1.a 실제 test subdir ⊆ run-all 커버 (완결)" \
  || nope "T1.a 완결성" "run-all 미커버 subdir: $(echo $missing)"

# ── T2: SoT 단일 — 커버가 for 루프에서 도출(하드코딩 배열 복제 없음) (AC-3) ──
# 계약 테스트 자신에 subdir 리터럴 배열이 없음을 자기검증(grep -oE 도출만)
if grep -qE 'COVER=\(|SUBDIRS=\(|cover=\(' "$0"; then
  nope "T2.a SoT" "커버 목록 하드코딩 배열 발견(SoT 복제)"
else
  ok "T2.a SoT 단일 (run-all grep 도출)"
fi

# ── T3: reverse-observe — 미등록 subdir 적발 (AC-2) ──
dummy="$PLUGIN/scripts/tests/extract-test-commands/test-glob-canary.sh"
trap 'rm -f "$dummy"' EXIT   # abort 잔존 방지 (plan-reviewer M-4)
mkdir -p "$(dirname "$dummy")"
printf '#!/usr/bin/env bash\nexit 0\n' > "$dummy"
miss_after=$(comm -23 <(_actual) <(_cover))
rm -f "$dummy"
echo "$miss_after" | grep -q 'extract-test-commands' \
  && ok "T3.a reverse-observe — 미등록 subdir FAIL 적발" \
  || nope "T3.a reverse-observe" "dummy 넣어도 미검출(계약 무력)"

# ── T4: 주석 배제 — 커버 ⊆ 실제 (주석에만 있는 가짜 dir 오포획 없음) (AC-4) ──
# count 하드코딩 대신 역방향 부분집합: for-루프 형태를 주석에 써도 실제에 없으면 FAIL (plan-reviewer M-1)
extra=$(comm -13 <(_actual) <(_cover))
[ -z "$extra" ] && ok "T4.a 커버 ⊆ 실제 (주석 오포획 없음)" \
  || nope "T4.a 주석배제" "실제에 없는 커버 dir: $(echo $extra)"

echo ""
finish
