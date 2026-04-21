#!/usr/bin/env bash
# specops-ko v0.2 · .specops/<FID>/tasks.md의 shell 태스크 의존성 검증
# tasks.md에서 scripts/·hooks/·tests/ 하위 .sh 파일 참조를 추출하여
# 실제 파일 존재 + 실행권한(exec-bit)을 확인한다.
# 누락(MISSING) 또는 실행불가(NOT_EXEC)가 있으면 exit 1.
# 사용 예: scripts/validate-task-dependencies.sh <FID>
set -u

if [ "$#" -ne 1 ]; then
  echo "usage: validate-task-dependencies.sh <FID>" >&2
  exit 1
fi

fid=$1
tasks=".specops/${fid}/tasks.md"
if [ ! -f "$tasks" ]; then
  echo "error: $tasks not found" >&2
  exit 1
fi

# tasks.md에서 .sh 참조 추출 — scripts/·hooks/·tests/ 하위만 대상
# 동일 파일 중복 제거
refs=$(grep -oE '(scripts|hooks|tests)/[a-zA-Z0-9_./-]+\.sh' "$tasks" 2>/dev/null | sort -u || true)

if [ -z "$refs" ]; then
  echo "no shell task dependencies in $tasks"
  exit 0
fi

missing=0
not_exec=0
ok=0

while IFS= read -r r; do
  [ -z "$r" ] && continue
  if [ ! -f "$r" ]; then
    echo "MISSING: $r" >&2
    missing=$((missing+1))
    continue
  fi
  if [ ! -x "$r" ]; then
    echo "NOT_EXEC: $r (fix: chmod +x $r)" >&2
    not_exec=$((not_exec+1))
  else
    echo "OK: $r"
    ok=$((ok+1))
  fi
done <<< "$refs"

total_fail=$((missing+not_exec))
if [ "$total_fail" -gt 0 ]; then
  echo "failed: missing=$missing not_exec=$not_exec ok=$ok" >&2
  exit 1
fi
echo "all ok: $ok refs validated"
exit 0
