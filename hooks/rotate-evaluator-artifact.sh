#!/usr/bin/env bash
# 평가자 아티팩트 회전 — 기존 파일을 타임스탬프 접미사로 아카이브
# 사용: hooks/rotate-evaluator-artifact.sh <artifact-path>
# 예: hooks/rotate-evaluator-artifact.sh .specops/20260520-foo/clarifications.md
set -u

artifact="${1:-}"
if [ -z "$artifact" ]; then
  echo "사용법: $0 <artifact-path>" >&2
  exit 1
fi

if [ ! -f "$artifact" ]; then
  exit 0
fi

ts=$(date +%Y%m%dT%H%M%S)
dir=$(dirname "$artifact")
base=$(basename "$artifact" .md)
archive="${dir}/${base}-${ts}.md"

mv "$artifact" "$archive"
echo "rotated: $artifact → $archive"
