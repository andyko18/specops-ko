#!/usr/bin/env bash
# uiux-assets.sh 어댑터 단위 + Phase 6 통합 — FID 20260810-uiux-asset-driven-design
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
FX="$PLUGIN/scripts/tests/fixtures/uiux"
. "$PLUGIN/scripts/_internal/uiux-assets.sh" || { echo "FATAL: 어댑터 로드 실패"; exit 1; }
PASS=0; FAIL=0
ok()   { echo "PASS $1"; PASS=$((PASS+1)); }
nope() { echo "FAIL $1 — $2"; FAIL=$((FAIL+1)); }

# U0 가드 — 픽스처가 git 에 추적(또는 stage)되는가.
#   untracked 는 ls-files 에 안 잡힌다 — 다른 clone 에서 아래가 전부 공허해진다.
_t=$(cd "$PLUGIN" && git ls-files scripts/tests/fixtures/uiux/ | wc -l | tr -d ' ')
[ "$_t" -ge 2 ] && ok "U0 픽스처 git 추적 ${_t}건" \
  || { nope "U0" "픽스처 미추적(${_t}건) — git add -N 후 재실행"; echo "PASS=$PASS FAIL=$FAIL"; exit 1; }

export UIUX_ASSET_ROOT="$FX"

# U1 — 16토큰 전량 추출 + A안 라벨 매핑
_p=$(uiux::palette "Financial Dashboard")
_n=$(printf '%s\n' "$_p" | grep -c '	#')
[ "$_n" -eq 16 ] && ok "U1 팔레트 16행 전량 추출" || nope "U1" "행수 ${_n}(기대 16 — 토큰 소실)"
for lbl in "Text Primary" "Text Secondary" "Surface" "Error"; do
  printf '%s\n' "$_p" | grep -q "^${lbl}	" \
    && ok "U1.$lbl DESIGN 라벨로 매핑" || nope "U1.$lbl" "매핑 부재 — _inject_design_palette 가 죽는다"
done

# U2 — Decision_Rules 중복키 무손실 (AC-3)
#   실 자산 40%(66/161)가 중복키다. json.loads 는 뒤엣것만 남겨 앞을 잃는다.
_c=$(uiux::concept "Financial Dashboard")
if printf '%s' "$_c" | grep -q 'real-time-updates' && printf '%s' "$_c" | grep -q 'high-contrast'; then
  ok "U2 중복키 both 보존 (AC-3)"
else
  nope "U2" "중복키 소실 — json.loads 를 쓰지 않았는가?"
fi

# U3 — 자산 부재 → rc=1 (AC-4)
UIUX_ASSET_ROOT=/nonexistent/path uiux::available
[ $? -eq 1 ] && ok "U3 자산 부재 → rc=1" || nope "U3" "부재인데 available 이 0"

# U3b — colors.csv 만 없는 경우 (AC-4 세 번째 케이스)
_nc=$(mktemp -d); cp "$FX/ui-reasoning.csv" "$_nc/" 2>/dev/null
UIUX_ASSET_ROOT="$_nc" uiux::available
[ $? -eq 1 ] && ok "U3b colors.csv 부재 → rc=1 (AC-4)" || nope "U3b" "colors 없는데 통과"
rm -rf "$_nc"

# U4 — 스키마 불일치(컬럼 누락) → rc=1 (AC-4)
_bad=$(mktemp -d)
printf 'No,Product Type,Notes\n1,X,y\n' > "$_bad/colors.csv"
cp "$FX/ui-reasoning.csv" "$_bad/" 2>/dev/null
UIUX_ASSET_ROOT="$_bad" uiux::available
[ $? -eq 1 ] && ok "U4 컬럼 누락 → rc=1 (AC-4)" || nope "U4" "스키마 깨졌는데 통과"
rm -rf "$_bad"

# U5 — 영문 키워드 매칭 (AC-7 bash 측)
_m=$(uiux::match "financ")
printf '%s' "$_m" | grep -qi 'Financial' && ok "U5 영문 키워드 매칭" || nope "U5" "매칭 실패: [$_m]"

# U6 — 매칭 0건은 rc=1 (AC-7 degrade 근거)
uiux::match "zzzznomatch" >/dev/null 2>&1
[ $? -eq 1 ] && ok "U6 매칭 0건 → rc=1" || nope "U6" "0건인데 rc=0"

# U7 — ui-reasoning 없는 유형도 팔레트는 나온다 (FR-5)
_p2=$(uiux::palette "OrphanType"); _c2=$(uiux::concept "OrphanType" 2>/dev/null); _rc2=$?
[ -n "$_p2" ] && [ "$_rc2" -eq 1 ] \
  && ok "U7 colors 만 있는 유형 — 팔레트 O, 컨셉 rc=1" \
  || nope "U7" "palette=[$_p2] concept_rc=$_rc2"

# U7b/U7c — 사본 불일치 경고 (AC-6). 경로 인자화 덕에 픽스처로 검증 가능.
_c1=$(mktemp); _c2f=$(mktemp); printf 'a\n' > "$_c1"; printf 'b\n' > "$_c2f"
_w=$(uiux::warn_copies "$_c1" "$_c2f" 2>&1); _wrc=$?
[ "$_wrc" -eq 1 ] && printf '%s' "$_w" | grep -q '사본 2벌 불일치' \
  && ok "U7b 사본 불일치 경고 (AC-6)" || nope "U7b" "rc=$_wrc out=[$_w]"
printf 'a\n' > "$_c2f"
uiux::warn_copies "$_c1" "$_c2f" >/dev/null 2>&1 \
  && ok "U7c 사본 동일 시 무경고 (AC-6 음성)" || nope "U7c" "동일한데 경고"
rm -f "$_c1" "$_c2f"

# U8 — AC-5 결합 격리: 구현 파일에서 CSV 이름이 어댑터 밖에 없다
_leak=$(cd "$PLUGIN" && grep -rl 'colors\.csv\|ui-reasoning\.csv' \
  --include='*.sh' scripts/ hooks/ 2>/dev/null | grep -v 'uiux-assets.sh\|tests/' | wc -l | tr -d ' ')
[ "$_leak" -eq 0 ] && ok "U8 결합 격리 (어댑터 밖 0건)" || nope "U8" "누출 ${_leak}건"


# ── Task 2: DESIGN.md 템플릿 확장 ──
_T="$PLUGIN/templates/DESIGN.md"

# U9 — 신설 섹션 (AC-9)
for sec in "Motion" "레이아웃 패턴" "상태 표현"; do
  grep -q "^## .*${sec}" "$_T" && ok "U9.$sec 섹션 존재 (AC-9)" || nope "U9.$sec" "템플릿에 없음"
done

# U10 — 신규 토큰 행 (A안 추가분)
for lbl in Accent Muted Ring "Card Foreground" "On Primary" "On Destructive"; do
  grep -q "^| ${lbl} |" "$_T" && ok "U10.$lbl 토큰 행 존재" || nope "U10.$lbl" "행 없음"
done

# U11 — ★ 기존 9라벨 보존 (AC-10 근거 — _inject_design_palette 가 grep 하는 것)
#   하나라도 사라지면 screens/*.html 색 주입이 **무음으로** 죽는다(lib.sh 의 continue).
for lbl in Primary Secondary Background Surface "Text Primary" "Text Secondary" Border Error Success; do
  grep -q "^| ${lbl} |" "$_T" && ok "U11.$lbl 기존 라벨 보존" || nope "U11.$lbl" "라벨 소실 — 화면 주입이 죽는다"
done

# U11b — Success 는 템플릿에서도 사유로 비운다 (AC-11)
grep -qE '^\| Success \| \(자산 미제공' "$_T" \
  && ok "U11b 템플릿 Success 사유 명시 (AC-11)" || nope "U11b" "#______ 또는 임의값"

# ── U24: 패턴 라이브러리 확장 (FID 20260821-design-pattern-library) ──
# §6.1 화면 원형 (AC-1)
grep -q '^## 6\.1 ' "$_T" && ok "U24.a §6.1 화면 원형 섹션 존재 (AC-1)" \
  || nope "U24.a" "## 6.1 섹션 없음"
_arch_miss=""
for a in 목록 상세 폼 대시보드; do
  grep -q "^| ${a} |" "$_T" || _arch_miss="$_arch_miss $a"
done
[ -z "$_arch_miss" ] && ok "U24.b 4원형 행 존재 (AC-1)" || nope "U24.b" "누락:$_arch_miss"

# §7 구간 한정 placeholder 0 (AC-2) — ★ 전역 스캔 금지: §8 의 [원칙 N]·[금지 패턴 N] 은 보존 대상(AC-R-1)
#   한계: §7 산문에 '[인라인 편집]' 처럼 세 단어로 **시작하는** 대괄호를 쓰면 오탐한다.
#   placeholder 재유입 차단이 목적이라 fail-safe 방향으로 남긴다 — 정당한 FAIL 로 오독 말 것.
_s7=$(awk '/^## 7\. /{f=1;next} /^## /{f=0} f' "$_T")
_s7ph=$(printf '%s\n' "$_s7" | grep -cE '\[(스켈레톤|일러스트|인라인)[^]]*\]' || true)
_s7hit=$(printf '%s\n' "$_s7" | grep -E '\[(스켈레톤|일러스트|인라인)[^]]*\]' | head -1)
[ "${_s7ph:-99}" -eq 0 ] && ok "U24.c §7 placeholder 0 (AC-2)" || nope "U24.c" "잔존 ${_s7ph}건 — 예: ${_s7hit}"
printf '%s\n' "$_s7" | grep -q '값 채움은' \
  && nope "U24.d" "'값 채움은 후속 FID' 유도 주석 잔존 (AC-2)" \
  || ok "U24.d §7 유도 주석 삭제 (AC-2)"
_row_miss=""
for r in 로딩 "빈 상태" 에러; do
  printf '%s\n' "$_s7" | grep -q "^| ${r} |" || _row_miss="$_row_miss [$r]"
done
[ -z "$_row_miss" ] && ok "U24.e §7 3행 보존 (AC-2)" || nope "U24.e" "누락:$_row_miss"
printf '%s\n' "$_s7" | grep -E '^\| 빈 상태 \|' | grep -q '자산' \
  && ok "U24.f 빈 상태 자산 부재 명시 (AC-3)" || nope "U24.f" "비고에 자산 근거 언급 없음"

# 회귀 — _design_apply_concept 접두 리터럴 8종 (AC-R-1)
_lit_miss=""
while IFS= read -r lit; do
  # ★ -e 필수: 리터럴 5종이 `-` 로 시작해 -e 없으면 grep 이 옵션으로 오파싱 → 영구 FAIL
  grep -qF -e "$lit" "$_T" || _lit_miss="$_lit_miss [$lit]"
done <<'LITS'
- **권장 패턴**:
- **스타일 우선순위**:
- **핵심 효과**:
1. **[원칙 1]**
2. **[원칙 2]**
3. **[원칙 3]**
- [금지 패턴 1]
- [금지 패턴 2]
LITS
[ -z "$_lit_miss" ] && ok "U24.g 자산 주입 앵커 8종 보존 (AC-R-1)" || nope "U24.g" "소실:$_lit_miss"

# 회귀 — 기존 9섹션 제목 포함 검사 (AC-R-3) ★ 개수 검사 금지 — §6.1 추가로 10이 된다
_sec_miss=""
while IFS= read -r sec; do
  grep -qF -e "$sec" "$_T" || _sec_miss="$_sec_miss [$sec]"
done <<'SECS'
## 1. Color System
## 2. Typography
## 3. Spacing & Layout
## 4. Components
## 5. Motion
## 6. 레이아웃 패턴
## 7. 상태 표현
## 8. Design Principles
## 9. AI Usage Guidelines
SECS
[ -z "$_sec_miss" ] && ok "U24.h 기존 섹션 제목 보존 (AC-R-3)" || nope "U24.h" "소실:$_sec_miss"

# 배선 리터럴 3파일 (AC-4·AC-5·AC-10)
for f in skills/specifying-ko/SKILL.md commands/design-screen.md commands/design-screens.md; do
  _wire_n=$(grep -cF '**DESIGN.md 준수**' "$PLUGIN/$f" 2>/dev/null || true)
  _line=$(grep -F '**DESIGN.md 준수**' "$PLUGIN/$f" 2>/dev/null | head -1)
  if [ "${_wire_n:-0}" -eq 1 ] \
     && printf '%s' "$_line" | grep -q '§6 ' \
     && printf '%s' "$_line" | grep -q '§6\.1' \
     && printf '%s' "$_line" | grep -q '§7' \
     && printf '%s' "$_line" | grep -q '§8' \
     && printf '%s' "$_line" | grep -q '§9'; then
    ok "U24.i.$(basename "$f") 배선 1줄 + §6~§9 (AC-10)"
  else
    nope "U24.i.$(basename "$f")" "매칭 ${_wire_n:-0}건 / 섹션 참조 불충족"
  fi
done

# ── Task 3: Phase 6 통합 ──
#   ★ phases-design.sh 는 **library-only** 다 — 직접 실행하면 함수만 정의하고 rc=0 으로 끝난다.
#     source 후 phase_6_design 을 호출해야 한다. 함수명은 phase_6_design 이다.
#   ★ _should_skip 이 $CONFLICT_POLICY 를 참조하므로 반드시 설정한다.
_p6() {   # $1=자산루트 $2=유형 → 생성된 DESIGN.md 경로
  local d; d=$(mktemp -d)
  ( cd "$d" \
    && PLUGIN="$PLUGIN" PROJECT_KIND=1 PROJECT_NAME=TestProj CONFLICT_POLICY=overwrite \
       UIUX_ASSET_ROOT="$1" UIUX_PRODUCT_TYPE="$2" \
       bash -c '
         . "$PLUGIN/scripts/_internal/init-project/lib.sh"
         . "$PLUGIN/scripts/_internal/init-project/phases-design.sh"
         phase_6_design </dev/null
       ' >/dev/null 2>&1 )
  echo "$d/DESIGN.md"
}
# §1 표 행의 미채움만 센다 — Gradient 는 §1 밖이고 CSV 토큰이 아니다.
#   ★ `grep -c` 는 0건에서 `0` 출력 + rc=1 이라 `|| echo 99` 를 붙이면 "0\n99" 가 되어
#     정수 비교가 폭발한다. rc 를 무시하고 값만 받는다.
_ph_in_table() { grep -cE '^\| [A-Za-z ]+ \| `#______`' "$1" 2>/dev/null; }

# U12 — 자산 경로: §1 표 미채움 0 (AC-1)
_f=$(_p6 "$FX" "Financial Dashboard")
if [ -f "$_f" ]; then
  _ph=$(_ph_in_table "$_f")
  [ "${_ph:-99}" -eq 0 ] && ok "U12 자산 경로 §1 미채움 0 (AC-1)" || nope "U12" "미채움 ${_ph}개"
else
  nope "U12" "DESIGN.md 미생성 — 하네스가 phase_6_design 에 도달 못 했다"
fi
# U12b — 대표 hex 가 CSV 값 그대로이고 **백틱으로 감싸였는가** (AC-1)
#   백틱이 load-bearing 이다 — _inject_design_palette 가 백틱 감싼 hex 만 뽑는다.
grep -qE '^\| Primary \| `#0F172A`' "$_f" 2>/dev/null \
  && grep -qE '^\| Accent \| `#3FB950`' "$_f" 2>/dev/null \
  && ok "U12b Primary·Accent 값 1:1 + 백틱 (AC-1)" || nope "U12b" "CSV 값 불일치 또는 백틱 누락"
# U12c — 라벨 매핑 결과가 DESIGN 라벨로 들어갔는가
for lbl in "Text Primary" "Surface" "Error"; do
  grep -qE "^\| ${lbl} \| \`#[0-9A-Fa-f]{6}\`" "$_f" 2>/dev/null \
    && ok "U12c.$lbl 매핑 주입" || nope "U12c.$lbl" "미주입 — _inject_design_palette 가 죽는다"
done
# U13 — 컨셉 주입 (AC-2)
grep -q 'Data-Dense' "$_f" 2>/dev/null && ok "U13 Recommended_Pattern (AC-2)" || nope "U13" "패턴 미주입"
grep -q 'Light mode default' "$_f" 2>/dev/null && ok "U13b Anti_Patterns (AC-2)" || nope "U13b" "안티패턴 미주입"
_pr=$(grep -cE '\[원칙 [0-9]\]|\[금지 패턴 [0-9]\]' "$_f" 2>/dev/null)
[ "${_pr:-99}" -eq 0 ] && ok "U13c §Principles 산문 placeholder 0 (AC-2)" || nope "U13c" "잔존 ${_pr}개"
# U14 — 라이선스 머리말 + 버전 (AC-8)
grep -q 'Next Level Builder' "$_f" 2>/dev/null && ok "U14 라이선스 고지 (AC-8)" || nope "U14" "고지 부재"
grep -qE 'ui-ux-pro-max ([0-9]+\.[0-9]+\.[0-9]+|\(marketplace\)|\(unknown\))' "$_f" 2>/dev/null \
  && ok "U14b 버전 기록 (AC-8)" || nope "U14b" "버전 부재"
# U15 — 자산 부재 → fallback, DESIGN.md 는 생성 (AC-4 · NFR-2)
#   ★ 유형을 **지정한 채** 자산만 없앤다. 유형이 비면 분기 자체를 안 타 가드 유무가 무의미하다.
_f2=$(_p6 "/nonexistent" "Financial Dashboard")
if [ -f "$_f2" ]; then
  ok "U15 fallback 에서도 DESIGN.md 생성 (AC-4)"
  grep -q 'Next Level Builder' "$_f2" && nope "U15.lic" "fallback 인데 자산 고지가 있다" \
    || ok "U15.lic fallback 에 고지 없음 (AC-8)"
else
  nope "U15" "생성 실패 — init 이 중단됐다"
  nope "U15.lic" "U15 미달로 판정 불가"
fi
# U15b — ★ fallback **사유가 출력**되는가 (AC-4 Then · FR-6). 변이 M4 의 관측점이다.
_d15=$(mktemp -d)
_err=$( cd "$_d15" \
  && PLUGIN="$PLUGIN" PROJECT_KIND=1 PROJECT_NAME=T CONFLICT_POLICY=overwrite \
     UIUX_ASSET_ROOT="/nonexistent" UIUX_PRODUCT_TYPE="Financial Dashboard" \
     bash -c '. "$PLUGIN/scripts/_internal/init-project/lib.sh"
              . "$PLUGIN/scripts/_internal/init-project/phases-design.sh"
              phase_6_design </dev/null' 2>&1 >/dev/null )
printf '%s' "$_err" | grep -q '자산을 쓸 수 없습니다' \
  && ok "U15b fallback 사유 출력 (AC-4·FR-6)" || nope "U15b" "사유 없음 — 조용히 5택으로 빠졌다"
rm -rf "$_d15"
# U16 — _inject_design_palette 무손상 (AC-10). 3변수 전부 본다.
_hd=$(mktemp -d); _h="$_hd/s.html"
printf '<style>:root{--color-surface: #000000; --color-text: #000000; --color-error: #000000;}</style>' > "$_h"
( cd "$(dirname "$_f")" && . "$PLUGIN/scripts/_internal/init-project/lib.sh" && _inject_design_palette "$_h" )
# ★ grep -c 는 **줄 수**를 센다 — 세 변수가 한 줄에 있어 "1개" 로 보인다. 발생 수를 센다.
_left=$(grep -o -- '#000000' "$_h" 2>/dev/null | wc -l | tr -d ' ')
[ "${_left:-9}" -eq 0 ] && ok "U16 _inject_design_palette 3변수 치환 (AC-10)" \
  || nope "U16" "미치환 ${_left}개 — 라벨 매핑이 깨졌다(무음 sink)"
rm -rf "$_hd"
# U17 — AC-R-1: 기존 DESIGN.md 를 덮지 않는다
_sd=$(mktemp -d); printf '# 기존 파일\n' > "$_sd/DESIGN.md"
_m1=$(cksum < "$_sd/DESIGN.md")
( cd "$_sd" && PLUGIN="$PLUGIN" PROJECT_KIND=1 PROJECT_NAME=T CONFLICT_POLICY=skip \
    UIUX_ASSET_ROOT="$FX" UIUX_PRODUCT_TYPE="Financial Dashboard" \
    bash -c '. "$PLUGIN/scripts/_internal/init-project/lib.sh"
             . "$PLUGIN/scripts/_internal/init-project/phases-design.sh"
             phase_6_design </dev/null' >/dev/null 2>&1 )
_m2=$(cksum < "$_sd/DESIGN.md")
[ "$_m1" = "$_m2" ] && ok "U17 기존 DESIGN.md 보존 (AC-R-1)" || nope "U17" "덮어썼다 — _should_skip 뒤에 넣었는가?"
rm -rf "$_sd"
# U18 — AC-11: Success 는 사유로 비우고 임의 값을 발명하지 않는다
grep -qE '^\| Success \| \(자산 미제공' "$_f" 2>/dev/null \
  && ok "U18 Success 미제공 사유 명시 (AC-11)" || nope "U18" "사유 부재 — 값을 발명했는가?"
grep -qE '^\| Success \| `#[0-9A-Fa-f]{6}`' "$_f" 2>/dev/null \
  && nope "U18b" "Success 에 임의 hex 발명" || ok "U18b Success 임의값 없음 (AC-11)"
# U19 — FR-5: ui-reasoning 없는 유형도 색상만 넣고 진행한다
_f3=$(_p6 "$FX" "OrphanType")
if [ -f "$_f3" ]; then
  grep -q '`#123456`' "$_f3" && ok "U19 colors-only 유형 팔레트 주입 (FR-5)" || nope "U19" "색상 미주입"
  grep -q 'Next Level Builder' "$_f3" && ok "U19b colors-only 도 자산 경로 유지" \
    || nope "U19b" "5택으로 추락 — 컨셉 rc=1 을 실패로 취급했는가?"
else
  nope "U19" "생성 실패"; nope "U19b" "U19 미달로 판정 불가"
fi

# ── Task 4: 우선순위 정정 + 잠금 ──
# U20 — 구 우선순위 문구가 **3곳 전부** 사라졌는가 (FR-9)
#   실측 3곳: skills/specifying-ko/SKILL.md · commands/design-screen.md · commands/start-all.md.
#   1곳만 고치면 나머지가 정정과 정면 모순으로 남는다.
_stale=$(cd "$PLUGIN" && grep -rl 'ui-ux-pro-max 결과 우선' --include='*.md' \
  skills/ commands/ 2>/dev/null | wc -l | tr -d ' ')
[ "$_stale" -eq 0 ] && ok "U20 구 우선순위 문구 0건 (FR-9)" || nope "U20" "잔존 ${_stale}곳"
for f in skills/specifying-ko/SKILL.md commands/design-screen.md commands/start-all.md; do
  grep -q 'DESIGN.md 우선' "$PLUGIN/$f" \
    && ok "U20.$(basename $f) 정정" || nope "U20.$(basename $f)" "미정정"
done
# U20b — AC-9 범위 부기 (verify 가 AC-9 를 FAIL 로 읽지 않게 근거를 남긴다)
#   ★ SoT 는 tracked CHANGELOG 다. `.specops/<FID>/` 는 gitignore 로컬 전용이라
#     CI clone 에 없어 이 검사가 항상 FAIL 했다(v1.71.0 Actions 실측: U20b only).
grep -q 'AC-9 범위 부기' "$PLUGIN/CHANGELOG.md" \
  && ok "U20b AC-9 범위 부기" || nope "U20b" "부기 부재 — verify 가 AC-9 를 FAIL 로 판정한다"
# U21 — propagation 잠금
grep -q 'uiux-asset-adapter' "$PLUGIN/scripts/_internal/propagation-matrix.jsonl" \
  && ok "U21 propagation 잠금" || nope "U21" "레코드 부재"

# ── 시한폭탄 회귀 잠금 (2026-08-10 실발화) ──
# 계기: test-verification-state.sh·test-verdict-board.sh 가 waiver 만료일을
#   "2026-08-10T00:00:00Z" 로 **하드코딩**해, 그 시각이 지나자 WAIVED 가 NOT_RUN 으로
#   계산돼 두 스위트가 동시에 FAIL 했다(현재 UTC 가 24분 지난 시점에 실발화).
#   프로덕션(verification-state.sh)은 정상이다 — 조회 시점에 만료를 계산하는 게 설계다.
#   테스트가 "미래" 라고 가정한 값이 과거가 된 것뿐이다.
# ★ 미래 날짜 하드코딩은 **언젠가 반드시** 터진다. 상대 날짜만 쓴다.
# ★ **미래** 날짜만 잡는다. 과거 날짜(2020-01-01)는 "만료된 waiver 는 거부된다" 를
#   증명하는 의도적 고정값이라 시한폭탄이 아니다 — 시간이 지나도 계속 과거다.
_today=$(date -u +%Y-%m-%d)
_tb=$(cd "$PLUGIN" && grep -rhoE -- '--waiver-expires-at "[0-9]{4}-[0-9]{2}-[0-9]{2}' scripts/tests/*.sh 2>/dev/null \
      | sed 's/.*"//' | awk -v t="$_today" '$0 >= t' | wc -l | tr -d ' ')
[ "$_tb" -eq 0 ] && ok "TB1 미래 만료일 하드코딩 0건 (시한폭탄 잠금)" \
  || nope "TB1" "하드코딩 ${_tb}곳 — 그 날짜가 지나면 스위트가 스스로 터진다"

# ── Phase C Important 2건 회귀 잠금 ──
# U22 — awk sub() 의 `&` 확장 오염 차단 (Phase C 프로브 P2)
#   실측: HEX='#AB&C' → "| Primary | `#AB`#______`C` |" 로 오염됐다. 현 자산의 매핑
#   16컬럼엔 & 가 0건이나(Notes 에만 52건) 자산 갱신 한 번에 활성화된다.
_ev=$(mktemp -d)
{ head -1 "$FX/colors.csv"
  echo '9,EvilType,#AB&C,#FFFFFF,#234567,#FFFFFF,#345678,#FFFFFF,#FFFFFF,#111111,#FAFAFA,#111111,#EEEEEE,#666666,#DDDDDD,#CC0000,#FFFFFF,#123456,메타문자 값'
} > "$_ev/colors.csv"
cp "$FX/ui-reasoning.csv" "$_ev/"
_fe=$(_p6 "$_ev" "EvilType")
if [ -f "$_fe" ]; then
  grep -q '`#______`C`' "$_fe" 2>/dev/null \
    && nope "U22" "& 확장 오염 — 값 형식 가드가 없다" || ok "U22 & 포함 hex skip (오염 없음)"
else
  nope "U22" "생성 실패"
fi
rm -rf "$_ev"

# U23 — 중도 실패 시 **성공 보고 금지** (Phase C 프로브 P6)
#   실측: $target.tmp 를 디렉터리로 선점하면 16행 전원 미주입인데 "작성 완료(자산)" 가
#   나갔다. 실패는 rc=1 로 전파돼 5택 fallback 이 흡수해야 한다.
_td=$(mktemp -d); mkdir -p "$_td/DESIGN.md.tmp"
_out=$( cd "$_td" \
  && PLUGIN="$PLUGIN" PROJECT_KIND=1 PROJECT_NAME=T CONFLICT_POLICY=overwrite \
     UIUX_ASSET_ROOT="$FX" UIUX_PRODUCT_TYPE="Financial Dashboard" \
     bash -c '. "$PLUGIN/scripts/_internal/init-project/lib.sh"
              . "$PLUGIN/scripts/_internal/init-project/phases-design.sh"
              phase_6_design </dev/null' 2>/dev/null )
printf '%s' "$_out" | grep -q '작성 완료 (자산:' \
  && nope "U23" "중도 실패인데 자산 성공 보고 — 실패가 전파되지 않는다" \
  || ok "U23 중도 실패 시 자산 성공 보고 없음"
rm -rf "$_td"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
