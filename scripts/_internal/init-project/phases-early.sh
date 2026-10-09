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
  _init_hold_scan
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
  # 빈 답의 기본값: 재개(--resume)이고 종류가 기록돼 있으면 그 값, 아니면 4(풀스택).
  #   종전엔 재개에서도 4 였다 — 답 없이 재개하면 CLI 저장소에 풀스택 파일이 생겼다(20261009 재현).
  #   질문 자체는 건너뛰지 않는다: stdin 모드는 질문 수가 바뀌면 뒤의 답이 밀린다.
  local def="4" rec
  rec=$(_recorded_kind)
  [ "$RESUME_MODE" = "1" ] && [ -n "$rec" ] && def="$rec"
  printf "선택 [%s]: " "$def"
  if [ -n "$ANSWERS_FILE" ] && [ -z "$(_ans_get kind 2>/dev/null)" ] && [ "$RESUME_MODE" = "1" ] && [ -n "$rec" ]; then
    REPLY="$rec"      # 답변 파일 모드의 재개 — 기록된 종류면 키를 생략할 수 있다
  else
    _ask_choice kind "프로젝트 종류" "$def" '[1-6]' "1~6"
  fi
  PROJECT_KIND="$REPLY"
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
  if [ -n "$ANSWERS_FILE" ] && [ "$(_ans_get principles 2>/dev/null)" = "skip" ]; then
    p1="skip"
  else
    printf "원칙 1 이름: "; _ask principle.1 "헌법 원칙 1"; p1="$REPLY"
  fi
  if [ "${p1}" = "skip" ]; then
    mkdir -p .specops/memory
    cp "$PLUGIN/templates/constitution.md" "$target"
    # skip 은 **원칙을 나중에 정한다**는 뜻이다 — 결정이 아닌 토큰(프로젝트명·날짜)까지 남길 이유는 없다.
    #   원칙 이름 자리표시자는 그대로 둔다(미채움 스캔에 잡혀야 한다).
    _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
    _replace_token "$target" "<YYYY-MM-DD>" "$(date +%Y-%m-%d)"
    echo "→ ${target} (원칙은 placeholder 유지 — 나중에 채운다)"
    return
  fi
  printf "원칙 2 이름: "; _ask principle.2 "헌법 원칙 2"; p2="$REPLY"
  printf "원칙 3 이름: "; _ask principle.3 "헌법 원칙 3"; p3="$REPLY"
  printf "원칙 4 이름: "; _ask principle.4 "헌법 원칙 4"; p4="$REPLY"
  printf "원칙 5 이름: "; _ask principle.5 "헌법 원칙 5"; p5="$REPLY"
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
  # 터미널을 **열 수 있는지** 본다 — 존재만 보던 종전 가드는 열 수 없는 환경에서 듣지 않았고,
  #   아래 `read … </dev/tty || true` 가 전부 실패해 `<TODO>` 8건짜리 PRD 를 만들고 rc=0 으로 끝났다(20261009 재현).
  if ! _tty_ok; then
    echo "양식 파싱 실패 (${got}/6) + 비대화 환경 (tty 부재) — abort." >&2
    _stop_input "PRD 6필드 중 ${got}개만 읽혔습니다 (PRD.md 를 <TODO> 로 채우지 않습니다)."
  fi
  echo "양식 파싱 실패 (${got}/6). 개별 입력 모드로 전환합니다."
  [ -z "$PRD_F1" ] && { printf "1. 한 줄 설명: "; read -r PRD_F1 </dev/tty || true; }
  [ -z "$PRD_F2" ] && { printf "2. 페르소나: "; read -r PRD_F2 </dev/tty || true; }
  [ -z "$PRD_F3" ] && { printf "3. 가치제안 (콤마 구분 3개): "; read -r PRD_F3 </dev/tty || true; }
  [ -z "$PRD_F4" ] && { printf "4. M1: "; read -r PRD_F4 </dev/tty || true; }
  [ -z "$PRD_F5" ] && { printf "5. M2: "; read -r PRD_F5 </dev/tty || true; }
  [ -z "$PRD_F6" ] && { printf "6. M3: "; read -r PRD_F6 </dev/tty || true; }
}

# PRD 6 필드 수집: Phase 0 확정 파일 → numbered list stdin → < 4 시 단답 fallback
_phase_4_collect() {
  # 답변 파일 모드 — 키로 받는다(사전 점검이 6필드 존재를 이미 확인했다). 낡은 필드 파일은 쓰지 않고 지운다.
  if [ -n "$ANSWERS_FILE" ]; then
    echo ""
    echo "[Phase 4] 답변 파일의 PRD 6필드 사용"
    _ask prd.oneline "PRD 한 줄 설명"; PRD_F1="$REPLY"
    _ask prd.persona "PRD 페르소나";   PRD_F2="$REPLY"
    _ask prd.values "PRD 가치제안";    PRD_F3="$REPLY"
    _ask prd.m1 "PRD M1"; PRD_F4="$REPLY"
    _ask prd.m2 "PRD M2"; PRD_F5="$REPLY"
    _ask prd.m3 "PRD M3"; PRD_F6="$REPLY"
    rm -f .specops/.init-prd-fields
    return
  fi
  # Phase 0 확정값 강제 공급 (.specops/.init-prd-fields — 줄당 1필드, 6줄)
  if [ -f .specops/.init-prd-fields ]; then
    echo ""
    echo "[Phase 4] Phase 0 확정 PRD 6필드 사용 (.specops/.init-prd-fields) — 재입력 생략"
    PRD_F1=$(sed -n '1p' .specops/.init-prd-fields)
    PRD_F2=$(sed -n '2p' .specops/.init-prd-fields)
    PRD_F3=$(sed -n '3p' .specops/.init-prd-fields)
    PRD_F4=$(sed -n '4p' .specops/.init-prd-fields)
    PRD_F5=$(sed -n '5p' .specops/.init-prd-fields)
    PRD_F6=$(sed -n '6p' .specops/.init-prd-fields)
    rm -f .specops/.init-prd-fields
    if [ "$(_phase_4_count_filled)" -ge 4 ]; then
      return
    fi
    echo "→ Phase 0 파일 필드 부족 — stdin/수동으로 보완" >&2
  fi
  echo ""
  echo "[Phase 4] PRD — 다음 6 필드를 numbered list 로 입력 (빈 줄로 종료):"
  echo "  1. 한 줄 설명: <텍스트>"
  echo "  2. 페르소나: <텍스트>"
  echo "  3. 가치제안: <콤마 구분 3개>"
  echo "  4. M1: <텍스트>"
  echo "  5. M2: <텍스트>"
  echo "  6. M3: <텍스트>"
  echo "  (Phase 0 확정분이 stdin으로 오면 재입력 불필요)"
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
    # 보존하더라도 **확정한 6필드가 있으면** 다른 산출물에는 쓴다 — CLAUDE.md·README.md 의 한 줄 설명과 FR 시드.
    #   종전엔 PRD.md 가 이미 있으면 6필드를 통째로 버려, 기존 PRD 가 specops 형식이 아닐 때 CLAUDE.md 는
    #   `<TODO>` · FR 시드는 자리표시자로 남았다(필드 파일은 지워지지도 않았다). PRD.md 자체는 고치지 않는다.
    PRD_F1=""; PRD_F2=""; PRD_F3=""; PRD_F4=""; PRD_F5=""; PRD_F6=""
    if [ -n "$ANSWERS_FILE" ]; then
      PRD_F1=$(_ans_get prd.oneline 2>/dev/null || true)
      PRD_F4=$(_ans_get prd.m1 2>/dev/null || true)
      PRD_F5=$(_ans_get prd.m2 2>/dev/null || true)
      PRD_F6=$(_ans_get prd.m3 2>/dev/null || true)
    elif [ -f .specops/.init-prd-fields ]; then
      PRD_F1=$(sed -n '1p' .specops/.init-prd-fields)
      PRD_F4=$(sed -n '4p' .specops/.init-prd-fields)
      PRD_F5=$(sed -n '5p' .specops/.init-prd-fields)
      PRD_F6=$(sed -n '6p' .specops/.init-prd-fields)
      rm -f .specops/.init-prd-fields
    fi
    if [ -n "${PRD_F1}${PRD_F4}${PRD_F5}${PRD_F6}" ]; then
      [ -n "$PRD_F1" ] && PRD_ONELINE="$PRD_F1"
      echo "  (확정한 PRD 필드는 PRD.md 에 쓰지 않고 CLAUDE.md·README.md 의 한 줄 설명과 FR 시드에만 반영합니다)"
    fi
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
