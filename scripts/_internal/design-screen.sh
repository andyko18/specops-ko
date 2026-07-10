#!/usr/bin/env bash
# design-screen.sh — /design-screen 보일러플레이트 자동화
# 사용: bash scripts/_internal/design-screen.sh <name> [--force]
#   - screens/{name}.md + screens/{name}.html 스캐폴딩
#   - DESIGN.md §1 Color System 전체 팔레트(9색) 추출 → HTML :root 변수 주입
#   - .specops/memory/screens-overview.md fence 갱신
set -u

FORCE=0
NAME=""

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    *) NAME="$arg" ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "Usage: $0 <name> [--force]" >&2
  exit 1
fi

# 이름 검증 — 영숫자/-/_ 1~64 (path traversal 방어)
if [[ ! "$NAME" =~ ^[A-Za-z0-9_-]{1,64}$ ]]; then
  echo "Error: 화면 이름 '$NAME' 이 유효하지 않습니다 (영숫자/-/_ 1~64만 허용)" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN=$(dirname "$(dirname "$script_dir")")

# 공유 팔레트 주입 헬퍼 (_inject_design_palette) — lib.sh 순수 함수 정의만 로드
source "$PLUGIN/scripts/_internal/init-project/lib.sh"

# 충돌 감지
if [ -f "screens/${NAME}.md" ] && [ "$FORCE" -ne 1 ]; then
  echo "Error: screens/${NAME}.md 이미 존재합니다. 덮어쓰려면 --force 사용." >&2
  exit 1
fi

today=$(date +%Y-%m-%d)
mkdir -p screens

# screen.md 생성
cp "$PLUGIN/templates/screen.md" "screens/${NAME}.md"
sed -i.bak "s/{{name}}/${NAME}/g"      "screens/${NAME}.md"
sed -i.bak "s/{{화면 제목}}/${NAME}/g" "screens/${NAME}.md"
sed -i.bak "s/{{created}}/${today}/g"  "screens/${NAME}.md"
sed -i.bak "s/{{updated}}/${today}/g"  "screens/${NAME}.md"
rm -f "screens/${NAME}.md.bak"

# screen.html 생성 (DESIGN.md 전체 팔레트 주입 — 9색)
cp "$PLUGIN/templates/screen.html" "screens/${NAME}.html"
sed -i.bak "s/{{title}}/${NAME}/g"      "screens/${NAME}.html"
sed -i.bak "s/{{화면 제목}}/${NAME}/g" "screens/${NAME}.html"
rm -f "screens/${NAME}.html.bak"
_inject_design_palette "screens/${NAME}.html"

# screens-overview.md 갱신 (fence 기반 — 존재 시만)
overview=".specops/memory/screens-overview.md"
if [ -f "$overview" ]; then
  # 기존 fence 내 행 목록 추출 (name 컬럼 — 첫 번째 파이프 뒤)
  existing_names=$(awk '
    /^<!-- screens-table:start -->/ { inside=1; next }
    /^<!-- screens-table:end -->/ { inside=0; next }
    inside && /^\|/ { split($0, f, "|"); gsub(/^[[:space:]]+|[[:space:]]+$/, "", f[2]); if (f[2] != "name") print f[2] }
  ' "$overview" 2>/dev/null)

  # 신규 이름이 이미 있으면 중복 추가 안 함
  if echo "$existing_names" | grep -qx "$NAME"; then
    :
  else
    all_names=$(printf "%s\n%s" "$existing_names" "$NAME" | grep -v '^$')
    rows=""
    while IFS= read -r n; do
      [ -z "$n" ] && continue
      rows="${rows}| ${n} | ${n} | TODO | [screens/${n}.md](../../screens/${n}.md) | [screens/${n}.html](../../screens/${n}.html) |
"
    done <<< "$all_names"
    ROWS="$rows" awk '
      /^<!-- screens-table:start -->/ { print; printf "%s", ENVIRON["ROWS"]; inside=1; next }
      /^<!-- screens-table:end -->/ { inside=0; print; next }
      inside { next }
      { print }
    ' "$overview" > "${overview}.tmp" && mv "${overview}.tmp" "$overview"
  fi
fi

echo "→ screens/${NAME}.md"
echo "→ screens/${NAME}.html"
echo "→ DESIGN.md 팔레트 주입 (확정 색상만)"
[ -f "$overview" ] && echo "→ screens-overview.md 갱신됨"
exit 0
