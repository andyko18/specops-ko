#!/usr/bin/env bash
# test-check-screen-quality.sh — 화면 품질 계측기 계약 (FID 20260820-design-quality-gate)
# 실 screens/ 미변경 — tmpdir fixture 로 결정적 검증.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SCRIPT="$PLUGIN/scripts/_internal/check-screen-quality.sh"
AGENT="$PLUGIN/agents/design-reviewer-ko.md"

TD=$(mktemp -d) || exit 1
trap 'rm -rf "$TD"' EXIT

# ── fixture: 위반(bad) / 정상(good) 쌍 ──
cat > "$TD/bad.html" <<'H'
<html><head><style>
:root { --color-primary: #7C3AED; --color-bg: #0F0F10; }
.btn { color: #7C3AED; background: #0F0F10; }
.shadow { box-shadow: 0 0 0 2px rgba(124,58,237,0.2); }
</style></head>
<body><div><input type="text"><input type="password"><select></select></div></body></html>
H
cat > "$TD/good.html" <<'H'
<html><head><style>
:root { --color-primary: #7C3AED; }
.btn { color: var(--color-primary); }
</style></head>
<body><main><nav></nav><section>
<label for="a">이메일</label><input id="a">
</section></main></body></html>
H
cat > "$TD/bad.md" <<'M'
## States
- Default: 빈 폼
- Loading: 버튼 비활성
- Error: 테두리 빨강
## 에러 메시지
- 오류
- 실패
M
cat > "$TD/good.md" <<'M'
## States
- 기본: 빈 상태 안내 표시
- 로딩: 스피너
- 오류: 재시도 버튼
## 에러 메시지
- 이메일 형식이 올바르지 않습니다
M

_val() {  # $1=출력 $2=키 → 값 추출
  printf '%s' "$1" | head -1 | grep -oE "$2=[^ ]+" | cut -d= -f2
}

bad=$(bash "$SCRIPT" "$TD/bad.md" "$TD/bad.html" 2>/dev/null)
good=$(bash "$SCRIPT" "$TD/good.md" "$TD/good.html" 2>/dev/null)

# ── T1.a: 5종 키를 모두 낸다 (AC-1) ──
miss=""
for k in states a11y-label semantic token microcopy; do
  printf '%s' "$bad" | head -1 | grep -q "$k=" || miss="$miss $k"
done
# 헤더 이름은 fixture 에서 파생한다 — 하드코딩하면 fixture 를 고칠 때 어서션이 조용히 낡는다
want_name=$(basename "$TD/bad.md" .md)
if printf '%s' "$bad" | head -1 | grep -q "^SCREEN-QUALITY: $want_name" && [ -z "$miss" ]; then
  ok "T1.a 5종 키 + SCREEN-QUALITY 헤더"
else
  nope "T1.a" "want=$want_name 누락:$miss head=$(printf '%s' "$bad" | head -1)"
fi

# ── T1.b~f: 각 검사가 양성·음성을 구분한다 (AC-2) ──
# 한쪽만 보면 항상통과 어서션이 된다 — bad/good 값이 서로 달라야 한다.
_diff_check() {  # $1=키 $2=TEST-ID $3=기대(bad) $4=기대(good)
  local kb kg; kb=$(_val "$bad" "$1"); kg=$(_val "$good" "$1")
  if [ "$kb" = "$3" ] && [ "$kg" = "$4" ] && [ "$kb" != "$kg" ]; then
    ok "$2 $1 양성·음성 구분 (bad=$kb good=$kg)"
  else
    nope "$2" "$1 bad=$kb(기대 $3) good=$kg(기대 $4)"
  fi
}
_diff_check states      T1.b "2/3" "3/3"
_diff_check a11y-label  T1.c "0/3" "1/1"
_diff_check semantic    T1.d "0"   "3"
_diff_check token       T1.e "2"   "0"
_diff_check microcopy   T1.f "2"   "0"

# ── T1.g: 항상 exit 0 (AC-3) ──
bash "$SCRIPT" "$TD/bad.md"  "$TD/bad.html"  >/dev/null 2>&1; r1=$?
bash "$SCRIPT" "$TD/good.md" "$TD/good.html" >/dev/null 2>&1; r2=$?
bash "$SCRIPT" "$TD/none.md" "$TD/none.html" >/dev/null 2>&1; r3=$?
if [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && [ "$r3" -eq 0 ]; then
  ok "T1.g 항상 exit 0 (위반=$r1 정상=$r2 부재=$r3) — 계측 전용"
else
  nope "T1.g" "위반=$r1 정상=$r2 부재=$r3"
fi

# ── T1.h: 판정 불가는 unknown (AC-4) ──
# .html 부재를 '위반 0' 으로 보고하면 무음 낙관이다 (doctor.sh v1.78.0 교훈).
out=$(bash "$SCRIPT" "$TD/good.md" "$TD/absent.html" 2>/dev/null)
uk_a=$(_val "$out" a11y-label); uk_s=$(_val "$out" semantic); st=$(_val "$out" states)
if [ "$uk_a" = "unknown" ] && [ "$uk_s" = "unknown" ] && [ "$st" = "3/3" ]; then
  ok "T1.h html 부재 → html 검사만 unknown, md 검사는 계속 (states=$st)"
else
  nope "T1.h" "a11y=$uk_a semantic=$uk_s states=$st (0 이 아니라 unknown 이어야)"
fi

# ── T1.i: read-only (AC-3) ──
b1=$(shasum "$TD/bad.html" | awk '{print $1}'); n1=$(ls -1 "$TD" | wc -l | tr -d ' ')
bash "$SCRIPT" "$TD/bad.md" "$TD/bad.html" >/dev/null 2>&1
b2=$(shasum "$TD/bad.html" | awk '{print $1}'); n2=$(ls -1 "$TD" | wc -l | tr -d ' ')
[ "$b1" = "$b2" ] && [ "$n1" = "$n2" ] && ok "T1.i read-only — sha·파일수 불변" \
  || nope "T1.i" "sha $b1→$b2 files $n1→$n2"

# ── T1.j: 리뷰어에 품질 관점 4개 + 실측 명령 (AC-5) ──
pmiss=""
for p in '상태 설계' '접근성' '디자인 시스템 준수' '콘텐츠 품질'; do
  grep -qF "$p" "$AGENT" || pmiss="$pmiss $p"
done
cmd=$(grep -c 'check-screen-quality' "$AGENT" || true)
if [ -z "$pmiss" ] && [ "${cmd:-0}" -ge 1 ]; then
  ok "T1.j 품질 관점 4개 + 실측 명령 참조 (${cmd}건)"
else
  nope "T1.j" "누락:$pmiss cmd=$cmd"
fi

# ── T1.k: 신규 4관점에 Critical 없음 (AC-6) ──
# /start-all-auto 는 Critical>=1 에서 무인 실행을 정지한다 — 주관 판정으로 배치를 세우지 않는다.
badrow=""
for p in '상태 설계' '접근성' '디자인 시스템 준수' '콘텐츠 품질'; do
  row=$(grep -F "| $p |" "$AGENT" | head -1)
  [ -n "$row" ] || { badrow="$badrow [$p:행없음]"; continue; }
  # 2번째 칸(Critical)이 '—' 또는 공백이어야 한다
  crit=$(printf '%s' "$row" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$3); print $3}')
  case "$crit" in ''|'—'|'-') ;; *) badrow="$badrow [$p:$crit]" ;; esac
done
[ -z "$badrow" ] && ok "T1.k 신규 4관점 Critical 칸 비움" || nope "T1.k" "Critical 기재:$badrow"

# ── T1.l: 무출력 exit 0 금지 (외부 critic — T1.h 동일 클래스) ──
# 대상이 없거나 인자가 틀려도 침묵하면 리뷰어가 "위반 없음" 으로 읽는다.
o1=$(bash "$SCRIPT" 2>/dev/null); r1=$?
o2=$(cd "$TD" && bash "$SCRIPT" --all 2>/dev/null); r2=$?   # screens/ 없는 cwd
if [ "$r1" -eq 0 ] && printf '%s' "$o1" | grep -q 'SCREEN-QUALITY:.*unknown' \
   && [ "$r2" -eq 0 ] && printf '%s' "$o2" | grep -q 'SCREEN-QUALITY:.*unknown'; then
  ok "T1.l 대상 0개·인자 부족에도 unknown 1줄 출력 (무음 낙관 차단)"
else
  nope "T1.l" "인자부족 rc=$r1 out='$(printf '%s' "$o1" | head -1)' / --all rc=$r2 out='$(printf '%s' "$o2" | head -1)'"
fi

# ── T1.m: token 정의부 정규식이 scale·대문자 var 명을 인정한다 (Phase C I-1) ──
# `[a-z-]` 로 좁히면 --gray-100·--Color-Primary 를 정의부로 못 잡아 정상 코드가
# 전부 하드코딩으로 오탐된다. 리뷰어 기준이 "3건 이상=Important" 라 곧바로 오판정.
cat > "$TD/scale.html" <<'H'
<style>:root { --gray-100: #F3F4F6; --Color-Primary: #7C3AED; --c1: #ABCDEF; }
.x { color: #F3F4F6; }</style>
H
cp "$TD/good.md" "$TD/scale.md"
tk=$(_val "$(bash "$SCRIPT" "$TD/scale.md" "$TD/scale.html" 2>/dev/null)" token)
[ "$tk" = "1" ] && ok "T1.m token 정의부 — scale·대문자 var 명 인정 (token=$tk)" \
  || nope "T1.m" "token=$tk (기대 1 — 정의부 3건 제외 후 하드코딩 1건). [a-z-] 로 좁히면 4 가 나온다"

# ── T1.n: states 상세가 누락 '항목명' 을 낸다 (Phase C I-2) ──
# 리뷰어 표는 심각도를 종류로 가른다(empty·error=Important / loading만=Minor).
# 비율만 내면 그 판정을 계측 결과에서 도출할 수 없다.
det=$(bash "$SCRIPT" "$TD/bad.md" "$TD/bad.html" 2>/dev/null | grep '\[states\]')
if printf '%s' "$det" | grep -q 'empty'; then
  ok "T1.n states 상세에 누락 항목명 표기 ($(printf '%s' "$det" | sed 's/^ *//'))"
else
  nope "T1.n" "det='$det' (누락 항목명이 없으면 리뷰어가 심각도를 도출할 수 없다)"
fi

# ── T1.o: hidden input 은 label 대상에서 제외 (Phase C M-1) ──
cat > "$TD/hid.html" <<'H'
<main><label for="a">이메일</label><input id="a"><input type="hidden" name="csrf"></main>
H
cp "$TD/good.md" "$TD/hid.md"
al=$(_val "$(bash "$SCRIPT" "$TD/hid.md" "$TD/hid.html" 2>/dev/null)" a11y-label)
[ "$al" = "1/1" ] && ok "T1.o hidden input 제외 (a11y-label=$al)" \
  || nope "T1.o" "a11y-label=$al (기대 1/1 — hidden 은 label 대상 아님)"

finish
