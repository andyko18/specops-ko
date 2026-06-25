#!/usr/bin/env bash
# /promote 진입 검증. <FID> → OK | REJECT:<사유>
# 사유: usage(인자없음)·bad-format(FID 포맷위배)·no-dir(디렉토리부재)·not-mini-fid(freework.md부재)·already-promoted(spec.md존재)
# 반드시 repo root 에서 호출(.specops/ 상대경로)
set -u

fid="${1:-}"
[ -z "$fid" ] && { echo "REJECT:usage"; exit 0; }
printf '%s' "$fid" | grep -qE '^[0-9]{8}-[a-z0-9-]+$' || { echo "REJECT:bad-format"; exit 0; }
dir=".specops/$fid"
[ -d "$dir" ] || { echo "REJECT:no-dir"; exit 0; }
[ -f "$dir/freework.md" ] || { echo "REJECT:not-mini-fid"; exit 0; }
[ -f "$dir/spec.md" ] && { echo "REJECT:already-promoted"; exit 0; }
echo "OK"
