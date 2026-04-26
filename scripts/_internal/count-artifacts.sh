#!/usr/bin/env bash
# specops-ko v0.1 · FID 20260420-count-artifacts
# 지정 디렉토리 최상위의 .md 아티팩트 파일 수를 stdout에 출력
set -u

if [ "$#" -ne 1 ]; then
  echo "usage: count-artifacts.sh <dir>" >&2
  exit 1
fi

dir=$1
if [ ! -d "$dir" ]; then
  echo "error: $dir not found" >&2
  exit 1
fi

n=$(find "$dir" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')
echo "$n"
