#!/usr/bin/env bash
# specops-ko v0.0 PoC · 플러그인 구조 무결성 정적 검증 (Gate)
# 체크: 디렉토리·파일수·frontmatter·superpowers 런타임 참조·매니페스트 일관성
# 사용: scripts/validate-structure.sh [--json]
# baseline: 실측 카운트의 단일 출처는 scripts/_internal/.structure-baseline (jsonl) — 본 주석에 수치 비기재(드리프트 방지).
#           카테고리: skills/<name>/SKILL.md · commands · agents · templates (conductor 없이 chain)
# 참조: README.md §현재 상태
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
meta="skills/using-specops-ko/SKILL.md"
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
# 유효 포맷: (a) owner/repo@version path  (b) specops-ko 독자 추가 (upstream 미존재 명시)
total=$(grep -rh '^reference_upstream:' commands/ skills/ docs/ 2>/dev/null | wc -l | tr -d ' ')
struct_std=$(grep -rhE '^reference_upstream:[[:space:]]+[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+@[a-zA-Z0-9._-]+[[:space:]]+[^[:space:]]+' \
         commands/ skills/ docs/ 2>/dev/null | wc -l | tr -d ' ')
struct_local=$(grep -rh '^reference_upstream:' commands/ skills/ docs/ 2>/dev/null | grep -c '독자 추가' || true)
struct=$((struct_std + struct_local))
emit ref_upstream_fmt INFO "struct=${struct}/${total}"

# 7) skill_conventions — SKILL.md frontmatter + 섹션 규약 검증
if [ ! -f "scripts/tests/test-skill-conventions.sh" ]; then
  emit skill_conventions SKIP "test-skill-conventions.sh 미존재"
elif bash scripts/tests/test-skill-conventions.sh >/dev/null 2>&1; then
  emit skill_conventions OK
else
  detail=$(bash scripts/tests/test-skill-conventions.sh 2>&1 | grep '^FAIL' | head -3 | tr '\n' '; ')
  emit skill_conventions FAIL "$detail"
fi

# 8) version_sync — plugin.json 기준 README header/footer · CHANGELOG 최신 헤딩 · marketplace description 동기화
pv2=$(jq -r '.version // empty' .claude-plugin/plugin.json 2>/dev/null || true)
if [ -z "$pv2" ]; then
  emit version_sync SKIP "plugin.json version 미확인"
elif [ ! -f README.md ] && [ ! -f CHANGELOG.md ]; then
  emit version_sync SKIP "README/CHANGELOG 부재"
else
  vs=()
  mdesc=$(jq -r '.metadata.description // empty' .claude-plugin/marketplace.json 2>/dev/null || true)
  mdv=$(printf '%s' "$mdesc" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
  [ -n "$mdv" ] && [ "$mdv" != "v$pv2" ] && vs+=("marketplace.description=$mdv")
  if [ -f README.md ]; then
    rh=$(grep -oE '\(v[0-9]+\.[0-9]+\.[0-9]+\)' README.md | head -1 | tr -d '()' || true)
    [ -n "$rh" ] && [ "$rh" != "v$pv2" ] && vs+=("README.header=$rh")
    rf=$(grep -oE '최신: v[0-9]+\.[0-9]+\.[0-9]+' README.md | head -1 | grep -oE 'v[0-9.]+' || true)
    [ -n "$rf" ] && [ "$rf" != "v$pv2" ] && vs+=("README.footer=$rf")
  fi
  if [ -f CHANGELOG.md ]; then
    cl=$(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
    [ -n "$cl" ] && [ "$cl" != "$pv2" ] && vs+=("CHANGELOG.latest=$cl")
  fi
  if [ ${#vs[@]} -eq 0 ]; then emit version_sync OK "v$pv2"; else emit version_sync FAIL "plugin.json=v$pv2 vs ${vs[*]}"; fi
fi

# 9) readme_counts — README 구조 트리 카운트 (SKILL.md × N / templates ← N건 / agents ← N건) vs 실측
if [ ! -f README.md ]; then
  emit readme_counts SKIP "README.md 부재"
else
  rc_i=()
  r_sk=$(grep -oE 'SKILL\.md × [0-9]+' README.md | head -1 | grep -oE '[0-9]+' || true)
  a_sk=$(find skills -mindepth 2 -maxdepth 2 -name SKILL.md -type f 2>/dev/null | wc -l | tr -d ' ')
  [ -n "$r_sk" ] && [ "$r_sk" != "$a_sk" ] && rc_i+=("skills: README=$r_sk actual=$a_sk")
  r_tp=$(grep -E 'templates/.*← [0-9]+건' README.md | head -1 | grep -oE '[0-9]+건' | tr -d '건' || true)
  a_tp=$(find templates -type f ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
  [ -n "$r_tp" ] && [ "$r_tp" != "$a_tp" ] && rc_i+=("templates: README=$r_tp actual=$a_tp")
  r_ag=$(grep -E 'agents/.*← [0-9]+건' README.md | head -1 | grep -oE '[0-9]+건' | tr -d '건' || true)
  a_ag=$(ls agents/*.md 2>/dev/null | wc -l | tr -d ' ')
  [ -n "$r_ag" ] && [ "$r_ag" != "$a_ag" ] && rc_i+=("agents: README=$r_ag actual=$a_ag")
  if [ ${#rc_i[@]} -eq 0 ]; then emit readme_counts OK; else emit readme_counts FAIL "${rc_i[*]}"; fi
fi

# 10) changelog_body — 최신 릴리즈 섹션 본문 비공백 (공백 릴리즈 노트 차단)
if [ ! -f CHANGELOG.md ]; then
  emit changelog_body SKIP "CHANGELOG.md 부재"
elif ! grep -qE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md; then
  emit changelog_body SKIP "릴리즈 헤딩 없음"
else
  latest=$(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1)
  body=$(awk '
    /^## \[[0-9]+\.[0-9]+\.[0-9]+\]/ { if (found) exit; found=1; next }
    found && /^## /        { exit }
    found && /^\[[0-9A-Za-z]/ { exit }
    found && NF && !/^-+$/ { print }
  ' CHANGELOG.md)
  if [ -n "$body" ]; then emit changelog_body OK "$latest"; else emit changelog_body FAIL "최신 릴리즈 ${latest} 본문 공백"; fi
fi

# 11) xref_resolve — skills/·commands/ 본문의 skill/agent 참조 토큰이 skills/·commands/·agents/ 에 실재
#     ① prefix 형: specops-ko:<name>  ② bare 형: <name>-ko (FID 20260713-ghost-agent-drift)
#     bare 확장 배경: prefix 토큰만 수집하던 탓에 bare 로 서술된 유령 에이전트(analyzer-ko·planner-ko 등)가
#     검사망 밖이었다 — 문서가 존재하지 않는 에이전트를 서술해도 전 테스트가 통과했다.
#     allowlist: 플러그인명 자체(specops-ko) · 구 플러그인명(specops-auto-ko — 케이스 스터디 파일명 참조)
#     · upstream 프로젝트/파일 참조 — 본 repo 에 파일이 없는 게 정상.
#     (두 grep 을 합집합 — 단일 alternation 은 BSD/GNU leftmost-longest 차이에 노출)
XREF_ALLOW=" specops-ko specops-auto-ko writing-plans-ko subagent-driven-development-ko "
xr=()
while IFS= read -r tok; do
  [ -z "$tok" ] && continue
  short="${tok#specops-ko:}"
  case "$XREF_ALLOW" in *" $short "*) continue ;; esac
  [ -f "skills/$short/SKILL.md" ] || [ -f "commands/$short.md" ] || [ -f "agents/$short.md" ] || xr+=("$tok")
done < <({ grep -rhoE 'specops-ko:[a-z0-9][a-z0-9-]*' skills commands templates --include='*.md' 2>/dev/null
           grep -rhoE '[a-z][a-z0-9-]*-ko' skills commands templates --include='*.md' 2>/dev/null; } | sort -u)
if [ ${#xr[@]} -eq 0 ]; then emit xref_resolve OK; else emit xref_resolve FAIL "미해석: ${xr[*]}"; fi

# 12) used_by_fmt — skill used_by 는 short name 규약 (CLAUDE.md): skill 참조는 <name>-ko, command 는 /<name>.
#     full `specops-ko:` prefix 금지 (used_by 역참조·기계 파싱 일관성). 본문 토큰(xref_resolve 대상)은 무관.
ubf=$(grep -rlE '^used_by:.*specops-ko:' skills --include='SKILL.md' 2>/dev/null \
  | sed 's#.*/skills/##; s#/SKILL.md##' | tr '\n' ' ')
if [ -z "$ubf" ]; then emit used_by_fmt OK; else emit used_by_fmt FAIL "full-prefix 위반: $ubf"; fi

# 12.5) plugin_root_paths — 사용자 프로젝트 cwd(≠plugin)서 실행되는 커맨드/스킬 본문의 번들 스크립트 호출은
#       상대 `bash scripts/` 금지 (외부 cwd 서 스크립트 부재 → No such file). 정식형 `bash "${CLAUDE_PLUGIN_ROOT}"/scripts/`
#       (docs: Skill·agent 본문의 ${CLAUDE_PLUGIN_ROOT} 는 로드 시점 절대경로 치환). 예외 2종:
#       ① 자기유지보수 전용 파일(cwd=plugin 서만 실행): release.md·release-ko·e2e-test-ko
#       ② 라이브 호출 아닌 산문·PR템플릿: `scripts/*.sh` 러너 glob · `scripts/tests/test-*` · `scripts/_internal/validate-structure`
prp=$(grep -rnE 'bash scripts/' commands/ skills/ 2>/dev/null \
  | grep -vE '/(release\.md|release-ko/SKILL\.md|e2e-test-ko/SKILL\.md):' \
  | grep -vE 'bash scripts/(\*\.sh|tests/test-\*|_internal/validate-structure)' \
  || true)
if [ -z "$prp" ]; then
  emit plugin_root_paths OK
else
  cnt=$(printf '%s\n' "$prp" | grep -c .)
  loc=$(printf '%s\n' "$prp" | head -3 | cut -d: -f1-2 | tr '\n' ' ')
  emit plugin_root_paths FAIL "상대 bash scripts/ ${cnt}건(정식형 \${CLAUDE_PLUGIN_ROOT} 필요): ${loc}"
fi

# 13) agent_tools — role: evaluator 역방향 스캔 (Generator-Evaluator 도구 박탈 하드강제)
#     ① 마킹 evaluator 전체: tools 명시 + Write/Edit 박탈 ② 파일명 *reviewer* 미마킹 FAIL (2차 방어)
#     ③ 파일 존재 + 마킹 0건 FAIL (공회전 방지) ④ agents/*.md 0건(sandbox) SKIP
#     한계 고백: 미마킹 + 파일명 비reviewer 신규 evaluator (critic 류) 는 사각 — 마킹 규약(CLAUDE.md)으로 안내
if ! ls agents/*.md >/dev/null 2>&1; then
  emit agent_tools SKIP "agents/*.md 부재 (sandbox 등)"
else
  atf=()
  ev=$(grep -l '^role: evaluator' agents/*.md 2>/dev/null || true)
  if [ -z "$ev" ]; then
    atf+=("evaluator마킹0건")
  else
    for f in $ev; do
      a=$(basename "$f" .md)
      tl=$(grep -E '^tools:' "$f" 2>/dev/null)
      if [ -z "$tl" ]; then atf+=("$a:tools누락"); continue; fi
      printf '%s' "$tl" | grep -qwE 'Write|Edit' && atf+=("$a:Write/Edit포함")
    done
  fi
  for f in agents/*reviewer*.md; do
    [ -f "$f" ] || continue
    grep -q '^role: evaluator' "$f" || atf+=("$(basename "$f" .md):role마킹누락")
  done
  if [ ${#atf[@]} -eq 0 ]; then emit agent_tools OK; else emit agent_tools FAIL "${atf[*]}"; fi
fi

# 14) chain_consistency — hooks/chain.yaml(단일 source) ↔ SKILL.md `## 다음 skill` ↔ 메타 skill 화살표 목록
#     primary edge 만 대조 (조건 분기 산문은 xref_resolve 관할). T-H1(prefilter≡rules.jsonl) 동일 클래스.
if ! command -v python3 >/dev/null 2>&1 || ! python3 -c "import yaml" 2>/dev/null; then
  emit chain_consistency SKIP "python3+pyyaml 미설치 — 한계 고백"
elif [ ! -f hooks/chain.yaml ]; then
  emit chain_consistency FAIL "hooks/chain.yaml 부재"
else
  cc_out=$(python3 - <<'PYEOF' 2>&1
import glob, re, sys, yaml

try:
    with open('hooks/chain.yaml') as f:
        data = yaml.safe_load(f)
    declared = {(e['from'], e['to']) for e in data['edges']}
except Exception as ex:
    print(f"chain.yaml 파싱 실패: {ex}"); sys.exit(1)

actual = set()
for path in glob.glob('skills/*/SKILL.md'):
    name = path.split('/')[1]
    in_sec = False
    for line in open(path, encoding='utf-8'):
        if line.startswith('## 다음 skill'):
            in_sec = True; continue
        if in_sec and line.startswith('## '):
            in_sec = False; continue  # 섹션 종료 리셋 — 후속 섹션 Skill: 라인 오수집 방지
        m = re.match(r'^Skill: specops-ko:([a-z-]+)\s*$', line)
        if in_sec and m:
            actual.add((name, m.group(1)))

issues = [f"chain.yaml에만: {f} → {t}" for f, t in sorted(declared - actual)]
issues += [f"SKILL.md에만: {f} → {t}" for f, t in sorted(actual - declared)]

# 메타 skill 화살표 목록: 인접 pair ⊆ declared (요약 목록이라 생략 허용 — 존재하지 않는 edge 주장만 FAIL)
meta = open('skills/using-specops-ko/SKILL.md', encoding='utf-8').read()
for line in meta.splitlines():
    if '→' not in line or '-ko' not in line:
        continue
    toks = [t for t in (re.fullmatch(r'([a-z][a-z-]*-ko)\b.*', s.strip()) for s in line.split('→')) if t]
    names = [t.group(1) for t in toks]
    for a, b in zip(names, names[1:]):
        if (a, b) not in declared:
            issues.append(f"메타목록 미선언 edge: {a} → {b}")

if issues:
    print('; '.join(issues)); sys.exit(1)
PYEOF
)
  if [ $? -eq 0 ]; then emit chain_consistency OK; else emit chain_consistency FAIL "$cc_out"; fi
fi

# 15) contract_consistency — cross-skill 계약 토큰(BATCH-*-DONE halt signal) 방출↔감시 정합
#     skill 이 방출(emit)하는 signal 을 오케스트레이터 command 가 감시(watch)하는지 + suffix 일치.
#     recurring 결함 클래스(feedback_skill_body_infra_propagation)의 구조적 절반을 결정적으로 적발:
#     start-all F1(suffix drift <BATCH_ID>↔<FID>)·고아 signal 을 LLM 없이 CI 에서 차단.
if ! command -v python3 >/dev/null 2>&1; then
  emit contract_consistency SKIP "python3 미설치 — 한계 고백"
else
  ct_out=$(python3 - <<'PYEOF' 2>&1
import glob, re, sys
sig_re = re.compile(r'(BATCH-[A-Z0-9]+-DONE): <([A-Z_]+)>')
emit_, watch = {}, {}   # token -> set(suffix)
for path in glob.glob('skills/*/SKILL.md'):
    for line in open(path, encoding='utf-8'):
        for m in sig_re.finditer(line):
            emit_.setdefault(m.group(1), set()).add(m.group(2))
for path in glob.glob('commands/*.md'):
    for line in open(path, encoding='utf-8'):
        for m in sig_re.finditer(line):
            watch.setdefault(m.group(1), set()).add(m.group(2))
tokens = sorted(set(emit_) | set(watch))
if not tokens:
    print("0 signals"); sys.exit(0)
issues = []
for t in tokens:
    e, w = emit_.get(t, set()), watch.get(t, set())
    if not e:
        issues.append(f"{t}: 오케스트레이터 감시하나 skill 방출 없음(고아 watcher)")
    if not w:
        issues.append(f"{t}: skill 방출하나 오케스트레이터 감시 없음(고아 emitter)")
    sfx = e | w
    if len(sfx) > 1:
        issues.append(f"{t}: suffix 불일치 {sorted(sfx)} (emit↔watch drift)")
if issues:
    print('; '.join(issues)); sys.exit(1)
print(f"{len(tokens)} signals OK")
PYEOF
)
  if [ $? -eq 0 ]; then emit contract_consistency OK "$ct_out"; else emit contract_consistency FAIL "$ct_out"; fi
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
