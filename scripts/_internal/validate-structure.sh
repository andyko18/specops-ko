#!/usr/bin/env bash
# specops-auto-ko v0.0 PoC · 플러그인 구조 무결성 정적 검증 (Gate)
# 체크: 디렉토리·파일수·frontmatter·superpowers 런타임 참조·매니페스트 일관성
# 사용: scripts/validate-structure.sh [--json]
# baseline: skills/<name>/SKILL.md × 27  (SKILL.md 템플릿 + skill_conventions 검증 추가)
#           (commands=8 · agents=3 · conductor 없이 chain)  (templates=26)
# 참조: README.md §현재 상태 · specops-ko docs/case-studies/2026-04-21-session-5-design.md §3.1
set -u

JSON_MODE=0
UPDATE_BASELINE=0
case "${1:-}" in
  --json) JSON_MODE=1 ;;
  --update-baseline) UPDATE_BASELINE=1 ;;
esac

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(dirname "$(dirname "$script_dir")")
cd "$plugin_root"
BASELINE="$script_dir/.structure-baseline"

FAILS=0
RESULTS=()
emit() { RESULTS+=("$1|$2|${3:-}"); [ "$2" = "FAIL" ] && FAILS=$((FAILS+1)); }

# 1) 디렉토리 존재 (v0.4a: agents/ 추가; docs/ 제거됨)
miss_d=()
for d in commands skills templates hooks scripts agents; do
  [ -d "$d" ] || miss_d+=("$d")
done
if [ ${#miss_d[@]} -eq 0 ]; then emit directories OK; else emit directories FAIL "누락: ${miss_d[*]}"; fi

# 2) 파일 개수 — .structure-baseline (jsonl) 동적 검증 (U4)
#    각 줄: {"category":"<라벨>","glob":"<패턴>","count":<정수>}
#    --update-baseline: 현 실측으로 baseline 갱신 후 종료
count_glob() {
  local glob="$1"
  if [[ "$glob" == */SKILL.md ]]; then
    # glob 형식 가정: <root>/*/SKILL.md (root 만 fixed). dirname 은 wildcard 포함이라 부적합.
    local root="${glob%%/*}"
    find "$root" -mindepth 2 -maxdepth 2 -name SKILL.md -type f 2>/dev/null | wc -l | tr -d ' '
  else
    ls $glob 2>/dev/null | wc -l | tr -d ' '
  fi
}

if [ "$UPDATE_BASELINE" = "1" ]; then
  if [ ! -f "$BASELINE" ]; then
    echo "❌ .structure-baseline 부재 — 초기 생성은 수동 권장 (스크립트가 카테고리 추측 X)" >&2
    exit 1
  fi
  tmp=$(mktemp)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    cat=$(echo "$line" | jq -r '.category')
    glob=$(echo "$line" | jq -r '.glob')
    actual=$(count_glob "$glob")
    printf '{"category":"%s","glob":"%s","count":%s}\n' "$cat" "$glob" "$actual" >> "$tmp"
  done < "$BASELINE"
  mv "$tmp" "$BASELINE"
  echo "✅ .structure-baseline 갱신 완료. git diff 로 의도 확인 후 commit 하세요."
  exit 0
fi

if [ ! -f "$BASELINE" ]; then
  emit file_counts FAIL ".structure-baseline 부재. --update-baseline 로 생성하세요"
else
  fc=()
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    cat=$(echo "$line" | jq -r '.category')
    glob=$(echo "$line" | jq -r '.glob')
    expected=$(echo "$line" | jq -r '.count')
    actual=$(count_glob "$glob")
    [ "$actual" = "$expected" ] || fc+=("${cat}: got ${actual}, expect ${expected}")
  done < "$BASELINE"
  if [ ${#fc[@]} -eq 0 ]; then emit file_counts OK; else emit file_counts FAIL "${fc[*]}"; fi
fi

# 2b) 메타 skill SessionStart 주입 경로 필수 (P1 핵심 가설)
meta="skills/using-specops-auto-ko-ko/SKILL.md"
hook="hooks/session-start.sh"
miss_m=()
[ -f "$meta" ] || miss_m+=("$meta")
[ -x "$hook" ] || miss_m+=("$hook (exec-bit)")
if [ ${#miss_m[@]} -eq 0 ]; then emit meta_injection OK; else emit meta_injection FAIL "누락: ${miss_m[*]}"; fi

# 3) frontmatter YAML 유효 (skills/*/SKILL.md + commands + templates)
if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" 2>/dev/null; then
  bad=()
  while IFS= read -r -d '' f; do
    head -1 "$f" | grep -q '^---$' || continue
    awk 'NR==1 && /^---$/ {inside=1; next} inside && /^---$/ {exit} inside' "$f" \
      | python3 -c "import sys,yaml; yaml.safe_load(sys.stdin)" 2>/dev/null || bad+=("$f")
  done < <(find commands skills templates -name '*.md' -type f -print0)
  if [ ${#bad[@]} -eq 0 ]; then emit frontmatter OK; else emit frontmatter FAIL "${bad[*]}"; fi
else
  emit frontmatter SKIP "python3+pyyaml 미설치 — 한계 고백"
fi

# 4) commands/ 에 superpowers 런타임 참조 0건 (v0.0: agents/ 없음)
# 허용: #/<!-- 주석, YAML 리스트(- superpowers), reference_upstream:, superpowers:/... 경로
sp=$(grep -rE '^[^#<-]*superpowers:' commands/ 2>/dev/null \
     | grep -vE '^[^:]*:[[:space:]]*(#|reference_upstream)' || true)
if [ -z "$sp" ]; then emit no_superpowers OK; else emit no_superpowers FAIL "$(echo "$sp" | head -3 | tr '\n' ';')"; fi

# 5) 매니페스트 version 일관성
if command -v python3 >/dev/null 2>&1; then
  pv=$(python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])" 2>/dev/null || echo ERR)
  mv=$(python3 -c "import json; print(json.load(open('.claude-plugin/marketplace.json'))['plugins'][0]['version'])" 2>/dev/null || echo ERR)
  if [ "$pv" = "$mv" ] && [ "$pv" != ERR ]; then
    emit manifest OK "both=$pv"
  else
    emit manifest FAIL "plugin.json=$pv vs marketplace.json=$mv"
  fi
else
  emit manifest SKIP "python3 미설치"
fi

# 6) reference_upstream 포맷 정보성
# 유효 포맷: (a) owner/repo@version path  (b) specops-auto-ko 독자 추가 (upstream 미존재 명시)
total=$(grep -rh '^reference_upstream:' commands/ skills/ docs/ 2>/dev/null | wc -l | tr -d ' ')
struct_std=$(grep -rhE '^reference_upstream:[[:space:]]+[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+@[a-zA-Z0-9._-]+[[:space:]]+[^[:space:]]+' \
         commands/ skills/ docs/ 2>/dev/null | wc -l | tr -d ' ')
struct_local=$(grep -rh '^reference_upstream:' commands/ skills/ docs/ 2>/dev/null | grep -c '독자 추가' || true)
struct=$((struct_std + struct_local))
emit ref_upstream_fmt INFO "struct=${struct}/${total}"

<<<<<<< HEAD
<<<<<<< HEAD
# 7) skill_conventions — SKILL.md frontmatter + 섹션 규약 검증
if [ ! -f "scripts/tests/test-skill-conventions.sh" ]; then
  emit skill_conventions SKIP "test-skill-conventions.sh 미존재"
elif bash scripts/tests/test-skill-conventions.sh >/dev/null 2>&1; then
  emit skill_conventions OK
else
  detail=$(bash scripts/tests/test-skill-conventions.sh 2>&1 | grep '^FAIL' | head -3 | tr '\n' '; ')
  emit skill_conventions FAIL "$detail"
=======
=======
>>>>>>> origin/feat/20260518-to-prd
# 7) skill_conventions
if bash "$script_dir/../tests/test-skill-conventions.sh" >/dev/null 2>&1; then
  emit skill_conventions OK
else
  emit skill_conventions FAIL "test-skill-conventions.sh 실패 — bash scripts/tests/test-skill-conventions.sh 로 상세 확인"
<<<<<<< HEAD
>>>>>>> origin/feat/20260518-skill-conventions
=======
>>>>>>> origin/feat/20260518-to-prd
fi

# 출력
if [ "$JSON_MODE" -eq 1 ]; then
  printf '{"fails":%d,"checks":[' "$FAILS"
  i=0
  for r in "${RESULTS[@]}"; do
    name=${r%%|*}; rest=${r#*|}; status=${rest%%|*}; detail=${rest#*|}
    [ $i -gt 0 ] && printf ','
    esc=$(printf '%s' "$detail" | python3 -c "import sys,json; sys.stdout.write(json.dumps(sys.stdin.read()))" 2>/dev/null || printf '""')
    printf '{"name":"%s","status":"%s","detail":%s}' "$name" "$status" "$esc"
    i=$((i+1))
  done
  printf ']}\n'
else
  for r in "${RESULTS[@]}"; do
    name=${r%%|*}; rest=${r#*|}; status=${rest%%|*}; detail=${rest#*|}
    case "$status" in
      OK)   echo "✅ $name: OK${detail:+ ($detail)}" ;;
      FAIL) echo "❌ $name: FAIL — $detail" ;;
      SKIP) echo "⚠️  $name: SKIP — $detail" ;;
      INFO) echo "ℹ️  $name: $detail" ;;
    esac
  done
fi

[ "$FAILS" -eq 0 ] && exit 0 || exit 1
