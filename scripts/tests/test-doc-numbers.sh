#!/usr/bin/env bash
# doc-lock 검사 스위트 — 마커 대조·미마커 금지·경로 allowlist·비-git 트리 판정
# run-all: 이 스위트는 sandbox 트리(mktemp)만 쓴다 — 실 트리 쓰기 0
#
# ★ 자기 충돌 회피: 이 파일은 "수치 + 한글 단위어" 리터럴을 쓰지 않는다 — 한글 토큰을
#   printf 로 조립한다. 리터럴을 두면 tracked 되는 순간 자기 스캔에 걸려
#   검사가 자기 자신 때문에 FAIL 한다.
set -u
# ★★ 훅 환경 격리 — 반드시 sandbox git 호출보다 앞에 온다.
#   git 은 pre-push 훅에 GIT_DIR 를 export 하고 run-all 은 그 훅에서 돈다. 떼지 않으면
#   아래 sandbox 의 `git init`·`git add -A` 가 **실 저장소 인덱스**에 기록해 실 트리 파일
#   전체가 스테이징 삭제로 뒤집힌다(실측: 구현 중 이 사고를 실제로 냈다 — 작업 트리는
#   무손상이나 인덱스가 오염됐다). 검사 본체에도 같은 unset 이 있으나 그것만으로는
#   이 스위트 자신의 git 호출을 막지 못한다.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
PASS=0; FAIL=0; SKIP=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }

CHK="$PLUGIN/scripts/_internal/check-doc-numbers.sh"
WORD=$(printf '\xec\x8a\xa4\xec\x9c\x84\xed\x8a\xb8')
RE="[0-9]{2,4}[[:space:]]*$WORD"
# 픽스처 기대 실측: validate-structure 무조건 1 + test 파일 9 = 10.
#   ★ 두 자리여야 한다 — 검사 정규식이 [0-9]{2,4} 라 한 자리 픽스처는 아예 스캔되지 않아
#   T1.b~T1.d 가 공허하게 통과한다(초안의 결함 — 구현 중 실측으로 정정).
EXP=10

# ── sandbox 구축 ─────────────────────────────────────────────
# git add -A 가 필수다 — add 없이는 git ls-files 가 0건이라
# 검사가 아무것도 스캔하지 않고 공허 통과한다.
_mksandbox() {
  local d
  d=$(mktemp -d "${TMPDIR:-/tmp}/docnum.XXXXXX") || return 1
  mkdir -p "$d/scripts/_internal" "$d/docs" \
           "$d/scripts/tests/dag" "$d/scripts/tests/governance" \
           "$d/scripts/tests/llm-eval" "$d/scripts/tests/test-convention" \
           "$d/scripts/tests/freecomment" "$d/scripts/tests/promote"
  : > "$d/scripts/_internal/validate-structure.sh"
  # 7개 수집 디렉터리를 모두 덮는다 — 검사의 수집 목록에서 한 줄이 빠지면
  #   실측이 줄어 T1.a 가 잡는다(디렉터리 누락 실패 모드 검출).
  : > "$d/scripts/tests/test-a.sh"
  : > "$d/scripts/tests/test-b.sh"
  : > "$d/scripts/tests/test-c.sh"
  : > "$d/scripts/tests/dag/test-d.sh"
  : > "$d/scripts/tests/governance/test-e.sh"
  : > "$d/scripts/tests/llm-eval/test-f.sh"
  : > "$d/scripts/tests/test-convention/test-g.sh"
  : > "$d/scripts/tests/freecomment/test-h.sh"
  : > "$d/scripts/tests/promote/test-i.sh"
  ( cd "$d" && git init -q && git add -A ) >/dev/null 2>&1 || return 1
  printf '%s' "$d"
}
_addfile() { # <sandbox> <상대경로> <내용>
  mkdir -p "$(dirname "$1/$2")"; printf '%s\n' "$3" > "$1/$2"
  ( cd "$1" && git add -A ) >/dev/null 2>&1
}
_rmfile() { # <sandbox> <상대경로>
  rm -f "$1/$2"; ( cd "$1" && git add -A ) >/dev/null 2>&1
}
_run() { DOC_NUMBERS_ROOT="$1" bash "$CHK" 2>&1; }
_rc()  { DOC_NUMBERS_ROOT="$1" bash "$CHK" >/dev/null 2>&1; printf '%s' "$?"; }

# ── T1.a 실측 계산: 픽스처를 정확히 센다 ──
sb=$(_mksandbox) || nope "T1.a" "sandbox 생성 실패"
if [ -n "${sb:-}" ]; then
  out=$(_run "$sb")
  case "$out" in
    *"suite-count=$EXP"*) ok "T1.a 실측 계산 = $EXP (validate-structure 1 + 수집 파일 9)" ;;
    *) nope "T1.a" "실측 $EXP 이 아니다 — 실제: $out" ;;
  esac
fi

# ── T1.b 마커 대조 PASS: 값이 실측과 같으면 통과 ──
_addfile "$sb" docs/lock.md "게이트는 $EXP $WORD 를 돈다 <!-- doc-lock: suite-count -->"
[ "$(_rc "$sb")" = 0 ] \
  && ok "T1.b 마커 값이 실측과 일치 → rc=0" \
  || nope "T1.b" "일치하는데 FAIL — $(_run "$sb")"

# ── T1.c 마커 대조 FAIL: 값이 다르면 4요소 리포트 + rc=1 (AC-1) ──
_addfile "$sb" docs/lock.md "게이트는 $((EXP+1)) $WORD 를 돈다 <!-- doc-lock: suite-count -->"
out=$(_run "$sb"); rc=$(_rc "$sb")
if [ "$rc" = 1 ] \
   && printf '%s' "$out" | grep -q 'docs/lock.md' \
   && printf '%s' "$out" | grep -q ":1 " \
   && printf '%s' "$out" | grep -q "기대=$EXP" \
   && printf '%s' "$out" | grep -q "실제=$((EXP+1))"; then
  ok "T1.c 마커 불일치 → rc=1 + 경로·줄·기대·실제 리포트 (AC-1)"
else
  nope "T1.c" "rc=$rc · 출력: $out"
fi

# ── T1.d 미마커 금지: 마커·allowlist 없으면 rc=1 + 조치 2종 (AC-2) ──
# lock.md 를 실측값으로 원복해 둔다 — 그래야 이 케이스의 rc=1 이 bare.md 때문임이 확정된다
# (원복 자체가 rc 를 0 으로 되돌린다는 실증은 T4 되돌려-관찰이 담당한다).
_addfile "$sb" docs/lock.md "게이트는 $EXP $WORD 를 돈다 <!-- doc-lock: suite-count -->"
_addfile "$sb" docs/bare.md "예전엔 99 $WORD 였다"
out=$(_run "$sb"); rc=$(_rc "$sb")
if [ "$rc" = 1 ] \
   && printf '%s' "$out" | grep -q 'docs/bare.md' \
   && printf '%s' "$out" | grep -q 'doc-lock: suite-count' \
   && printf '%s' "$out" | grep -q 'doc-lock: historical'; then
  ok "T1.d 미마커 → rc=1 + 조치 2종 안내 (AC-2)"
else
  nope "T1.d" "rc=$rc · 출력: $out"
fi

# ── T1.e 숨김 디렉터리도 스캔한다 (FR-6) ──
_rmfile "$sb" docs/bare.md
_addfile "$sb" .githooks/pre-push "echo '99 $WORD'"
[ "$(_rc "$sb")" = 1 ] \
  && ok "T1.e 숨김 디렉터리(.githooks/) 도 스캔 (FR-6)" \
  || nope "T1.e" "숨김 디렉터리를 놓쳤다"

# ── T1.f allowlist 경로 3종은 통과 (AC-3 sandbox 판) ──
_rmfile "$sb" .githooks/pre-push
_addfile "$sb" CHANGELOG.md "v1: 99 $WORD"
_addfile "$sb" docs/audit/2026-01-01-x.md "당시 88 $WORD"
_addfile "$sb" docs/2026-02-02-y.md "당시 77 $WORD"
[ "$(_rc "$sb")" = 0 ] \
  && ok "T1.f allowlist 경로 3종 통과 — 오탐 0 (AC-3)" \
  || nope "T1.f" "allowlist 오탐 — $(_run "$sb")"

# ── T1.g historical 마커도 통과 ──
_addfile "$sb" docs/old.md "당시 66 $WORD <!-- doc-lock: historical -->"
[ "$(_rc "$sb")" = 0 ] \
  && ok "T1.g doc-lock: historical 마커 통과" \
  || nope "T1.g" "historical 마커를 인정하지 않는다"

# ── T1.h 반공허 가드: 스캔 파일·줄 수가 출력된다 (AC-3) ──
out=$(_run "$sb")
if printf '%s' "$out" | grep -qE "스캔 [1-9][0-9]*파일" \
   && printf '%s' "$out" | grep -qE "/[1-9][0-9]*줄"; then
  ok "T1.h 스캔 파일·줄 수 ≥ 1 출력 — 반공허 가드 (AC-3)"
else
  nope "T1.h" "도달 증거 미출력 — $out"
fi

# ── T1.i 지표는 suite-count·historical 뿐 (AC-6①) ──
if [ ! -f "$CHK" ]; then
  nope "T1.i" "검사 본체가 없다 — 지표 목록을 판정할 수 없다"
elif grep -q 'harness-suite-count' "$CHK"; then
  nope "T1.i" "기각된 harness-suite-count 가 구현에 남아 있다"
else
  ok "T1.i 지표 1종(suite-count) + historical — harness 지표 미지원 (AC-6①)"
fi

# ── T1.j 대상 트리가 git 아니면 rc=2 ──
nd=$(mktemp -d "${TMPDIR:-/tmp}/docnum-nogit.XXXXXX")
[ "$(_rc "$nd")" = 2 ] \
  && ok "T1.j 비-git 트리 → rc=2 (판정 불가를 통과로 위장하지 않는다)" \
  || nope "T1.j" "비-git 트리에서 rc=2 가 아니다"
rm -rf "$nd" "$sb"

finish
