#!/usr/bin/env bash
# specops-ko · SKILL.md frontmatter + 섹션 규약 정적 검증
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
PLUGIN="${SPECOPS_PLUGIN_ROOT:-$PLUGIN}"
SELF="${BASH_SOURCE[0]}"

# T1.a: SKILL.md 개수 ≥ 23
count=$(find "$PLUGIN/skills" -name 'SKILL.md' | wc -l | tr -d ' ')
if [ "$count" -ge 23 ]; then
  PASS=$((PASS+1)); echo "PASS: T1.a SKILL.md 개수 $count ≥ 23"
else
  FAIL=$((FAIL+1)); echo "FAIL: T1.a SKILL.md 개수 $count < 23"
fi

# T2.a: 모든 SKILL.md — frontmatter 6 필드 존재
fields="name description layer reference_upstream specops_version used_by"
missing_all=()
while IFS= read -r -d '' f; do
  fm=$(sed -n '/^---$/,/^---$/p' "$f" | head -50)
  for field in $fields; do
    if ! printf '%s' "$fm" | grep -q "^${field}:"; then
      missing_all+=("$f:$field")
    fi
  done
done < <(find "$PLUGIN/skills" -name 'SKILL.md' -print0)

if [ ${#missing_all[@]} -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS: T2.a 모든 SKILL.md frontmatter 6 필드 존재"
else
  FAIL=$((FAIL+1)); echo "FAIL: T2.a frontmatter 필드 누락 (${#missing_all[@]}건)"
  for item in "${missing_all[@]}"; do echo "  - $item"; done
fi

# T3.a: layer 값이 1, 2, 3 중 하나 (잘못된 값 없음)
invalid_layer=()
while IFS= read -r -d '' f; do
  layer=$(sed -n '/^---$/,/^---$/p' "$f" | head -50 | grep '^layer:' | head -1 | sed 's/layer: *//')
  case "$layer" in
    1|2|3) ;;
    *) invalid_layer+=("$f: layer='$layer'") ;;
  esac
done < <(find "$PLUGIN/skills" -name 'SKILL.md' -print0)

if [ ${#invalid_layer[@]} -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS: T3.a 모든 SKILL.md layer 값 유효 (1|2|3)"
else
  FAIL=$((FAIL+1)); echo "FAIL: T3.a layer 값 비유효 (${#invalid_layer[@]}건)"
  for item in "${invalid_layer[@]}"; do echo "  - $item"; done
fi

# T4.a: layer == 2 SKILL.md — ## 5원칙 주입 섹션 존재 (harness layer 3은 제외)
missing_5p=()
while IFS= read -r -d '' f; do
  layer=$(sed -n '/^---$/,/^---$/p' "$f" | head -50 | grep '^layer:' | head -1 | sed 's/layer: *//')
  if [ "$layer" = "2" ]; then
    if ! grep -qE '^## 5원칙' "$f"; then
      missing_5p+=("$f")
    fi
  fi
done < <(find "$PLUGIN/skills" -name 'SKILL.md' -print0)

if [ ${#missing_5p[@]} -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS: T4.a 모든 layer=2 SKILL.md 에 '## 5원칙' 섹션 존재"
else
  FAIL=$((FAIL+1)); echo "FAIL: T4.a '## 5원칙' 섹션 누락 (${#missing_5p[@]}건)"
  for item in "${missing_5p[@]}"; do echo "  - $item"; done
fi

# T5.a: layer == 2 SKILL.md — ## 다음 skill 또는 ## 참조 섹션 존재 (harness layer 3은 제외)
missing_ref=()
while IFS= read -r -d '' f; do
  layer=$(sed -n '/^---$/,/^---$/p' "$f" | head -50 | grep '^layer:' | head -1 | sed 's/layer: *//')
  if [ "$layer" = "2" ]; then
    if ! grep -qE '^## (다음 skill|참조)' "$f"; then
      missing_ref+=("$f")
    fi
  fi
done < <(find "$PLUGIN/skills" -name 'SKILL.md' -print0)

if [ ${#missing_ref[@]} -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS: T5.a 모든 layer=2 SKILL.md 에 '## 다음 skill' 또는 '## 참조' 섹션 존재"
else
  FAIL=$((FAIL+1)); echo "FAIL: T5.a 섹션 누락 (${#missing_ref[@]}건)"
  for item in "${missing_ref[@]}"; do echo "  - $item"; done
fi

# T6.a: templates/SKILL.md 존재
if [ -f "$PLUGIN/templates/SKILL.md" ]; then
  PASS=$((PASS+1)); echo "PASS: T6.a templates/SKILL.md 존재"
else
  FAIL=$((FAIL+1)); echo "FAIL: T6.a templates/SKILL.md 없음"
fi

# T6.b: templates/SKILL.md — frontmatter 6 필드 포함
if [ -f "$PLUGIN/templates/SKILL.md" ]; then
  fm=$(sed -n '/^---$/,/^---$/p' "$PLUGIN/templates/SKILL.md" | head -50)
  missing_tmpl=()
  for field in $fields; do
    if ! printf '%s' "$fm" | grep -q "^${field}:"; then
      missing_tmpl+=("$field")
    fi
  done
  if [ ${#missing_tmpl[@]} -eq 0 ]; then
    PASS=$((PASS+1)); echo "PASS: T6.b templates/SKILL.md frontmatter 6 필드 존재"
  else
    FAIL=$((FAIL+1)); echo "FAIL: T6.b templates/SKILL.md 필드 누락: ${missing_tmpl[*]}"
  fi
else
  FAIL=$((FAIL+1)); echo "FAIL: T6.b templates/SKILL.md 없어서 검사 불가"
fi

# T7: 메타 skill(using-specops-ko) — rationalization 차단 문구 존재
# discipline-class 핵심 skill 이 합리화 차단을 명시적으로 포함하는지 검증
META_SKILL="$PLUGIN/skills/using-specops-ko/SKILL.md"
if [ -f "$META_SKILL" ] && grep -qE '합리화.*우회|rationalization|rationalize|우회.*금지' "$META_SKILL"; then
  PASS=$((PASS+1)); echo "PASS: T7 메타 skill 합리화 차단 문구 존재"
else
  FAIL=$((FAIL+1)); echo "FAIL: T7 메타 skill 합리화 차단 문구 없음 (using-specops-ko)"
fi

# T8: templates/SKILL.md — rationalization-table 섹션 양식 존재
# 신규 discipline-class skill 작성자가 양식을 즉시 참조할 수 있어야 함
if [ -f "$PLUGIN/templates/SKILL.md" ] && grep -q '합리화 차단표' "$PLUGIN/templates/SKILL.md"; then
  PASS=$((PASS+1)); echo "PASS: T8 templates/SKILL.md 합리화 차단표 섹션 존재"
else
  FAIL=$((FAIL+1)); echo "FAIL: T8 templates/SKILL.md 합리화 차단표 섹션 없음"
fi

# T9: discipline-class skill (frontmatter `^discipline: true`) — 합리화 차단표 존재 + 하한 3
# 한계 고백: 미마킹 신규 discipline skill 은 사각 — 마킹 규약(CLAUDE.md)으로 안내
disc_files=$(grep -l '^discipline: true' "$PLUGIN"/skills/*/SKILL.md 2>/dev/null || true)
disc_count=$(printf '%s' "$disc_files" | grep -c . || true)
disc_missing=()
for ds in $disc_files; do
  grep -q '^## 합리화 차단표' "$ds" || disc_missing+=("${ds#"$PLUGIN"/}")
done
if [ "$disc_count" -ge 3 ] && [ ${#disc_missing[@]} -eq 0 ]; then
  PASS=$((PASS+1)); echo "PASS: T9 discipline marker ${disc_count}종 합리화 차단표 존재"
else
  FAIL=$((FAIL+1)); echo "FAIL: T9 discipline 하한/차단표 위반 (count=$disc_count, 누락=${disc_missing[*]:-없음})"
fi

# T9.r/T9.s red-green — inner 재귀 1회 (grep 판정만, inner exit code 미사용)
if [ -z "${SPECOPS_T9_INNER:-}" ]; then
  # T9.r 가짜 discipline (차단표 없음) 자동 편입 적발
  sb=$(mktemp -d) || exit 1
  mkdir -p "$sb/skills/fake-discipline-ko"
  printf -- '---\nname: fake-discipline-ko\ndiscipline: true\n---\n' > "$sb/skills/fake-discipline-ko/SKILL.md"
  for real in systematic-debugging-ko tdd-ko verifying-evidence-ko; do
    mkdir -p "$sb/skills/$real"; cp "$PLUGIN/skills/$real/SKILL.md" "$sb/skills/$real/"
  done
  out=$(SPECOPS_T9_INNER=1 SPECOPS_PLUGIN_ROOT="$sb" bash "$SELF" 2>&1)
  if printf '%s' "$out" | grep -q 'FAIL: T9.*fake-discipline-ko'; then
    PASS=$((PASS+1)); echo "PASS: T9.r 가짜 discipline 자동 편입 적발"
  else
    FAIL=$((FAIL+1)); echo "FAIL: T9.r 가짜 discipline 미적발"
  fi
  rm -rf "$sb"

  # T9.s 하한 3 방어 (real 2종만)
  sb=$(mktemp -d) || exit 1
  for real in systematic-debugging-ko tdd-ko; do
    mkdir -p "$sb/skills/$real"; cp "$PLUGIN/skills/$real/SKILL.md" "$sb/skills/$real/"
  done
  out=$(SPECOPS_T9_INNER=1 SPECOPS_PLUGIN_ROOT="$sb" bash "$SELF" 2>&1)
  if printf '%s' "$out" | grep -q 'FAIL: T9 discipline 하한/차단표 위반 (count=2'; then
    PASS=$((PASS+1)); echo "PASS: T9.s 하한 3 방어"
  else
    FAIL=$((FAIL+1)); echo "FAIL: T9.s 하한 미방어"
  fi
  rm -rf "$sb"
fi

# ── T10 정적 밀도/bloat lint (리포트/정보성 — wshobson PluginEval Layer1 이식) ──
# outer+inner 모두 실행 (meta-test 가 inner 산출 라인을 grep)
T10_BLOAT_MAX=800                 # specops coding-style "800 max" norm
T10_BLOAT_EXCEPTIONS="e2e-test-ko"   # 문서화된 예외 (대규모 리팩터 별개)
T10_DENSITY_MAX=25                # 현 최댓값(22) 위 — 현재 0건 flag, 미래 폭증만 포착
# T10.a bloat: 예외 밖 >800 → FAIL (회귀 가드)
t10_bloat_fail=""
for f in "$PLUGIN"/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  name=$(basename "$(dirname "$f")")
  lc=$(wc -l < "$f" | tr -d ' ')
  if [ "$lc" -gt "$T10_BLOAT_MAX" ]; then
    case " $T10_BLOAT_EXCEPTIONS " in
      *" $name "*) echo "  INFO: T10.a bloat 예외 $name (${lc}줄 — 문서화 예외)" ;;
      *) t10_bloat_fail="$t10_bloat_fail $name(${lc})" ;;
    esac
  fi
done
if [ -z "$t10_bloat_fail" ]; then
  PASS=$((PASS+1)); echo "PASS: T10.a 예외 밖 >${T10_BLOAT_MAX}줄 bloat 없음"
else
  FAIL=$((FAIL+1)); echo "FAIL: T10.a bloat 예외 밖 >${T10_BLOAT_MAX}줄:$t10_bloat_fail"
fi
# T10.b 밀도: discipline 제외, 임계 초과 → INFO (FAIL 아님 — OVER_CONSTRAINED 는 사용자 판단)
t10_dense=""
for f in "$PLUGIN"/skills/*/SKILL.md; do
  [ -f "$f" ] || continue
  grep -q '^discipline: true' "$f" && continue
  name=$(basename "$(dirname "$f")")
  dc=$(grep -oE "반드시|금지|의무|강제|MUST|NEVER|ALWAYS|절대" "$f" | wc -l | tr -d ' ')
  [ "$dc" -gt "$T10_DENSITY_MAX" ] && t10_dense="$t10_dense $name($dc)"
done
[ -n "$t10_dense" ] && echo "  INFO: T10.b 밀도 임계(${T10_DENSITY_MAX}) 초과 — 검토 권고(단순화 또는 discipline:true):$t10_dense"
PASS=$((PASS+1)); echo "PASS: T10.b 밀도 스캔 완료 (discipline 제외)"

# ── T10 meta-tests (outer only — SPECOPS_T9_INNER 가드로 inner 재귀 차단) ──
if [ -z "${SPECOPS_T9_INNER:-}" ]; then
  # T10.a-red: bloat 예외 목록 밖 >800 skill → 적발(FAIL)
  sb=$(mktemp -d) || exit 1
  mkdir -p "$sb/skills/huge-ko"; yes '# line' | head -900 > "$sb/skills/huge-ko/SKILL.md"
  out=$(SPECOPS_T9_INNER=1 SPECOPS_PLUGIN_ROOT="$sb" bash "$SELF" 2>&1)
  if printf '%s' "$out" | grep -q 'FAIL: T10.a bloat'; then
    PASS=$((PASS+1)); echo "PASS: T10.a-red 예외 밖 >800 적발"
  else
    FAIL=$((FAIL+1)); echo "FAIL: T10.a-red 미적발"
  fi
  rm -rf "$sb"

  # T10.a-green: 예외 목록(e2e-test-ko) >800 → 미적발
  sb=$(mktemp -d) || exit 1
  mkdir -p "$sb/skills/e2e-test-ko"; yes '# line' | head -900 > "$sb/skills/e2e-test-ko/SKILL.md"
  out=$(SPECOPS_T9_INNER=1 SPECOPS_PLUGIN_ROOT="$sb" bash "$SELF" 2>&1)
  # AC-2: FAIL 부재 AND INFO 출력 존재 (정보 출력 계약도 잠금)
  if ! printf '%s' "$out" | grep -q 'FAIL: T10.a bloat' \
     && printf '%s' "$out" | grep -q 'INFO: T10.a bloat 예외 e2e-test-ko'; then
    PASS=$((PASS+1)); echo "PASS: T10.a-green 예외 목록 적용(INFO 출력)"
  else
    FAIL=$((FAIL+1)); echo "FAIL: T10.a-green 예외 미적용 또는 INFO 누락"
  fi
  rm -rf "$sb"

  # T10.b-info: 비-discipline dense(>25) → INFO 출력
  sb=$(mktemp -d) || exit 1
  mkdir -p "$sb/skills/loud-ko"
  { printf -- '---\nname: loud\n---\n'; for _ in $(seq 1 30); do echo '반드시 금지 의무'; done; } > "$sb/skills/loud-ko/SKILL.md"
  out=$(SPECOPS_T9_INNER=1 SPECOPS_PLUGIN_ROOT="$sb" bash "$SELF" 2>&1)
  if printf '%s' "$out" | grep -qE 'T10.b 밀도 임계.*loud-ko'; then
    PASS=$((PASS+1)); echo "PASS: T10.b-info 비discipline dense INFO"
  else
    FAIL=$((FAIL+1)); echo "FAIL: T10.b-info INFO 누락"
  fi
  rm -rf "$sb"

  # T10.b-exempt: discipline:true dense → INFO 미출력(제외)
  sb=$(mktemp -d) || exit 1
  mkdir -p "$sb/skills/dense-ko"
  { printf -- '---\ndiscipline: true\n---\n'; for _ in $(seq 1 30); do echo '반드시 금지 의무'; done; } > "$sb/skills/dense-ko/SKILL.md"
  out=$(SPECOPS_T9_INNER=1 SPECOPS_PLUGIN_ROOT="$sb" bash "$SELF" 2>&1)
  if printf '%s' "$out" | grep -qE 'T10.b 밀도 임계.*dense-ko'; then
    FAIL=$((FAIL+1)); echo "FAIL: T10.b-exempt discipline 밀도 미제외"
  else
    PASS=$((PASS+1)); echo "PASS: T10.b-exempt discipline 밀도 제외"
  fi
  rm -rf "$sb"
fi

# T11: skills/engine/* 유령 경로 금지 (플랫 skills/<name>/SKILL.md 만)
if command -v rg >/dev/null 2>&1; then
  eng=$(rg -l 'skills/engine/' "$PLUGIN/skills" "$PLUGIN/commands" "$PLUGIN/scripts/README.md" --glob '*.md' 2>/dev/null || true)
else
  eng=$(grep -rl 'skills/engine/' "$PLUGIN/skills" "$PLUGIN/commands" "$PLUGIN/scripts/README.md" 2>/dev/null || true)
fi
if [ -z "$eng" ]; then
  PASS=$((PASS+1)); echo "PASS: T11 skills/engine/ 유령 경로 0건"
else
  FAIL=$((FAIL+1)); echo "FAIL: T11 skills/engine/ 잔존: $eng"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
