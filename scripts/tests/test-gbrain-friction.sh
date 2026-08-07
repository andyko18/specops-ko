#!/usr/bin/env bash
# test-gbrain-friction.sh — 마찰 집계 회귀 (20260807, 학습 루프 A: observe→distill 첫 단계)
#
# 왜 필요한가: `friction-log.jsonl` 이 **FID 디렉터리마다 흩어져** 아무도 읽지 않았다.
#   실측 20260807: 25개 파일 130행, 그중 **R-1 이 89행(68%)**.
#   한 규칙이 25개 FID 에 걸쳐 89번 위반됐는데 그 신호로 바뀐 것이 0이다.
#   Hermes 학습 루프의 observe→distill 에서 specops 는 observe 만 있고 distill 이 없다
#   (`docs/openspec-gap-analysis.md` 와 별개 — 학습 루프 축).
#   본 집계기가 그 첫 단계다: 흩어진 관찰을 **반복 패턴으로 묶어 사람에게 제시**한다.
#   게이트 자동 생성은 하지 않는다 — 클래스 B 정적 메타 규칙이 4/4 오탐으로 철회된 전례.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
SH="$PLUGIN/scripts/gbrain-friction.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

_row() {  # $1=fid $2=rule $3=severity $4=ts
  printf '{"ts":"%s","fid":"%s","rule_id":"%s","principle":1,"severity":"%s","evidence_snippet":"x","transcript_offset":1}\n' \
    "$4" "$1" "$2" "$3"
}
_seed() {  # 표준 fixture 적재
  rm -rf "$TMP/.specops"
  mkdir -p "$TMP/.specops/f1" "$TMP/.specops/f2" "$TMP/.specops/f3"
  { _row f1 R-1 warn 2026-07-01T00:00:00Z
    _row f1 R-1 warn 2026-07-02T00:00:00Z
    _row f1 R-2 warn 2026-07-03T00:00:00Z; } > "$TMP/.specops/f1/friction-log.jsonl"
  { _row f2 R-1 warn 2026-07-04T00:00:00Z; } > "$TMP/.specops/f2/friction-log.jsonl"
  { _row f3 R-5 block 2026-07-05T00:00:00Z
    _row f3 R-5 warn  2026-07-06T00:00:00Z; } > "$TMP/.specops/f3/friction-log.jsonl"
  # 총: R-1 3행/2FID · R-2 1행/1FID · R-5 2행/1FID
}
_run() { _OUT=$(cd "$TMP" && SPECOPS_ROOT=".specops" bash "$SH" "$@" 2>&1); _RC=$?; }

# ── T1: friction 파일 0개 → rc=0 + 안내 (조용한 실패 금지) ──────────────
rm -rf "$TMP/.specops"; mkdir -p "$TMP/.specops"
_run
[ "$_RC" -eq 0 ] && printf '%s' "$_OUT" | grep -q '마찰 기록 없음' \
  && ok "T1 기록 0건 → rc=0 + 안내" || nope "T1" "rc=$_RC out=$_OUT"

# ── T2: 규칙별 행수 집계 ───────────────────────────────────────────────
_seed; _run
printf '%s' "$_OUT" | grep -qE '^\| R-1 \| +3 \|' \
  && ok "T2 R-1 행수 3 집계" || nope "T2" "out=$_OUT"

# ── T3: FID 수는 중복 제거 (R-1 은 f1 2행 + f2 1행 = 2 FID) ────────────
# 행수와 FID 수를 분리해야 "한 FID 에서만 시끄러운 규칙" 과 "전역 패턴" 이 구분된다.
printf '%s' "$_OUT" | grep -qE '^\| R-1 \| +3 \| +2 \|' \
  && ok "T3 FID 수 중복 제거(2)" || nope "T3" "out=$_OUT"

# ── T4: 정렬 — 행수 내림차순 (R-1 → R-5 → R-2) ────────────────────────
_order=$(printf '%s' "$_OUT" | grep -oE '^\| R-[0-9]+ ' | tr -d '| ' | tr '\n' ',')
[ "$_order" = "R-1,R-5,R-2," ] \
  && ok "T4 행수 내림차순 정렬" || nope "T4" "order=$_order"

# ── T5: 증류 후보 임계 — 3회 이상만 (Hermes 3+ 임계 차용) ──────────────
printf '%s' "$_OUT" | grep -q 'R-1' \
  && printf '%s' "$_OUT" | sed -n '/증류 후보/,$p' | grep -q 'R-1' \
  && ok "T5 R-1(3회) 증류 후보 등재" || nope "T5" "out=$_OUT"

# ── T6: 임계 미만은 후보 아님 (R-2 1회 · R-5 2회) ─────────────────────
# 축 분리: T5 가 "표시된다" 를, T6 이 "임계가 실제로 작동한다" 를 본다.
_cand=$(printf '%s' "$_OUT" | sed -n '/증류 후보/,$p')
# ⚠️ 빈 출력에서 공허 통과 방지 — 후보 섹션 **존재**를 먼저 요구한다
#    (구현 전 RED 에서 T6 만 통과했다: 없는 문자열 2개를 grep 하면 항상 참).
if [ -n "$_cand" ] && printf '%s' "$_cand" | grep -q 'R-1' \
   && ! printf '%s' "$_cand" | grep -q 'R-2' && ! printf '%s' "$_cand" | grep -q 'R-5'; then
  ok "T6 임계 미만(R-2·R-5) 후보 제외"
else
  nope "T6" "cand=$_cand"
fi

# ── T7: 임계 조정 가능 (환경변수) ──────────────────────────────────────
_OUT=$(cd "$TMP" && SPECOPS_ROOT=".specops" GBRAIN_FRICTION_MIN=2 bash "$SH" 2>&1)
printf '%s' "$_OUT" | sed -n '/증류 후보/,$p' | grep -q 'R-5' \
  && ok "T7 GBRAIN_FRICTION_MIN=2 → R-5 편입" || nope "T7" "out=$_OUT"

# ── T8: --json 기계 판독 ───────────────────────────────────────────────
_seed
_OUT=$(cd "$TMP" && SPECOPS_ROOT=".specops" bash "$SH" --json 2>&1); _RC=$?
if [ "$_RC" -eq 0 ] && printf '%s' "$_OUT" | jq -e '.rules[] | select(.rule_id=="R-1") | .rows==3 and .fids==2' >/dev/null 2>&1; then
  ok "T8 --json 스키마"
else
  nope "T8" "rc=$_RC out=$_OUT"
fi

# ── T9: 깨진 행 무시 (fail-safe — 로그 1줄이 집계를 죽이지 않는다) ─────
_seed
{ printf '{"ts":"broken"\nnot-json\n'
  _row f1 R-9 warn 2026-07-09T00:00:00Z   # ← 깨진 행 **뒤** 유효 행
} >> "$TMP/.specops/f1/friction-log.jsonl"
_run
# 두 축을 함께 본다: ① 집계가 죽지 않는다 ② 깨진 행 **이후** 유효 행도 세어진다.
#   ②가 없으면 "중간에 중단됐지만 앞부분은 맞다" 를 통과시킨다(부분 집계 = 조용한 오답).
if [ "$_RC" -eq 0 ] \
   && printf '%s' "$_OUT" | grep -qE '^\| R-1 \| +3 \|' \
   && printf '%s' "$_OUT" | grep -qE '^\| R-9 \| +1 \|'; then
  ok "T9 깨진 행 무시 + 이후 유효 행 집계"
else
  nope "T9" "rc=$_RC out=$_OUT"
fi

# ── T10: severity block 은 별도 표기 (warn 과 섞이면 우선순위가 안 보임) ──
_seed; _run
printf '%s' "$_OUT" | grep -E '^\| R-5 ' | grep -q 'block' \
  && ok "T10 severity 분포 표기" || nope "T10" "out=$_OUT"

# ── T11: 배선 — gbrain-ko / commands 가 집계를 호출한다 ────────────────
# 스크립트만 만들고 아무도 안 부르면 "흩어져서 안 읽힌다" 가 그대로다(본 결함의 재발).
if grep -q 'gbrain-friction\.sh' "$PLUGIN/skills/gbrain-ko/SKILL.md" \
   && grep -q 'gbrain-friction\.sh' "$PLUGIN/commands/gbrain.md"; then
  ok "T11 gbrain-ko·/gbrain 배선"
else
  nope "T11" "배선 부재 — 집계기가 고아"
fi

# ── T12: 기본 출력에 포함 (플래그 없이도 보인다) ──────────────────────
# 이 결함의 본질은 "데이터가 없다" 가 아니라 "있는데 안 본다" 다.
# --friction 플래그로만 보이면 아무도 안 친다.
grep -q '기본 출력' "$PLUGIN/skills/gbrain-ko/SKILL.md" \
  && sed -n '/Step 2/,/Step 3/p' "$PLUGIN/skills/gbrain-ko/SKILL.md" | grep -q 'gbrain-friction\.sh' \
  && ok "T12 /gbrain 기본 출력에 편입" || nope "T12" "플래그 전용이면 안 읽힌다"

finish
