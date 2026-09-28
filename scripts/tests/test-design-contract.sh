#!/usr/bin/env bash
# DESIGN.md 템플릿·소비측 배선 계약 + 외부 디자인 플러그인 재유입 금지 — FID 20260928-uiux-promax-removal-design-master
#   이관 원본: test-uiux-assets.sh(삭제). 그 스위트에 promax 무관 가드가 섞여 있어 통째 삭제하면 조용히 사라졌다.
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
PASS=0; FAIL=0
ok()   { echo "PASS $1"; PASS=$((PASS+1)); }
nope() { echo "FAIL $1 — $2"; FAIL=$((FAIL+1)); }

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

# 배선 리터럴 4파일 (AC-1·AC-4·AC-5·AC-10 + 20260829-design-consume-sync AC-1)
# start-all.md 는 Phase 2.5-A 가 [공통] 블록을 상속하지 않아 별도 기재가 필요하다
#   (실측 20260829: specifying-ko 만 §2·§3 보유 → batch 화면만 새 축을 몰랐다)
for f in skills/specifying-ko/SKILL.md commands/design-screen.md commands/design-screens.md commands/start-all.md; do
  _wire_n=$(grep -cF '**DESIGN.md 준수**' "$PLUGIN/$f" 2>/dev/null || true)
  _line=$(grep -F '**DESIGN.md 준수**' "$PLUGIN/$f" 2>/dev/null | head -1)
  if [ "${_wire_n:-0}" -eq 1 ] \
     && printf '%s' "$_line" | grep -q '§2 ' \
     && printf '%s' "$_line" | grep -q '§3 ' \
     && printf '%s' "$_line" | grep -q '§6 ' \
     && printf '%s' "$_line" | grep -q '§6\.1' \
     && printf '%s' "$_line" | grep -q '§7' \
     && printf '%s' "$_line" | grep -q '§8' \
     && printf '%s' "$_line" | grep -q '§9'; then
    ok "U24.i.$(basename "$f") 배선 1줄 + §2·§3·§6~§9 (AC-10)"
  else
    nope "U24.i.$(basename "$f")" "매칭 ${_wire_n:-0}건 / 섹션 참조 불충족"
  fi
done

# U24.k — 배선줄 § 토큰 집합의 canonical 대칭 (Phase C Important-1, 20260829)
#   U24.i 는 '알려진 7토큰의 존재'만 본다 → canonical 에 새 축(§4 등)이 늘어도 나머지 3파일은 무음 통과했다
#   (리뷰어 프로브 P1 실증 20260829: specifying-ko 에만 §4 추가 → 4파일 전부 PASS).
#   여기서는 존재가 아니라 **집합 동일성**을 잠근다 — 축이 늘든 줄든 4파일이 같이 움직여야 한다.
#   줄 전체에서 추출한다: start-all 배선줄 꼬리의 batch 부연에는 § 토큰이 0건이다(실측 20260829).
#   미래에 부연이 §를 달면 여기서 **보이는 FAIL** 이 난다 — 무음 드리프트보다 낫다(§2 앵커와 같은 tripwire 입장).
_canon_f="skills/specifying-ko/SKILL.md"
_sect_of() {
  grep -F '**DESIGN.md 준수**' "$PLUGIN/$1" 2>/dev/null | head -1 \
    | grep -oE '§[0-9]+(\.[0-9]+)?' | LC_ALL=C sort -u | tr '\n' ' '
}
_canon=$(_sect_of "$_canon_f")
if [ -z "$_canon" ]; then
  # 추출이 깨지면 빈 집합끼리 같아져 U24.k 가 공허하게 PASS 한다 — 그건 두 번째 스냅샷 잠금일 뿐이다
  nope "U24.k" "canonical($_canon_f) 배선줄에서 § 토큰 0건 — 추출/배선이 깨졌다"
else
  _sym_bad=""
  for f in commands/design-screen.md commands/design-screens.md commands/start-all.md; do
    _o=$(_sect_of "$f")
    [ "$_o" = "$_canon" ] && continue
    _miss=""; _extra=""
    for t in $_canon; do
      case " $_o " in *" $t "*) ;; *) _miss="$_miss$t " ;; esac
    done
    for t in $_o; do
      case " $_canon " in *" $t "*) ;; *) _extra="$_extra$t " ;; esac
    done
    _sym_bad="$_sym_bad$(basename "$f") 누락[${_miss% }] 잉여[${_extra% }]; "
  done
  if [ -z "$_sym_bad" ]; then
    ok "U24.k 배선줄 § 토큰 집합 4파일 대칭 [${_canon% }] (AC-10)"
  else
    nope "U24.k" "canonical[${_canon% }] 과 비대칭 — ${_sym_bad%; }"
  fi
fi

# start-all **Phase 2.5-A 구간 안**이 화면 템플릿을 참조하는가 (AC-2)
#   전체 파일 grep 은 위치를 안 잠근다 — 참조를 파일 끝으로 옮겨도 통과했다(프로브 P3 실증 20260829).
#   AC-2 는 "화면 산출물 생성 문맥 안"을 요구하므로 A~B 구간으로 잘라 본다.
#   구간 경계가 사라지면 awk 범위가 EOF 까지 흘러 위치 잠금이 되살아난다 → 경계 존재를 먼저 단언한다.
_sa="$PLUGIN/commands/start-all.md"
_bnd_a=$(grep -cE '^#### A\.' "$_sa" 2>/dev/null || true)
_bnd_b=$(grep -cE '^#### B\.' "$_sa" 2>/dev/null || true)
if [ "${_bnd_a:-0}" -ne 1 ] || [ "${_bnd_b:-0}" -ne 1 ]; then
  nope "U24.j" "Phase 2.5 구간 경계 소실 (#### A.=${_bnd_a:-0} / #### B.=${_bnd_b:-0}, 각 1건 기대) — 구간 한정 검사 불가"
else
  _tmpl_n=$(awk '/^#### A\./,/^#### B\./' "$_sa" | grep -c 'templates/screen\.html' || true)
  if [ "${_tmpl_n:-0}" -ge 1 ]; then
    ok "U24.j start-all Phase 2.5-A 구간 내 templates/screen.html 참조 (AC-2)"
  else
    nope "U24.j" "Phase 2.5-A 구간 내 templates/screen.html 참조 0건 — batch 화면이 --text-*/--space-* 토큰을 못 받는다"
  fi
fi


# U16 — _inject_design_palette 무손상 (3변수). 입력은 인라인 픽스처 — 자산 경로 DESIGN.md 는 제거됐다.
_hd=$(mktemp -d); _h="$_hd/s.html"
printf '| Surface | `#111111` |\n| Text Primary | `#222222` |\n| Error | `#333333` |\n' > "$_hd/DESIGN.md"
printf '<style>:root{--color-surface: #000000; --color-text: #000000; --color-error: #000000;}</style>' > "$_h"
( cd "$_hd" && . "$PLUGIN/scripts/_internal/init-project/lib.sh" && _inject_design_palette "$_h" )
_left=$(grep -o -- '#000000' "$_h" 2>/dev/null | wc -l | tr -d ' ')
[ "${_left:-9}" -eq 0 ] && ok "U16 _inject_design_palette 3변수 치환" \
  || nope "U16" "미치환 ${_left}개 — 라벨 매핑이 깨졌다(무음 sink)"
rm -rf "$_hd"
# U17 — AC-R-1: 기존 DESIGN.md 를 덮지 않는다
_sd=$(mktemp -d); printf '# 기존 파일\n' > "$_sd/DESIGN.md"
_m1=$(cksum < "$_sd/DESIGN.md")
( cd "$_sd" && PLUGIN="$PLUGIN" PROJECT_KIND=1 PROJECT_NAME=T CONFLICT_POLICY=skip \
    bash -c '. "$PLUGIN/scripts/_internal/init-project/lib.sh"
             . "$PLUGIN/scripts/_internal/init-project/phases-design.sh"
             phase_6_design </dev/null' >/dev/null 2>&1 )
_m2=$(cksum < "$_sd/DESIGN.md")
[ "$_m1" = "$_m2" ] && ok "U17 기존 DESIGN.md 보존 (AC-R-1)" || nope "U17" "덮어썼다 — _should_skip 뒤에 넣었는가?"
rm -rf "$_sd"

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


# E10 소비측 배선 (AC-5)
grep -q '§2 타이포·§3 간격' "$PLUGIN/skills/specifying-ko/SKILL.md" \
  && ok "E10 Step 5.5 소비 목록에 §2·§3" || nope "E10" "소비측 미배선"
grep -q -- '--text-base' "$PLUGIN/templates/screen.html" \
  && ok "E11 screen.html 타입 토큰" || nope "E11" "토큰 부재"
grep -q -- '--space-4' "$PLUGIN/templates/screen.html" \
  && ok "E12 screen.html 간격 토큰" || nope "E12" "토큰 부재"

# ── N: 외부 디자인 플러그인 재유입 금지 (FID 20260928-uiux-promax-removal-design-master) ──
#   판정 리터럴 보유 3파일과 과거 기록(CHANGELOG·docs/audit)은 제외한다(AC-6 ④).
_NL_RE='ui-ux-pro-max|uiux::|uiux-assets|UIUX_'   # UIUX_ = 제거된 엔진·자산 env(UIUX_ENGINE_DISABLE 등) 재유입
_nl() { # $1=라벨, 나머지=pathspec
  local lbl="$1"; shift
  local hits
  hits=$(cd "$PLUGIN" && git grep -nE "$_NL_RE" -- "$@" \
    ':!CHANGELOG.md' ':!docs/audit' ':!scripts/tests/test-design-contract.sh' \
    ':!scripts/tests/test-batch-orchestration.sh' ':!scripts/tests/test-screen-routing-doc.sh' 2>/dev/null | head -3)
  [ -z "$hits" ] && ok "$lbl 재유입 0건" || nope "$lbl" "잔존: $(printf '%s' "$hits" | tr '\n' ' ')"
}
# N1 — 매니페스트 의존 선언 0 (AC-1)
_pj="$PLUGIN/.claude-plugin/plugin.json"; _mj="$PLUGIN/.claude-plugin/marketplace.json"
grep -q '"ui-ux-pro-max' "$_pj" && nope "N1.a" "plugin.json 에 의존 선언" || ok "N1.a plugin.json 의존 0"
grep -q 'allowCrossMarketplaceDependenciesOn' "$_mj" && nope "N1.b" "marketplace.json 에 cross-marketplace 허용" \
  || ok "N1.b marketplace.json cross-marketplace 0"
if command -v jq >/dev/null 2>&1; then
  jq -e . "$_pj" >/dev/null 2>&1 && jq -e . "$_mj" >/dev/null 2>&1 \
    && ok "N1.c 매니페스트 JSON 유효" || nope "N1.c" "JSON 파싱 실패"
fi
# N2 — bash 어댑터·픽스처 부재 (AC-2·AC-6 ③)
_nl "N2.a scripts/·.claude-plugin/" scripts .claude-plugin
_fx=$(cd "$PLUGIN" && git ls-files scripts/_internal/uiux-assets.sh scripts/tests/fixtures/uiux scripts/tests/fixtures/uiux-engine | wc -l | tr -d ' ')
[ "$_fx" -eq 0 ] && ok "N2.b 어댑터·픽스처 추적 0건" || nope "N2.b" "추적 ${_fx}건 잔존"
# N3 — 산문 표면(skills/commands/agents/hooks/templates) 재유입 0 (AC-2·AC-5)
_nl "N3 skills/·commands/·agents/·hooks/·templates/" skills commands agents hooks templates

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
