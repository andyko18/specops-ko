#!/usr/bin/env bash
# 추출된 검증 명령을 순차 실행 + evidence.md append + exit code 집계
# Usage: run-verification.sh <FID>
#
# 동작:
#   1. extract-test-commands.sh <FID 의 tasks.md> 로 명령 목록 추출
#   2. 각 명령 순차 실행 + stdout/stderr 전문을 evidence.md 에 append
#   3. 모두 PASS → stdout "VERIFY: PASS" + exit 0
#   4. 1건 FAIL → stderr "VERIFY: FAIL <cmd> (exit=N)" + exit 1
#
# U3 (wobbly §U3): verifying-evidence-ko 의 수동 명령 실행 → 자동화.
# "요약 금지" 5원칙 1 투명성을 스크립트가 강제 (출력 전문 기록).
set -u

FID="${1:?usage: $0 <FID>}"
TASKS=".specops/$FID/tasks.md"
EVIDENCE=".specops/$FID/evidence.md"

if [ ! -f "$TASKS" ]; then
  echo "tasks.md not found: $TASKS" >&2
  exit 1
fi

PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
EXTRACT="$PLUGIN/scripts/_internal/extract-test-commands.sh"

commands=$(bash "$EXTRACT" "$TASKS")
if [ -z "$commands" ]; then
  echo "VERIFY: NO COMMANDS"
  exit 0
fi

mkdir -p "$(dirname "$EVIDENCE")"
{
  echo ""
  echo "## run-verification.sh ($(date '+%Y-%m-%d %H:%M:%S'))"
  echo ""
} >> "$EVIDENCE"

all_pass=1
executed=0
skipped=0
_WHITELIST_PAT='^bash[[:blank:]]+scripts/[A-Za-z0-9_/.-]+\.sh([[:blank:]][A-Za-z0-9_/.=-]*)*$'

while IFS= read -r cmd; do
  [ -z "$cmd" ] && continue
  if [[ ! "$cmd" =~ $_WHITELIST_PAT ]] || [[ "$cmd" == *..* ]]; then
    echo "WARN: SKIP '$cmd' — whitelist 미통과 (bash scripts/*.sh 만 허용)" >&2
    {
      echo "### \`$cmd\`"
      echo '> WARN: SKIP — whitelist 미통과'
      echo ""
    } >> "$EVIDENCE"
    skipped=$((skipped + 1))
    continue
  fi
  {
    echo "### \`$cmd\`"
    echo '```'
  } >> "$EVIDENCE"
  executed=$((executed + 1))
  read -r -a _parts <<< "$cmd"
  out=$(bash "${_parts[@]:1}" 2>&1)
  ec=$?
  {
    echo "$out"
    echo '```'
    echo "exit: $ec"
    echo ""
  } >> "$EVIDENCE"
  if [ "$ec" -ne 0 ]; then
    all_pass=0
    echo "VERIFY: FAIL $cmd (exit=$ec)" >&2
  fi
done <<< "$commands"

if [ "$skipped" -gt 0 ]; then
  echo "VERIFY: PARTIAL — ${skipped}개 명령 whitelist 미통과, 수동 검증 필요 (executed=${executed} skipped=${skipped})"
  exit 1
fi
if [ "$executed" -eq 0 ]; then
  echo "VERIFY: WARN — 실행된 명령 0건" >&2
  exit 0
fi
if [ "$all_pass" = "1" ]; then
  echo "VERIFY: PASS"
  exit 0
fi
exit 1
