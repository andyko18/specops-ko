#!/usr/bin/env bash
# /start-project 오케스트레이터 — 10 Phase 구현 (T13b~T13f 가 각 phase 함수 추가)
# 한국 SI 표준 13종 산출물 자동 부트스트랩
set -u

PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)

# 13종 산출물 (root 4개 + .specops/memory 9개)
ARTIFACTS_ROOT=("PRD.md" "CLAUDE.md" "README.md" "DESIGN.md")
ARTIFACTS_MEMORY=(
  ".specops/memory/constitution.md"
  ".specops/memory/requirements.md"
  ".specops/memory/test-strategy.md"
  ".specops/memory/architecture.md"
  ".specops/memory/frontend-architecture.md"
  ".specops/memory/backend-architecture.md"
  ".specops/memory/api-spec.md"
  ".specops/memory/data-model.md"
  ".specops/memory/screens-overview.md"
)
PROJECT_KIND=""           # 1=UI 2=BE 3=CLI 4=Full 5=Mobile 6=Other
CONFLICT_POLICY="skip"    # skip|overwrite|merge
PROJECT_NAME=""           # phase_1 에서 인자/basename 으로 설정
PRD_ONELINE=""            # PRD §1 한 줄 — phase_5 에서 CLAUDE/README 인용

# ── 헬퍼 ─────────────────────────────────────
_check_git() {
  if [ ! -d .git ]; then
    echo "git 저장소가 아닙니다. git init 을 먼저 실행하세요." >&2
    exit 1
  fi
}

_check_memory() {
  if [ -d .specops/memory ]; then
    echo ".specops/memory/ 가 이미 존재합니다 (이미 부트스트랩됨)."
    printf "재부트스트랩 진행? [y/N]: "
    local ans=""
    read -r ans || true
    if [ "${ans}" != "y" ] && [ "${ans}" != "Y" ]; then
      echo "취소됨."
      exit 0
    fi
  fi
}

_print_artifacts_table() {
  echo ""
  echo "산출물 현황 (13종):"
  local f
  for f in "${ARTIFACTS_ROOT[@]}" "${ARTIFACTS_MEMORY[@]}"; do
    if [ -e "$f" ]; then
      echo "  [✓] $f"
    else
      echo "  [✗] $f"
    fi
  done
  echo ""
}

_resolve_conflict_policy() {
  local conflicts=0 f p=""
  for f in "${ARTIFACTS_ROOT[@]}" "${ARTIFACTS_MEMORY[@]}"; do
    [ -e "$f" ] && conflicts=$((conflicts + 1))
  done
  if [ "$conflicts" -gt 0 ]; then
    echo "충돌 파일 ${conflicts}개 감지."
    printf "기존 파일 처리 정책? (skip/overwrite/merge) [skip]: "
    read -r p || true
    case "$p" in
      overwrite) CONFLICT_POLICY="overwrite" ;;
      merge)     CONFLICT_POLICY="skip"; echo "→ merge 미구현, skip 으로 fallback (기존 파일 보존)" ;;
      *)         CONFLICT_POLICY="skip" ;;
    esac
  fi
}

# 토큰 치환: <TOKEN> → value (sed | 구분자, value 의 |·& escape)
_replace_token() {
  local file="$1" token="$2" value="$3"
  local esc
  esc=$(printf '%s' "$value" | sed 's/[|&\\]/\\&/g')
  sed -i.bak "s|${token}|${esc}|g" "$file" && rm -f "${file}.bak"
}

# 라인 교체: prefix 가 일치하는 줄을 content 로 바꿈 (awk dynamic regex backslash 회피)
_replace_line_prefix() {
  local file="$1" prefix="$2" content="$3"
  awk -v p="$prefix" -v c="$content" '
    BEGIN { plen = length(p) }
    substr($0, 1, plen) == p { print c; next }
    { print }
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# 충돌 시 보존 정책: 대상 파일 존재 + overwrite 가 아니면 true (보존)
# 방어 깊이: 새 정책 추가 시에도 안전 디폴트 (overwrite 만 명시 통과)
_should_skip() {
  [ -e "$1" ] && [ "$CONFLICT_POLICY" != "overwrite" ]
}

# numbered list 의 N 번 항목 추출 (": " 뒤 텍스트)
_parse_numbered() {
  local raw="$1" num="$2"
  printf '%s\n' "$raw" | awk -v n="$num" '
    BEGIN { pat = "^[[:space:]]*" n "\\." }
    $0 ~ pat {
      sub(/^[[:space:]]*[0-9]+\.[[:space:]]*[^:]*:[[:space:]]*/, "")
      print
      exit
    }'
}

# ── Phase 함수 ───────────────────────────────
phase_1_precheck() {
  PROJECT_NAME="${1:-$(basename "$PWD")}"
  _check_git
  _check_memory
  _print_artifacts_table
  _resolve_conflict_policy
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

# PRD 6 필드 수집: numbered list 1차 시도 → < 4 추출 시 단답 fallback
_phase_4_collect() {
  echo ""
  echo "[Phase 4] PRD — 다음 6 필드를 numbered list 로 입력 (빈 줄로 종료):"
  echo "  1. 한 줄 설명: <텍스트>"
  echo "  2. 페르소나: <텍스트>"
  echo "  3. 가치제안: <콤마 구분 3개>"
  echo "  4. M1: <텍스트>"
  echo "  5. M2: <텍스트>"
  echo "  6. M3: <텍스트>"
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
  local got=0 v
  for v in "$PRD_F1" "$PRD_F2" "$PRD_F3" "$PRD_F4" "$PRD_F5" "$PRD_F6"; do
    [ -n "$v" ] && got=$((got + 1))
  done
  if [ "$got" -lt 4 ]; then
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
  fi
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
  echo "→ ${target} 작성 완료"
}

phase_4_prd() {
  if _should_skip "PRD.md"; then
    echo "→ PRD.md 보존 (skip 정책)"
    PRD_ONELINE=$(grep -m1 '^\*\*한 줄 설명\*\*:' PRD.md 2>/dev/null | sed 's/^\*\*한 줄 설명\*\*: *//' || echo "")
    return
  fi
  PRD_F1=""; PRD_F2=""; PRD_F3=""; PRD_F4=""; PRD_F5=""; PRD_F6=""
  _phase_4_collect
  _phase_4_render
}
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
# screens-overview.md §1 표의 home/login/dashboard 예시 행을 사용자 입력으로 교체
_rebuild_screens_table() {
  local file="$1"
  shift
  local names=("$@") n rows=""
  for n in "$@"; do
    rows="${rows}| ${n} | ${n} | TODO | [screens/${n}.md](../../screens/${n}.md) | [screens/${n}.html](../../screens/${n}.html) |
"
  done
  ROWS="$rows" awk '
    /^\| home \|/, /^\| dashboard \|/ {
      if (!printed) { printf "%s", ENVIRON["ROWS"]; printed = 1 }
      next
    }
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
  done
  _rebuild_screens_table .specops/memory/screens-overview.md "${names[@]}"
  echo "→ screens/ ${#names[@]}개 + .specops/memory/screens-overview.md 작성"
}

# 8a~8h 헬퍼 — 활성 매트릭스 (plan §4.4)
_phase_8a_requirements() {
  local target=".specops/memory/requirements.md"
  _should_skip "$target" && { echo "→ ${target} skip"; return; }
  cp "$PLUGIN/templates/requirements.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  echo "→ ${target} (8a 모든 종류)"
}

_phase_8b_architecture() {
  if [ "$PROJECT_KIND" = "3" ]; then
    echo "→ architecture.md skip (8b CLI 디폴트)"
    return
  fi
  local target=".specops/memory/architecture.md"
  _should_skip "$target" && return
  cp "$PLUGIN/templates/architecture.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  echo "→ ${target} (8b)"
}

_phase_8c_frontend() {
  case "$PROJECT_KIND" in 1|4|5) ;; *) return ;; esac
  local target=".specops/memory/frontend-architecture.md"
  _should_skip "$target" && return
  cp "$PLUGIN/templates/frontend-architecture.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  echo "→ ${target} (8c UI/Full/Mobile)"
}

_phase_8d_backend() {
  case "$PROJECT_KIND" in 2|4) ;; *) return ;; esac
  local target=".specops/memory/backend-architecture.md"
  _should_skip "$target" && return
  cp "$PLUGIN/templates/backend-architecture.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  echo "→ ${target} (8d BE/Full)"
}

_phase_8e_data_model() {
  printf "[Phase 8e] DB (Postgres/MySQL/MongoDB 등) 사용? [y/N/skip]: "
  local ans=""
  read -r ans || true
  case "$ans" in y|Y) ;; *) echo "→ data-model.md skip (8e ${ans:-N})"; return ;; esac
  local target=".specops/memory/data-model.md"
  _should_skip "$target" && return
  cp "$PLUGIN/templates/data-model.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  echo "→ ${target} (8e DB=y)"
}

_phase_8f_api_spec() {
  case "$PROJECT_KIND" in 2|4) ;; *) return ;; esac
  echo "[Phase 8f] API 정의 방식? (1)Markdown (2)OpenAPI (3)GraphQL (4)RPC (5)skip"
  printf "선택 [1]: "
  local m=""
  read -r m || true
  case "$m" in 5) echo "→ api-spec.md skip"; return ;; esac
  case "$m" in 1|2|3|4) ;; *) m="1" ;; esac
  local target=".specops/memory/api-spec.md"
  _should_skip "$target" && return
  cp "$PLUGIN/templates/api-spec.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  echo "→ ${target} (8f 방식=${m})"
}

_phase_8h_test_strategy() {
  local target=".specops/memory/test-strategy.md"
  _should_skip "$target" && return
  cp "$PLUGIN/templates/test-strategy.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  echo "→ ${target} (8h 모든 종류)"
}

phase_8_artifacts() {
  echo ""
  echo "[Phase 8] 종류별 산출물 매트릭스 (KIND=${PROJECT_KIND}):"
  mkdir -p .specops/memory
  _phase_8a_requirements
  _phase_8b_architecture
  _phase_8c_frontend
  _phase_8d_backend
  _phase_8e_data_model
  _phase_8f_api_spec
  _phase_8h_test_strategy
}
phase_9_readme() {
  local target="README.md"
  if _should_skip "$target"; then
    echo "→ ${target} 보존 (skip 정책)"
    return
  fi
  cp "$PLUGIN/templates/README.md" "$target"
  _replace_token "$target" "<PROJECT_NAME>" "$PROJECT_NAME"
  _replace_line_prefix "$target" "<PRD §1 한 줄 설명" "${PRD_ONELINE:-<TODO>}"
  _replace_token "$target" "<YYYY-MM-DD>" "$(date +%Y-%m-%d)"
  echo "→ ${target} 작성 완료"
}
_kind_label() {
  case "$1" in
    1) echo "Web/UI" ;;
    2) echo "백엔드/API" ;;
    3) echo "CLI/라이브러리" ;;
    4) echo "풀스택" ;;
    5) echo "모바일" ;;
    *) echo "기타" ;;
  esac
}

# 13종 중 실제 생성된 파일 카운트
_count_active() {
  local n=0 f
  for f in "${ARTIFACTS_ROOT[@]}" "${ARTIFACTS_MEMORY[@]}"; do
    [ -f "$f" ] && n=$((n + 1))
  done
  echo "$n"
}

phase_10_commit() {
  echo ""
  echo "[Phase 10] commit + .specops/.gitignore"
  mkdir -p .specops
  # .gitignore: memory/ 와 session-progress.md 는 commit, FID 디렉토리는 ignore
  cat > .specops/.gitignore <<'EOF'
# specops-auto-ko 정책: memory/ 와 session-progress.md 는 commit, FID 디렉토리는 ignore
# FID 컨벤션: YYYYMMDD-slug (8자리 날짜 + dash). 일반 디렉토리 false positive 차단.
[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*/
EOF
  # session-progress.md 골격
  if [ ! -f .specops/session-progress.md ]; then
    cp "$PLUGIN/templates/session-progress.md" .specops/session-progress.md
    sed -i.bak "s|<project-name>|${PROJECT_NAME}|g" .specops/session-progress.md \
      && rm -f .specops/session-progress.md.bak
  fi
  local active label
  active=$(_count_active)
  label=$(_kind_label "$PROJECT_KIND")
  # git add — 활성 산출물 + screens + .specops/.gitignore + session-progress.md
  local f
  for f in "${ARTIFACTS_ROOT[@]}" "${ARTIFACTS_MEMORY[@]}"; do
    [ -f "$f" ] && git add "$f"
  done
  [ -d screens ] && git add screens
  git add .specops/.gitignore .specops/session-progress.md
  if git diff --cached --quiet; then
    echo "→ commit 대상 없음 (skip 정책으로 모두 보존된 듯)"
    return
  fi
  git commit -q -m "chore(init): /start-project 부트스트랩 (${label} · 13종 중 ${active}종)"
  echo "→ git commit 완료 (${label} · ${active}/13)"
  echo ""
  echo "초기화 완료. 활성 산출물 ${active}종."
  echo "이제 /start \"<첫 기능>\" 으로 lifecycle 진입하세요."
}

main() {
  local project_name="${1:-}"
  if [ "${project_name}" = "--help" ]; then
    echo "Usage: $0 [<project-name>]"
    echo ""
    echo "specops-auto-ko 한국어 자율 Lifecycle 부트스트랩 — 한국 SI 표준 13종 산출물 자동 생성"
    echo ""
    echo "Phase:"
    echo "  1  사전검사 (git/memory/ + 13종 파일별 표)"
    echo "  2  종류 분류 (Web/UI · BE/API · CLI/lib · 풀스택 · 모바일 · 기타)"
    echo "  3  헌법 입력"
    echo "  4  PRD 입력 (numbered list 6 필드)"
    echo "  5  CLAUDE.md 자동 생성"
    echo "  6  DESIGN.md (UI/풀스택/모바일만)"
    echo "  7  초기 화면 목록"
    echo "  8  종류별 산출물 매트릭스 (8a~8h)"
    echo "  9  README.md 자동 생성"
    echo "  10 git commit + .specops/.gitignore"
    exit 0
  fi
  phase_1_precheck "${project_name}"
  phase_2_classify
  phase_3_constitution
  phase_4_prd
  phase_5_claude
  phase_6_design
  phase_7_screens
  phase_8_artifacts
  phase_9_readme
  phase_10_commit
}

main "$@"
