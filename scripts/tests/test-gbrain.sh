#!/usr/bin/env bash
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)

run() {
  local desc="$1"; shift
  if "$@" 2>/dev/null; then PASS=$((PASS+1)); echo "PASS: $desc"
  else FAIL=$((FAIL+1)); echo "FAIL: $desc"; fi
}

# T1.a: gbrain-append.sh 존재
run "T1.a gbrain-append.sh 존재" \
  test -f "$PLUGIN/scripts/gbrain-append.sh"

# T1.b: usage 출력 (인자 없음 → exit 1)
T1_b() {
  bash "$PLUGIN/scripts/gbrain-append.sh" 2>&1 | grep -qi "usage\|insight" && \
  ! bash "$PLUGIN/scripts/gbrain-append.sh" >/dev/null 2>&1
}
run "T1.b usage 출력 exit 1" T1_b

# T2.a: JSONL 레코드 추가 (ts·fid·insight·tags 포함)
T2_a() {
  local tmp
  tmp=$(mktemp)
  GBRAIN_FILE="$tmp" bash "$PLUGIN/scripts/gbrain-append.sh" "테스트 인사이트" 2>/dev/null
  local result
  result=$(cat "$tmp")
  rm -f "$tmp"
  echo "$result" | grep -q '"insight"' && \
  echo "$result" | grep -q '"ts"' && \
  echo "$result" | grep -q '"tags"'
}
run "T2.a JSONL 레코드 추가" T2_a

# T2.b: insight 값 round-trip
run "T2.b JSONL insight 값 round-trip" bash -c '
  tmp=$(mktemp)
  GBRAIN_FILE="$tmp" bash "'"$PLUGIN"'"/scripts/gbrain-append.sh "라운드트립인사이트"
  grep -q "\"insight\":\"라운드트립인사이트\"" "$tmp"
  rm -f "$tmp"
'

# T2.c: 큰따옴표 포함 insight JSONL 유효 (C-1 검증)
run "T2.c insight 큰따옴표 포함 JSONL 유효" bash -c '
  tmp=$(mktemp)
  GBRAIN_FILE="$tmp" bash "'"$PLUGIN"'"/scripts/gbrain-append.sh '"'"'he said \"hello\"'"'"'
  line=$(tail -1 "$tmp")
  echo "$line" | grep -q '"'"'"insight"'"'"'
  rm -f "$tmp"
'

<<<<<<< HEAD
# T2.d: 큰따옴표 포함 insight python3 json 파싱 round-trip
T2_d() {
  command -v python3 >/dev/null 2>&1 || return 0  # python3 없으면 SKIP (pass)
  local tmp line ts insight result
  tmp=$(mktemp)
  GBRAIN_FILE="$tmp" bash "$PLUGIN/scripts/gbrain-append.sh" 'he said "hello world"' 2>/dev/null
  line=$(tail -1 "$tmp")
  # python3로 파싱
  result=$(python3 - "$line" <<'PYEOF'
import sys, json
obj = json.loads(sys.argv[1])
print(obj.get("insight", ""))
PYEOF
)
  rm -f "$tmp"
  [ "$result" = 'he said "hello world"' ]
}
run "T2.d 큰따옴표 포함 insight python3 round-trip" T2_d

# T2.e: SKILL.md parse_line 코드 블록에 python3 분기 존재
run "T2.e SKILL.md python3 파싱 분기 존재" \
  grep -q 'python3' "$PLUGIN/skills/gbrain-ko/SKILL.md"

=======
>>>>>>> origin/feat/20260519-gbrain-skill
# T3.a: 파일 미존재 시 자동 생성
T3_a() {
  local tmpdir tmp
  tmpdir=$(mktemp -d)
  tmp="$tmpdir/learnings.jsonl"
  GBRAIN_FILE="$tmp" bash "$PLUGIN/scripts/gbrain-append.sh" "첫 인사이트" 2>/dev/null
  local ret=0
  test -f "$tmp" || ret=1
  rm -rf "$tmpdir"
  return $ret
}
run "T3.a 파일 미존재 시 자동 생성" T3_a

# T4.a: SKILL.md 존재 + frontmatter 6 필드
T4_a() {
  local count
  count=$(grep -c "^name:\|^description:\|^layer:\|^reference_upstream:\|^specops_version:\|^used_by:" \
    "$PLUGIN/skills/gbrain-ko/SKILL.md" 2>/dev/null || echo 0)
  [ "$count" -ge 6 ]
}
run "T4.a SKILL.md frontmatter 6 필드" T4_a

# T5.a: SKILL.md 조회 프로세스 언급
run "T5.a SKILL.md 조회 프로세스 언급" \
  grep -q "learnings.jsonl\|tail\|최신" "$PLUGIN/skills/gbrain-ko/SKILL.md" 2>/dev/null

# T6.a: commands/gbrain.md 존재
run "T6.a commands/gbrain.md 존재" \
  test -f "$PLUGIN/commands/gbrain.md"

# T6.b: gbrain-ko 언급
run "T6.b commands/gbrain.md gbrain-ko 언급" \
  grep -q "gbrain-ko" "$PLUGIN/commands/gbrain.md" 2>/dev/null

# T7.a: --fid 레코드 기록 (should)
T7_a() {
  local tmp
  tmp=$(mktemp)
  GBRAIN_FILE="$tmp" bash "$PLUGIN/scripts/gbrain-append.sh" "인사이트A" --fid "fid-A" 2>/dev/null
  GBRAIN_FILE="$tmp" bash "$PLUGIN/scripts/gbrain-append.sh" "인사이트B" --fid "fid-B" 2>/dev/null
  local ret=0
  grep -q '"fid-A"' "$tmp" && grep -q '"fid-B"' "$tmp" || ret=1
  rm -f "$tmp"
  return $ret
}
run "T7.a --fid 레코드 기록" T7_a

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
