#!/usr/bin/env bash
# review-cost.sh — plan-reviewer 비용·재dispatch 집계 (fixture 만 사용 — 실제 .specops·~/.claude 를 읽지 않는다, 토큰 0)
# run-all: serial — 합성 대형 입력(T9.c)의 시간 임계가 CPU 경합에 약하다
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
RCS_SH="$PLUGIN/scripts/review-cost.sh"
BASH_BIN=$(command -v bash)
SB=$(mktemp -d)
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/tmp" "$SB/home" "$SB/cfg"

ck() { if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS+1)); else echo "FAIL $1 — exp '$3' got '$2'"; FAIL=$((FAIL+1)); fi; }

# dispatch-log fixture: dl 이름 FID — 본문은 stdin. $SB/이름 이 곧 SPECOPS_ROOT 다.
dl() { mkdir -p "$SB/$1/$2" && cat > "$SB/$1/$2/dispatch-log.md"; }
# 행: pr 번호 판정 [비고] [단계] — 필드 2=번호 4=단계 6=판정 7=비고
pr() { printf '| %s | 2026-09-01T10:00:00+09:00 | %s | plan-reviewer-ko | %s | %s |\n' "$1" "${4:-plan-reviewer}" "$2" "${3:--}"; }
HDR='| # | 시각 | 단계 | 에이전트 | 판정 | 비고 |
|---|---|---|---|---|---|'
ledger() { mkdir -p "$SB/$1" && cat > "$SB/$1/session-progress.md"; }
# 실행: runs 이름 옵션... — TZ=UTC(TZV 로 변경) · HOME·CLAUDE_CONFIG_DIR 은 fixture 로 격리 · TMPDIR 은 전용 디렉토리(누출 검사용)
runs() {
  local nm="$1"; shift
  OUT=$(TZ="${TZV:-UTC}" TMPDIR="$SB/tmp" HOME="$SB/home" CLAUDE_CONFIG_DIR="$SB/cfg" SPECOPS_ROOT="$SB/$nm" "$BASH_BIN" "$RCS_SH" "$@" 2>"$SB/err"); RC=$?
  # shellcheck disable=SC2034  # Part B 의 단언에서 쓴다
  ERR=$(cat "$SB/err")
}
cnt() { printf '%s\n' "$OUT" | grep -cF -- "$1"; }
# 표의 한 행을 "라운드 첫 끝 Crit Imp wall분" 으로
trow() { printf '%s\n' "$OUT" | awk -v f="$1" '$1 == f { print $2, $3, $4, $5, $6, $7 }'; }
# 표의 FID 순서(헤더 제외 — 날짜로 시작하는 첫 열만)
order() { printf '%s\n' "$OUT" | awk '$1 ~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-/ { printf "%s,", $1 }'; }
# wall 줄을 뺀 라운드 요약(wall 유무와 무관해야 하는 줄)
core() { printf '%s\n' "$OUT" | grep -E '^(FID [0-9]+개|첫 라운드 FAIL|마지막 판정|도입|  20[0-9]{4}  FID)'; }

# ══ AC-1: dispatch-log plan-reviewer 행 파싱·판정 정규화 ══
dl a1 20260901-ord <<EOF
$HDR
$(pr 3 PASS)
$(pr 1 FAIL 'Critical 1')
$(pr 2 '**FAIL**' 'Important 2')
EOF
dl a1 20260902-star <<EOF
$HDR
$(pr 1 '**PASS**')
EOF
dl a1 20260903-arrow <<EOF
$HDR
$(pr 1 'FAIL→PASS')
$(pr 2 ABORT)
EOF
dl a1 20260904-misc <<EOF
$HDR
$(pr 1 PROCEED)
$(pr 2 —)
| 3 | 2026-09-01T10:00:00+09:00 | plan-reviewer | DEFERRED | — | Phase 2 batch |
$(pr 4 ABORT)
$(pr 1 PASS - A:T1)
$(pr 2 FAIL - End-loaded-B)
$(pr 3 PASS - 외부 critic)
plan-reviewer FAIL 2회 후 PASS — 산문 줄(파이프로 시작하지 않는다)
| 1 | x | plan-reviewer |
| 5 | 2026-09-01T10:00:00+09:00 | plan-reviewer | FAIL |
note: | 1 | 2026-09-01T10:00:00+09:00 | plan-reviewer | plan-reviewer-ko | FAIL | x |
EOF
dl a1 notes <<EOF
$HDR
$(pr 1 PASS)
EOF
mkdir -p "$SB/a1/20260905-empty"; : > "$SB/a1/20260905-empty/dispatch-log.md"
runs a1
ck "T1.a 라운드 FID 3개(ord·star·arrow) · 분포 1회 2·3회 1 · 평균 1.67 · rc=0 — 기타만 있는 FID(misc)·비 FID 폴더(notes)·빈 파일은 FID 수에 안 든다" "$RC|$(printf '%s\n' "$OUT" | grep -F 'FID 3개')" "0|FID 3개 · 라운드 분포 1회 2 · 3회 1 — 평균 1.67"
ck "T1.b 첫 라운드 FAIL 2/3(ord·arrow) · 마지막 판정 PASS 2/3(ord·star) — arrow 의 FAIL→PASS 는 FAIL" "$(cnt '첫 라운드 FAIL 2/3 (67%)')|$(cnt '마지막 판정 PASS 2/3 (67%)')" "1|1"
ck "T1.c 기타 행은 5건(ABORT 1 + PROCEED·—·DEFERRED·ABORT) — 단계가 A:T1·End-loaded-B·외부 critic 인 행·산문 줄·열이 모자란 줄은 어디에도 세지 않는다" "$(cnt '기타 행 5건')" "1"
ck "T1.d 표: ord 는 번호 3·1·2 순서로 기록돼도 번호 오름차순이라 첫 FAIL·끝 PASS · star **PASS** 는 PASS · arrow 는 1라운드 FAIL/FAIL · 기타 전용 FID·비 FID 폴더는 표에 없다" "$(trow 20260901-ord)|$(trow 20260902-star)|$(trow 20260903-arrow)|$(cnt 20260904-misc)$(cnt notes)" "3 FAIL PASS 1 2 -|1 PASS PASS 0 0 -|1 FAIL FAIL 0 0 -|00"
dl a1b 20260905-nonnum <<EOF
$HDR
$(pr x FAIL)
$(pr y PASS)
EOF
dl a1b 20260906-dup <<EOF
$HDR
$(pr 2 PASS)
$(pr 2 FAIL)
$(pr 1 FAIL)
EOF
runs a1b
ck "T1.e 번호가 숫자가 아니면 파일 순서(FAIL→PASS) · 같은 번호는 파일 순서 유지(번호 1 FAIL → 2 PASS → 2 FAIL)" "$(trow 20260905-nonnum)|$(trow 20260906-dup)" "2 FAIL PASS 0 0 -|3 FAIL FAIL 0 0 -"

# ══ AC-2: FID 요약 ══
dl a2 20260901-f1 <<EOF
$HDR
$(pr 1 PASS)
EOF
dl a2 20260902-f2 <<EOF
$HDR
$(pr 1 FAIL)
EOF
dl a2 20260903-f3 <<EOF
$HDR
$(pr 1 FAIL)
$(pr 2 PASS)
EOF
dl a2 20260904-f4 <<EOF
$HDR
$(pr 1 FAIL)
$(pr 2 PASS)
EOF
dl a2 20260905-f5 <<EOF
$HDR
$(pr 1 FAIL)
$(pr 2 FAIL)
$(pr 3 PASS)
EOF
dl a2 20260906-f6 <<EOF
$HDR
$(pr 1 FAIL)
$(pr 2 FAIL)
EOF
runs a2
ck "T2.a 요약: FID 6개 · 분포 1회 2·2회 3·3회 1 · 평균 1.83(11/6)" "$(printf '%s\n' "$OUT" | grep -F 'FID 6개')" "FID 6개 · 라운드 분포 1회 2 · 2회 3 · 3회 1 — 평균 1.83"
ck "T2.b 첫 라운드 FAIL 5/6(83%) · 마지막 판정 PASS 4/6(67%) — f2~f6 가 첫 FAIL, f1·f3·f4·f5 가 끝 PASS" "$(cnt '첫 라운드 FAIL 5/6 (83%)')|$(cnt '마지막 판정 PASS 4/6 (67%)')" "1|1"
ck "T2.c 표 순서(wall 없음 → 라운드 내림차순, 동률은 FID 이름 내림차순)와 첫·끝 열" "$(order)|$(trow 20260905-f5)|$(trow 20260906-f6)|$(trow 20260901-f1)" "20260905-f5,20260906-f6,20260904-f4,20260903-f3,20260902-f2,20260901-f1,|3 FAIL PASS 0 0 -|2 FAIL FAIL 0 0 -|1 PASS PASS 0 0 -"
runs a2 --top 3
ck "T2.d --top 3 이면 표 3행(위 3개 FID)" "$(order)" "20260905-f5,20260906-f6,20260904-f4,"

# ══ AC-3: Critical/Important 숫자 ══
dl a3 20260901-c1 <<EOF
$HDR
$(pr 1 FAIL 'Critical 2 · Important 3(범위 CANARY-N1)')
$(pr 2 PASS 'Important 7 CANARY-N5')
EOF
dl a3 20260902-c2 <<EOF
$HDR
$(pr 1 FAIL 'Important 1(CANARY-N2) · Minor 5')
EOF
dl a3 20260903-c3 <<EOF
$HDR
$(pr 1 FAIL 'Critical: 1건, Important 4건')
EOF
dl a3 20260904-c4 <<EOF
$HDR
$(pr 1 FAIL '범위 오류 — 재작성 CANARY-N3')
EOF
dl a3 20260905-c5 <<EOF
$HDR
$(pr 1 FAIL 'Important 2 … Important 9 CANARY-N4')
EOF
runs a3
ck "T3.a 합계: Critical 3(2+1) · Important 10(3+1+4+2 — 첫 매치만, PASS 행의 7 은 안 쓴다) · 숫자 읽힌 FAIL 행 4/5" "$(printf '%s\n' "$OUT" | grep -F 'Critical 합')" "FAIL 행 Critical 합 3 · Important 합 10 (숫자 읽힌 FAIL 행 4/5)"
ck "T3.b 숫자 못 읽은 FAIL 행 1건(c4) — 비고의 비숫자 텍스트(CANARY-N*·재작성)는 stdout·stderr 에 0건" "$(cnt '숫자 못 읽은 FAIL 행 1건')|$(printf '%s\n%s\n' "$OUT" "$ERR" | grep -c -e 'CANARY-N' -e '재작성')" "1|0"
ck "T3.c 표의 FID 별 Crit·Imp: c1 은 2·3 · c3 은 1·4 · c4 는 0·0" "$(trow 20260901-c1 | awk '{print $4, $5}')|$(trow 20260903-c3 | awk '{print $4, $5}')|$(trow 20260904-c4 | awk '{print $4, $5}')" "2 3|1 4|0 0"
dl a3b 20260901-w6 <<EOF
$HDR
$(pr 1 FAIL 'Critical abcde7 · Imp')
EOF
dl a3b 20260902-w7 <<EOF
$HDR
$(pr 1 FAIL 'Critical abcdef7 · Imp')
EOF
runs a3b
ck "T3.d 키워드와 숫자 사이 비숫자는 6자까지(공백 포함 6자 abcde7 은 읽고 7자 abcdef7 은 못 읽는다)" "$(printf '%s\n' "$OUT" | grep -F 'Critical 합')|$(cnt '숫자 못 읽은 FAIL 행 1건')" "FAIL 행 Critical 합 7 · Important 합 0 (숫자 읽힌 FAIL 행 1/2)|1"

dl a3c 20260901-n1 <<EOF
$HDR
$(pr 1 FAIL 'Critical (see below) 2 … Critical 4 · Important (none)')
EOF
runs a3c
ck "T3.e 키워드의 첫 출현 뒤에 6자 안의 숫자가 없으면 다음 출현에서 읽는다(Critical 4 · Important 는 못 읽음 → 읽힌 행 1/1)" "$(printf '%s\n' "$OUT" | grep -F 'Critical 합')" "FAIL 행 Critical 합 4 · Important 합 0 (숫자 읽힌 FAIL 행 1/1)"

# ══ AC-4: 도입 전후·--since ══
dl a4 20260801-a <<EOF
$HDR
$(pr 1 FAIL)
$(pr 2 PASS)
EOF
dl a4 20260808-b <<EOF
$HDR
$(pr 1 PASS)
EOF
dl a4 20260809-c <<EOF
$HDR
$(pr 1 FAIL)
$(pr 2 FAIL)
$(pr 3 PASS)
EOF
dl a4 20260901-d <<EOF
$HDR
$(pr 1 FAIL)
EOF
runs a4
ck "T4.a 기본(20260809): 도입 전(a·b) FID 2 · FAIL 1(50%) · 평균 1.50 / 도입 후(c·d) FID 2 · FAIL 2(100%) · 평균 2.00" "$(printf '%s\n' "$OUT" | grep -F '도입 전(')|$(printf '%s\n' "$OUT" | grep -F '도입 후(')" "도입 전(20260809 미만): FID 2 · 첫 라운드 FAIL 1 (50%) · 평균 라운드 1.50|도입 후(20260809 이상): FID 2 · 첫 라운드 FAIL 2 (100%) · 평균 라운드 2.00"
runs a4 --predispatch-date 20260901
ck "T4.b --predispatch-date 20260901: 전(a·b·c) FID 3 · FAIL 2(67%) · 평균 2.00 / 후(d) FID 1 · FAIL 1(100%) · 평균 1.00" "$(printf '%s\n' "$OUT" | grep -F '도입 전(')|$(printf '%s\n' "$OUT" | grep -F '도입 후(')" "도입 전(20260901 미만): FID 3 · 첫 라운드 FAIL 2 (67%) · 평균 라운드 2.00|도입 후(20260901 이상): FID 1 · 첫 라운드 FAIL 1 (100%) · 평균 라운드 1.00"
runs a4 --since 20260809
ck "T4.c --since 20260809: 전체 요약·표·전후 비교 모두 c·d 만 — FID 2개 · 도입 전 FID 0개 · 후 FID 2 · 표에 a·b 없음" "$(printf '%s\n' "$OUT" | grep -F 'FID 2개')|$(cnt '도입 전 FID 0개')|$(printf '%s\n' "$OUT" | grep -F '도입 후(')|$(cnt 20260801-a)$(cnt 20260808-b)" "FID 2개 · 라운드 분포 1회 1 · 3회 1 — 평균 2.00|1|도입 후(20260809 이상): FID 2 · 첫 라운드 FAIL 2 (100%) · 평균 라운드 2.00|00"
runs a4 --since 20260902
ck "T4.d --since 가 모든 FID 를 거르면(0개) 오류가 아니라 사실 줄 · rc=0" "$RC|$(cnt 'plan-reviewer 행 없음')" "0|1"

# ══ AC-11: 월별 첫 라운드 FAIL ══
dl a11 20260801-m1 <<EOF
$HDR
$(pr 1 FAIL)
EOF
dl a11 20260815-m2 <<EOF
$HDR
$(pr 1 FAIL)
$(pr 2 PASS)
EOF
dl a11 20260820-m3 <<EOF
$HDR
$(pr 1 PASS)
EOF
dl a11 20260901-m4 <<EOF
$HDR
$(pr 1 FAIL)
EOF
dl a11 20260902-m5 <<EOF
$HDR
$(pr 1 PASS)
EOF
dl a11 20260903-m6 <<EOF
$HDR
$(pr 1 PROCEED)
EOF
runs a11
ck "T11.a 월별 줄: 제목 + 202608 FID 3 · FAIL 2(67%) / 202609 FID 2 · FAIL 1(50%) 월 오름차순 — 기타 행만 있는 FID(m6)는 제외" "$(cnt '월별 첫 라운드 FAIL (FID 이름 날짜 접두 기준 · 표본 n 병기)')|$(printf '%s\n' "$OUT" | grep -E '^  20[0-9]{4}  FID' | tr '\n' '|')" "1|  202608  FID 3 · 첫 라운드 FAIL 2 (67%)|  202609  FID 2 · 첫 라운드 FAIL 1 (50%)|"
runs a11 --since 20260901
ck "T11.b --since 20260901 이면 202609 월만 나온다" "$(printf '%s\n' "$OUT" | grep -E '^  20[0-9]{4}  FID' | tr '\n' '|')" "  202609  FID 2 · 첫 라운드 FAIL 1 (50%)|"

# ══ AC-12: 첫 라운드 FAIL 심각도 분해 ══
dl a12 20260901-s1 <<EOF
$HDR
$(pr 1 FAIL 'Critical 1 · Important 2')
EOF
dl a12 20260902-s2 <<EOF
$HDR
$(pr 1 FAIL 'Critical 2 · Important 1')
EOF
dl a12 20260903-s3 <<EOF
$HDR
$(pr 1 FAIL 'Important 3 · Minor 4')
EOF
dl a12 20260904-s4 <<EOF
$HDR
$(pr 1 FAIL 'Critical 0 · Important 0 · Minor 3')
EOF
dl a12 20260905-s5 <<EOF
$HDR
$(pr 1 FAIL '서술만 있음')
EOF
runs a12
ck "T12.a 심각도 분해: Critical≥1 2/5(40%) · Important 만 1/5(20%) · 둘 다 0 1/5(20%) · 읽지 못함 1/5(20%) — 네 구간의 합 = 분모" "$(printf '%s\n' "$OUT" | grep -F '심각도')" "첫 라운드 FAIL 심각도: Critical≥1 2/5 (40%) · Important 만 1/5 (20%) · 둘 다 0 1/5 (20%) · 읽지 못함 1/5 (20%)"
dl a12b 20260901-z1 <<EOF
$HDR
$(pr 1 FAIL 'Critical 0 · Minor 2')
$(pr 2 PASS)
EOF
dl a12b 20260902-z2 <<EOF
$HDR
$(pr 1 PASS)
EOF
dl a12b 20260903-z3 <<EOF
$HDR
$(pr 1 FAIL 'Critical 2 · Important 0')
$(pr 2 PASS)
EOF
runs a12b
ck "T12.b Critical 0 만 읽히고 Important 는 못 읽은 첫 FAIL(z1)은 '둘 다 0' 이 아니라 '읽지 못함' · 심각도는 마지막이 아니라 첫 라운드 기준(z3 는 첫 라운드 Critical 2)" "$(printf '%s\n' "$OUT" | grep -F '심각도')" "첫 라운드 FAIL 심각도: Critical≥1 1/2 (50%) · Important 만 0/2 (0%) · 둘 다 0 0/2 (0%) · 읽지 못함 1/2 (50%)"
dl a12c 20260901-y1 <<EOF
$HDR
$(pr 1 PASS)
EOF
runs a12c
ck "T12.c 첫 라운드 FAIL 이 0건이면 심각도 줄이 '첫 라운드 FAIL 없음'" "$(cnt '첫 라운드 FAIL 없음')|$(cnt '심각도')" "1|0"

# ── Part B ──
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
