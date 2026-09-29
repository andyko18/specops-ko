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
_NLT='
'

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

# ── 품질 관점 목록 (단일 소스 — 관점 추가 시 여기만 늘린다) ──
QP='상태 설계
접근성
디자인 시스템 준수
콘텐츠 품질
DESIGN 준수
장르 규칙
안티패턴'
QP_N=$(printf '%s\n' "$QP" | wc -l | tr -d ' ')

# ── T1.j: 리뷰어에 품질 관점 전건 + 실측 명령 (AC-5 · 20260821 AC-8) ──
pmiss=""
while IFS= read -r p; do
  grep -qF -e "$p" "$AGENT" || pmiss="$pmiss $p"
done <<EOF2
$QP
EOF2
cmd=$(grep -c 'check-screen-quality' "$AGENT" || true)
if [ -z "$pmiss" ] && [ "${cmd:-0}" -ge 1 ]; then
  ok "T1.j 품질 관점 ${QP_N}개 + 실측 명령 참조 (${cmd}건)"
else
  nope "T1.j" "누락:$pmiss cmd=$cmd"
fi

# ── T1.k: 품질 관점 전건에 Critical 없음 (AC-6) ──
# /start-all-auto 는 Critical>=1 에서 무인 실행을 정지한다 — 주관 판정으로 배치를 세우지 않는다.
badrow=""
while IFS= read -r p; do
  row=$(grep -F "| $p |" "$AGENT" | head -1)
  [ -n "$row" ] || { badrow="$badrow [$p:행없음]"; continue; }
  # 2번째 칸(Critical)이 '—' 또는 공백이어야 한다
  crit=$(printf '%s' "$row" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$3); print $3}')
  case "$crit" in ''|'—'|'-') ;; *) badrow="$badrow [$p:$crit]" ;; esac
done <<EOF2
$QP
EOF2
[ -z "$badrow" ] && ok "T1.k 품질 관점 ${QP_N}개 Critical 칸 비움" || nope "T1.k" "Critical 기재:$badrow"

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

# ══ genre 축 — 화면 원형별 장르 규칙 (FID 20260929-enterprise-genre-rules) ══
_gmd() {  # $1=파일 $2=원형 값('-'=원형 줄 생략) $3=본문
  { printf '# 픽스처\n\n'; [ "$2" = "-" ] || printf '**원형**: %s\n\n' "$2"; printf '%s\n' "$3"; } > "$1"
}
_gout() { bash "$SCRIPT" "$1" "$TD/good.html" 2>/dev/null; }
_gdet() { printf '%s\n' "$1" | grep -F '[genre]'; }

LIST_OK='## States
- Empty: 데이터 없음이면 첫 등록 안내, 검색 결과 없음이면 조건 초기화
- Loading: 스켈레톤
- Error: 재시도 버튼
## Interactions
- 페이지네이션 20건 단위 · 총 건수 표시
- 기본 정렬 기준: 등록일 내림차순'
FORM_OK='## States
- Empty: 빈 입력 폼
- Loading: 제출 중 버튼 비활성
- Error: 입력 단위 인라인 메시지
## Interactions
- 취소 버튼은 목록으로 이동'
WIZ_OK="$FORM_OK
- 단계 표시 1/3 · 이전 버튼 · 임시 저장"
DASH_OK='## States
- Empty: 지표 없음 안내
- Loading: 스켈레톤
- Error: 재시도
## Interactions
- 기간 선택 (최근 7일 기본)'
LNEG="${LIST_OK/기본 정렬 기준: 등록일 내림차순/제목 셀 중앙 정렬}"

# ── G1: 판정 불가·계측 규칙 없음 경로 (AC-1) — 숫자로 위장하지 않는다 ──
cp "$PLUGIN/templates/screen.md" "$TD/tpl.md"
_g1() {  # $1=라벨 $2=md $3=기대(unknown|n/a)
  local o v c; o=$(_gout "$2"); v=$(_val "$o" genre)
  c=$(_gdet "$o" | grep -c . || true)
  if [ "$v" != "$3" ] || _gdet "$o" | grep -q '미충족'; then
    nope "G1.$1" "genre=$v (기대 $3) det=$(_gdet "$o" | tr '\n' ' ')"
  elif [ "$3" = unknown ] && [ "$c" != 1 ]; then
    nope "G1.$1" "unknown 사유 상세줄 ${c}개 (기대 1)"
  elif [ "$3" = n/a ] && [ "$c" != 0 ]; then
    nope "G1.$1" "n/a 인데 상세줄 ${c}개"
  else
    ok "G1.$1 genre=$v"
  fi
}
_gmd "$TD/g-none.md" - "$LIST_OK";  _g1 원형없음 "$TD/g-none.md" unknown
_gmd "$TD/g-ph.md" '[목록 | 상세 | 폼 | 다단 폼 | 대시보드 | 기타]' "$LIST_OK"; _g1 자리표시자 "$TD/g-ph.md" unknown
_gmd "$TD/g-bad.md" 갤러리 "$LIST_OK"; _g1 목록밖 "$TD/g-bad.md" unknown
_gmd "$TD/g-det.md" 상세 "$LIST_OK";  _g1 상세 "$TD/g-det.md" n/a
_gmd "$TD/g-etc.md" 기타 "$LIST_OK";  _g1 기타 "$TD/g-etc.md" n/a
_g1 md부재 "$TD/absent-genre.md" unknown
_g1 login "$PLUGIN/screens/login.md" unknown
_g1 템플릿복사 "$TD/tpl.md" unknown

# G1.k 요약줄 키 순서 — 기존 5키 뒤 genre 가 마지막 (전체 줄 일치)
_kre='^SCREEN-QUALITY: [^ ]+  states=[^ ]+  a11y-label=[^ ]+  semantic=[^ ]+  token=[^ ]+  microcopy=[^ ]+  genre=[^ ]+  anti=[^ ]+$'
_gk=$(_gout "$TD/g-none.md" | head -1)
printf '%s\n' "$_gk" | grep -qE "$_kre" && ok "G1.k 요약줄 키 순서 — genre 마지막" || nope "G1.k" "head='$_gk'"
_gu1=$(bash "$SCRIPT" 2>/dev/null | head -1); _gu2=$(cd "$TD" && bash "$SCRIPT" --all 2>/dev/null | head -1)
if printf '%s\n' "$_gu1" | grep -qE '  genre=unknown  anti=unknown$' && printf '%s\n' "$_gu2" | grep -qE '  genre=unknown  anti=unknown$'; then
  ok "G1.u _unknown_line 도 genre=unknown 으로 끝남"
else
  nope "G1.u" "인자부족='$_gu1' --all='$_gu2'"
fi

# ── G2: 계측 규칙 7개 판별력 (AC-2) — 양성 통과 · 음성은 그 ID 만 적발 ──
_gcase() {  # $1=ID $2=원형 $3=양성 본문 $4=음성 본문 $5=규칙 수
  local p n pv nv want_n
  want_n="$(( $5 - 1 ))/$5"
  _gmd "$TD/gp.md" "$2" "$3"; p=$(_gout "$TD/gp.md"); pv=$(_val "$p" genre)
  _gmd "$TD/gn.md" "$2" "$4"; n=$(_gout "$TD/gn.md"); nv=$(_val "$n" genre)
  if [ "$pv" = "$5/$5" ] && [ "$nv" = "$want_n" ] \
     && ! _gdet "$p" | grep -q '미충족' \
     && [ "$(_gdet "$n" | grep -c '미충족' || true)" = 1 ] \
     && _gdet "$n" | grep -qF "[genre] $1 미충족 — "; then
    ok "G2.$1 양성 $pv · 음성 $nv — $1 만 적발"
  else
    nope "G2.$1" "양성=$pv(기대 $5/$5) 음성=$nv(기대 $want_n) det=$(_gdet "$n" | tr '\n' ' ')"
  fi
}
_gcase G-LIST-PAGING     목록      "$LIST_OK" "${LIST_OK/ · 총 건수 표시/}" 3
_gcase G-LIST-SORT       목록      "$LIST_OK" "$LNEG" 3
_gcase G-LIST-EMPTY-KIND 목록      "$LIST_OK" "${LIST_OK/, 검색 결과 없음이면 조건 초기화/}" 3
_gcase G-FORM-SUBMIT     폼        "$FORM_OK" "${FORM_OK/제출 중 버튼 비활성/스피너 표시}" 2
_gcase G-FORM-CANCEL     폼        "$FORM_OK" "${FORM_OK/취소 버튼은 목록으로 이동/저장 후 상세로 이동}" 2
_gcase G-WIZARD-STEP     '다단 폼' "$WIZ_OK"  "${WIZ_OK/ · 임시 저장/}" 3
_gcase G-DASH-PERIOD     대시보드  "$DASH_OK" "${DASH_OK/기간 선택 (최근 7일 기본)/지표 카드 4개}" 1

# ── G3: override 계약 (AC-3) — 조용히 제외하지 않는다 ──
_gmd "$TD/ov1.md" 목록 "$LNEG
<!-- genre-override: G-LIST-SORT 시간순 고정 스트림 -->"
o=$(_gout "$TD/ov1.md")
if [ "$(_val "$o" genre)" = 3/3 ] && _gdet "$o" | grep -qF '[genre] G-LIST-SORT override — 시간순 고정 스트림' \
   && ! _gdet "$o" | grep -q '미충족'; then
  ok "G3.a 사유 있는 override — 충족으로 세고 항상 출력"
else nope "G3.a" "genre=$(_val "$o" genre) det=$(_gdet "$o" | tr '\n' ' ')"; fi

_gmd "$TD/ov2.md" 목록 "$LNEG
<!-- genre-override: G-LIST-SORT -->"
o=$(_gout "$TD/ov2.md")
if [ "$(_val "$o" genre)" = 2/3 ] && _gdet "$o" | grep -qF '[genre] G-LIST-SORT 미충족' \
   && _gdet "$o" | grep -qF '[genre] G-LIST-SORT override 사유 없음 — 억제하지 않음'; then
  ok "G3.b 사유 없는 override — 억제 안 함 + 경고"
else nope "G3.b" "genre=$(_val "$o" genre) det=$(_gdet "$o" | tr '\n' ' ')"; fi

_gmd "$TD/ov3.md" 목록 "$LNEG
<!-- genre-override: G-DASH-PERIOD 무관 -->"
o=$(_gout "$TD/ov3.md")
if [ "$(_val "$o" genre)" = 2/3 ] && _gdet "$o" | grep -qF '[genre] G-DASH-PERIOD override 대상 아님' \
   && _gdet "$o" | grep -qF '[genre] G-LIST-SORT 미충족'; then
  ok "G3.c 원형 밖 ID override — 경고 · 판정 불변"
else nope "G3.c" "genre=$(_val "$o" genre) det=$(_gdet "$o" | tr '\n' ' ')"; fi

# G3.d 주석 구간만 제거 — 같은 줄의 본문은 판정에 남는다
_gmd "$TD/ov4.md" 목록 "$LNEG
- 기본 정렬 기준: 최신순 <!-- genre-override: G-DASH-PERIOD 무관 -->"
o=$(_gout "$TD/ov4.md")
[ "$(_val "$o" genre)" = 3/3 ] && ok "G3.d override 주석과 같은 줄 본문 보존" \
  || nope "G3.d" "genre=$(_val "$o" genre) (같은 줄 '정렬 기준' 이 사라짐)"

# G3.e 사유 문구가 다른 규칙 키워드로 새지 않는다
_gmd "$TD/ov5.md" 목록 "$LNEG
<!-- genre-override: G-DASH-PERIOD 정렬 기준 없음 -->"
o=$(_gout "$TD/ov5.md")
_gdet "$o" | grep -qF '[genre] G-LIST-SORT 미충족' && ok "G3.e override 사유가 판정 본문에 새지 않음" \
  || nope "G3.e" "det=$(_gdet "$o" | tr '\n' ' ')"

# G3.f·g 판독 불가 override(다중줄 · 사유에 '>') — 무음 통과 금지 (Phase C Important)
# 정규식이 못 잡으면 사유 키워드('기간 선택')가 본문으로 새어 충족으로 위장되고 override 줄도 안 나온다.
_gunparse() {  # $1=라벨 $2=md
  local o; o=$(_gout "$2")
  if [ "$(_val "$o" genre)" = 0/1 ] && _gdet "$o" | grep -qF '[genre] override 구문 판독 불가 1건' \
     && _gdet "$o" | grep -qF '[genre] G-DASH-PERIOD 미충족'; then
    ok "G3.$1 판독 불가 override — 경고 + 사유 키워드 미누설"
  else nope "G3.$1" "genre=$(_val "$o" genre) det=$(_gdet "$o" | tr '\n' ' ')"; fi
}
_gmd "$TD/ov6.md" 대시보드 "${DASH_OK/기간 선택 (최근 7일 기본)/지표 카드 4개}
<!-- genre-override: G-DASH-PERIOD
     기간 선택 없음 — 실시간 뷰 -->"
_gunparse f "$TD/ov6.md"
_gmd "$TD/ov7.md" 대시보드 "${DASH_OK/기간 선택 (최근 7일 기본)/지표 카드 4개}
<!-- genre-override: G-DASH-PERIOD 상단 > 기간 선택 대신 실시간 -->"
_gunparse g "$TD/ov7.md"

# ── G7: 복합 원형 (AC-7 · clarify Q1) ──
_gmd "$TD/c1.md" '목록, 상세' "$LIST_OK"; o=$(_gout "$TD/c1.md")
[ "$(_val "$o" genre)" = 3/3 ] && ok "G7.a 목록, 상세 → 3/3" || nope "G7.a" "genre=$(_val "$o" genre)"
_gmd "$TD/c1n.md" '목록, 상세' "$LNEG"; o=$(_gout "$TD/c1n.md")
{ [ "$(_val "$o" genre)" = 2/3 ] && _gdet "$o" | grep -qF '[genre] G-LIST-SORT 미충족'; } \
  && ok "G7.b 복합 원형 음성 → G-LIST-SORT 적발" || nope "G7.b" "genre=$(_val "$o" genre)"
_gmd "$TD/c2.md" '폼, 다단 폼' "$WIZ_OK"; o=$(_gout "$TD/c2.md")
[ "$(_val "$o" genre)" = 3/3 ] && ok "G7.c 폼, 다단 폼 → 중복 1회 3/3" || nope "G7.c" "genre=$(_val "$o" genre)"
_gmd "$TD/c3.md" '상세, 기타' "$LIST_OK"; o=$(_gout "$TD/c3.md")
[ "$(_val "$o" genre)" = n/a ] && ok "G7.d 상세, 기타 → n/a" || nope "G7.d" "genre=$(_val "$o" genre)"
_gmd "$TD/c4.md" '목록, 갤러리' "$LIST_OK"; o=$(_gout "$TD/c4.md")
{ [ "$(_val "$o" genre)" = unknown ] && _gdet "$o" | grep -F '원형 값 판독 불가: ' | grep -qF '갤러리'; } \
  && ok "G7.e 목록, 갤러리 → 전체 unknown" || nope "G7.e" "genre=$(_val "$o" genre)"

# ── G6: verify backstop 배선 (AC-6 · AC-8) — 화면 껍데기 점검과 같은 목록 ──
VS="$PLUGIN/skills/verifying-evidence-ko/SKILL.md"
_l_sh=$(grep -n '화면 껍데기 점검' "$VS" | head -1 | cut -d: -f1)
_l_cv=$(grep -n '테스트=spec 커버 점검' "$VS" | head -1 | cut -d: -f1)
_l_q=$(grep -n 'check-screen-quality\.sh --all' "$VS" | head -1 | cut -d: -f1)
if [ -n "$_l_sh" ] && [ -n "$_l_cv" ] && [ -n "$_l_q" ] && [ "$_l_q" -gt "$_l_sh" ] && [ "$_l_q" -lt "$_l_cv" ]; then
  _blk=$(sed -n "${_l_q},$((_l_cv - 1))p" "$VS")
  { printf '%s' "$_blk" | grep -qF '## 화면 품질 계측' && printf '%s' "$_blk" | grep -qF 'VERIFY: FAIL' \
    && printf '%s' "$_blk" | grep -qF 'graceful skip'; } \
    && ok "G6.a verify SKILL 계측 실행 · evidence 섹션 · 비차단 · skip" \
    || nope "G6.a" "블록에 '## 화면 품질 계측'·'VERIFY: FAIL'(승급 금지)·'graceful skip' 중 누락"
  printf '%s' "$_blk" | grep -qF '상세줄이 있는 화면' \
    && ok "G6.b 사용자 출력은 상세줄 있는 화면만 (AC-8)" || nope "G6.b" "출력 수준 문구 없음"
else
  nope "G6.a" "배선 위치 — 껍데기=${_l_sh:-없음} 계측=${_l_q:-없음} 커버=${_l_cv:-없음} (껍데기 < 계측 < 커버 기대)"
  nope "G6.b" "배선 부재로 판정 불가"
fi

# ══ 규칙 ID 카탈로그 (FID 20260929-design-rule-id-catalog) ══
_rules=$(bash "$SCRIPT" --rules 2>/dev/null); _rrc=$?
# 규칙 행 = 첫 셀이 S-/G-/A- 로 시작. NF==6 강제 — snippet/fix 안 '|' 가 열을 밀면 드러난다
_rrows=$(printf '%s\n' "$_rules" | awk -F'|' '{c=$2; gsub(/^ +| +$/,"",c)} c ~ /^[SGA]-/')
_rids=$(printf '%s\n' "$_rrows" | awk -F'|' '{c=$2; gsub(/^ +| +$/,"",c); print c}')
_rn=$(printf '%s\n' "$_rids" | grep -c . || true)
_rdup=$(printf '%s\n' "$_rids" | sort | uniq -d | tr '\n' ' ')
_rbad=$(printf '%s\n' "$_rrows" | awk -F'|' '{
  id=$2; s=$3; sn=$4; fx=$5; gsub(/^ +| +$/,"",id); gsub(/^ +| +$/,"",s); gsub(/^ +| +$/,"",sn); gsub(/^ +| +$/,"",fx)
  if (NF != 6) print "nf:" id
  if (s != "Important" && s != "Minor" && s != "단계형") print "sev:" id
  if (sn == "" || fx == "") print "empty:" id }' | tr '\n' ' ')
_rR=$(printf '%s\n' "$_rules" | awk -F'|' '{c=$2; gsub(/^ +| +$/,"",c)} c ~ /^R-/' | grep -c . || true)
if [ "$_rrc" -eq 0 ] && [ "${_rn:-0}" -eq 20 ] && [ -z "$_rdup" ] && [ -z "$_rbad" ] && [ "${_rR:-0}" -eq 0 ]; then
  ok "R1.a --rules 20행 · 4필드 · ID 유일 · severity 3종 · R- 없음"
else
  nope "R1.a" "rc=$_rrc n=$_rn dup='$_rdup' bad='$_rbad' R=$_rR"
fi
_gids=$(sed -n "s/^_GENRE_IDS='\(.*\)'\$/\1/p" "$SCRIPT")
_gmiss=""
for id in $_gids; do printf '%s\n' "$_rids" | grep -qx -- "$id" || _gmiss="$_gmiss $id"; done
{ [ -n "$_gids" ] && [ -z "$_gmiss" ]; } && ok "R1.b _GENRE_IDS 7개 전부 카탈로그에 있음" \
  || nope "R1.b" "gids='$_gids' 누락:$_gmiss"

# ── R2: 위반·경고 상세줄은 전부 카탈로그 ID 로 끝난다 (판정 불가 사유줄 제외) ──
printf '## States\n- Loading: 스피너\n' > "$TD/st2.md"          # empty·error 누락
_gmd "$TD/g-comma.md" ',' "$LIST_OK"                             # nv=0 경로(원형 자리표시자)
_rdl=""
for p in "$TD/bad.md|$TD/bad.html" "$TD/st2.md|$TD/good.html" \
         "$TD/g-none.md|$TD/good.html" "$TD/g-ph.md|$TD/good.html" "$TD/g-bad.md|$TD/good.html" "$TD/g-comma.md|$TD/good.html" \
         "$TD/ov1.md|$TD/good.html" "$TD/ov2.md|$TD/good.html" "$TD/ov3.md|$TD/good.html" "$TD/ov6.md|$TD/good.html" \
         "$TD/gn.md|$TD/good.html"; do
  _rdl="$_rdl$(bash "$SCRIPT" "${p%%|*}" "${p##*|}" 2>/dev/null | grep '^  \[')$_NLT"
done
_rdl=$(printf '%s\n' "$_rdl" | grep '^  \[' | grep -vF '[scope]' | grep -vF '화면 스펙 판독 불가')
_rchk=$(printf '%s\n' "$_rdl" | grep -c . || true)
_rno=$(printf '%s\n' "$_rdl" | grep -vE '  rule=[SGA]-[A-Z0-9-]+(,[SGA]-[A-Z0-9-]+)*$' | head -3)
_rukn=""
for id in $(printf '%s\n' "$_rdl" | sed -n 's/.*  rule=//p' | tr ',' '\n' | sort -u); do
  printf '%s\n' "$_rids" | grep -qx -- "$id" || _rukn="$_rukn $id"
done
if [ "${_rchk:-0}" -ge 12 ] && [ -z "$_rno" ] && [ -z "$_rukn" ]; then
  ok "R2.a 상세줄 ${_rchk}건 전부 카탈로그 ID 로 끝남"
else
  nope "R2.a" "검사 ${_rchk}건(기대 ≥12) ID 없음='$_rno' 카탈로그 밖:$_rukn"
fi
bash "$SCRIPT" "$TD/st2.md" "$TD/good.html" 2>/dev/null | grep -F '[states]' | grep -qE '  rule=S-STATES-EMPTY,S-STATES-ERROR$' \
  && ok "R2.b [states] 누락 항목별 ID (empty·error)" || nope "R2.b" "$(bash "$SCRIPT" "$TD/st2.md" "$TD/good.html" 2>/dev/null | grep -F '[states]')"
for want in G-ARCHETYPE-UNDECLARED G-OVERRIDE-INVALID G-OVERRIDE-UNREASONED S-A11Y-LABEL S-LANDMARK S-TOKEN-HEX S-COPY-VAGUE; do
  printf '%s\n' "$_rdl" | grep -qE "  rule=$want\$" || _rmiss2="${_rmiss2:-} $want"
done
[ -z "${_rmiss2:-}" ] && ok "R2.c 경고 규칙 7종이 각 발화 지점에서 실제로 나온다" || nope "R2.c" "미발화:$_rmiss2"
# R2.d [genre] <ID> 미충족 / <ID> override — 줄은 본문 ID 와 rule ID 가 같다
_rmm=$(printf '%s\n' "$_rdl" | grep -E '^  \[genre\] G-[A-Z-]+ (미충족|override) — ' \
  | awk '{ id=$2; r=$0; sub(/.*  rule=/, "", r); if (id != r) print id "≠" r }')
_rmn=$(printf '%s\n' "$_rdl" | grep -cE '^  \[genre\] G-[A-Z-]+ (미충족|override) — ' || true)
{ [ "${_rmn:-0}" -ge 3 ] && [ -z "$_rmm" ]; } && ok "R2.d genre 본문 ID == rule ID (${_rmn}줄)" || nope "R2.d" "검사 ${_rmn}줄 불일치:$_rmm"


# ══ anti 축 — 금지 패턴 3개 (FID 20260929-design-rule-id-catalog) ══
_aout() { bash "$SCRIPT" "$TD/good.md" "$1" 2>/dev/null; }
_adet() { printf '%s\n' "$1" | grep -F '[anti]'; }
_acase() {  # $1=라벨 $2=ID $3=양성 html $4=음성 html
  printf '%s\n' "$3" > "$TD/ap.html"; printf '%s\n' "$4" > "$TD/an.html"
  local p n; p=$(_aout "$TD/ap.html"); n=$(_aout "$TD/an.html")
  if [ "$(_val "$p" anti)" != 0 ] && [ -n "$(_val "$p" anti)" ] && _adet "$p" | grep -qE "  rule=$2\$" \
     && [ "$(_val "$n" anti)" = 0 ] && [ -z "$(_adet "$n")" ]; then
    ok "A1.$1 $2 양성 anti=$(_val "$p" anti) · 음성 anti=0"
  else
    nope "A1.$1" "$2 양성 anti=$(_val "$p" anti) det='$(_adet "$p")' · 음성 anti=$(_val "$n" anti) det='$(_adet "$n")'"
  fi
}
_acase a A-PLACEHOLDER-NAME '<main><p>John Doe</p></main>' '<main><!-- 예시
Lorem ipsum --><p>홍길동</p></main>'
_acase b A-SCROLL-LISTENER '<script>window.addEventListener("scroll", f);</script>' '<script>/* 예전 코드
window.addEventListener("scroll", f); */</script>'
_acase c A-VIEWPORT-HEIGHT '<style>.x { height: 100vh; }</style>' '<style>body { min-height: 100vh; }</style>'
_acase d A-VIEWPORT-HEIGHT '<div class="flex h-screen"></div>' '<div class="min-h-screen"></div>'
_acase f A-PLACEHOLDER-NAME '<script>foo(); // c</script><p>John Doe</p>' '<script>foo(); // John Doe</script><p>홍길동</p>'
_acase g A-PLACEHOLDER-NAME '<input type="file" accept="image/*"><p>John Doe</p>' '<input type="file" accept="image/*"><p>홍길동</p>'
_acase e A-SCROLL-LISTENER "<script>fetch('https://x.example/a'); window.addEventListener('scroll', g);</script>" "<script>
  // window.addEventListener('scroll', g);
</script>"
# Tailwind 변형 접두(md: · !)는 같은 위반 — min-/max- 는 계속 제외 (Phase C Important 1)
_acase h A-VIEWPORT-HEIGHT '<div class="md:h-screen"></div>' '<div class="min-h-screen"></div>'
_acase j A-VIEWPORT-HEIGHT '<div class="!h-screen"></div>' '<div class="max-h-screen"></div>'
# <script 앞의 텍스트 // 는 주석이 아니다 — 여는 태그를 지우면 스크립트 블록 통째로 무음 누락 (Phase C Important 2)
_acase i A-SCROLL-LISTENER '<p>a // b</p><script>window.addEventListener("scroll", f)</script>' '<p>a // b</p><script>foo()</script>'
# // 절단은 script 구간 안에서만 — 한 줄 두 블록 사이 텍스트 // 가 둘째 여는 태그를 지우면 안 되고 (Phase C 2회차 Important),
#   </script> 뒤 텍스트 // 도 절단 대상이 아니다 (Minor)
_acase k A-SCROLL-LISTENER '<script>a()</script><p>x // y</p><script>window.addEventListener("scroll", f)</script>' '<script>a()</script><p>x // y</p><script>foo()</script>'
_acase l A-PLACEHOLDER-NAME '<script>a()</script><p>x // John Doe</p>' '<script>a() // John Doe</script><p>홍길동 // z</p>'

# ── A4: 기준 화면 오탐 0 (AC-4) — 템플릿 복사본 · design-screen 스캐폴드 · screens/login ──
cp "$PLUGIN/templates/screen.md" "$TD/tplA.md"; cp "$PLUGIN/templates/screen.html" "$TD/tplA.html"
mkdir -p "$TD/sc/screens"
( cd "$TD/sc" && bash "$PLUGIN/scripts/_internal/design-screen.sh" demo >/dev/null 2>&1 )
_a4=""
for p in "$TD/tplA.md|$TD/tplA.html" "$TD/sc/screens/demo.md|$TD/sc/screens/demo.html" \
         "$PLUGIN/screens/login.md|$PLUGIN/screens/login.html"; do
  [ -f "${p##*|}" ] || { _a4="$_a4 부재:${p##*|}"; continue; }
  o=$(bash "$SCRIPT" "${p%%|*}" "${p##*|}" 2>/dev/null)
  { [ "$(_val "$o" anti)" = 0 ] && [ -z "$(_adet "$o")" ]; } || _a4="$_a4 $(basename "${p##*|}"):anti=$(_val "$o" anti)"
done
[ -z "$_a4" ] && ok "A4 템플릿 복사본·스캐폴드·login 모두 anti=0" || nope "A4" "$_a4"

# ── A6: 판정 불가 (AC-6) ──
o=$(bash "$SCRIPT" "$TD/good.md" "$TD/absent.html" 2>/dev/null)
{ [ "$(_val "$o" anti)" = unknown ] && [ -z "$(_adet "$o")" ]; } \
  && ok "A6 .html 부재 → anti=unknown · 금지 패턴 상세줄 없음" || nope "A6" "anti=$(_val "$o" anti) det='$(_adet "$o")'"

# ── A7: anti= 는 적중 건수 합 · 자리표시 이름은 .html 만 (AC-7) ──
printf '<main><p>John Doe</p><p>john doe</p><div class="h-screen"></div></main>\n' > "$TD/a7.html"
{ cat "$TD/good.md"; printf '## 필드 정의표\n| 이름 | John Doe |\n'; } > "$TD/a7.md"
o=$(bash "$SCRIPT" "$TD/a7.md" "$TD/a7.html" 2>/dev/null)
_a7p=$(_adet "$o" | grep -E '  rule=A-PLACEHOLDER-NAME$')
_a7v=$(_adet "$o" | grep -E '  rule=A-VIEWPORT-HEIGHT$')
if [ "$(_val "$o" anti)" = 3 ] && printf '%s' "$_a7p" | grep -q ' 2건 ' && printf '%s' "$_a7v" | grep -q ' 1건 '; then
  ok "A7 anti=3 (자리표시 2 + 뷰포트 1) · .md 예시값 미집계"
else
  nope "A7" "anti=$(_val "$o" anti) p='$_a7p' v='$_a7v'"
fi

finish
