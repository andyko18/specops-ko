#!/usr/bin/env bash
# specops-ko v0.2 묶음 1 · 세션 진입 맥락 rehydrate
# .specops/session-progress.md 최신 N 블록(`## ` 헤더 기준)을 stdout으로 출력
# 새 Claude Code 세션 진입 시 에이전트가 대화 기억 대신 이 파일을 읽어 현재 FID/상태 복원
# 사용 예: hooks/context-reset.sh [--blocks N]    (기본 N=1, 최대 10)
# Exit  : 0 항상 (file 없으면 stderr 경고 후 종료)
# 참조  : docs/case-studies/2026-04-23-session-6-design.md §4.4
set -u

# v0.2 묶음 3: config guard — disabled 시 조용히 exit 0
script_dir_guard=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root_guard=$(dirname "$script_dir_guard")
bash "$plugin_root_guard/scripts/is-hook-enabled.sh" context-reset || exit 0

N=1
if [ "${1:-}" = "--blocks" ]; then
  shift
  if [ -z "${1:-}" ] || ! [ "$1" -eq "$1" ] 2>/dev/null; then
    echo "error: --blocks requires positive integer" >&2
    exit 2
  fi
  N=$1
  if [ "$N" -lt 1 ]; then N=1; fi
  if [ "$N" -gt 10 ]; then N=10; fi  # 상한
fi

target=".specops/session-progress.md"
if [ ! -f "$target" ]; then
  echo "⚠️  $target 없음 — 새 프로젝트이거나 ensure-session-progress 미실행" >&2
  exit 0
fi

# `## ` 헤더 블록 단위 split 후 상위 N개 출력
awk -v n="$N" '
  /^## / {
    if (in_block && current != "") blocks[++count] = current
    in_block = 1
    current = $0 "\n"
    next
  }
  in_block { current = current $0 "\n" }
  END {
    if (in_block && current != "") blocks[++count] = current
    for (i = 1; i <= n && i <= count; i++) printf "%s", blocks[i]
  }
' "$target"
