#!/usr/bin/env bash
# 공통부 FR foundation-scope SKIP + hybrid 금지 — 20260812
#
# 결함: [공통] FR 이 /start-all PENDING 에 들어가면 §유형=신규+§batch 로 구현되어
#   foundation 경로(manifest·Step 5.6)와 어긋난다. hybrid(§유형=foundation+§batch)는
#   Argus FR-28 실측 — 생산 배타 계약을 모델이 깨면 halt/verify/reuse 가 충돌한다.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
CHK="$PLUGIN/scripts/_internal/check-fr-table.sh"
LBL="$PLUGIN/scripts/_internal/check-spec-label-compat.sh"

_req() { mkdir -p "$(dirname "$1")"; cat > "$1"; }

# T1: Argus형 — [공통] FR-4 + 기능 FR-5 → foundation-scope / ELIGIBLE
TD=$(mktemp -d)
_req "$TD/.specops/memory/requirements.md" <<'EOF'
<!-- seed-fr: FR-1,FR-2,FR-3 -->
| ID | 요구사항 | 마일스톤 | 우선순위 | 관련 spec |
|---|---|---|---|---|
| FR-1 | M1 시드 전체 | M1 | must | (TBD) |
| FR-4 | **[공통]** 프로젝트 스캐폴딩 — Poetry·app 트리 | M1 | must | (TBD) |
| FR-5 | 종목 마스터 동기화 | M1 | must | (TBD) |
EOF
out=$(cd "$TD" && bash "$CHK" --classify 2>&1); rc=$?
printf '%s' "$out" | grep -qE '^SKIP\|FR-4\|foundation-scope\|M1$' \
  && printf '%s' "$out" | grep -qE '^ELIGIBLE\|FR-5\|' \
  && printf '%s' "$out" | grep -qE 'foundation_skip=1' \
  && [ "$rc" -eq 0 ] \
  && ok "T1 [공통] → foundation-scope, FR-5 ELIGIBLE" \
  || nope "T1" "rc=$rc out=$out"
rm -rf "$TD"

# T2: HTML foundation-fr 목록만
TD=$(mktemp -d)
_req "$TD/.specops/memory/requirements.md" <<'EOF'
<!-- foundation-fr: FR-27, FR-28 -->
| ID | 요구사항 | 마일스톤 | 우선순위 | 관련 spec |
|---|---|---|---|---|
| FR-27 | 백엔드 공통 코어 | M1 | must | (TBD) |
| FR-28 | 프론트 공통 기반 | M1 | must | (TBD) |
| FR-10 | 기술적 지표 | M1 | must | (TBD) |
EOF
out=$(cd "$TD" && bash "$CHK" --classify 2>&1); rc=$?
printf '%s' "$out" | grep -qE '^SKIP\|FR-27\|foundation-scope\|' \
  && printf '%s' "$out" | grep -qE '^SKIP\|FR-28\|foundation-scope\|' \
  && printf '%s' "$out" | grep -qE '^ELIGIBLE\|FR-10\|' \
  && printf '%s' "$out" | grep -qE 'foundation_skip=2' \
  && [ "$rc" -eq 0 ] \
  && ok "T2 HTML foundation-fr → SKIP" \
  || nope "T2" "rc=$rc out=$out"
rm -rf "$TD"

# T3: 미표기 — 설명 중간에만 '공통' → ELIGIBLE (오탐 방지)
TD=$(mktemp -d)
_req "$TD/.specops/memory/requirements.md" <<'EOF'
| ID | 요구사항 | 마일스톤 | 우선순위 | 관련 spec |
|---|---|---|---|---|
| FR-9 | 배치 스케줄러 — 공통 로그 포맷 사용 | M1 | must | (TBD) |
EOF
out=$(cd "$TD" && bash "$CHK" --classify 2>&1); rc=$?
printf '%s' "$out" | grep -qE '^ELIGIBLE\|FR-9\|' \
  && ! printf '%s' "$out" | grep -q 'foundation-scope' \
  && [ "$rc" -eq 0 ] \
  && ok "T3 중간 '공통' 산문 → ELIGIBLE" \
  || nope "T3" "rc=$rc out=$out"
rm -rf "$TD"

# T4: start-all 배선
grep -q 'foundation-scope' "$PLUGIN/commands/start-all.md" \
  && grep -q 'check-spec-label-compat\|hybrid' "$PLUGIN/commands/start-all.md" \
  && ok "T4 start-all foundation-scope·hybrid 배선" \
  || nope "T4" "start-all 누락"

# T5: start-all-auto 승계
grep -q 'foundation-scope' "$PLUGIN/commands/start-all-auto.md" \
  && ok "T5 start-all-auto 승계" \
  || nope "T5" "auto 누락"

# T6 mutation: foundation-scope 분기 제거하면 T1이 ELIGIBLE 로 붕괴
TD=$(mktemp -d)
mut=$(mktemp)
sed '/_is_foundation_scope/,/^}/d; /if _is_foundation_scope/,/continue$/d' "$CHK" > "$mut" 2>/dev/null \
  || sed '/foundation-scope/d' "$CHK" > "$mut"
# 더 안전한 mutation: _is_foundation_scope 본문을 항상 return 1
awk '
  /^_is_foundation_scope\(\)/ { print; print "  return 1"; skip=1; next }
  skip && /^}/ { skip=0; print; next }
  skip { next }
  { print }
' "$CHK" > "$mut"
_req "$TD/.specops/memory/requirements.md" <<'EOF'
| ID | 요구사항 | 마일스톤 | 우선순위 | 관련 spec |
|---|---|---|---|---|
| FR-4 | [공통] 스캐폴딩 | M1 | must | (TBD) |
| FR-5 | 기능 A | M1 | must | (TBD) |
EOF
out=$(cd "$TD" && bash "$mut" --classify 2>&1); rc=$?
if printf '%s' "$out" | grep -q 'foundation-scope'; then
  nope "T6 mutation" "분기 무력화했는데도 foundation-scope — mutation 무효 out=$out"
else
  printf '%s' "$out" | grep -qE '^ELIGIBLE\|FR-4\|' \
    && ok "T6 mutation: 무력화 → FR-4 ELIGIBLE (비-vacuous)" \
    || nope "T6 mutation" "rc=$rc out=$out"
fi
rm -rf "$TD" "$mut"

# T7: eligible=0 중단 지시 (공통만)
grep -qE 'eligible=0' "$PLUGIN/commands/start-all.md" \
  && grep -qE '공통|/start-foundation' "$PLUGIN/commands/start-all.md" \
  && ok "T7 eligible=0·공통 중단 안내" \
  || nope "T7" "eligible=0 안내 부족"

# H1: hybrid FAIL
TD=$(mktemp -d)
mkdir -p "$TD/.specops/x"
printf '%s\n' '**§유형**: foundation' '**§batch**: batch-1' > "$TD/.specops/x/spec.md"
out=$(cd "$TD" && bash "$LBL" x 2>&1); rc=$?
printf '%s' "$out" | grep -q 'SPEC-LABEL: FAIL' \
  && [ "$rc" -eq 1 ] \
  && ok "H1 hybrid → FAIL" \
  || nope "H1" "rc=$rc out=$out"
rm -rf "$TD"

# H2: foundation alone / batch+신규 PASS
TD=$(mktemp -d)
mkdir -p "$TD/.specops/a" "$TD/.specops/b"
printf '%s\n' '**§유형**: foundation' > "$TD/.specops/a/spec.md"
printf '%s\n' '**§유형**: 신규' '**§batch**: batch-1' > "$TD/.specops/b/spec.md"
outa=$(cd "$TD" && bash "$LBL" a 2>&1); rca=$?
outb=$(cd "$TD" && bash "$LBL" b 2>&1); rcb=$?
[ "$rca" -eq 0 ] && [ "$rcb" -eq 0 ] \
  && printf '%s' "$outa" | grep -q 'PASS' \
  && printf '%s' "$outb" | grep -q 'PASS' \
  && ok "H2 foundation alone / batch+신규 PASS" \
  || nope "H2" "rca=$rca rcb=$rcb outa=$outa outb=$outb"
rm -rf "$TD"

# H3: specifying-ko 금지 문구
grep -q 'hybrid' "$PLUGIN/skills/specifying-ko/SKILL.md" \
  && grep -q 'check-spec-label-compat' "$PLUGIN/skills/specifying-ko/SKILL.md" \
  && ok "H3 specifying-ko hybrid 금지" \
  || nope "H3" "skill 누락"

# H4: emit-context · run-verification 배선
grep -q 'check-spec-label-compat' "$PLUGIN/scripts/dag/emit-context.sh" \
  && grep -q 'check-spec-label-compat' "$PLUGIN/scripts/_internal/run-verification.sh" \
  && ok "H4 emit/verify 배선" \
  || nope "H4" "배선 누락"

# H5 mutation: hybrid 검사 무력화(항상 PASS) 시 H1이 통과해 버림
mut=$(mktemp)
cat > "$mut" <<'EOF'
#!/usr/bin/env bash
echo "SPEC-LABEL: PASS"
exit 0
EOF
TD=$(mktemp -d)
mkdir -p "$TD/.specops/x"
printf '%s\n' '**§유형**: foundation' '**§batch**: batch-1' > "$TD/.specops/x/spec.md"
out=$(cd "$TD" && bash "$mut" x 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q PASS; then
  # 원본은 FAIL 이어야 함 — mutation 이 PASS 로 바뀌었으니 비-vacuous
  out_real=$(cd "$TD" && bash "$LBL" x 2>&1); rc_real=$?
  [ "$rc_real" -eq 1 ] \
    && ok "H5 mutation: stub PASS vs real FAIL (비-vacuous)" \
    || nope "H5" "원본이 FAIL 아님 rc_real=$rc_real"
else
  nope "H5" "stub 실패"
fi
rm -rf "$TD" "$mut"

# T8: FR-4 vs FR-40 id 경계 (HTML)
TD=$(mktemp -d)
_req "$TD/.specops/memory/requirements.md" <<'EOF'
<!-- foundation-fr: FR-4 -->
| ID | 요구사항 | 마일스톤 | 우선순위 | 관련 spec |
|---|---|---|---|---|
| FR-4 | 스캐폴딩 | M1 | must | (TBD) |
| FR-40 | 다른 기능 | M1 | must | (TBD) |
EOF
out=$(cd "$TD" && bash "$CHK" --classify 2>&1)
printf '%s' "$out" | grep -qE '^SKIP\|FR-4\|foundation-scope\|' \
  && printf '%s' "$out" | grep -qE '^ELIGIBLE\|FR-40\|' \
  && ok "T8 FR-4 목록이 FR-40 을 오탐하지 않음" \
  || nope "T8" "out=$out"
rm -rf "$TD"

finish
