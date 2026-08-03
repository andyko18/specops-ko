#!/usr/bin/env bash
# library-only — sourced by init-project.sh
# 공용 헬퍼 9개 (init-project.sh 에서 이동)

# ── 헬퍼 ─────────────────────────────────────
_check_git() {
  if [ ! -d .git ]; then
    echo "git 저장소가 아닙니다. git init 을 먼저 실행하세요." >&2
    exit 1
  fi
}

_check_memory() {
  if [ -d .specops/memory ]; then
    if [ "${RESUME_MODE}" = "1" ]; then
      return 0
    fi
    # M2: 경고/안내·prompt·취소 결과 모두 stderr (자동화 일관성 — _check_git 와 동등)
    echo ".specops/memory/ 가 이미 존재합니다 (이미 부트스트랩됨)." >&2
    printf "재부트스트랩 진행? [y/N]: " >&2
    local ans=""
    read -r ans || true
    if [ "${ans}" != "y" ] && [ "${ans}" != "Y" ]; then
      echo "취소됨." >&2
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
    if [ "${RESUME_MODE}" = "1" ]; then
      CONFLICT_POLICY="skip"
      return 0
    fi
    echo "충돌 파일 ${conflicts}개 감지."
    printf "기존 파일 처리 정책? (skip/overwrite/merge) [skip]: "
    read -r p || true
    case "$p" in
      overwrite) CONFLICT_POLICY="overwrite" ;;
      merge)     CONFLICT_POLICY="skip"; echo "⚠️  merge 정책 미구현 — skip 으로 fallback. 기존 파일은 보존됩니다." >&2 ;;
      *)         CONFLICT_POLICY="skip" ;;
    esac
  fi
}

# 토큰 치환: <TOKEN> → value (sed | 구분자, LHS 토큰 BRE 메타문자 + RHS value 의 |·& escape)
_replace_token() {
  local file="$1" token="$2" value="$3"
  local esc_token esc
  # 토큰(LHS)은 BRE 리터럴로 — . * [ ] ^ $ \ 및 구분자 | escape (`.` any-char 오매치 차단)
  esc_token=$(printf '%s' "$token" | sed 's/[].[*^$\|]/\\&/g')
  esc=$(printf '%s' "$value" | sed 's/[|&\\]/\\&/g')
  sed -i.bak "s|${esc_token}|${esc}|g" "$file" && rm -f "${file}.bak"
}

# DESIGN.md 색상 표(9행) → screen.html :root CSS 변수 전체 주입
# 사용: _inject_design_palette <html-file>
# - DESIGN.md 부재 또는 대상 파일 부재 시 no-op (return 0)
# - 색상별 hex 검증 — 미확정(`#______` placeholder)·비hex 는 skip → 템플릿 기본값 유지
#   (Phase 6 단독 시점엔 Primary 만 확정, 나머지는 Phase 11 후 확정 — 부분 주입 안전)
# - DESIGN.md 행 라벨 ≠ CSS 변수명 (Background→--color-bg, Text Primary→--color-text) — 명시 매핑
# 공유: phases-design.sh Phase 7 + design-screen.sh 양쪽에서 호출 (DRY)
_inject_design_palette() {
  local html="$1"
  [ -f "$html" ] || return 0
  [ -f "DESIGN.md" ] || return 0
  local map="Primary|--color-primary
Secondary|--color-secondary
Background|--color-bg
Surface|--color-surface
Text Primary|--color-text
Text Secondary|--color-text-secondary
Border|--color-border
Error|--color-error
Success|--color-success"
  local label var hex
  while IFS='|' read -r label var; do
    [ -z "$label" ] && continue
    # 행 앵커 `| <label> |` — "| Primary |" 가 "| Text Primary |" 오매치 안 함
    hex=$(grep -m1 "| ${label} |" DESIGN.md 2>/dev/null \
      | grep -Eo '`#[A-Fa-f0-9]{3,6}`' | tr -d '`' | head -1)
    [ -z "$hex" ] && continue
    # `${var}: ` 의 콜론+공백이 --color-text 와 --color-text-secondary 를 분리
    sed -i.bak "s|${var}: #[A-Fa-f0-9]\{3,6\}|${var}: ${hex}|g" "$html" \
      && rm -f "${html}.bak"
  done <<< "$map"
}

# 라인 교체: prefix 가 일치하는 줄을 content 로 바꿈 (awk dynamic regex backslash 회피)
# M4 주의: 같은 prefix 가 본문에 2회 이상 등장하면 **모두** 치환. 호출 사이트는
# prefix 의 유일성을 보장해야 한다 (현재 모든 호출처는 1회만 등장하는 prefix 사용).
# 다중 매칭이 필요한 케이스가 등장하면 fence 패턴 (_rebuild_screens_table 참조) 으로 전환.
_replace_line_prefix() {
  local file="$1" prefix="$2" content="$3"
  P="$prefix" C="$content" awk '
    BEGIN { plen = length(ENVIRON["P"]) }
    substr($0, 1, plen) == ENVIRON["P"] { print ENVIRON["C"]; next }
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

_check_brainstorming() {
  local bm_files
  bm_files=$(ls -t .specops/memory/brainstorming-*.md 2>/dev/null | head -3)
  if [ -n "$bm_files" ]; then
    echo ""
    echo "브레인스토밍 메모 발견 (Phase 0에서 이미 확인했다고 가정 — 재질문 생략):"
    echo "$bm_files" | sed 's/^/  /'
    BM_REF="y"
  fi
}
