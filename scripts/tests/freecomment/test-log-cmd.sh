#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
CMD="$PLUGIN/commands/log.md"

# T6.a /log 커맨드 정의 존재 + gbrain-append 재사용 명시
if [ -f "$CMD" ] && grep -q 'gbrain-append' "$CMD"; then
  PASS=$((PASS+1)); echo "PASS T6.a /log 커맨드"
else
  FAIL=$((FAIL+1)); echo "FAIL T6.a"
fi
echo "---"; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
