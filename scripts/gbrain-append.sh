#!/usr/bin/env bash
# Usage: gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2]
set -euo pipefail

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

# 전체 객체를 jq 로 생성 — insight/fid 의 제어문자(개행·탭, U+0000~U+001F)·"·\ 까지 완전 이스케이프.
# (printf+수동 json_esc 는 제어문자 미처리 → 무효 JSON 줄 + recall 유실 결함. TAGS 는 이미 valid JSON array → --argjson.)
jq -cn \
  --arg ts "$TS" \
  --arg fid "$FID_VAL" \
  --arg insight "$INSIGHT" \
  --argjson tags "$TAGS" \
  '{ts:$ts, fid:$fid, insight:$insight, tags:$tags}' >> "$TARGET"
