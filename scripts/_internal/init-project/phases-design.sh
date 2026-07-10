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
    rows="${rows}| ${n} | ${n} | TODO | [screens/${n}.md](../../screens/${n}.md) | [screens/${n}.html](../../screens/${n}.html) |
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
  echo "[Phase 7] 초기 화면 목록 (콤마/공백 구분, 비우면 skip):"
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
  local IFS=', ' today
  local -a raw_names=($input) names=()
  IFS=$' \t\n'
  today=$(date +%Y-%m-%d)
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
  mkdir -p screens
  for n in "${names[@]}"; do
    cp "$PLUGIN/templates/screen.md" "screens/${n}.md"
    cp "$PLUGIN/templates/screen.html" "screens/${n}.html"
    _replace_token "screens/${n}.md" "{{name}}" "$n"
    _replace_token "screens/${n}.md" "{{화면 제목}}" "$n"
    _replace_token "screens/${n}.md" "{{created}}" "$today"
    _replace_token "screens/${n}.md" "{{updated}}" "$today"
    _replace_token "screens/${n}.html" "{{title}}" "$n"
    _replace_token "screens/${n}.html" "{{화면 제목}}" "$n"
    # DESIGN.md 팔레트 주입 (Phase 6 시점 Primary 확정분 + 재실행 시 전체) — design-screen.sh 와 공유
    _inject_design_palette "screens/${n}.html"
  done
  _rebuild_screens_table .specops/memory/screens-overview.md "${names[@]}"
  echo "→ screens/ ${#names[@]}개 + .specops/memory/screens-overview.md 작성"
}
