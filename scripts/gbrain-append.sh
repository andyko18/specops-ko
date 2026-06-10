#!/usr/bin/env bash
# Usage: gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2]
set -euo pipefail

json_esc() {
  local s="$1"
  s="${s//\\/\\\\}"    # 백슬래시 먼저
  s="${s//\"/\\\"}"    # 큰따옴표
  printf '%s' "$s"
}

INSIGHT="${1:-}"
if [ -z "$INSIGHT" ]; then
  echo "Usage: gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2]" >&2
  exit 1
fi
shift

case "$INSIGHT" in
  --*) echo "Usage: gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2]" >&2; exit 1 ;;
esac

FID_VAL=""
TAGS="[]"
while [ $# -gt 0 ]; do
  case "$1" in
    --fid)
      if [ $# -lt 2 ]; then
        echo "Usage: gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2]" >&2
        exit 1
      fi
      FID_VAL="$2"
      shift 2
      ;;
    --tags)
      if [ $# -lt 2 ]; then
        echo "Usage: gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2]" >&2
        exit 1
      fi
      raw="$2"
      # jq 로 안전 생성 — 태그에 " · \ 포함돼도 유효 JSON (awk 미이스케이프 결함 수정)
      if [ -z "$raw" ]; then
        TAGS="[]"
      else
        TAGS=$(jq -cn --arg r "$raw" '$r | split(",")')
      fi
      shift 2
      ;;
    *)
      echo "Usage: gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2]" >&2
      exit 1 ;;
  esac
done

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TARGET="${GBRAIN_FILE:-.specops/memory/learnings.jsonl}"
mkdir -p "$(dirname "$TARGET")"

printf '{"ts":"%s","fid":"%s","insight":"%s","tags":%s}\n' \
  "$TS" "$(json_esc "$FID_VAL")" "$(json_esc "$INSIGHT")" "$TAGS" >> "$TARGET"
