#!/usr/bin/env bash
set -euo pipefail
if [ $# -eq 0 ]; then
  echo "usage: count-artifacts.sh <dir>" >&2
  exit 1
fi
dir="$1"
if [ ! -d "$dir" ]; then
  echo "not found: $dir" >&2
  exit 1
fi
find "$dir" -maxdepth 1 -name "*.md" | wc -l | tr -d ' '
