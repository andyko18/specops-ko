#!/usr/bin/env bash
# design-screen.sh — /design-screen 보일러플레이트 자동화
# 사용: bash scripts/_internal/design-screen.sh <name> [--force]
#   - screens/{name}.md + screens/{name}.html 스캐폴딩
#   - DESIGN.md §1 Color System 전체 팔레트(9색) 추출 → HTML :root 변수 주입
#   - .specops/memory/screens-overview.md fence 갱신
set -u

# ── 껍데기(placeholder) 판정 — 마커 단일 출처 ───────────────────────
# templates/screen.md · templates/screen.html 이 이 토큰을 담은 주석 1줄을 갖고,
# 화면을 실제 내용으로 채울 때 그 줄을 삭제한다. 판정은 템플릿 본문 문구를 보지 않는다
# — 본문이 바뀌어도 판정이 살아남게 하기 위함 (clarify Q1, AC-12).
SCREEN_PLACEHOLDER_MARKER="specops:screen-placeholder"

# screen_is_placeholder <file> — 0=껍데기 1=정상 2=파일없음
screen_is_placeholder() {
  [ -f "$1" ] || return 2
  grep -qF "$SCREEN_PLACEHOLDER_MARKER" "$1"
}

# 필수 8섹션 (specifying-ko Step 5.5 · /design-screen(s) 공통 계약).
# 조건부 4섹션(RBAC·반응형·접근성·진입/이탈)은 미해당 시 넣지 않는 규약이라 대상 아님.
SCREEN_REQUIRED_SECTIONS="목적
Layout
Components
States
Interactions
필드 정의표
데이터 소스
에러 메시지"

# screen_missing_sections <file.md> — 미완 섹션명을 줄단위 출력 (없으면 무출력)
#
# 왜 필요한가: 마커는 "채우면 이 줄을 삭제한다" 규약이라 **모델이 스스로 지워
#   '채웠다'고 선언**하는 자기보고다(20260806). 마커만 지우고 섹션을 비워도
#   FILLED 로 통과했다 — 선언된 필수 8섹션을 실제로 검사한다.
#   헤더만 있고 본문이 비면 미완(헤더 복사만으로 통과 방지).
screen_missing_sections() {
  local f="$1" sec
  [ -f "$f" ] || return 0
  case "$f" in *.md) ;; *) return 0 ;; esac   # .html 은 마커 판정만
  while IFS= read -r sec; do
    [ -n "$sec" ] || continue
    SEC="$sec" awk '
      BEGIN { want = ENVIRON["SEC"]; found = 0; body = 0 }
      /^##[[:space:]]/ {
        if (inblk) { inblk = 0 }
        h = $0; sub(/^##[[:space:]]+/, "", h)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", h)
        if (h == want) { found = 1; inblk = 1 }
        next
      }
      inblk && NF > 0 { body = 1 }
      END { exit((found && body) ? 0 : 1) }
    ' "$f" || printf '%s\n' "$sec"
  done <<EOF
$SCREEN_REQUIRED_SECTIONS
EOF
}

# --check 진입점 — 소비처(Phase 2.5 · Step 5.5 · verify backstop)가 호출.
# 기존 `<name> [--force]` 경로보다 앞에서 즉시 exit 하므로 스캐폴딩 동작에 무접촉.
if [ "${1:-}" = "--check" ]; then
  shift
  if [ $# -lt 1 ]; then
    echo "Usage: $0 --check <path>..." >&2
    exit 2
  fi
  _check_rc=1
  for _f in "$@"; do
    if screen_is_placeholder "$_f"; then
      echo "PLACEHOLDER: $_f"
      _check_rc=0
      continue
    fi
    # 마커는 지웠지만 필수 8섹션이 미완이면 여전히 껍데기다 (자기보고 차단)
    _miss=$(screen_missing_sections "$_f")
    if [ -n "$_miss" ]; then
      echo "PLACEHOLDER: $_f (필수 섹션 미완: $(printf '%s' "$_miss" | tr '\n' ',' | sed 's/,$//'))"
      _check_rc=0
    fi
  done
  [ "$_check_rc" -eq 0 ] || echo "FILLED"
  exit "$_check_rc"
fi

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
overview_note=""
if [ -f "$overview" ]; then
  # 기존 fence 내 행 목록 추출 (name 컬럼 — 첫 번째 파이프 뒤)
  existing_names=$(awk '
    /^<!-- screens-table:start -->/ { inside=1; next }
    /^<!-- screens-table:end -->/ { inside=0; next }
    inside && /^\|/ { split($0, f, "|"); gsub(/^[[:space:]]+|[[:space:]]+$/, "", f[2]); if (f[2] != "name") print f[2] }
  ' "$overview" 2>/dev/null)

  # 신규 이름이 이미 있으면 중복 추가 안 함.
  #   행을 안 넣었는데 아래에서 "갱신됨" 만 출력하면 거짓 보고다(20260806) — 명시한다.
  if echo "$existing_names" | grep -qx "$NAME"; then
    overview_note="이미 등록된 이름 — 기존 행 유지(중복 추가 안 함)"
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
if [ -f "$overview" ]; then
  if [ -n "$overview_note" ]; then
    echo "→ screens-overview.md: $overview_note"
  else
    echo "→ screens-overview.md 갱신됨"
  fi
fi
exit 0
