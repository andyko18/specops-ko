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

finish
