#!/usr/bin/env bash
# specops-auto-ko — upstream drift 감지 (로컬 캐시 전용, 네트워크 접근 없음)
# Usage: diff-upstream.sh [--cached] [--no-fetch] [--file <path>]
set -euo pipefail

CACHE_DIR=".specops-cache/upstream"
LOG_FILE="docs/upstream-drift-log.md"
FILE_FILTER=""

# 인자 파싱 (AC-5: 알 수 없는 플래그 → usage + exit 1)
while [ $# -gt 0 ]; do
  case "$1" in
    --cached|--no-fetch) shift ;;
    --file) FILE_FILTER="$2"; shift 2 ;;
    --) shift; break ;;
    -*)
      echo "usage: diff-upstream.sh [--cached] [--no-fetch] [--file <path>]" >&2
      exit 1
      ;;
  esac
done

# drift-log 템플릿 자동 생성 (AC-8)
mkdir -p "$(dirname "$LOG_FILE")"
if [ ! -f "$LOG_FILE" ]; then
  cat > "$LOG_FILE" <<'TMPL'
# Upstream Drift Log

> 카운트 해석: struct=N (구조적 diff 파일 수), cache_miss=N (캐시 없음), cache_hit=N (캐시 있음), manual=N (다중 참조 — 수동 분류 필요)

| 파일 | 비고 |
|---|---|
TMPL
fi

struct=0; cache_miss=0; cache_hit=0; fetched=0; manual=0

scan_file() {
  local f="$1"
  # frontmatter에서 reference_upstream 추출
  local ref
  ref=$(grep -m1 '^reference_upstream:' "$f" 2>/dev/null \
        | sed 's/^reference_upstream:[[:space:]]*//' || true)
  [ -z "$ref" ] && return

  # 다중 upstream 참조 ('+' 포함) → manual
  if echo "$ref" | grep -q '+'; then
    manual=$((manual+1))
    return
  fi

  struct=$((struct+1))

  # 캐시 파일명 변환
  local repo_ver path_part repo_ver_clean path_clean cache_name cache_path
  repo_ver="${ref%% *}"
  path_part="${ref#* }"
  repo_ver_clean="${repo_ver//\//__}"
  repo_ver_clean="${repo_ver_clean//@/__}"
  path_clean="${path_part//\//_}"
  cache_name="${repo_ver_clean}__${path_clean}"
  cache_path="$CACHE_DIR/$cache_name"

  # 캐시 미존재 → CACHE_MISS (AC-6)
  if [ ! -f "$cache_path" ]; then
    cache_miss=$((cache_miss+1))
    printf '\n## CACHE_MISS: %s\n참조: %s\n' "$f" "$ref" >> "$LOG_FILE"
    return
  fi

  cache_hit=$((cache_hit+1))

  # 섹션(## 헤더) 비교 (AC-7)
  local upstream_count local_count common upstream_only local_only
  upstream_count=$(grep -c '^## ' "$cache_path" 2>/dev/null || echo 0)
  local_count=$(grep -c '^## ' "$f" 2>/dev/null || echo 0)
  common=$(comm -12 \
    <(grep '^## ' "$cache_path" 2>/dev/null | sort || true) \
    <(grep '^## ' "$f" 2>/dev/null | sort || true) \
    | wc -l | tr -d ' ')
  upstream_only=$((upstream_count - common))
  local_only=$((local_count - common))

  {
    printf '\n## %s\n' "$f"
    printf '상류 헤더: %s, 로컬 헤더: %s, 공통: %s\n' \
      "$upstream_count" "$local_count" "$common"
    printf '상류에만: %s, 로컬에만: %s\n' "$upstream_only" "$local_only"
    comm -23 \
      <(grep '^## ' "$cache_path" 2>/dev/null | sort || true) \
      <(grep '^## ' "$f" 2>/dev/null | sort || true) \
      | while IFS= read -r h; do printf '  - %s\n' "$h"; done
  } >> "$LOG_FILE"
}

if [ -n "$FILE_FILTER" ]; then
  # 단일 파일 모드 (--file)
  [ -f "$FILE_FILTER" ] && scan_file "$FILE_FILTER"
else
  # 전체 스캔
  for d in commands agents skills knowledge docs scripts; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do
      scan_file "$f"
    done < <(find "$d" -maxdepth 3 -type f -name "*.md" 2>/dev/null || true)
  done
fi

echo "struct=$struct cache_miss=$cache_miss fetched=$fetched manual=$manual cache_hit=$cache_hit"
