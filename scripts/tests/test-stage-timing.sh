#!/usr/bin/env bash
# stage-timing.sh — FID 간 단계별 소요 집계 (fixture 원장은 SPECOPS_ROOT 로 주입, 토큰 0)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ST="$PLUGIN/scripts/stage-timing.sh"
SB=$(mktemp -d)
trap 'rm -rf "$SB"' EXIT

ck() { if [ "$2" = "$3" ]; then echo "PASS $1"; PASS=$((PASS+1)); else echo "FAIL $1 — exp '$3' got '$2'"; FAIL=$((FAIL+1)); fi; }

# 원장 fixture 를 만든다: mkroot 이름 — 본문은 stdin. SPECOPS_ROOT 로 쓸 디렉토리를 출력한다.
mkroot() { mkdir -p "$SB/$1" && cat > "$SB/$1/session-progress.md" && printf '%s' "$SB/$1"; }
# 실행: run root [옵션...] — 전역 OUT·ERR·RC
run() {
  local root="$1"; shift
  OUT=$(SPECOPS_ROOT="$root" bash "$ST" "$@" 2>"$SB/err"); RC=$?
  ERR=$(cat "$SB/err")
}
# 표에서 단계 행의 "합계 비중 n 중앙값 p90 max" 를 뽑는다 (단계 이름은 행 끝)
row() { printf '%s\n' "$OUT" | grep -E "^ *[0-9]+ +[0-9.]+% .* $1\$" | awk '{print $1, $2, $3, $4, $5, $6}'; }

FX1=$(mkroot fx1 <<'EOF'
# Session Progress

## 20261001-aaa · A

- 2026-10-01 10:30 /plan 완료 (x)
- 2026-10-01 10:10 /clarify 완료 (x)
- 2026-10-01 10:00 /specify 완료 (x)

## 20261001-bbb · B

- 2026-10-02 09:10 /clarify 완료 (x)
- 2026-10-02 09:08 /specify 완료 (x)
EOF
)

# ── AC-1: 인접 차이 귀속·집계 ──
run "$FX1"
ck "T1.a rc=0" "$RC" "0"
ck "T1.b /clarify 완료: n=2 중앙값 2 p90 10 max 10 합계 12 비중 37.5%" "$(row '/clarify 완료')" "12 37.5% 2 2 10 10"
ck "T1.c /plan 완료: n=1 합계 20 비중 62.5%" "$(row '/plan 완료')" "20 62.5% 1 20 20 20"
FIRST=$(printf '%s\n' "$OUT" | grep -E '^ *[0-9]+ +[0-9.]+% ' | head -1 | awk '{print $NF" "$(NF-1)}')
ck "T1.d 합계 내림차순 — 첫 행이 /plan 완료" "$FIRST" "완료 /plan"
ck "T1.e 기준 행 없는 /specify 완료는 집계에 없음 + FID 경계 비교차" "$(printf '%s\n' "$OUT" | grep -cE '^ *[0-9]+ +[0-9.]+% .* /specify 완료$')" "0"

FX2=$(mkroot fx2 <<'EOF'
## 20261001-ccc · C

- 2026-10-01 09:01 /verify PASS (x)
- 2026-10-01 09:01 /implement DONE (x)
- 2026-10-01 08:59 /tasks 완료 (x)
EOF
)
run "$FX2"
ck "T1.f 08:59→09:01 = 2분(8진수 함정 없음) · 동일 분은 원장 순서 tiebreak(implement 2 · verify 0)" \
   "$(row '/implement DONE') | $(row '/verify PASS')" "2 100.0% 1 2 2 2 | 0 0.0% 1 0 0 0"

TIE=$(mkroot tie <<'EOF'
## 20261001-ggg · G

- 2026-10-01 10:05 /plan 완료 (x)
- 2026-10-01 10:04 /plan SKIP (x)
- 2026-10-01 10:03 /m 완료 (x)
- 2026-10-01 10:02 /a 완료 (x)
- 2026-10-01 10:01 /z 완료 (x)
- 2026-10-01 10:00 /specify 완료 (x)
EOF
)
run "$TIE"
ck "T1.g 합계 동률(각 1분)이면 단계 이름 바이트 순 — 삽입 순서·로케일과 무관" \
   "$(printf '%s\n' "$OUT" | grep -E '^ *[0-9]+ +[0-9.]+% ' | awk '{print $(NF-1)" "$NF}' | tr '\n' ',')" "/a 완료,/m 완료,/plan SKIP,/plan 완료,/z 완료,"

# ── AC-2: 방치 구간 ──
FX3=$(mkroot fx3 <<'EOF'
## 20261001-ddd · D

- 2026-10-02 10:05 /verify PASS (x)
- 2026-10-02 10:00 /implement DONE (x)
- 2026-10-01 10:00 /tasks 완료 (x)
EOF
)
run "$FX3"
ck "T2.a 기본 상한: 1440분 구간은 통계에서 제외, /verify PASS 5분만" "$(row '/verify PASS')" "5 100.0% 1 5 5 5"
ck "T2.b 제외 줄: 1건 합 1440분" "$(printf '%s\n' "$OUT" | grep -c '방치 구간 제외 1건 (합 1440분)')" "1"
ck "T2.c 제외 구간의 단계는 표에 없음" "$(printf '%s\n' "$OUT" | grep -cE '^ *[0-9]+ +[0-9.]+% .* /implement DONE$')" "0"
run "$FX3" --gap-cap-min 2000
ck "T2.d 상한 2000: 포함 — /implement DONE 합계 1440" "$(row '/implement DONE')" "1440 99.7% 1 1440 1440 1440"
ck "T2.e 상한 2000: 제외 0건 표시" "$(printf '%s\n' "$OUT" | grep -c '방치 구간 제외 0건 (합 0분)')" "1"

EDGE=$(mkroot edge <<'EOF'
## 20261001-hhh · H

- 2026-10-01 10:21 /c 완료 (x)
- 2026-10-01 10:10 /b 완료 (x)
- 2026-10-01 10:00 /a 완료 (x)
EOF
)
run "$EDGE" --gap-cap-min 10
ck "T2.f 경계값: 정확히 상한(10분)은 포함, 상한+1(11분)은 제외" \
   "$(row '/b 완료')|$(printf '%s\n' "$OUT" | grep -cE '^ *[0-9]+ +[0-9.]+% .* /c 완료$')|$(printf '%s\n' "$OUT" | grep -c '방치 구간 제외 1건 (합 11분)')" "10 100.0% 1 10 10 10|0|1"

# ── AC-3: 머리말·가림·집계 불가 ──
FX4=$(mkroot fx4 <<'EOF'
## 20261001-aaa · A

- 2026-10-01 10:30 /plan 완료 (x)
- 2026-10-01 10:10 /clarify 완료 (x)
- 2026-10-01 10:00 /specify 완료 (x)

## 20261001-bbb · B

- 2026-10-02 09:10 /clarify 완료 (x)
- 2026-10-02 09:08 /specify 완료 (x)

## 20261001-eee · E

- 2026-10-03 08:00 /specify 완료 (x)
EOF
)
run "$FX4" --min-n 2
for kw in '완료시각 인접 차이' '분 해상도' '대기 포함 경과 시간' 'FID 경계 미교차' 'DST'; do
  ck "T3.a 머리말 키워드: $kw" "$(printf '%s\n' "$OUT" | grep -c "$kw")" "1"
done
ck "T3.b --min-n 2: /plan 완료(n=1) 가림, 가린 단계 수 표시" "$(printf '%s\n' "$OUT" | grep -c '표 가림(--min-n 2) 1단계')" "1"
ck "T3.c 가려진 단계는 표에 없음" "$(printf '%s\n' "$OUT" | grep -cE '^ *[0-9]+ +[0-9.]+% .* /plan 완료$')" "0"
ck "T3.d 집계 불가 표시: FID 첫 행 3개 · 행 1개뿐인 FID 1개" "$(printf '%s\n' "$OUT" | grep -c 'FID 첫 행 3개는 기준 행이 없어 집계에 없음 (행 1개뿐인 FID 1개)')" "1"

ck "T3.e 표 머리행은 한글 표시 폭에 맞춰 정렬된 고정 문자열" "$(printf '%s\n' "$OUT" | grep -E '단계$' | head -1)" "   합계    비중     n  중앙값    p90    max  단계"

# ── AC-4: 옵션·rc ──
run "$SB/없는-디렉토리"
ck "T4.a 원장 부재 → rc=2 · stderr 사유 · stdout 비어 있음" "$RC|$(printf '%s' "$ERR" | grep -c '원장 없음')|$OUT" "2|1|"
run "$FX1" --bogus
ck "T4.b 알 수 없는 옵션 → rc=2" "$RC|$(printf '%s' "$OUT")" "2|"
run "$FX1" --gap-cap-min abc
ck "T4.c 숫자 아닌 --gap-cap-min → rc=2" "$RC|$(printf '%s' "$OUT")" "2|"
run "$FX1" --since 2026-10-01
ck "T4.d --since 형식 오류 → rc=2" "$RC|$(printf '%s' "$OUT")" "2|"
run "$FX1" --min-n 0
ck "T4.e --min-n 0 → rc=2" "$RC|$(printf '%s' "$OUT")" "2|"
run "$FX1" --since
ck "T4.f 값 없는 옵션 → rc=2" "$RC|$(printf '%s' "$OUT")" "2|"
ONE=$(mkroot one <<'EOF'
## 20261001-fff · F

- 2026-10-01 10:00 /specify 완료 (x)
EOF
)
run "$ONE"
ck "T4.g 행 1개뿐 → rc=0 · '집계할 구간 없음' 사실 표시(원장 부재와 구별)" "$RC|$(printf '%s\n' "$OUT" | grep -c '집계할 구간 없음')" "0|1"
run "$FX1" --since 20261002
ck "T4.h --since 20261002: 도착 행 날짜가 기준일 이상인 구간만(bbb /clarify 2분)" "$(row '/clarify 완료')|$(printf '%s\n' "$OUT" | grep -cE '^ *[0-9]+ +[0-9.]+% .* /plan 완료$')" "2 100.0% 1 2 2 2|0"
EMPTY=$(mkroot empty <<'EOF'
# Session Progress (행 없음)
EOF
)
run "$EMPTY"
ck "T4.i 행이 아예 없는 원장 → rc=0 · 구간 없음 표시" "$RC|$(printf '%s\n' "$OUT" | grep -c '집계할 구간 없음')" "0|1"

# ── AC-5: 읽기 전용 · 정적 규약 · 성능 · 로케일 ──
BEFORE="$(cksum < "$FX1/session-progress.md")|$(git -C "$PLUGIN" status --porcelain 2>/dev/null | cksum)"
run "$FX1"
AFTER="$(cksum < "$FX1/session-progress.md")|$(git -C "$PLUGIN" status --porcelain 2>/dev/null | cksum)"
ck "T5.a 실행 전후 원장 바이트·git status 동일(읽기 전용)" "$AFTER" "$BEFORE"
ck "T5.b mktime 호출 없음(BSD awk 에 없다)" "$(grep -cE 'mktime *\(' "$ST")" "0"
ck "T5.c 행 단위 read 루프 없음(외부 프로세스 줄 스폰 금지)" "$(grep -cE 'while +(IFS= +)?(-r +)?read' "$ST")" "0"
OUT_DEFAULT="$OUT"
OUT_KO=$(LANG=ko_KR.UTF-8 LC_ALL=ko_KR.UTF-8 SPECOPS_ROOT="$FX1" bash "$ST" 2>&1)
ck "T5.d 로케일을 바꿔도 출력 동일(LC_ALL 고정 — 동률 정렬 비교가 로케일 의존이라 T1.g 와 함께 잠근다)" "$OUT_KO" "$OUT_DEFAULT"
BIG="$SB/big"; mkdir -p "$BIG"
awk 'BEGIN {
  print "# Session Progress"
  for (f = 1; f <= 350; f++) {
    printf "\n## 202610%02d-big%d · B\n\n", (f % 28) + 1, f
    for (r = 10; r >= 1; r--) printf "- 2026-10-%02d %02d:%02d /step%d 완료 (x)\n", (f % 28) + 1, 9 + int(r / 6), (r * 7) % 60, r
  }
}' > "$BIG/session-progress.md"
T0=$(date +%s)
run "$BIG"
T1=$(date +%s)
ck "T5.e 3500행 원장 집계 rc=0 · 3초 이내(NFR-1 은 1초 — CPU 경합 여유)" "$RC|$(( T1 - T0 <= 3 ))" "0|1"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
