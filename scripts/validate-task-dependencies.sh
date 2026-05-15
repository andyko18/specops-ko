#!/usr/bin/env bash
# tasks.md 자유형식 텍스트에서 .sh 참조 추출 → 존재·exec-bit 검증
set -euo pipefail
if [ $# -eq 0 ]; then
  echo "usage: validate-task-dependencies.sh <FID>" >&2
  exit 1
fi
FID="$1"
if [ ! -d ".specops/$FID" ]; then
  echo "not found: $FID" >&2
  exit 1
fi
tasks_file=".specops/$FID/tasks.md"
if [ ! -f "$tasks_file" ]; then
  echo "no shell task dependencies"
  exit 0
fi

refs=$(grep -oE '[a-zA-Z0-9_./:-]+\.sh' "$tasks_file" | grep -v '://' | sort -u || true)
if [ -z "$refs" ]; then
  echo "no shell task dependencies"
  exit 0
fi

exit_code=0
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  if [ ! -f "$ref" ]; then
    echo "MISSING: $ref" >&2
    exit_code=1
  elif [ ! -x "$ref" ]; then
    echo "NOT_EXEC: $ref" >&2
    exit_code=1
  fi
done <<< "$refs"

if [ "$exit_code" -eq 0 ]; then
  echo "all ok"
fi
exit "$exit_code"
