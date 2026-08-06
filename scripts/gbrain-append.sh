#!/usr/bin/env bash
# Usage: gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2] [--confidence low|medium|high]
set -euo pipefail

INSIGHT="${1:-}"
if [ -z "$INSIGHT" ]; then
  echo "Usage: gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2] [--confidence low|medium|high]" >&2
  exit 1
fi
shift

case "$INSIGHT" in
  --*) echo "Usage: gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2] [--confidence low|medium|high]" >&2; exit 1 ;;
esac

FID_VAL=""
TAGS="[]"
CONF_VAL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --fid)
      if [ $# -lt 2 ]; then
        echo "Usage: gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2]" >&2
        exit 1
      fi
      # FID 형식 검증 (20260806) — repo 전 스크립트 공통 규약
      #   (session-progress-append·show-fid-status·record-metric·record-task-receipt·
      #    promote-validate 와 동일 패턴). 여기만 무검증이라 실 learnings.jsonl 에
      #   형식 위배 5건(`audit-20260710` 등)이 적재됐고, `/gbrain --fid` 필터가
      #   조용히 어긋났다. 빈 문자열(생략)은 자유작업 인사이트라 허용.
      if [ -n "$2" ] && ! printf '%s' "$2" | grep -qE '^[0-9]{8}-[a-z0-9-]+$'; then
        echo "gbrain-append: invalid FID '$2' — YYYYMMDD-kebab-slug 형식이어야 합니다" >&2
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
    --confidence)
      case "${2:-}" in
        low|medium|high) CONF_VAL="$2" ;;
        *) echo "Usage: gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2] [--confidence low|medium|high]" >&2; exit 1 ;;
      esac
      shift 2 ;;
    *)
      echo "Usage: gbrain-append.sh <insight> [--fid FID] [--tags tag1,tag2] [--confidence low|medium|high]" >&2
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
  --arg conf "${CONF_VAL:-}" \
  '{ts:$ts, fid:$fid, insight:$insight, tags:$tags} + (if $conf != "" then {confidence:$conf} else {} end)' >> "$TARGET"
