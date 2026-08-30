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

finish
