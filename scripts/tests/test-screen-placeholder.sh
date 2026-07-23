#!/usr/bin/env bash
# test-screen-placeholder.sh — 화면 껍데기 마커 판정 헬퍼 검증 (FID 20260722-screen-design-quality)
# AC-1(껍데기 판정) · AC-2(정상 무해 통과) · AC-11(bash 3.2) · AC-12(마커 단일출처) · AC-13(함수 배치)
set -u

PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SCRIPT="$PLUGIN/scripts/_internal/design-screen.sh"
PASS=0; FAIL=0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 스크립트 상수에서 마커 토큰 추출 — 단일 출처 계약 (AC-12 ③)
MARKER=$(grep -m1 '^SCREEN_PLACEHOLDER_MARKER=' "$SCRIPT" | sed 's/^SCREEN_PLACEHOLDER_MARKER="\(.*\)"$/\1/')

# T1: 헬퍼가 design-screen.sh 내 함수로 존재 (AC-13 ①)
grep -qE '^screen_is_placeholder\(\)' "$SCRIPT" \
  && ok  "T1.a screen_is_placeholder() 함수가 design-screen.sh 내 정의" \
  || nope "T1.a screen_is_placeholder() 함수 정의" "design-screen.sh 에 함수 없음"

[ -n "$MARKER" ] \
  && ok  "T1.b SCREEN_PLACEHOLDER_MARKER 상수 정의 (단일 출처)" \
  || nope "T1.b SCREEN_PLACEHOLDER_MARKER 상수" "상수 미정의 또는 추출 실패"

# T2: 껍데기 판정 (AC-1) — fixture 는 마커를 포함한다
cat > "$TMP/shell.md" <<EOF
<!-- $MARKER — 실제 내용으로 채우면 이 줄을 삭제한다 -->
# login 화면 스펙
## 목적
[이 화면이 사용자에게 하는 일 — 1~2 문장]
EOF
bash "$SCRIPT" --check "$TMP/shell.md" >/dev/null 2>&1
[ $? -eq 0 ] \
  && ok  "T2.a 마커 잔존 .md → 껍데기 판정 (exit 0)" \
  || nope "T2.a 껍데기 판정" "exit 0 아님"

cat > "$TMP/shell.html" <<EOF
<!DOCTYPE html>
<!-- $MARKER — 실제 내용으로 채우면 이 줄을 삭제한다 -->
<html lang="ko"><body></body></html>
EOF
bash "$SCRIPT" --check "$TMP/shell.html" >/dev/null 2>&1
[ $? -eq 0 ] \
  && ok  "T2.b 마커 잔존 .html → 껍데기 판정 (exit 0)" \
  || nope "T2.b .html 껍데기 판정" "exit 0 아님"

# T3: 정상 화면 무해 통과 (AC-2 · M-2 핵심 단언)
cat > "$TMP/filled.md" <<'EOF'
# 로그인 화면 스펙
## 목적
사용자가 이메일과 비밀번호로 인증한다.
## Layout
[헤더] 로고
EOF
bash "$SCRIPT" --check "$TMP/filled.md" >/dev/null 2>&1
[ $? -eq 1 ] \
  && ok  "T3.a 마커 부재 .md → 정상 판정 (exit 1, false-trigger 0)" \
  || nope "T3.a 정상 판정" "exit 1 아님"

bash "$SCRIPT" --check "$TMP/none.md" >/dev/null 2>&1
[ $? -eq 1 ] \
  && ok  "T3.b 부재 파일 → 정상 집계 (잡음 방지)" \
  || nope "T3.b 부재 파일 처리" "exit 1 아님"

# T3.c: 혼합 인자 — 하나라도 껍데기면 exit 0 + 해당 경로 출력
out=$(bash "$SCRIPT" --check "$TMP/filled.md" "$TMP/shell.md" 2>/dev/null); rc=$?
{ [ $rc -eq 0 ] && echo "$out" | grep -q "PLACEHOLDER: $TMP/shell.md"; } \
  && ok  "T3.c 혼합 인자 → 껍데기 경로만 PLACEHOLDER 출력" \
  || nope "T3.c 혼합 인자" "rc=$rc out=$out"

# T4: 마커 단일 출처 계약 (AC-12 ①②) — 상수 토큰으로 두 템플릿 대조
grep -qF "$MARKER" "$PLUGIN/templates/screen.md" \
  && ok  "T4.a templates/screen.md 에 마커 존재 (상수 대조)" \
  || nope "T4.a screen.md 마커" "상수 토큰이 템플릿에 없음 — drift"

grep -qF "$MARKER" "$PLUGIN/templates/screen.html" \
  && ok  "T4.b templates/screen.html 에 마커 존재 (상수 대조)" \
  || nope "T4.b screen.html 마커" "상수 토큰이 템플릿에 없음 — drift"

# T4.c: 뮤테이션 — 판정이 템플릿 본문 리터럴이 아니라 마커에만 의존함을 입증 (AC-12 ③)
cat > "$TMP/mutated.md" <<EOF
<!-- $MARKER — 실제 내용으로 채우면 이 줄을 삭제한다 -->
# 완전히 다른 본문. 템플릿 리터럴 0개.
EOF
bash "$SCRIPT" --check "$TMP/mutated.md" >/dev/null 2>&1
[ $? -eq 0 ] \
  && ok  "T4.c 본문 리터럴 전무 + 마커만 → 여전히 껍데기 (본문 비의존)" \
  || nope "T4.c 본문 비의존" "본문 리터럴에 의존하는 판정 — AC-12 위반"

cat > "$TMP/literal-only.md" <<'EOF'
## 목적
[이 화면이 사용자에게 하는 일 — 1~2 문장]
- [ComponentName, 예: Button(primary)] — DESIGN.md §4
EOF
bash "$SCRIPT" --check "$TMP/literal-only.md" >/dev/null 2>&1
[ $? -eq 1 ] \
  && ok  "T4.d 본문 리터럴 잔존 + 마커 부재 → 정상 (마커가 유일 기준)" \
  || nope "T4.d 마커 단독 기준" "리터럴 grep 회귀 — AC-12 위반"

# T5: bash 3.2 호환 (AC-11) — 연상배열·mapfile 미사용
grep -nE '^\s*(declare|local)\s+-A\b|^\s*mapfile\b|^\s*readarray\b' "$SCRIPT" >/dev/null 2>&1 \
  && nope "T5.a bash 3.2 호환" "연상배열/mapfile 사용 발견" \
  || ok  "T5.a bash 3.2 전용 문법 미사용 (연상배열·mapfile 0)"

finish
