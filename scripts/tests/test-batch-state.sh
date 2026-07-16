#!/usr/bin/env bash
# test-batch-state.sh — scripts/batch-state.sh 검증 (FID 20260710-p2-batch-state)
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SCRIPT="$PLUGIN/scripts/batch-state.sh"
PASS=0; FAIL=0
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT

# ── fixture A: 실물 batch-20260624 재현 (미완 3 + 드리프트 5 + 2-테이블 분할) ──
mkdir -p "$TMP/a/.specops/batch-x"
cat > "$TMP/a/.specops/batch-x/queue.md" <<'EOF'
# Batch Queue — batch-x

| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
| FR-1 | 20260624-vercel-pr | 어댑터 | MERGED |
| FR-2 | — | 확장 | HELD (자격증명 준비 후) |
| FR-3 | — | 머지 | HELD (자격증명 준비 후) |
| FR-4 | — | placeholder | SKIP |

| FR-5 | 20260624-dashboard-ui | 대시보드 | MERGED |
EOF
cat > "$TMP/a/req.md" <<'EOF'
| FR-1 | a | M1 | must | s | f |
| FR-2 | b | M2 | should | s | f |
| FR-3 | c | M3 | nice | s | f |
| FR-4 | d | M3 | nice | s | f |
| FR-5 | e | M1 | should | s | f |
| FR-6 | f | M1 | must | s | f |
| FR-7 | g | M1 | must | s | f |
| FR-8 | h | M1 | should | s | f |
| FR-9 | i | M1 | must | s | f |
| FR-3b | j | M3 | should | s | f |
EOF
out=$(bash "$SCRIPT" "$TMP/a/.specops/batch-x" "$TMP/a/req.md" 2>&1); code=$?
if [ "$code" -eq 1 ] && echo "$out" | grep -q "미완" && echo "$out" | grep -q "드리프트" \
   && echo "$out" | grep -q "FR-6" && echo "$out" | grep -q "FR-3b" && echo "$out" | grep -q "FR-2"; then
  ok "T1.a 실물 fixture — exit 1 + 미완·드리프트 검출 (2-테이블 견딤)"
else
  nope "T1.a 실물 fixture" "exit=$code out=$(echo "$out" | head -3 | tr '\n' ' ')"
fi

# ── fixture B: clean (전 행 IMPL_DONE, parity 일치 + per-FID 산출물 존재) ──
mkdir -p "$TMP/b/.specops/batch-y" "$TMP/b/.specops/20260101-a" "$TMP/b/.specops/20260101-b"
cat > "$TMP/b/.specops/batch-y/queue.md" <<'EOF'
| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
| FR-1 | 20260101-a | one | IMPL_DONE |
| FR-2 | 20260101-b | two | MERGED |
EOF
# per-FR 산출물 (뭉개짐 방지 teeth 전제) — review-base.sha + evidence.md + review-request.md 3종
# 단, 20260101-b 는 MERGED → teeth 제외 대상이므로 seed 불요(IMPL_DONE 한정 검증도 겸함)
: > "$TMP/b/.specops/20260101-a/review-base.sha"
: > "$TMP/b/.specops/20260101-a/evidence.md"; : > "$TMP/b/.specops/20260101-a/review-request.md"
printf '| FR-1 | a | M1 | must | s | f |\n| FR-2 | b | M1 | must | s | f |\n' > "$TMP/b/req.md"
bash "$SCRIPT" "$TMP/b/.specops/batch-y" "$TMP/b/req.md" >/dev/null 2>&1; code=$?
[ "$code" -eq 0 ] && ok "T2.a clean fixture — exit 0 (산출물 존재)" || nope "T2.a clean" "exit=$code (기대 0)"

# ── fixture B2: IMPL_DONE 이나 per-FR 산출물 뭉개짐 (evidence.md만·review-request.md 부재) ──
mkdir -p "$TMP/b2/.specops/batch-y2" "$TMP/b2/.specops/20260101-c" "$TMP/b2/.specops/20260101-d"
cat > "$TMP/b2/.specops/batch-y2/queue.md" <<'EOF'
| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
| FR-1 | 20260101-c | one | IMPL_DONE |
| FR-2 | 20260101-d | two | IMPL_DONE |
EOF
# FR-1(-c): 3종 완전 / FR-2(-d): evidence.md만 (review-base.sha·review-request.md 부재 → 뭉개짐)
: > "$TMP/b2/.specops/20260101-c/review-base.sha"
: > "$TMP/b2/.specops/20260101-c/evidence.md"; : > "$TMP/b2/.specops/20260101-c/review-request.md"
: > "$TMP/b2/.specops/20260101-d/evidence.md"
printf '| FR-1 | c | M1 | must | s | f |\n| FR-2 | d | M1 | must | s | f |\n' > "$TMP/b2/req.md"
out=$(bash "$SCRIPT" "$TMP/b2/.specops/batch-y2" "$TMP/b2/req.md" 2>&1); code=$?
if [ "$code" -eq 1 ] && echo "$out" | grep -q "산출물 누락" \
   && echo "$out" | grep -q "FR-2" && echo "$out" | grep -q "review-request.md" \
   && ! echo "$out" | grep -q "FR-1.*evidence"; then
  ok "T2.b 산출물 누락 teeth — review-request.md 부재 FID 차단 (FR-1 완전은 미보고)"
else
  nope "T2.b 산출물 teeth" "exit=$code out=$(echo "$out" | tr '\n' ' ')"
fi

# ── fixture B3: IMPL_DONE 이나 FID 디렉토리 자체 부재 → 양쪽 누락 ──
mkdir -p "$TMP/b3/.specops/batch-y3"
cat > "$TMP/b3/.specops/batch-y3/queue.md" <<'EOF'
| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
| FR-1 | 20260101-e | one | IMPL_DONE |
EOF
printf '| FR-1 | e | M1 | must | s | f |\n' > "$TMP/b3/req.md"
out=$(bash "$SCRIPT" "$TMP/b3/.specops/batch-y3" "$TMP/b3/req.md" 2>&1); code=$?
if [ "$code" -eq 1 ] && echo "$out" | grep -q "산출물 누락" \
   && echo "$out" | grep -q "evidence.md" && echo "$out" | grep -q "review-request.md"; then
  ok "T2.c 산출물 누락 teeth — FID 디렉토리 부재 시 양쪽 보고"
else
  nope "T2.c FID 부재" "exit=$code out=$(echo "$out" | tr '\n' ' ')"
fi

# ── fixture B4: layer 2 — review-base.sha 만 부재 (evidence·review-request 는 존재) → 내용 뭉개짐 차단 ──
#    step 1a(review base 기록) 누락 시나리오. 존재 teeth 는 통과하나 내용 격리 base 가 없어 차단돼야 함.
mkdir -p "$TMP/b4/.specops/batch-y4" "$TMP/b4/.specops/20260101-f"
cat > "$TMP/b4/.specops/batch-y4/queue.md" <<'EOF'
| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
| FR-1 | 20260101-f | one | IMPL_DONE |
EOF
: > "$TMP/b4/.specops/20260101-f/evidence.md"; : > "$TMP/b4/.specops/20260101-f/review-request.md"
printf '| FR-1 | f | M1 | must | s | f |\n' > "$TMP/b4/req.md"
out=$(bash "$SCRIPT" "$TMP/b4/.specops/batch-y4" "$TMP/b4/req.md" 2>&1); code=$?
if [ "$code" -eq 1 ] && echo "$out" | grep -q "review-base.sha" \
   && ! echo "$out" | grep -q "evidence.md 없음" && ! echo "$out" | grep -q "review-request.md 없음"; then
  ok "T2.d layer 2 teeth — review-base.sha 부재만으로 차단 (내용 뭉개짐 방지)"
else
  nope "T2.d review-base teeth" "exit=$code out=$(echo "$out" | tr '\n' ' ')"
fi

# ── fixture B5: layer 2 read-path — §batch spec + review-base.sha → 문서화 BASE_SHA 스니펫 resolve ──
#    requesting-code-review-ko §1 [batch 모드] 분기의 실제 bash 로직을 재현해 격리 base 가 파일 내용으로
#    resolve 되는지(HEAD~1 falling back 아님) 실행 검증.
mkdir -p "$TMP/b5/.specops/20260101-g"
printf '**§batch**: true\n' > "$TMP/b5/.specops/20260101-g/spec.md"
printf 'cafef00d\n' > "$TMP/b5/.specops/20260101-g/review-base.sha"
( cd "$TMP/b5"
  FID=20260101-g
  BASE_SHA=HEAD~1  # 단일 모드 기본 (스니펫 시작값)
  if grep -qE '^\*\*§batch\*\*:' ".specops/$FID/spec.md" 2>/dev/null && [ -f ".specops/$FID/review-base.sha" ]; then
    BASE_SHA=$(cat ".specops/$FID/review-base.sha")
  fi
  [ "$BASE_SHA" = "cafef00d" ] )
[ "$?" -eq 0 ] && ok "T2.e layer 2 read-path — §batch BASE_SHA = review-base.sha 내용 (HEAD~1 미사용)" \
  || nope "T2.e §batch resolve" "BASE_SHA 가 review-base.sha 로 resolve 안 됨"

# ── fixture C: FR-ID 중복 + read-only 검증 ──
mkdir -p "$TMP/c/.specops/batch-z"
cat > "$TMP/c/.specops/batch-z/queue.md" <<'EOF'
| FR-ID | FID | FR 설명(1줄) | Status |
|---|---|---|---|
| FR-3 | x | dup1 | IMPL_DONE |
| FR-3 | y | dup2 | IMPL_DONE |
EOF
printf '| FR-3 | a | M1 | must | s | f |\n' > "$TMP/c/req.md"
sum_before=$(cksum "$TMP/c/.specops/batch-z/queue.md" "$TMP/c/req.md")
out=$(bash "$SCRIPT" "$TMP/c/.specops/batch-z" "$TMP/c/req.md" 2>&1); code=$?
sum_after=$(cksum "$TMP/c/.specops/batch-z/queue.md" "$TMP/c/req.md")
if [ "$code" -eq 1 ] && echo "$out" | grep -q "중복" && [ "$sum_before" = "$sum_after" ]; then
  ok "T3.a 중복 감지 + read-only (cksum 불변)"
else
  nope "T3.a 중복/read-only" "exit=$code"
fi

# ── 사용 오류: 인자 없음 → exit 2 ──
bash "$SCRIPT" 2>/dev/null; code=$?
[ "$code" -eq 2 ] && ok "T4.a 인자 없음 → exit 2" || nope "T4.a usage" "exit=$code"

# ── 배선·규약 grep 계약 (AC-4·AC-5) ──
grep -q 'batch-state.sh' "$PLUGIN/commands/start-all.md" && grep -q '그래도 batch PR' "$PLUGIN/commands/start-all.md" \
  && ok "T5.a start-all 게이트 배선" || nope "T5.a 배선" "batch-state 호출/[y/n] 없음"
grep -q '_inject_design_palette' "$PLUGIN/commands/init-project.md" \
  && ok "T5.b Phase11 재주입 지시" || nope "T5.b 재주입" "없음"
grep -q '복수 표기' "$PLUGIN/templates/data-model.md" \
  && ok "T5.c 하이브리드 복수 표기" || nope "T5.c 복수표기" "없음"
grep -q '해당 행 갱신' "$PLUGIN/skills/specifying-ko/SKILL.md" \
  && ok "T5.d Step5.6 dedup" || nope "T5.d dedup" "없음"

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
