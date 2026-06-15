#!/usr/bin/env bash
# specops-auto-ko HUD statusLine — Lifecycle 진행 상태 1줄 표시.
# stdin: Claude Code statusLine JSON ({cwd,...}). stdout: 상태줄 1줄. 항상 exit 0.
set -uo pipefail

FALLBACK="◆ specops-auto-ko"

command -v jq >/dev/null 2>&1 || { printf '%s\n' "$FALLBACK"; exit 0; }

input=$(cat 2>/dev/null || true)
# 빈/무효 stdin → 즉시 graceful (pwd fallback 금지 — run-all 루트 CWD 오파싱 차단, C-1)
[ -n "$input" ] || { printf '%s\n' "$FALLBACK"; exit 0; }
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -n "$cwd" ] || { printf '%s\n' "$FALLBACK"; exit 0; }

PROGRESS="$cwd/.specops/session-progress.md"
[ -f "$PROGRESS" ] || { printf '%s\n' "$FALLBACK"; exit 0; }

parsed=$(awk '
  /^## [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[a-z0-9-]+/ {
    if (seen) exit
    seen=1
    line=$2
    next
  }
  seen && /^- / {
    print line "\t" $4 "\t" $5
    exit
  }
' "$PROGRESS" 2>/dev/null)

[ -n "$parsed" ] || { printf '%s\n' "$FALLBACK"; exit 0; }

fid=$(printf '%s' "$parsed" | cut -f1)
step=$(printf '%s' "$parsed" | cut -f2)
status=$(printf '%s' "$parsed" | cut -f3)

case "$status" in
  *PASS*|*완료*|*DONE*) col=$'\033[32m'; rst=$'\033[0m' ;;
  *FAIL*|*BLOCK*)       col=$'\033[31m'; rst=$'\033[0m' ;;
  *)                    col=''; rst='' ;;
esac

printf '◆ specops · %s · %s %s%s%s\n' "$fid" "$step" "$col" "$status" "$rst"
exit 0
