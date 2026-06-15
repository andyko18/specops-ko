#!/usr/bin/env bash
# specops-auto-ko · session-progress-append.sh 검증
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/session-progress-append.sh"

ok() { PASS=$((PASS+1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }

# ── fixture helpers ─────────────────────────────────────────────────────

EXISTING_FID="20260101-existing-fid"

make_progress() {
  local f="$1"
  cat > "$f" <<EOF
# Session Progress

---

## ${EXISTING_FID} · 기존 기능

- 2026-01-01 10:00 /specify 완료 (spec.md)

---

## 활용 방법
EOF
}

# ── T1: usage / exit code ──────────────────────────────────────────────

# T1.a: 스크립트 존재
[ -f "$SCRIPT" ] && ok "T1.a script 존재" || fail "T1.a script 존재"

# T1.b: exec-bit
[ -x "$SCRIPT" ] && ok "T1.b exec-bit" || fail "T1.b exec-bit"

# T1.c: 인자 없음 → exit 2 + usage 출력
T1_c_out=$(bash "$SCRIPT" 2>&1)
T1_c_rc=$?
[ $T1_c_rc -eq 2 ] && echo "$T1_c_out" | grep -qi "usage\|FID" \
  && ok "T1.c 인자 없음 → exit 2" || fail "T1.c 인자 없음 → exit 2"

# T1.d: 잘못된 FID 포맷 → exit 1
bash "$SCRIPT" "bad-fid" "/specify" "완료" >/dev/null 2>&1
[ $? -eq 1 ] && ok "T1.d FID 포맷 오류 → exit 1" || fail "T1.d FID 포맷 오류 → exit 1"

# ── T2: 신규 섹션 생성 ────────────────────────────────────────────────

# T2.a: 신규 FID → 섹션 생성
T2_a() {
  local tmp dir fid
  tmp=$(mktemp -d)
  fid="20260101-new-fid"
  mkdir -p "$tmp/.specops"
  make_progress "$tmp/.specops/session-progress.md"
  (cd "$tmp" && bash "$PLUGIN/scripts/session-progress-append.sh" "$fid" "/specify" "완료" "spec.md") >/dev/null 2>&1
  grep -q "## $fid" "$tmp/.specops/session-progress.md" || { rm -rf "$tmp"; return 1; }
  grep -q "/specify 완료" "$tmp/.specops/session-progress.md" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}
T2_a && ok "T2.a 신규 FID 섹션 생성" || fail "T2.a 신규 FID 섹션 생성"

# T2.b: feature-name 인자 → 섹션 헤더에 포함
T2_b() {
  local tmp fid
  tmp=$(mktemp -d)
  fid="20260101-feat-b"
  mkdir -p "$tmp/.specops"
  make_progress "$tmp/.specops/session-progress.md"
  (cd "$tmp" && bash "$PLUGIN/scripts/session-progress-append.sh" "$fid" "/specify" "완료" "" "테스트기능") >/dev/null 2>&1
  grep -q "## $fid · 테스트기능" "$tmp/.specops/session-progress.md" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}
T2_b && ok "T2.b feature-name 헤더 포함" || fail "T2.b feature-name 헤더 포함"

# ── T3: 기존 섹션 append ──────────────────────────────────────────────

# T3.a: 기존 FID → 기존 섹션에 줄 추가
T3_a() {
  local tmp
  tmp=$(mktemp -d)
  mkdir -p "$tmp/.specops"
  make_progress "$tmp/.specops/session-progress.md"
  (cd "$tmp" && bash "$PLUGIN/scripts/session-progress-append.sh" "$EXISTING_FID" "/clarify" "완료" "clarifications.md") >/dev/null 2>&1
  grep -q "/clarify 완료" "$tmp/.specops/session-progress.md" || { rm -rf "$tmp"; return 1; }
  grep -q "/specify 완료" "$tmp/.specops/session-progress.md" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}
T3_a && ok "T3.a 기존 섹션 줄 추가" || fail "T3.a 기존 섹션 줄 추가"

# T3.b: 멱등 — 동일 줄 중복 추가 안 함
T3_b() {
  local tmp count
  tmp=$(mktemp -d)
  mkdir -p "$tmp/.specops"
  make_progress "$tmp/.specops/session-progress.md"
  (cd "$tmp" && bash "$PLUGIN/scripts/session-progress-append.sh" "$EXISTING_FID" "/clarify" "완료" "memo") >/dev/null 2>&1
  (cd "$tmp" && bash "$PLUGIN/scripts/session-progress-append.sh" "$EXISTING_FID" "/clarify" "완료" "memo") >/dev/null 2>&1
  # 동일 내용 줄이 2개 이상이면 중복
  count=$(grep -Fc "/clarify 완료 (memo)" "$tmp/.specops/session-progress.md" 2>/dev/null)
  rm -rf "$tmp"
  [ "${count:-0}" -le 1 ]
}
T3_b && ok "T3.b 멱등 — 중복 추가 안 함" || fail "T3.b 멱등 — 중복 추가 안 함"

# ── T4: 파일 미존재 시 자동 생성 ─────────────────────────────────────

# T4.a: .specops/session-progress.md 없음 → hooks/ensure-session-progress.sh 호출·생성
# (ensure 스크립트가 templates에서 생성하므로 plugin_root 에서 동작 필요)
T4_a() {
  local tmp fid
  tmp=$(mktemp -d)
  fid="20260101-auto-create"
  mkdir -p "$tmp/.specops"
  # progress 파일 없이 시작
  (cd "$tmp" && bash "$PLUGIN/scripts/session-progress-append.sh" "$fid" "/specify" "완료") >/dev/null 2>&1
  local ret=0
  [ -f "$tmp/.specops/session-progress.md" ] || ret=1
  rm -rf "$tmp"
  return $ret
}
T4_a && ok "T4.a 파일 미존재 시 자동 생성" || fail "T4.a 파일 미존재 시 자동 생성"

# ── T5: 멱등성·빈섹션 회귀 ─────────────────────────────────────────────

# T5.a AC-2/5: 신규섹션 동일 라인 재append → 1회 (멱등 섹션 전체 스캔)
T5_a() {
  local tmp; tmp=$(mktemp -d)
  ( cd "$tmp" && mkdir -p .specops && bash "$PLUGIN/hooks/ensure-session-progress.sh" >/dev/null 2>&1
    bash "$SCRIPT" 20260615-i /specify 완료 "m" "F" >/dev/null 2>&1
    bash "$SCRIPT" 20260615-i /specify 완료 "m" >/dev/null 2>&1 )
  local cnt; cnt=$(grep -c "specify 완료 (m)" "$tmp/.specops/session-progress.md" 2>/dev/null || echo 99)
  rm -rf "$tmp"
  [ "$cnt" = "1" ]
}
T5_a && ok "T5.a 멱등 재append 1회 (AC-2/5)" || fail "T5.a 멱등 재append 1회 (AC-2/5)"

# T5.b AC-R-1: 다른 라인 → prepend (섹션 첫 줄 앞), 기존 라인 보존
T5_b() {
  local tmp; tmp=$(mktemp -d)
  ( cd "$tmp" && mkdir -p .specops && bash "$PLUGIN/hooks/ensure-session-progress.sh" >/dev/null 2>&1
    bash "$SCRIPT" 20260615-p /specify 완료 "a" "F" >/dev/null 2>&1
    bash "$SCRIPT" 20260615-p /clarify 완료 "b" >/dev/null 2>&1 )
  local f; f="$tmp/.specops/session-progress.md"
  local ret=0
  grep -q "clarify 완료 (b)" "$f" && grep -q "specify 완료 (a)" "$f" || ret=1
  rm -rf "$tmp"
  return $ret
}
T5_b && ok "T5.b 다른 라인 prepend 무손상 (AC-R-1)" || fail "T5.b 다른 라인 prepend 무손상 (AC-R-1)"

# T5.c AC-6: 빈섹션(항목0)에 첫 항목 추가 보존
T5_c() {
  local tmp; tmp=$(mktemp -d); mkdir -p "$tmp/.specops"
  printf -- '---\n\n## 20260615-e · F\n\n## 20260101-old · O\n\n- old line\n' > "$tmp/.specops/session-progress.md"
  ( cd "$tmp" && bash "$SCRIPT" 20260615-e /specify 완료 "x" >/dev/null 2>&1 )
  local ret=0
  grep -q "specify 완료 (x)" "$tmp/.specops/session-progress.md" || ret=1
  rm -rf "$tmp"
  return $ret
}
T5_c && ok "T5.c 빈섹션 첫 항목 추가 (AC-6)" || fail "T5.c 빈섹션 첫 항목 추가 (AC-6)"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
