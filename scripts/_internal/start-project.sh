#!/usr/bin/env bash
# /start-project 오케스트레이터 — 10 Phase 구현 (T13b~T13f 가 각 phase 함수 추가)
# 한국 SI 표준 13종 산출물 자동 부트스트랩
set -u

PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)

phase_1_precheck() { :; }
phase_2_classify() { :; }
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
