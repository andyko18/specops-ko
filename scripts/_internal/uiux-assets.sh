#!/usr/bin/env bash
# library-only
# uiux-assets.sh — ui-ux-pro-max 자산 어댑터 (FID 20260810-uiux-asset-driven-design)
#
# ★ 이 파일이 타 플러그인과의 **유일한 결합 지점**이다 (AC-5).
#   ui-ux-pro-max 의 경로·CSV 스키마·파일명이 바뀌면 **여기만** 고친다. 호출부는 함수만 쓴다.
#   결합이 실재하는 위험인 근거: 캐시에 2.5.0·2.13.0 이 공존하고 data/ 구성이 다르며
#   (2.5.0 에는 design.csv 가 있다), 같은 파일이 src/ 와 cli/assets/ 두 곳에 사본으로 있는데
#   md5 가 다르다. plugin.json 의존 상한이 `>=2.0.0 <3.0.0` 이라 minor 는 자동 신뢰된다.
#
# 자산 출처: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill (MIT, © 2024 Next Level Builder)

# 정본 경로 — marketplaces(버전 비고정) 우선, 없으면 cache 최신.
#   cli/assets/ 사본은 내용이 달라 src/ 를 쓴다. 정본 추정은 미확증이라(clarify Q2)
#   uiux::warn_copies 가 불일치를 드러낸다.
# UIUX_HOME 은 warn_copies 와 **대칭**으로 둔다 — 한쪽만 주입 가능하면 실경로 분기를
#   픽스처로 검증할 수 없다.
uiux::root() {
  if [ -n "${UIUX_ASSET_ROOT:-}" ]; then
    [ -d "$UIUX_ASSET_ROOT" ] && { printf '%s' "$UIUX_ASSET_ROOT"; return 0; }
    return 1
  fi
  local base="${UIUX_HOME:-$HOME}/.claude/plugins"
  local m="$base/marketplaces/ui-ux-pro-max-skill/src/ui-ux-pro-max/data"
  [ -d "$m" ] && { printf '%s' "$m"; return 0; }
  local c
  c=$(ls -d "$base"/cache/ui-ux-pro-max-skill/ui-ux-pro-max/*/src/ui-ux-pro-max/data 2>/dev/null \
      | sort -V | tail -1)
  [ -n "$c" ] && [ -d "$c" ] && { printf '%s' "$c"; return 0; }
  return 1
}

uiux::version() {
  local r; r=$(uiux::root) || return 1
  # ★ BSD sed(macOS)는 `t` 뒤의 `;` 를 **label 로 해석**해 `undefined label` 로 죽는다(실측).
  #   -e 로 분리해야 GNU·BSD 양쪽에서 돈다.
  printf '%s' "$r" | sed -E -e 's|.*/ui-ux-pro-max/([^/]+)/src.*|\1|' -e 't' -e 's|.*|(marketplace)|'
}

# 스키마까지 본다 — 경로만 확인하면 컬럼이 바뀐 자산을 통과시킨다.
uiux::available() {
  local r; r=$(uiux::root) || return 1
  [ -r "$r/colors.csv" ] && [ -r "$r/ui-reasoning.csv" ] || return 1
  head -1 "$r/colors.csv" | grep -q 'Product Type' || return 1
  head -1 "$r/colors.csv" | grep -q 'Destructive'  || return 1
  head -1 "$r/ui-reasoning.csv" | grep -q 'UI_Category'   || return 1
  head -1 "$r/ui-reasoning.csv" | grep -q 'Anti_Patterns' || return 1
  return 0
}

# 두 사본 경로를 **인자로** 받는다 — $HOME 하드코딩이면 픽스처 주입이 불통해
#   AC-6 을 검증할 방법이 없다.
uiux::warn_copies() {   # $1,$2 생략 시 실 경로 기본값
  local base="${UIUX_HOME:-$HOME}/.claude/plugins/marketplaces/ui-ux-pro-max-skill"
  local a="${1:-$base/src/ui-ux-pro-max/data/colors.csv}"
  local b="${2:-$base/cli/assets/data/colors.csv}"
  [ -r "$a" ] && [ -r "$b" ] || return 0
  local ha hb
  ha=$(cksum < "$a"); hb=$(cksum < "$b")
  [ "$ha" = "$hb" ] && return 0
  echo "  ⚠️  자산 사본 2벌 불일치 — src/ 사용 (cli/assets/ 는 다른 내용)" >&2
  return 1
}

# 라이선스 머리말을 **어댑터가 만든다** — 호출부가 자산 파일명을 문자열로 갖지 않게 해
#   AC-5(결합 격리, U8) 와 자기모순하지 않는다.
uiux::license_lines() {
  local v; v=$(uiux::version 2>/dev/null || echo "(unknown)")
  printf '> 팔레트·컨셉 출처: ui-ux-pro-max %s (MIT, © 2024 Next Level Builder)\n' "$v"
  printf '> — 색상·컨셉 데이터셋\n'
}

# 자산이 제공하지 않는 항목의 사유 문구도 어댑터가 준다 (같은 이유).
uiux::unavailable_note() {   # $1=항목명
  case "$1" in
    success)  printf '(자산 미제공 — shadcn 규약엔 success 토큰 없음)' ;;
    gradient) printf '(자산 미제공 — 색상 데이터셋에 gradient 컬럼 없음. Phase 11 enrich 또는 수기)' ;;
    *)        printf '(자산 미제공)' ;;
  esac
}

# ★ colors 를 매칭한다(products 아님). 실측상 두 파일의 Product Type 키는 **192개 완전 일치**
#   이고, colors 기준이면 "고른 유형에 팔레트가 반드시 있다" 가 구조적으로 보장된다.
uiux::match() {   # $1=키워드 → 후보 Product Type (최대 8)
  local r; r=$(uiux::root) || return 1
  local out
  out=$(python3 - "$r/colors.csv" "$1" <<'PY' 2>/dev/null
import csv,sys
rows=list(csv.DictReader(open(sys.argv[1],encoding='utf-8')))
kw=sys.argv[2].lower()
hit=[r['Product Type'] for r in rows if kw in r['Product Type'].lower()]
print('\n'.join(hit[:8]))
PY
)
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

# CSV → DESIGN.md 라벨 매핑 (A안). 기존 9라벨을 살려야 _inject_design_palette 가 산다.
uiux::palette() {   # $1=유형 → "DESIGN라벨<TAB>#HEX"
  local r; r=$(uiux::root) || return 1
  python3 - "$r/colors.csv" "$1" <<'PY'
import csv,sys
MAP=[("Primary","Primary"),("Secondary","Secondary"),("Background","Background"),
     ("Card","Surface"),("Foreground","Text Primary"),("Muted Foreground","Text Secondary"),
     ("Border","Border"),("Destructive","Error"),
     ("Accent","Accent"),("On Primary","On Primary"),("On Secondary","On Secondary"),
     ("On Accent","On Accent"),("Muted","Muted"),("Ring","Ring"),
     ("Card Foreground","Card Foreground"),("On Destructive","On Destructive")]
rows={r['Product Type']:r for r in csv.DictReader(open(sys.argv[1],encoding='utf-8'))}
row=rows.get(sys.argv[2])
if not row: sys.exit(1)
for src,dst in MAP:
    v=(row.get(src) or '').strip()
    if v: print(f"{dst}\t{v}")
PY
}

uiux::concept() {   # $1=유형 → "필드<TAB>값". ui-reasoning 없으면 rc=1
  local r; r=$(uiux::root) || return 1
  python3 - "$r/ui-reasoning.csv" "$1" <<'PY'
import csv,sys,re
rows={r['UI_Category']:r for r in csv.DictReader(open(sys.argv[1],encoding='utf-8'))}
row=rows.get(sys.argv[2])
if not row: sys.exit(1)
for k in ("Recommended_Pattern","Style_Priority","Color_Mood","Typography_Mood",
          "Key_Effects","Anti_Patterns","Severity"):
    v=(row.get(k) or '').strip()
    if v: print(f"{k}\t{v}")
# ★ json.loads 금지 — 실 자산 40%(66/161)가 중복키라 뒤엣것만 남아 앞을 잃는다(실측).
#   정규식으로 전 쌍을 순서대로 수집한다.
pairs=re.findall(r'"([^"]+)"\s*:\s*"([^"]*)"', row.get("Decision_Rules") or "")
for k,v in pairs:
    print(f"Rule:{k}\t{v}")
PY
}
