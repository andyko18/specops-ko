#!/usr/bin/env bash
# library-only — sourced by init-project.sh
# phase_5~7 (CLAUDE/DESIGN/screens) — init-project.sh 에서 이동

phase_5_claude() {
  local target="CLAUDE.md"
  if _should_skip "$target"; then
    echo "→ ${target} 보존 (skip 정책)"
    return
  fi
  cp "$PLUGIN/templates/CLAUDE.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  # PRD §1 한 줄 인용
  _replace_line_prefix "$target" "<PRD §1 한 줄 설명" "${PRD_ONELINE:-<TODO>}"
  _replace_line_prefix "$target" "<constitution.md §원칙 5개" "constitution.md 의 핵심 5 원칙:"
  # 원칙 5개 인덱스 (constitution.md ### 원칙 N: NAME 에서 NAME 추출)
  local i name
  for i in 1 2 3 4 5; do
    name=$(grep -m1 "^### 원칙 ${i}:" .specops/memory/constitution.md 2>/dev/null \
      | sed "s/^### 원칙 ${i}: *//" || echo "원칙${i}")
    [ -z "$name" ] && name="원칙${i}"
    # constitution 'skip' 시 raw placeholder(<PRINCIPLE_N_NAME>) 가 CLAUDE.md 로 누출되는 것 차단
    case "$name" in '<'*'>') name="원칙${i}" ;; esac
    _replace_line_prefix "$target" "- 원칙 ${i}:" "- 원칙 ${i}: ${name}"
  done
  echo "→ ${target} 작성 완료"
}

# brand-pick: 1=Stripe 2=Notion 3=Linear 4=Claude 5=직접
_design_brand_color() {
  case "$1" in
    1) echo "#635BFF" ;;
    2) echo "#000000" ;;
    3) echo "#5E6AD2" ;;
    4) echo "#7C3AED" ;;
    *) echo "#______" ;;
  esac
}

_design_brand_name() {
  case "$1" in
    1) echo "Stripe" ;;
    2) echo "Notion" ;;
    3) echo "Linear" ;;
    4) echo "Claude" ;;
    *) echo "Custom" ;;
  esac
}

# 자산으로 DESIGN.md 를 채운다. 성공 rc=0 / 실패 rc=1(호출부가 5택으로 fallback).
# ★ hex 는 반드시 **백틱으로 감싼다** — _inject_design_palette 가 백틱 감싼 hex 만 뽑기
#   때문에 백틱이 없으면 무음 skip 된다(lib.sh 실측).
_design_from_assets() {
  local target="$1" ptype="$2"
  local pal; pal=$(uiux::palette "$ptype") || return 1
  [ -n "$pal" ] || return 1
  cp "$PLUGIN/templates/DESIGN.md" "$target" || return 1
  _replace_line_prefix "$target" "# DESIGN.md — [Project Name]" \
    "# DESIGN.md — ${PROJECT_NAME} (${ptype})"
  # 라이선스 머리말 (AC-8) — 문구는 **어댑터가** 만든다(결합 격리).
  local lic; lic=$(uiux::license_lines)
  LIC="$lic" awk '
    { print }
    /^# DESIGN\.md — / && !seen { print ""; print ENVIRON["LIC"]; seen = 1 }' \
    "$target" > "$target.tmp" && mv "$target.tmp" "$target" \
    || { rm -f "$target.tmp"; return 1; }
  # 팔레트 주입 — "| <라벨> | `#______` |" 를 값으로 치환
  local lbl hex
  while IFS=$'\t' read -r lbl hex; do
    [ -n "$lbl" ] || continue
    # ★ 값 형식 가드 — awk sub() 의 대체문자열에서 `&` 는 **매치 전체로 확장**된다.
    #   실측: HEX='#AB&C' → `| Primary | `#AB`#______`C` |` 로 오염된다.
    #   현 자산의 매핑 16컬럼엔 `&` 가 0건이나(Notes 에만 52건), 어댑터가 "minor 는 자동
    #   신뢰" 라고 적은 결합 구조상 자산 갱신 한 번에 활성화된다. hex 만 통과시킨다.
    #   부수: 개행·탭이 든 값도 여기서 걸러진다(라인 프로토콜 파단 방지).
    case "$hex" in
      '#'[0-9A-Fa-f]*) : ;;
      *) echo "  ℹ️  ${lbl}: hex 아닌 값 skip (${hex})" >&2; continue ;;
    esac
    case "$hex" in *'&'*|*'\'*) echo "  ℹ️  ${lbl}: 메타문자 포함 skip" >&2; continue ;; esac
    LBL="$lbl" HEX="$hex" awk '
      BEGIN { l = ENVIRON["LBL"]; h = ENVIRON["HEX"] }
      index($0, "| " l " | `#______`") == 1 { sub(/`#______`/, "`" h "`"); print; next }
      { print }' "$target" > "$target.tmp" && mv "$target.tmp" "$target" \
      || { rm -f "$target.tmp"; return 1; }
  done <<< "$pal"
  # 컨셉 — 없어도(rc=1) **실패가 아니다**. colors-only 유형은 색상만 넣고 진행한다(FR-5).
  local con; con=$(uiux::concept "$ptype" 2>/dev/null) || con=""
  if [ -n "$con" ]; then
    _design_apply_concept "$target" "$con"
  else
    echo "  ℹ️  ${ptype} 는 컨셉 데이터 미보유 — 컨셉 섹션은 미채움으로 둡니다" >&2
  fi
  return 0
}

_design_apply_concept() {   # $1=target $2="필드<TAB>값" 행들
  local target="$1" con="$2" k v
  local pattern="" style="" effects="" anti=""
  while IFS=$'\t' read -r k v; do
    case "$k" in
      Recommended_Pattern) pattern="$v" ;;
      Style_Priority)      style="$v" ;;
      Key_Effects)         effects="$v" ;;
      Anti_Patterns)       anti="$v" ;;
    esac
  done <<< "$con"
  _replace_line_prefix "$target" "- **권장 패턴**:"      "- **권장 패턴**: ${pattern:-(미제공)}"
  _replace_line_prefix "$target" "- **스타일 우선순위**:" "- **스타일 우선순위**: ${style:-(미제공)}"
  _replace_line_prefix "$target" "- **핵심 효과**:"       "- **핵심 효과**: ${effects:-(미제공)}"
  # §Design Principles 산문 placeholder → 실제 값 (AC-2)
  _replace_line_prefix "$target" "1. **[원칙 1]**" "1. **패턴**: ${pattern:-(미제공)}"
  _replace_line_prefix "$target" "2. **[원칙 2]**" "2. **스타일**: ${style:-(미제공)}"
  _replace_line_prefix "$target" "3. **[원칙 3]**" "3. **핵심 효과**: ${effects:-(미제공)}"
  _replace_line_prefix "$target" "- [금지 패턴 1]" "- ${anti:-(미제공)}"
  _replace_line_prefix "$target" "- [금지 패턴 2]" "- (자산 제공 안티패턴은 위 1건)"
}

phase_6_design() {
  if [ "$PROJECT_KIND" != "1" ] && [ "$PROJECT_KIND" != "4" ] && [ "$PROJECT_KIND" != "5" ]; then
    echo "[Phase 6] DESIGN.md skip (PROJECT_KIND=${PROJECT_KIND}, UI/풀스택/모바일만 활성)"
    return
  fi
  local target="DESIGN.md"
  if _should_skip "$target"; then
    echo "→ ${target} 보존 (skip 정책)"
    return
  fi
  # ── 자산 경로 (FID 20260810-uiux-asset-driven-design) ──
  # ui-ux-pro-max 자산(192유형 팔레트 + 161 컨셉)으로 채운다. 파일명·경로·스키마는 전부
  #   scripts/_internal/uiux-assets.sh 안에 있다 — 여기서 알면 결합 격리(AC-5)가 깨진다.
  # 실패는 전부 아래 5택 fallback 이 흡수한다 — 부트스트랩 1회 경로라 중단이 치명적이다.
  . "$PLUGIN/scripts/_internal/uiux-assets.sh" 2>/dev/null || true
  if [ -n "${UIUX_PRODUCT_TYPE:-}" ]; then
    if type uiux::available >/dev/null 2>&1 && uiux::available; then
      uiux::warn_copies || true
      if _design_from_assets "$target" "$UIUX_PRODUCT_TYPE"; then
        echo "→ ${target} 작성 완료 (자산: ${UIUX_PRODUCT_TYPE}, ui-ux-pro-max $(uiux::version))"
        return
      fi
      echo "  ⚠️  자산 주입 실패 — 브랜드 5택으로 진행합니다" >&2
    else
      # ★ 조용히 5택으로 빠지면 사용자는 자산이 왜 안 쓰였는지 모른다(AC-4·FR-6).
      echo "  ⚠️  ui-ux-pro-max 자산을 쓸 수 없습니다(미설치 또는 스키마 불일치) — 브랜드 5택으로 진행합니다" >&2
    fi
  fi

  echo ""
  echo "[Phase 6] DESIGN.md — 디자인 시스템 브랜드 선택:"
  echo "  (1) Stripe   — 보라 그라디언트, 개발자 친화 ← 추천"
  echo "  (2) Notion   — 미니멀, 화이트 베이스"
  echo "  (3) Linear   — 기술적, 다크 인디고"
  echo "  (4) Claude   — AI 친화, 다크 퍼스트"
  echo "  (5) 직접 입력"
  printf "선택 [1]: "
  local b=""
  read -r b || true
  case "$b" in 1|2|3|4|5) ;; *) b="1" ;; esac
  local color name
  color=$(_design_brand_color "$b")
  name=$(_design_brand_name "$b")
  cp "$PLUGIN/templates/DESIGN.md" "$target"
  _replace_line_prefix "$target" "# DESIGN.md — [Project Name]" "# DESIGN.md — ${PROJECT_NAME} (${name} 스타일)"
  # §1 Color System Primary 행만 brand 색상으로
  awk -v c="$color" '
    /^\| Primary \| `#______`/ { sub(/`#______`/, "`" c "`"); print; next }
    { print }
  ' "$target" > "${target}.tmp" && mv "${target}.tmp" "$target"
  echo "→ ${target} 작성 완료 (브랜드: ${name}, Primary=${color})"
}
# screens-overview.md §1 표를 <!-- screens-table:start/end --> fence 내부에 교체.
# fence 패턴은 템플릿 예시 행 이름 (home/login/dashboard) 에 비의존 — 향후 템플릿 변경에 안정.
# 회귀: fence 가 존재하지 않으면 silent no-op (caller 검증 책임).
_rebuild_screens_table() {
  local file="$1"
  shift
  local n rows=""
  for n in "$@"; do
    rows="${rows}| ${n} | ${n} | 예정 — /start-all Phase 2.5 | [screens/${n}.md](../../screens/${n}.md) | [screens/${n}.html](../../screens/${n}.html) |
"
  done
  ROWS="$rows" awk '
    /^<!-- screens-table:start -->/ {
      print
      printf "%s", ENVIRON["ROWS"]
      inside = 1
      next
    }
    /^<!-- screens-table:end -->/ {
      inside = 0
      print
      next
    }
    inside { next }
    { print }
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

phase_7_screens() {
  case "$PROJECT_KIND" in 1|4|5) ;; *) echo "[Phase 7] screens skip (KIND=${PROJECT_KIND})"; return ;; esac
  echo ""
  echo "[Phase 7] 초기 화면 이름 목록 (콤마/공백 구분, 비우면 skip):"
  echo "  ※ screens/*.{md,html} 껍데기는 만들지 않음 — 본설계는 /start-all Phase 2.5 또는 /design-screen"
  printf "예) home, login, dashboard: "
  local input=""
  read -r input || true
  mkdir -p .specops/memory
  cp "$PLUGIN/templates/screens-overview.md" .specops/memory/screens-overview.md
  _replace_token .specops/memory/screens-overview.md "<PROJECT_NAME>" "$PROJECT_NAME"
  if [ -z "${input// }" ]; then
    echo "→ 화면 입력 비움. screens-overview.md placeholder 유지."
    return
  fi
  local IFS=', '
  local -a raw_names=($input) names=()
  IFS=$' \t\n'
  # path traversal 방어: 영숫자/-/_ 1~64 만 허용
  local n
  for n in "${raw_names[@]}"; do
    [ -z "$n" ] && continue
    if [[ ! "$n" =~ ^[A-Za-z0-9_-]{1,64}$ ]]; then
      echo "→ 화면명 '$n' 무시 (영숫자/-/_ 1~64 만 허용)" >&2
      continue
    fi
    names+=("$n")
  done
  if [ ${#names[@]} -eq 0 ]; then
    echo "→ 유효한 화면명 0개. screens-overview.md placeholder 유지."
    return
  fi
  _rebuild_screens_table .specops/memory/screens-overview.md "${names[@]}"
  echo "→ .specops/memory/screens-overview.md 목록 ${#names[@]}개 기록 (screens/ 파일 미생성 — Phase 2.5 예정)"
}
