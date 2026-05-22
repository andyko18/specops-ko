#!/usr/bin/env bash
# specops-ko v0.2 · pre-command hook
# .specops/session-progress.md 부재 시 templates로부터 자동 생성
# 존재하면 noop (idempotent).
# 사용 예: hooks/ensure-session-progress.sh [project-name]
set -u

# v0.2 묶음 3: config guard — disabled 시 조용히 exit 0
script_dir_guard=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root_guard=$(dirname "$script_dir_guard")
bash "$plugin_root_guard/scripts/_internal/is-hook-enabled.sh" ensure-session-progress || exit 0

target=".specops/session-progress.md"
if [ -f "$target" ]; then
  exit 0
fi

# 플러그인 루트 경로 해결: 이 스크립트는 <plugin-root>/hooks/ 에 위치
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(dirname "$script_dir")
template="$plugin_root/templates/session-progress.md"

if [ ! -f "$template" ]; then
  echo "error: template not found at $template" >&2
  exit 1
fi

mkdir -p .specops
project=${1:-$(basename "$(pwd)")}

# <project-name> 플레이스홀더 치환 후 복사
sed "s/<project-name>/${project}/g" "$template" > "$target"
echo "created: $target (project=$project)"
