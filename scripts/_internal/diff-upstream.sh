#!/usr/bin/env bash
# specops-ko v0.2 · upstream drift 감지 프로토타입
# 엄격 정규식(owner/repo@tag path.ext + 라인 끝 앵커)으로 struct 분류 후
# 상류 원본과 섹션 헤더 집합을 비교해 drift-log에 prepend.
# 한국어 재창작 특성상 본문 line-diff는 수행하지 않음.
# 사용: scripts/diff-upstream.sh [--cached] [--no-fetch] [--file <path>]
set -u

CACHED=0
NO_FETCH=0
SINGLE_FILE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --cached) CACHED=1 ;;
    --no-fetch) NO_FETCH=1 ;;
    --file)
      [ -n "${2:-}" ] || { echo "usage: --file <path>" >&2; exit 1; }
      SINGLE_FILE=$2
      shift
      ;;
    *) echo "usage: diff-upstream.sh [--cached] [--no-fetch] [--file <path>]" >&2; exit 1 ;;
  esac
  shift
done

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(cd "$script_dir/../.." && pwd)
cd "$plugin_root"

CACHE_DIR=".specops-cache/upstream"
LOG_FILE="docs/upstream-drift-log.md"
DATE=$(date -u +"%Y-%m-%d")

mkdir -p "$CACHE_DIR" docs

# drift-log 템플릿 생성 (첫 run)
if [ ! -f "$LOG_FILE" ]; then
  cat > "$LOG_FILE" <<'TEMPLATE'
# Upstream Drift Log

> 내재화된 OSS 원본과의 drift 감지 히스토리. scripts/diff-upstream.sh가 최신 run을 상단에 prepend.
> 한국어 재창작 특성상 **섹션 헤더 구조 비교**만 자동화. 본문 diff는 수동 리뷰.

**포맷**: `## <YYYY-MM-DD> drift 스캔` 블록 단위
**분류**:
- `struct` (auto): `<owner>/<repo>@<tag> <path.ext>` 엄격 매칭 — 섹션 수·제목 비교
- `manual`: 다중·서술형·확장자 없음 — 수동 리뷰 대상 (v0.3 구조화 마이그레이션 예정)

**카운트 해석**: `scripts/validate-structure.sh`의 `ref_upstream_fmt` struct는 덜 엄격한 정규식 산출. diff-upstream의 struct는 확장자 + 라인 끝 앵커 엄격 매칭. 두 숫자가 다른 것이 정상.

---

TEMPLATE
fi

# 검색 대상
if [ -n "$SINGLE_FILE" ]; then
  [ -f "$SINGLE_FILE" ] || { echo "error: $SINGLE_FILE not found" >&2; exit 1; }
  FILES=$(printf '%s\n' "$SINGLE_FILE")
else
  # docs/는 제외 (OSS-ATTRIBUTION 예시 자기 참조 회피)
  FILES=$(find commands agents skills knowledge -name '*.md' -type f 2>/dev/null | sort)
fi

# 엄격 정규식 — bash [[ =~ ]]
STRICT_RE='^reference_upstream:[[:space:]]+([a-zA-Z0-9_.-]+)/([a-zA-Z0-9_.-]+)@([a-zA-Z0-9._-]+)[[:space:]]+([a-zA-Z0-9_./-]+\.(md|py|ts|sh|yaml|yml))[[:space:]]*$'

struct_cnt=0; manual_cnt=0; cache_hit=0; fetched=0; cache_miss=0; errors=0

struct_tmp=$(mktemp)
manual_tmp=$(mktemp)
# 중단(SIGINT/kill)·중간 실패 시 임시파일 잔류 방지 — 정상경로 rm 은 유지(멱등)
trap 'rm -f "${struct_tmp:-}" "${manual_tmp:-}" "${up_tmp:-}" "${lo_tmp:-}" "${block_tmp:-}" "${final_tmp:-}"' EXIT

while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue

  ref_line=$(grep -m1 '^reference_upstream:' "$f" 2>/dev/null || true)
  [ -z "$ref_line" ] && continue

  if [[ "$ref_line" =~ $STRICT_RE ]]; then
    owner=${BASH_REMATCH[1]}
    repo=${BASH_REMATCH[2]}
    tag=${BASH_REMATCH[3]}
    path=${BASH_REMATCH[4]}
    struct_cnt=$((struct_cnt+1))

    cache_key="${owner}__${repo}__${tag}__$(printf '%s' "$path" | tr '/' '_')"
    cache_path="${CACHE_DIR}/${cache_key}"

    if [ -f "$cache_path" ]; then
      cache_hit=$((cache_hit+1))
    else
      if [ "$CACHED" -eq 1 ] || [ "$NO_FETCH" -eq 1 ]; then
        printf -- '- `%s` vs `%s/%s@%s %s` — CACHE_MISS\n' \
          "$f" "$owner" "$repo" "$tag" "$path" >> "$struct_tmp"
        cache_miss=$((cache_miss+1))
        continue
      fi
      url="https://raw.githubusercontent.com/${owner}/${repo}/${tag}/${path}"
      if ! curl -fsSL --max-time 10 "$url" -o "$cache_path" 2>/dev/null; then
        printf -- '- `%s` vs `%s/%s@%s %s` — fetch 실패(%s)\n' \
          "$f" "$owner" "$repo" "$tag" "$path" "$url" >> "$struct_tmp"
        rm -f "$cache_path"
        errors=$((errors+1))
        continue
      fi
      fetched=$((fetched+1))
    fi

    # 섹션 헤더 추출: `## ` 또는 `### ` (4개 이상은 제외)
    up_tmp=$(mktemp); lo_tmp=$(mktemp)
    grep -E '^(## |### )' "$cache_path" 2>/dev/null | sort -u > "$up_tmp" || true
    grep -E '^(## |### )' "$f" 2>/dev/null | sort -u > "$lo_tmp" || true

    up_count=$(grep -c . "$up_tmp" 2>/dev/null || true); up_count=${up_count:-0}
    lo_count=$(grep -c . "$lo_tmp" 2>/dev/null || true); lo_count=${lo_count:-0}
    common=$(comm -12 "$up_tmp" "$lo_tmp" 2>/dev/null | grep -c . || true); common=${common:-0}
    up_only=$(comm -23 "$up_tmp" "$lo_tmp" 2>/dev/null | grep -c . || true); up_only=${up_only:-0}
    lo_only=$(comm -13 "$up_tmp" "$lo_tmp" 2>/dev/null | grep -c . || true); lo_only=${lo_only:-0}

    {
      printf -- '- `%s` vs `%s/%s@%s %s`\n' "$f" "$owner" "$repo" "$tag" "$path"
      printf -- '  - 상류 헤더: %s, 로컬 헤더: %s, 공통: %s\n' "$up_count" "$lo_count" "$common"
      printf -- '  - 상류에만: %s, 로컬에만: %s\n' "$up_only" "$lo_only"
      if [ "$up_only" -gt 0 ]; then
        echo '  - 상류 신규 섹션 (최대 5건):'
        comm -23 "$up_tmp" "$lo_tmp" | head -5 | sed 's/^/    - /'
      fi
      echo '  - 권고: 수동 검토 (한국어 재창작 업데이트 여부)'
    } >> "$struct_tmp"

    rm -f "$up_tmp" "$lo_tmp"
  else
    manual_cnt=$((manual_cnt+1))
    content=$(printf '%s' "$ref_line" | sed 's/^reference_upstream:[[:space:]]*//' | cut -c1-80)
    printf -- '- `%s` — %s\n' "$f" "$content" >> "$manual_tmp"
  fi
done <<< "$FILES"

# 블록 조립
block_tmp=$(mktemp)
{
  printf '## %s drift 스캔\n\n' "$DATE"
  printf '**요약**: struct=%d · manual=%d · cache_hit=%d · fetched=%d · cache_miss=%d · errors=%d\n\n' \
    "$struct_cnt" "$manual_cnt" "$cache_hit" "$fetched" "$cache_miss" "$errors"

  if [ "$struct_cnt" -gt 0 ]; then
    printf '### struct (자동 처리)\n\n'
    cat "$struct_tmp"
    printf '\n'
  fi

  if [ "$manual_cnt" -gt 0 ]; then
    printf '### manual (수동 리뷰 대상)\n\n'
    cat "$manual_tmp"
    printf '\n'
  fi

  printf -- '---\n\n'
} > "$block_tmp"

# drift-log prepend — 첫 `^---$` 뒤에 삽입
final_tmp=$(mktemp)
awk -v block_file="$block_tmp" '
  BEGIN { injected=0 }
  /^---$/ && !injected {
    print
    print ""
    while ((getline line < block_file) > 0) print line
    close(block_file)
    injected=1
    next
  }
  { print }
' "$LOG_FILE" > "$final_tmp"

# 만약 ---가 없어서 injection 실패 시 append
if ! grep -qF "## ${DATE} drift 스캔" "$final_tmp"; then
  cat "$block_tmp" >> "$final_tmp"
fi

mv "$final_tmp" "$LOG_FILE"
rm -f "$struct_tmp" "$manual_tmp" "$block_tmp"

# stdout 요약
printf 'diff-upstream 완료: struct=%d manual=%d cache_hit=%d fetched=%d cache_miss=%d errors=%d\n' \
  "$struct_cnt" "$manual_cnt" "$cache_hit" "$fetched" "$cache_miss" "$errors"
printf '상세: %s\n' "$LOG_FILE"

[ "$errors" -eq 0 ] && exit 0 || exit 2
