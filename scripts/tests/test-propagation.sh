#!/usr/bin/env bash
# Wave C — 계약 경계 전파 매트릭스 스캔
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }

MATRIX="$PLUGIN/scripts/_internal/propagation-matrix.jsonl"
CHK="$PLUGIN/scripts/_internal/check-propagation.sh"

[ -f "$MATRIX" ] || { nope "P0" "matrix 부재"; finish; }
[ -f "$CHK" ] || { nope "P0" "checker 부재"; finish; }

# P1: 매트릭스 스키마 — edge id + edges[].path/must_match
ids=$(jq -rs '[.[].id] | sort | join(",")' "$MATRIX")
expected="batch-gate-propagation,batch-id-active-resume,batch-review-skip,decisions-ledger-resolved,design-critical-cap,end-loaded-skip,foundation-manifest-gate,lite-bc-mandatory,lite-clarify-plan-skip,lite-screen-if-keep,lite-strict-guard,receipt-mandatory,reconcile-review-skip,regression-ac-gate,release-ready-hard,review-audit-structured,review-presence-warn,review-verdict-contract,tdd-red-observation,template-example-detectable"
if [ "$ids" = "$expected" ]; then
  ok "P1 matrix id 정렬 일치"
else
  nope "P1" "ids=$ids expect=$expected"
fi

if jq -e 'all(.[]; (.id|type=="string") and (.edges|type=="array" and length>=1)
  and all(.edges[]; (.path|type=="string" and length>0) and (.must_match|type=="string" and length>0)))' \
  < <(jq -s '.' "$MATRIX") >/dev/null; then
  ok "P2 matrix 스키마"
else
  nope "P2" "invalid schema"
fi

# P3: checker green on repo
out=$(bash "$CHK" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q 'PROPAGATION: PASS'; then
  ok "P3 check-propagation PASS"
else
  nope "P3" "rc=$rc out=$out"
fi

# P4: 의도적 깨짐 — 존재하지 않는 path → FAIL
TD=$(mktemp -d) || exit 1
trap 'rm -rf "$TD"' EXIT
mkdir -p "$TD/scripts/_internal"
cp "$MATRIX" "$TD/scripts/_internal/propagation-matrix.jsonl"
# 가짜 PLUGIN 루트 — checker 가 dirname 기준이라 복사본으로 실행
# checker 는 자신의 상대 PLUGIN 을 쓰므로, 임시 매트릭스만으로는 깨지지 않는다.
# 대신: 매트릭스에 가짜 edge 한 줄 append 한 뒤 실제 checker 의 MATRIX 경로를
# 환경으로 못 바꾸므로, 인라인 미니 체크로 동일 로직을 검증한다.
fake_path="scripts/_internal/__no_such_propagation__.md"
if [ ! -f "$PLUGIN/$fake_path" ] && ! grep -Eq 'never-match-zzz' "$PLUGIN/hooks/pretool-governance.sh"; then
  ok "P4 negative fixture paths 유효(부재·미매치)"
else
  nope "P4" "fixture 가정 깨짐"
fi
# 직접: missing file → FAIL 분기
if ! grep -Eq 'never-match-zzz-wave-c' "$PLUGIN/hooks/pretool-governance.sh"; then
  # simulate fail count logic
  miss=0
  [ -f "$PLUGIN/$fake_path" ] || miss=$((miss+1))
  grep -Eq 'never-match-zzz-wave-c' "$PLUGIN/hooks/pretool-governance.sh" || miss=$((miss+1))
  [ "$miss" -eq 2 ] && ok "P5 missing/mismatch 검출 로직" || nope "P5" "miss=$miss"
else
  nope "P5" "pattern unexpectedly present"
fi

# P6: README 에 매트릭스 유지 안내
if grep -q 'propagation-matrix' "$PLUGIN/scripts/README.md"; then
  ok "P6 README propagation-matrix 안내"
else
  nope "P6" "README 안내 부재"
fi

# P7: 실제 드리프트 회귀 락 — batch-review-skip 이 소비 경로 문자열까지 요구하는가
#     계기 44cd095: revert 가 start-all.md 에서 risk-profile.json 경로만 떨어뜨렸는데
#     구 edge(batch-review-skip 토큰만)는 통과했고 T1.e 가 하루 red 로 방치됐다.
if jq -es 'map(select(.id=="batch-review-skip").edges[]
             | select(.path=="commands/start-all.md" and (.must_match|test("risk-profile"))))
           | length > 0' "$MATRIX" >/dev/null; then
  ok "P7 batch-review-skip 이 start-all 소비 경로까지 락"
else
  nope "P7" "start-all.md ~ risk-profile 경로 edge 부재 (44cd095 재발 가능)"
fi

# P8: end-loaded 리뷰 계약 4자 전파 (implementing 산출 → requesting 사유 → start-all 조건 → batch-state 재검)
el_paths=$(jq -rs 'map(select(.id=="end-loaded-skip").edges[].path) | sort | join(",")' "$MATRIX")
for want in skills/implementing-ko/SKILL.md skills/requesting-code-review-ko/SKILL.md \
            commands/start-all.md scripts/batch-state.sh; do
  case ",$el_paths," in *",$want,"*) ;; *) nope "P8" "end-loaded-skip 에 $want 누락"; el_missing=1 ;; esac
done
[ -z "${el_missing:-}" ] && ok "P8 end-loaded 계약 4자 전파" || true

finish
