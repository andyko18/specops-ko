#!/usr/bin/env bash
<<<<<<< HEAD
# specops-auto-ko · SKILL.md frontmatter + 섹션 규약 정적 검증
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

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

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
=======
# SKILL.md 작성 규약 정적 검증 (FID 20260518-skill-conventions)
# T1.a: SKILL.md 개수 ≥ 23
# T2.a: frontmatter 6 필드 전부 존재
# T3.a: layer 값 유효 (1|2|3)
# T4.a: layer=2 chain skill → ## 5원칙 주입 보유 (chain = ## 다음 skill 보유)
# T5.a: layer=2 ## 다음 skill 보유 수 ≥ 10 (회귀 보호)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SKILLS_DIR="$PLUGIN/skills"

ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
nope() { FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }

# ── T1.a: SKILL.md 개수 ≥ 23 ──
count=$(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$count" -ge 23 ]; then
  ok "T1.a SKILL.md 개수 ≥ 23 (실측: ${count})"
else
  nope "T1.a SKILL.md 개수" "실측 ${count} < 23"
fi

# ── T2.a: 모든 SKILL.md frontmatter 6 필드 전부 비어있지 않게 존재 ──
missing_fm=()
while IFS= read -r -d '' skill; do
  for field in name description layer reference_upstream specops_version used_by; do
    grep -qE "^${field}:[[:space:]]+\S" "$skill" || missing_fm+=("$(basename "$(dirname "$skill")"):$field")
  done
done < <(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md -type f -print0)
if [ ${#missing_fm[@]} -eq 0 ]; then
  ok "T2.a 모든 SKILL.md frontmatter 6 필드 전부 비어있지 않게 존재"
else
  nope "T2.a frontmatter 6 필드" "누락/빈값: ${missing_fm[*]:-}"
fi

# ── T3.a: layer 값이 1, 2, 3 중 하나 ──
invalid_layer=()
while IFS= read -r -d '' skill; do
  val=$(grep "^layer:" "$skill" | awk '{print $2}' | tr -d '"')
  case "$val" in
    1|2|3) ;;
    *) invalid_layer+=("$(basename "$(dirname "$skill")"):layer=$val") ;;
  esac
done < <(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md -type f -print0)
if [ ${#invalid_layer[@]} -eq 0 ]; then
  ok "T3.a layer 값 유효 (1|2|3만 허용)"
else
  nope "T3.a layer 값" "무효: ${invalid_layer[*]:-}"
fi

# ── T4.a: layer=2 + ## 다음 skill 보유 skill → ## 5원칙 주입도 보유 (chain skill 규약) ──
missing_5p=()
while IFS= read -r -d '' skill; do
  layer=$(grep "^layer:" "$skill" | awk '{print $2}' | tr -d '"')
  if [ "$layer" = "2" ]; then
    if grep -q "^## 다음 skill" "$skill" 2>/dev/null; then
      grep -q "^## 5원칙 주입" "$skill" 2>/dev/null || missing_5p+=("$(basename "$(dirname "$skill")")")
    fi
  fi
done < <(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md -type f -print0)
if [ ${#missing_5p[@]} -eq 0 ]; then
  ok "T4.a layer=2 chain skill 전부 ## 5원칙 주입 보유"
else
  nope "T4.a 5원칙 주입 누락" "${missing_5p[*]:-}"
fi

# ── T5.a: layer=2 ## 다음 skill 보유 수 ≥ 10 (회귀 보호) ──
next_count=0
while IFS= read -r -d '' skill; do
  layer=$(grep "^layer:" "$skill" | awk '{print $2}' | tr -d '"')
  if [ "$layer" = "2" ]; then
    grep -q "^## 다음 skill" "$skill" 2>/dev/null && next_count=$((next_count+1))
  fi
done < <(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md -type f -print0)
if [ "$next_count" -ge 10 ]; then
  ok "T5.a layer=2 ## 다음 skill 보유 수 ≥ 10 (실측: ${next_count})"
else
  nope "T5.a 다음 skill 보유 수" "실측 ${next_count} < 10"
fi

echo ""
echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
>>>>>>> origin/feat/20260518-skill-conventions
