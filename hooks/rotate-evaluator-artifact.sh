#!/usr/bin/env bash
# specops-ko v0.2 · pre-write hook for Evaluator
# 기존 evaluator 산출물을 <name>-v<N>.<ext>로 백업한다.
# 존재하지 않으면 noop (정상 exit 0).
# 사용 예: hooks/rotate-evaluator-artifact.sh .specops/<FID>/analysis.md
set -u

# v0.2 묶음 3: config guard — disabled 시 조용히 exit 0
script_dir_guard=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root_guard=$(dirname "$script_dir_guard")
bash "$plugin_root_guard/scripts/is-hook-enabled.sh" rotate-evaluator-artifact || exit 0

if [ "$#" -ne 1 ]; then
  echo "usage: rotate-evaluator-artifact.sh <path>" >&2
  exit 1
fi

f=$1
if [ ! -f "$f" ]; then
  # rotation 불필요 — 최초 작성 케이스
  exit 0
fi

dir=$(dirname "$f")
base=$(basename "$f")
name="${base%.*}"
ext="${base##*.}"

# 확장자 없는 파일은 거부 (계약: evaluator 산출물은 .md)
if [ "$name" = "$base" ] || [ -z "$ext" ]; then
  echo "error: file without extension is not supported ($f)" >&2
  exit 1
fi

# 기존 -v*.ext 개수 기반 N 계산
n=$(find "$dir" -maxdepth 1 -name "${name}-v*.${ext}" -type f | wc -l | tr -d ' ')
version=$((n+1))
target="$dir/${name}-v${version}.${ext}"

mv "$f" "$target"
echo "rotated: $target"
