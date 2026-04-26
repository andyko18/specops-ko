#!/usr/bin/env bash
# specops-auto-ko v0.0 PoC · 플러그인 구조 무결성 정적 검증 (Gate)
# 체크: 디렉토리·파일수·frontmatter·superpowers 런타임 참조·매니페스트 일관성
# 사용: scripts/validate-structure.sh [--json]
# baseline: P1 flat skill 구조 — skills/<name>/SKILL.md × 16
#           (commands=1 /start, agents 없음 · conductor 없이 chain, knowledge 없음)
# 참조: README.md §현재 상태 · specops-ko docs/case-studies/2026-04-21-session-5-design.md §3.1
set -u

JSON_MODE=0
[ "${1:-}" = "--json" ] && JSON_MODE=1

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin_root=$(dirname "$(dirname "$script_dir")")
cd "$plugin_root"

FAILS=0
RESULTS=()
emit() { RESULTS+=("$1|$2|${3:-}"); [ "$2" = "FAIL" ] && FAILS=$((FAILS+1)); }

# 1) 디렉토리 존재 (v0.4a: agents/ 추가; docs/ 제거됨)
miss_d=()
for d in commands skills templates hooks scripts agents; do
  [ -d "$d" ] || miss_d+=("$d")
done
if [ ${#miss_d[@]} -eq 0 ]; then emit directories OK; else emit directories FAIL "누락: ${miss_d[*]}"; fi

# 2) 파일 개수 (commands=1, skills=18, templates=7, agents=3)
# templates=7: spec, acceptance-criteria, plan, tasks, session-progress, dispatch-context, test-conventions-bash
fc=()
count_of() { ls $1 2>/dev/null | wc -l | tr -d ' '; }
count_skills() { find skills -mindepth 2 -maxdepth 2 -name SKILL.md -type f 2>/dev/null | wc -l | tr -d ' '; }
[ "$(count_of 'commands/*.md')"  = 1  ] || fc+=("commands: got $(count_of 'commands/*.md'), expect 1")
[ "$(count_skills)"              = 18 ] || fc+=("skills: got $(count_skills) SKILL.md, expect 18")
[ "$(count_of 'templates/*.md')" = 7  ] || fc+=("templates: got $(count_of 'templates/*.md'), expect 7")
[ "$(count_of 'agents/*.md')"    = 3  ] || fc+=("agents: got $(count_of 'agents/*.md'), expect 3")
if [ ${#fc[@]} -eq 0 ]; then emit file_counts OK; else emit file_counts FAIL "${fc[*]}"; fi

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

# 6) reference_upstream 포맷 정보성 (v0.0: agents·knowledge 없음)
total=$(grep -rh '^reference_upstream:' commands/ skills/ docs/ 2>/dev/null | wc -l | tr -d ' ')
struct=$(grep -rhE '^reference_upstream:[[:space:]]+[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+@[a-zA-Z0-9._-]+[[:space:]]+[^[:space:]]+' \
         commands/ skills/ docs/ 2>/dev/null | wc -l | tr -d ' ')
emit ref_upstream_fmt INFO "struct=${struct}/${total}"

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
