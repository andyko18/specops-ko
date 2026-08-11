#!/usr/bin/env bash
# /init-project 오케스트레이터 — 10 Phase 구현 (T13b~T13f 가 각 phase 함수 추가)
# 한국 SI 표준 13종 산출물 자동 부트스트랩
set -u

PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

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
BM_REF="n"               # brainstorming 메모 참조 여부 (y|n)
RESUME_MODE=${RESUME_MODE:-0}  # 1=resume 모드 (기존 파일 보존·누락만 생성)

# ── 분할 모듈 source (BASH_SOURCE 기준 — 임의 cwd 안전) ──
_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_DIR/init-project/lib.sh"
source "$_DIR/init-project/phases-early.sh"
source "$_DIR/init-project/phases-design.sh"
source "$_DIR/init-project/phases-artifacts.sh"

main() {
  local project_name="${1:-}"
  if [ "${project_name}" = "--resume" ]; then
    RESUME_MODE=1
    project_name="${2:-}"
    echo "[resume 모드] 기존 파일 보존, 누락 파일만 생성합니다." >&2
  fi
  if [ "${project_name}" = "--help" ]; then
    echo "Usage: $0 [--resume [<project-name>] | <project-name>]"
    echo ""
    echo "specops-ko 한국어 자율 Lifecycle 부트스트랩 — 한국 SI 표준 13종 산출물 자동 생성"
    echo ""
    echo "Options:"
    echo "  --resume [<project-name>]    기존 파일 보존, 누락 파일만 생성 (부분 부트스트랩 재개; project-name 선택적)"
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
  _cd_repo_root
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

# source 가드 — sourced 시 함수만 로드 (테스트가 _replace_line_prefix 등 단위 호출 가능)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
