#!/usr/bin/env bash
# tasks.md 에서 통합 검증 명령 추출 (`bash scripts/...` 패턴, placeholder 제외)
# Usage: extract-test-commands.sh <tasks.md>
#
# best-effort 추출 — tasks.md 의 inline backtick (`bash scripts/...`) 패턴만 매칭.
# placeholder (`<...>` 포함) 명령은 제외. 결과는 정렬·dedup.
# U3 (wobbly §U3): SSOT = tasks.md 의 검증 라인. 후속 (U2 후) YAML test_command 필드로 교체 예정.
set -u

tasks="${1:?usage: $0 <tasks.md>}"
if [ ! -f "$tasks" ]; then
  echo "tasks.md not found: $tasks" >&2
  exit 1
fi

grep -oE '`bash scripts/[^`]+`' "$tasks" \
  | sed -E 's/^`(.+)`$/\1/' \
  | grep -v '<' \
  | sort -u
