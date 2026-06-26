#!/usr/bin/env bash
# library-only — sourced by init-project.sh
# phase_1~4 (사전검사/분류/헌법/PRD) — init-project.sh 에서 이동

# ── Phase 함수 ───────────────────────────────
phase_1_precheck() {
  PROJECT_NAME="${1:-$(basename "$PWD")}"
  _check_git
  _check_memory
  _print_artifacts_table
  _resolve_conflict_policy
  _check_brainstorming
}

phase_2_classify() {
  echo "프로젝트 종류는?"
  echo "  (1) Web/UI"
  echo "  (2) 백엔드/API"
  echo "  (3) CLI/라이브러리"
  echo "  (4) 풀스택"
  echo "  (5) 모바일"
  echo "  (6) 기타"
  printf "선택 [4]: "
  local k=""
  read -r k || true
  case "$k" in
    1|2|3|4|5|6) PROJECT_KIND="$k" ;;
    *) PROJECT_KIND="4" ;;
  esac
  echo "→ PROJECT_KIND=${PROJECT_KIND}"
}
phase_3_constitution() {
  local target=".specops/memory/constitution.md"
  if _should_skip "$target"; then
    echo "→ ${target} 보존 (skip 정책)"
    return
  fi
  echo ""
  echo "[Phase 3] 헌법 — 핵심 원칙 5개 입력 ('skip' 시 placeholder 유지)"
  local p1="" p2="" p3="" p4="" p5=""
  printf "원칙 1 이름: "; read -r p1 || true
  if [ "${p1}" = "skip" ]; then
    mkdir -p .specops/memory
    cp "$PLUGIN/templates/constitution.md" "$target"
    echo "→ ${target} (placeholder 유지)"
    return
  fi
  printf "원칙 2 이름: "; read -r p2 || true
  printf "원칙 3 이름: "; read -r p3 || true
  printf "원칙 4 이름: "; read -r p4 || true
  printf "원칙 5 이름: "; read -r p5 || true
  mkdir -p .specops/memory
  cp "$PLUGIN/templates/constitution.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  _replace_token "$target" "<PRINCIPLE_1_NAME>" "${p1:-원칙1}"
  _replace_token "$target" "<PRINCIPLE_2_NAME>" "${p2:-원칙2}"
  _replace_token "$target" "<PRINCIPLE_3_NAME>" "${p3:-원칙3}"
  _replace_token "$target" "<PRINCIPLE_4_NAME>" "${p4:-원칙4}"
  _replace_token "$target" "<PRINCIPLE_5_NAME>" "${p5:-원칙5}"
  _replace_token "$target" "<YYYY-MM-DD>" "$(date +%Y-%m-%d)"
  echo "→ ${target} 작성 완료"
}

# stdin 의 numbered list → PRD_F1~F6 전역 (빈 줄 sentinel 종료)
_phase_4_parse_numbered_list() {
  local raw="" line
  while IFS= read -r line; do
    [ -z "$line" ] && break
    raw="${raw}${line}
"
  done
  PRD_F1=$(_parse_numbered "$raw" 1)
  PRD_F2=$(_parse_numbered "$raw" 2)
  PRD_F3=$(_parse_numbered "$raw" 3)
  PRD_F4=$(_parse_numbered "$raw" 4)
  PRD_F5=$(_parse_numbered "$raw" 5)
  PRD_F6=$(_parse_numbered "$raw" 6)
}

# PRD_F1~F6 중 비어있지 않은 개수 출력
_phase_4_count_filled() {
  local got=0 v
  for v in "$PRD_F1" "$PRD_F2" "$PRD_F3" "$PRD_F4" "$PRD_F5" "$PRD_F6"; do
    [ -n "$v" ] && got=$((got + 1))
  done
  echo "$got"
}

# parse 실패 (< 4) 시 단답 fallback. 비대화 환경 시 abort (silent failure 차단)
_phase_4_fallback_singleshot() {
  local got
  got=$(_phase_4_count_filled)
  if [ ! -e /dev/tty ]; then
    echo "양식 파싱 실패 (${got}/6) + 비대화 환경 (tty 부재) — abort." >&2
    echo "PRD.md 가 <TODO> 로 채워지는 silent failure 차단." >&2
    exit 2
  fi
  echo "양식 파싱 실패 (${got}/6). 개별 입력 모드로 전환합니다."
  [ -z "$PRD_F1" ] && { printf "1. 한 줄 설명: "; read -r PRD_F1 </dev/tty || true; }
  [ -z "$PRD_F2" ] && { printf "2. 페르소나: "; read -r PRD_F2 </dev/tty || true; }
  [ -z "$PRD_F3" ] && { printf "3. 가치제안 (콤마 구분 3개): "; read -r PRD_F3 </dev/tty || true; }
  [ -z "$PRD_F4" ] && { printf "4. M1: "; read -r PRD_F4 </dev/tty || true; }
  [ -z "$PRD_F5" ] && { printf "5. M2: "; read -r PRD_F5 </dev/tty || true; }
  [ -z "$PRD_F6" ] && { printf "6. M3: "; read -r PRD_F6 </dev/tty || true; }
}

# PRD 6 필드 수집: numbered list 1차 → < 4 시 단답 fallback (M1: 3 함수 분리)
_phase_4_collect() {
  echo ""
  echo "[Phase 4] PRD — 다음 6 필드를 numbered list 로 입력 (빈 줄로 종료):"
  echo "  1. 한 줄 설명: <텍스트>"
  echo "  2. 페르소나: <텍스트>"
  echo "  3. 가치제안: <콤마 구분 3개>"
  echo "  4. M1: <텍스트>"
  echo "  5. M2: <텍스트>"
  echo "  6. M3: <텍스트>"
  _phase_4_parse_numbered_list
  [ "$(_phase_4_count_filled)" -lt 4 ] && _phase_4_fallback_singleshot
}

# PRD 6 필드 → templates/PRD.md 치환 → PRD.md 작성
_phase_4_render() {
  local target="PRD.md"
  cp "$PLUGIN/templates/PRD.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  _replace_line_prefix "$target" '**한 줄 설명**:' "**한 줄 설명**: ${PRD_F1:-<TODO>}"
  _replace_line_prefix "$target" '**주요 페르소나**:' "**주요 페르소나**: ${PRD_F2:-<TODO>}"
  local v1="" v2="" v3=""
  IFS=',' read -r v1 v2 v3 _ <<< "${PRD_F3:-}"
  v1="${v1# }"; v2="${v2# }"; v3="${v3# }"
  _replace_line_prefix "$target" '- <가치 1>' "- ${v1:-<TODO>}"
  _replace_line_prefix "$target" '- <가치 2>' "- ${v2:-<TODO>}"
  _replace_line_prefix "$target" '- <가치 3>' "- ${v3:-<TODO>}"
  _replace_line_prefix "$target" '- **M1**:' "- **M1**: ${PRD_F4:-<TODO>}"
  _replace_line_prefix "$target" '- **M2**:' "- **M2**: ${PRD_F5:-<TODO>}"
  _replace_line_prefix "$target" '- **M3**:' "- **M3**: ${PRD_F6:-<TODO>}"
  _replace_token "$target" "<YYYY-MM-DD>" "$(date +%Y-%m-%d)"
  PRD_ONELINE="${PRD_F1:-<TODO>}"
  # brainstorming 참조 기록 (BM_REF="y" 이고 파일 존재 시)
  if [ "${BM_REF:-n}" = "y" ]; then
    local bm_file
    bm_file=$(ls -t .specops/memory/brainstorming-*.md 2>/dev/null | head -1)
    if [ -n "$bm_file" ]; then
      printf '\n---\n\n## 브레인스토밍 컨텍스트\n\n> 참조: `%s`\n' "$bm_file" >> "$target"
    fi
  fi
  echo "→ ${target} 작성 완료"
}

phase_4_prd() {
  if _should_skip "PRD.md"; then
    echo "→ PRD.md 보존 (skip 정책)"
    PRD_ONELINE=$(grep -m1 '^\*\*한 줄 설명\*\*:' PRD.md 2>/dev/null | sed 's/^\*\*한 줄 설명\*\*: *//' || echo "")
    return
  fi
  if [ "$BM_REF" = "y" ]; then
    echo ""
    echo "── 브레인스토밍 메모 요약 ──"
    local bm_file
    bm_file=$(find .specops/memory -maxdepth 1 -name "brainstorming-*.md" 2>/dev/null | sort -r | head -1)
    if [ -n "$bm_file" ]; then
      grep -E "^## |^###|^\*\*" "$bm_file" 2>/dev/null | head -20 | sed 's/^/  /'
      echo "  (전체: $bm_file)"
    fi
    echo "────────────────────────────"
    echo ""
  fi
  PRD_F1=""; PRD_F2=""; PRD_F3=""; PRD_F4=""; PRD_F5=""; PRD_F6=""
  _phase_4_collect
  _phase_4_render
}
