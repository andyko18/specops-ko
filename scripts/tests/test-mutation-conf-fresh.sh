#!/usr/bin/env bash
# mutation-equivalent.conf 신선도 계약 (FID 20260829-mutation-coverage)
#
# 왜 필요한가 (실측): conf 는 **절대 줄번호**로 equivalent mutant 를 지정한다. target 이
#   자라면 조용히 어긋나고, 어긋난 항목은 매칭 0건이 되어 **정상 변이가 equivalent 로 제외되지
#   못한 채** score 가 거짓 하락한다(conf 주석 실측: 64% → 50%). 반대로 stale 이 통과로
#   뭉개지면 거짓 상승한다.
#   판정기(`mutation-score.sh --check-conf`)는 **1초**면 끝나는데 `mutation-score.sh` 가
#   run-all 명명 규칙(test-*.sh) 밖이라 아무도 안 돌렸고, 이번 세션의 governance-lib 편집
#   3건으로 **16/18 이 stale** 이 됐다 — 그동안 아무 게이트도 울지 않았다.
#   무거운 mutation 실행은 그대로 수동으로 두고, **1초짜리 정합만** 상시 게이트에 넣는다.
set -u
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
PASS=0; FAIL=0

MS="$PLUGIN/scripts/tests/mutation-score.sh"
TCONF="$PLUGIN/scripts/tests/mutation-targets.conf"
ECONF="$PLUGIN/scripts/tests/mutation-equivalent.conf"

[ -f "$MS" ] && ok "T1.a mutation-score.sh 존재" || nope "T1.a" "$MS 부재"
[ -f "$TCONF" ] && ok "T1.b targets conf 존재" || nope "T1.b" "$TCONF 부재"
[ -f "$ECONF" ] && ok "T1.c equivalent conf 존재" || nope "T1.c" "$ECONF 부재"

# ── T2: equivalent conf 전 항목이 현재 소스에 실재한다 (핵심) ──
out=$(cd "$PLUGIN" && bash "$MS" --check-conf 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  ok "T2.a equivalent conf 신선 ($(printf '%s' "$out" | grep -o '[0-9]*/[0-9]* 매칭' | head -1))"
else
  nope "T2.a conf stale" "$(printf '%s' "$out" | grep STALE | head -3 | tr '\n' ' ') — 줄번호 재정렬 필요"
fi

# ── T3: targets conf 의 대상 스크립트·테스트 명령이 실재한다 ──
# 왜: 대상 경로가 오타·이동이면 mutation 이 **대상 0건으로 조용히 통과**한다(측정 없는 green).
miss=0; n=0
while IFS='|' read -r tgt cmd; do
  case "$tgt" in ''|\#*) continue ;; esac
  n=$((n+1))
  [ -f "$PLUGIN/$tgt" ] || { miss=$((miss+1)); echo "  대상 부재: $tgt"; }
  # 명령에 등장하는 test 스크립트 경로가 전부 실재하는가
  for p in $(printf '%s' "$cmd" | grep -oE '(scripts|hooks)/[A-Za-z0-9._/-]+\.sh'); do
    [ -f "$PLUGIN/$p" ] || { miss=$((miss+1)); echo "  테스트 부재: $p (target=$tgt)"; }
  done
done < "$TCONF"
[ "$miss" -eq 0 ] && ok "T3.a targets conf 경로 전건 실재 (대상 ${n}종)" \
  || nope "T3.a 경로" "부재 ${miss}건 — mutation 이 대상 0건으로 조용히 통과한다"

# ── T4: 게이트 핵심 스크립트가 측정 대상에 들어 있다 ──
# 왜: 측정 대상이 좁으면 "mutation 돌린다" 는 말만 남는다. 차단 판정을 실제로 내리는
#   두 파일(governance-lib·pretool-governance)과 신설 상한 헬퍼는 최소 커버 대상이다.
for must in hooks/governance-lib.sh hooks/pretool-governance.sh scripts/_internal/run-bounded.sh; do
  grep -q "^${must}|" "$TCONF" \
    && ok "T4 측정 대상 포함: $must" \
    || nope "T4 커버리지" "$must 가 mutation-targets.conf 에 없음"
done

echo ""
finish
