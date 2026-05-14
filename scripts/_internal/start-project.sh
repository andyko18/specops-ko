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
      overwrite|merge) CONFLICT_POLICY="$p" ;;
      *) CONFLICT_POLICY="skip" ;;
    esac
  fi
}

# ── Phase 함수 ───────────────────────────────
phase_1_precheck() {
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
phase_3_constitution() { :; }
phase_4_prd() { :; }
phase_5_claude() { :; }
phase_6_design() { :; }
phase_7_screens() { :; }
phase_8_artifacts() { :; }
phase_9_readme() { :; }
phase_10_commit() { :; }

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
