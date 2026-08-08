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

# ── T5 (승계): warn 만 있는 규칙은 증류 후보가 아니다 ──────────────────
#   종전 단언: "R-1(warn 3행)이 후보로 등재된다" — 행수 기준 의미. 폐기(clarify Q6).
#   픽스처 무수정 + 단언 반전. 양성 검증은 독립 픽스처를 쓰는 T14·T15 가 맡는다.
_cand5=$(printf '%s' "$_OUT" | sed -n '/증류 후보/,$p')
[ -n "$_cand5" ] && ! printf '%s' "$_cand5" | grep -q 'R-1' \
  && ok "T5 (승계) warn-only R-1 은 증류 후보 아님" || nope "T5" "cand=$_cand5"

# ── T6 (승계): block 임계 미만은 후보 아님 ─────────────────────────────
#   종전은 R-1 을 후보 섹션의 **양성 대조군**으로 요구했다(공허 통과 방지 목적 —
#   없는 문자열만 grep 하면 항상 참이 되므로). block 기준에선 표준 픽스처에 양성이 없다.
#   공허 방지는 **표에 R-1 행이 렌더됐음**으로 대체한다 — 출력이 실제로 생성됐고
#   R-1 이 집계에는 있는데 후보에만 없다는 것을 한 어서션에서 보인다(AC-4 축과 동형).
_cand=$(printf '%s' "$_OUT" | sed -n '/증류 후보/,$p')
if printf '%s' "$_OUT" | grep -qE '^\| R-1 \|' && [ -n "$_cand" ] \
   && ! printf '%s' "$_cand" | grep -q 'R-2' && ! printf '%s' "$_cand" | grep -q 'R-5'; then
  ok "T6 (승계) block 임계 미만(R-2:0 · R-5:1) 후보 제외 — 표엔 렌더됨"
else
  nope "T6" "cand=$_cand"
fi

# ── T7 (승계): 임계 조정 가능 (환경변수) ───────────────────────────────
#   종전: MIN=2 → R-5 편입(행수 2). block 기준에선 R-5 는 block 1 이라 탈락한다.
#   임계 동작을 검증하려면 **경계에 걸치는 규칙**이 필요하다 — R-5(block 1)는 MIN=1 에서 편입.
_OUT=$(cd "$TMP" && SPECOPS_ROOT=".specops" GBRAIN_FRICTION_MIN=1 bash "$SH" 2>&1)
printf '%s' "$_OUT" | sed -n '/증류 후보/,$p' | grep -q 'R-5' \
  && ok "T7 (승계) GBRAIN_FRICTION_MIN=1 → R-5(block 1) 편입" || nope "T7" "out=$_OUT"
_seed; _run   # 후속 어서션을 위해 표준 상태 복원

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

# ─────────────────────────────────────────────────────────────
# T13~T20: 증류 후보 정확도 (FID 20260808-friction-candidate-accuracy)
#   후보 판정 기준: 전 severity 합산 행수 → **block 건수**
#   ⚠️ T1~T4·T8~T12 무수정 (AC-R-1c). T5·T6·T7 은 clarify Q6 로 승계.
# ─────────────────────────────────────────────────────────────

# T13 (AC-1): warn-only 규칙은 임계를 넘겨도 후보가 아니다
rm -rf "$TMP/.specops"; mkdir -p "$TMP/.specops/w1"
{ _row w1 R-9 warn 2026-07-01T00:00:00Z
  _row w1 R-9 warn 2026-07-02T00:00:00Z
  _row w1 R-9 warn 2026-07-03T00:00:00Z; } > "$TMP/.specops/w1/friction-log.jsonl"
_run
_c=$(printf '%s' "$_OUT" | sed -n '/증류 후보/,$p')
[ -n "$_c" ] && ! printf '%s' "$_c" | grep -q 'R-9' \
  && ok "T13 warn-only 3행 → 후보 아님" || nope "T13" "cand=$_c"

# T14 (AC-2): block 이 임계 이상이면 후보다
rm -rf "$TMP/.specops"; mkdir -p "$TMP/.specops/b1"
{ _row b1 R-8 block 2026-07-01T00:00:00Z
  _row b1 R-8 block 2026-07-02T00:00:00Z
  _row b1 R-8 block 2026-07-03T00:00:00Z; } > "$TMP/.specops/b1/friction-log.jsonl"
_run
printf '%s' "$_OUT" | sed -n '/증류 후보/,$p' | grep -q 'R-8' \
  && ok "T14 block 3행 → 후보 등재" || nope "T14" "out=$_OUT"

# T15 (AC-3): 혼재 — block 만 센다 (행수 기준이면 통과·block 기준이면 탈락하는 변별 케이스)
#   warn 10 + block 2, 임계 3 → 총 12행이지만 block 2 < 3 이라 후보 아님.
rm -rf "$TMP/.specops"; mkdir -p "$TMP/.specops/m1"
{ for i in 1 2 3 4 5 6 7 8 9; do _row m1 R-7 warn "2026-07-0${i}T00:00:00Z"; done
  _row m1 R-7 warn  2026-07-10T00:00:00Z
  _row m1 R-7 block 2026-07-11T00:00:00Z
  _row m1 R-7 block 2026-07-12T00:00:00Z; } > "$TMP/.specops/m1/friction-log.jsonl"
_run
_c=$(printf '%s' "$_OUT" | sed -n '/증류 후보/,$p')
printf '%s' "$_OUT" | grep -q 'R-7' \
  && [ -n "$_c" ] && ! printf '%s' "$_c" | grep -q 'R-7' \
  && ok "T15 warn10+block2 (총12행) → 후보 아님" || nope "T15" "cand=$_c"

# T16 (AC-4): 정보 유실 0 — block 0 규칙도 표에는 남는다
#   후보에서 빼는 것과 안 보이게 하는 것은 다르다. 이 어서션이 그 경계다.
rm -rf "$TMP/.specops"; mkdir -p "$TMP/.specops/w2"
{ _row w2 R-6 warn 2026-07-01T00:00:00Z
  _row w2 R-6 warn 2026-07-02T00:00:00Z
  _row w2 R-6 warn 2026-07-03T00:00:00Z; } > "$TMP/.specops/w2/friction-log.jsonl"
_run
_c=$(printf '%s' "$_OUT" | sed -n '/증류 후보/,$p')
printf '%s' "$_OUT" | grep -qE '^\| R-6 \| +3 \|' \
  && [ -n "$_c" ] && ! printf '%s' "$_c" | grep -q 'R-6' \
  && ok "T16 block 0 규칙 — 표엔 남고 후보엔 없음" || nope "T16" "out=$_OUT"

# T17 (AC-5): 표에 block 컬럼 노출 (판정 근거가 보여야 한다)
rm -rf "$TMP/.specops"; mkdir -p "$TMP/.specops/m2"
{ _row m2 R-5 warn  2026-07-01T00:00:00Z
  _row m2 R-5 block 2026-07-02T00:00:00Z
  _row m2 R-5 block 2026-07-03T00:00:00Z; } > "$TMP/.specops/m2/friction-log.jsonl"
_run
printf '%s' "$_OUT" | grep -q '| block |' \
  && printf '%s' "$_OUT" | grep -qE '^\| R-5 \| +3 \| +1 \| +2 \|' \
  && ok "T17 표에 block 컬럼 + 값 정확(2)" || nope "T17" "out=$_OUT"

# T18 (AC-6): --json 기존 5키 불변 + blocks 필드 추가 + candidates 는 block 기준
rm -rf "$TMP/.specops"; mkdir -p "$TMP/.specops/j1"
{ for i in 1 2 3 4 5; do _row j1 R-4 warn "2026-07-0${i}T00:00:00Z"; done
  _row j1 R-3 block 2026-07-06T00:00:00Z
  _row j1 R-3 block 2026-07-07T00:00:00Z
  _row j1 R-3 block 2026-07-08T00:00:00Z; } > "$TMP/.specops/j1/friction-log.jsonl"
_run --json
if printf '%s' "$_OUT" | jq -e '
      (has("total_rows") and has("total_files") and has("min")
       and has("rules") and has("candidates"))
      and (all(.rules[]; has("blocks")))
      and ([.candidates[].rule_id] == ["R-3"])' >/dev/null 2>&1; then
  ok "T18 --json 5키 불변 + blocks + candidates=block기준"
else
  nope "T18" "out=$_OUT"
fi

# T19 (AC-7): 후보 0건이어도 판정 기준을 밝히는 안내 (빈 섹션 금지)
rm -rf "$TMP/.specops"; mkdir -p "$TMP/.specops/z1"
{ _row z1 R-2 warn 2026-07-01T00:00:00Z
  _row z1 R-2 warn 2026-07-02T00:00:00Z
  _row z1 R-2 warn 2026-07-03T00:00:00Z; } > "$TMP/.specops/z1/friction-log.jsonl"
_run
_c=$(printf '%s' "$_OUT" | sed -n '/증류 후보/,$p')
[ -n "$_c" ] && printf '%s' "$_c" | grep -q 'block' \
  && ok "T19 후보 0건 → 판정 기준 명시 안내" || nope "T19" "cand=$_c"

# T20 (AC-8): 판정 기준이 문서에 기술됐는가
#   `grep -q 'block'` 은 두 문서에 다른 맥락의 'block' 이 한 번만 들어와도 영구 공허화된다
#   (Phase C 지적). 실문구("block 기준"·"`block`(차단) 건수 기준")에 맞춰 조인다.
grep -qE 'block.*기준' "$PLUGIN/commands/gbrain.md" \
  && grep -qE 'block.*기준' "$PLUGIN/skills/gbrain-ko/SKILL.md" \
  && ok "T20 문서에 block 기준 판정 명시" || nope "T20" "문서 미갱신"

# T21 (Phase C Important 1): ts 누락 규칙에서 표의 block 열이 밀리지 않는다
#   bash read 의 IFS 탭은 whitespace 라 **빈 중간 필드가 붕괴**한다. blocks 컬럼을
#   추가하면서 last_ts 가 말단→중간이 되어 새로 생긴 회귀다(종전엔 말단이라 무해).
#   증상: 후보엔 등재되는데 표엔 block 0 — 판정 근거를 보이겠다는 목적과 정면 모순.
rm -rf "$TMP/.specops"; mkdir -p "$TMP/.specops/t1"
{ printf '{"fid":"t1","rule_id":"R-T","principle":1,"severity":"block","evidence_snippet":"x"}\n'
  printf '{"fid":"t1","rule_id":"R-T","principle":1,"severity":"block","evidence_snippet":"x"}\n'
  printf '{"fid":"t1","rule_id":"R-T","principle":1,"severity":"block","evidence_snippet":"x"}\n'; } \
  > "$TMP/.specops/t1/friction-log.jsonl"
_run
printf '%s' "$_OUT" | grep -qE '^\| R-T \| +3 \| +1 \| +3 \|' \
  && printf '%s' "$_OUT" | sed -n '/증류 후보/,$p' | grep -q 'R-T' \
  && ok "T21 ts 누락 — 표 block 열 정확(3) + 후보 등재" || nope "T21" "out=$_OUT"

finish
