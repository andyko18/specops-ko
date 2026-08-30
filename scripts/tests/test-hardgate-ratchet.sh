#!/usr/bin/env bash
# test-hardgate-ratchet.sh — hardgate_classified 래칫 계약 (20260830-metalayer-teeth)
# 왜: 메타 규칙이 꺾쇠 마커 보유 파일만 검사해 산문 HARD GATE 선언이 규칙 밖이었다.
#   회피법이 "마커를 안 쓰는 것" 이라 §auto 자기발급 면제표와 같은 형태였다.
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
PASS=0; FAIL=0
BL="$PLUGIN/scripts/_internal/.hardgate-baseline"
VS="$PLUGIN/scripts/_internal/validate-structure.sh"

# ── H1 (AC-4 a): baseline 실재 + 현재 트리에서 OK ──
if [ -f "$BL" ]; then
  ok "H1.a .hardgate-baseline 실재"
else
  nope "H1.a" "baseline 부재 — 실 repo 에서 사라지면 래칫이 무음이 된다"
fi
out=$(cd "$PLUGIN" && bash "$VS" 2>&1)
if printf '%s' "$out" | grep -q '✅ hardgate_classified'; then
  ok "H1.b 현재 트리에서 hardgate_classified OK (AC-4 a)"
else
  nope "H1.b" "$(printf '%s' "$out" | grep hardgate)"
fi

# ── H2 (AC-5): baseline 부재 → SKIP (FAIL 아님) — revert 안전 ──
# ★ 중단 안전: baseline 이 옮겨진 채 중단되면 이후 래칫이 무음 SKIP 이 된다. EXIT 단독.
mv "$BL" "$BL.h2bak"
# shellcheck disable=SC2064
trap "[ -f '$BL.h2bak' ] && mv '$BL.h2bak' '$BL'" EXIT
out2=$(cd "$PLUGIN" && bash "$VS" 2>&1)
mv "$BL.h2bak" "$BL"
trap - EXIT
if printf '%s' "$out2" | grep -qE 'hardgate_classified.*(SKIP|baseline 부재)'; then
  ok "H2.a baseline 부재 → SKIP (AC-5)"
else
  nope "H2.a" "$(printf '%s' "$out2" | grep hardgate)"
fi

# ── H3 (AC-6 b): 비율 노출 ──
if printf '%s' "$out" | grep -qE 'hardgate_classified.*마커 [0-9]+/[0-9]+'; then
  ok "H3.a 마커 보유 비율 노출 (AC-6 b)"
else
  nope "H3.a" "비율 미노출 — 감소 판단을 데이터로 못 한다"
fi
if printf '%s' "$out" | grep -qE 'hardgate_classified.*규칙밖 [0-9]+'; then
  ok "H3.b 규칙 밖 수 노출 (AC-6 b)"
else
  nope "H3.b" "규칙 밖 수 미노출"
fi

# ── H4 (AC-4 b): baseline 밖 신규 산문 HARD GATE → FAIL ──
# 래칫이 실제로 무는지 확인한다. 임시 skill 을 만들고 반드시 제거한다.
h4_dir="$PLUGIN/skills/__ratchet_probe__"
# ★ 중단 안전: probe 가 잔류하면 이후 **모든** validate-structure 가 4건 FAIL 한다
#   (file_counts·skill_conventions·readme_counts·skill_size — 리뷰어 실측). EXIT 단독.
# shellcheck disable=SC2064
trap "rm -rf '$h4_dir'" EXIT
mkdir -p "$h4_dir"
printf -- '---\nname: __ratchet_probe__\n---\n\n산문에서 HARD GATE 를 선언한다.\n' > "$h4_dir/SKILL.md"
out4=$(cd "$PLUGIN" && bash "$VS" 2>&1)
rm -rf "$h4_dir"
trap - EXIT
if printf '%s' "$out4" | grep -qE 'hardgate_classified.*__ratchet_probe__'; then
  ok "H4.a baseline 밖 신규 산문 HARD GATE → FAIL + 이름 표시 (AC-4 b)"
else
  nope "H4.a" "$(printf '%s' "$out4" | grep hardgate)"
fi

# ── H5 (AC-6 a): 기존 마커 검사 무손상 ──
# ★ 한 문구만 지우는 변이는 **vacuous** 다 — hardgate_classified 는 파일 **전체**에서
#   분류 토큰을 찾으므로(validate-structure.sh:422), specifying-ko:19 의 `대화 게이트` 를
#   지워도 :219 의 `판정 SoT` 가 규칙을 만족시켜 변이가 통과한다(20260807 실측 —
#   test-validate-structure T-hg.b 가 같은 함정을 주석으로 기록). **세 토큰을 모두** 치환한다.
h5_f="$PLUGIN/skills/specifying-ko/SKILL.md"
h5_bak=$(mktemp)
cp "$h5_f" "$h5_bak"
# ★ 중단 안전 (20260809-mutation-test-trap): 이 블록은 **실 파일**을 변이한다. 중단되면
#   손상이 워킹트리에 남고 다음 run-all 이 원인 불명 FAIL 을 낸다 — 2026-08-09 실제 발생
#   (git push 타임아웃이 pre-push 의 run-all 을 죽였고 SKILL.md 규약 문구가 깨졌다).
#   ★ EXIT **단독**이다. INT/TERM 을 함께 잡으면 셸 기본 종료가 사라져 핸들러가
#     포그라운드 명령 종료까지 지연되고 그 사이 손상이 남는다(T-hg.d 대조 실측).
# shellcheck disable=SC2064
trap "cp '$h5_bak' '$h5_f'; rm -f '$h5_bak'" EXIT
python3 - "$h5_f" <<'PYEOF2'
import sys
p=sys.argv[1]; s=open(p,encoding="utf-8").read()
for tok in ("판정 SoT", "기계화 불가", "대화 게이트"):
    s = s.replace(tok, "설명")
open(p,"w",encoding="utf-8").write(s)
PYEOF2
out5=$(cd "$PLUGIN" && bash "$VS" 2>&1)
cp "$h5_bak" "$h5_f"; rm -f "$h5_bak"
trap - EXIT
if printf '%s' "$out5" | grep -qE 'hardgate_classified.*specifying-ko\(미분류\)'; then
  ok "H5.a 기존 마커 검사 무손상 — 3토큰 제거 시 여전히 FAIL (AC-6 a)"
else
  nope "H5.a" "$(printf '%s' "$out5" | grep hardgate)"
fi

# ── H6 (T3 Phase C Minor): 접두 이름 계약 — checker grep 의 **닫는 따옴표** 잠금 ──
# 계약: `grep -qF "\"skill\":\"$sn\""` 의 닫는 따옴표가 baseline 이름과의 **접두 오매치**를
#   막는다. 방향이 하나뿐이라는 것이 실측의 핵심이다:
#     · H6.b `planning-k`(**신규 ⊂ baseline**) — 닫는 따옴표를 빼면 패턴 `"skill":"planning-k` 가
#       `{"skill":"planning-ko"}` 에 매치돼 신규 산문 HARD GATE 가 **조용히 등재된 척** 숨는다.
#       닫는 따옴표가 지키는 방향은 이쪽 **하나뿐**이다(실측: 따옴표 제거 → H6.b 만 FAIL).
#       리뷰 보고의 "닫는 따옴표가 양방향 차단(`planning-ko-v2` 격추 실측)" 은 원인 오귀속이다 —
#       격추는 사실이나 따옴표 덕이 아니다. 그 예시 1건만으로 만든 테스트는 vacuous 했을 것이다.
#     · H6.a `planning-ko-v2`(**baseline ⊂ 신규**) — 닫는 따옴표에는 둔감하지만 vacuous 하지 않다.
#       매칭을 baseline 쪽 접두 의미로 "단순화"하는 변이(예: `case "$sn" in "$bl"*)`)를 잡는
#       유일한 케이스다. 그 변이에서 H4(`__ratchet_probe__`)·H6.b 는 여전히 발화하고 H6.a 만 숨는다.
#       두 방향은 서로 다른 변이를 잠근다 — 어느 쪽도 지우지 마라.
# ★ 중단 안전: probe 잔류 시 이후 모든 validate-structure 가 FAIL 한다. EXIT 단독(H4 와 동일).
h6a_dir="$PLUGIN/skills/planning-ko-v2"   # baseline `planning-ko` 를 접두로 갖는 더 긴 이름
h6b_dir="$PLUGIN/skills/planning-k"       # baseline `planning-ko` 의 접두인 더 짧은 이름
# shellcheck disable=SC2064
trap "rm -rf '$h6a_dir' '$h6b_dir'" EXIT
mkdir -p "$h6a_dir" "$h6b_dir"
printf -- '---\nname: planning-ko-v2\n---\n\ntest-hardgate-ratchet H6 probe (자동 생성·자동 삭제 — 잔류 시 지워도 된다).\n산문에서 HARD GATE 를 선언한다.\n' > "$h6a_dir/SKILL.md"
printf -- '---\nname: planning-k\n---\n\ntest-hardgate-ratchet H6 probe (자동 생성·자동 삭제 — 잔류 시 지워도 된다).\n산문에서 HARD GATE 를 선언한다.\n' > "$h6b_dir/SKILL.md"
out6=$(cd "$PLUGIN" && bash "$VS" 2>&1)
rm -rf "$h6a_dir" "$h6b_dir"
trap - EXIT
hg6=$(printf '%s\n' "$out6" | grep hardgate_classified)
if printf '%s' "$hg6" | grep -qF 'planning-ko-v2(래칫'; then
  ok "H6.a baseline⊂신규(planning-ko-v2) → 래칫 FAIL — baseline 쪽 접두 매칭 변이 잠금"
else
  nope "H6.a" "$hg6"
fi
if printf '%s' "$hg6" | grep -qF 'planning-k(래칫'; then
  ok "H6.b baseline 이름의 **접두**(planning-k) → 래칫 FAIL — 닫는 따옴표 계약"
else
  nope "H6.b" "접두 이름이 baseline 항목에 숨었다(닫는 따옴표 소실 의심): $hg6"
fi

finish
