#!/usr/bin/env bash
# scripts/gbrain-recall.sh 검증 — GBRAIN_FILE 격리 fixture
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
SCRIPT="$PLUGIN/scripts/gbrain-recall.sh"
TD=$(mktemp -d); trap 'rm -rf "$TD"' EXIT
export GBRAIN_FILE="$TD/learnings.jsonl"

cat > "$GBRAIN_FILE" <<'EOF'
{"ts":"t1","fid":"f1","insight":"drift guard 자동화 release footer 동기화","tags":["release","drift-guard"]}
{"ts":"t2","fid":"f2","insight":"stdin 격리 sandbox 필수 headless 실행","tags":["llm-eval","sandbox"]}
{"ts":"t3","fid":"f3","insight":"공통 키워드 alpha 교훈 첫번째","tags":["alpha"]}
broken json line
{"ts":"t5","fid":"f5","insight":"공통 키워드 alpha 교훈 두번째","tags":["alpha"]}
EOF

# T2.a 관련 질의 → 매칭 출력 (release 토큰 → f1) + jsonl 원형 보존 (AC-10: fid/insight jq 추출 가능)
out=$(bash "$SCRIPT" "release footer 자동화"); rc=$?
top_fid=$(printf '%s\n' "$out" | head -1 | jq -r '.fid' 2>/dev/null)
if [ $rc -eq 0 ] && [ "$top_fid" = "f1" ]; then
  PASS=$((PASS+1)); echo "PASS T2.a 토큰 중첩 매칭 + jsonl 원형"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.a (rc=$rc top=$top_fid out=$out)"
fi

# T2.b 무관 질의 → 출력 0 + exit 0
out=$(bash "$SCRIPT" "kubernetes ingress"); rc=$?
if [ $rc -eq 0 ] && [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T2.b 무관 질의 → 빈 출력"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.b (rc=$rc out=$out)"
fi

# T2.c 깨진 jsonl 라인 skip — 전체 실패 없음 (FR-6)
out=$(bash "$SCRIPT" "alpha"); rc=$?
if [ $rc -eq 0 ] && ! echo "$out" | grep -q 'broken'; then
  PASS=$((PASS+1)); echo "PASS T2.c 깨진 라인 skip"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.c (rc=$rc out=$out)"
fi

# T2.d 동점 시 최신 (후순 라인) 우선 — alpha 동점 f3/f5 → f5 가 1순위 (AC-3)
top_fid=$(bash "$SCRIPT" "alpha" | head -1 | jq -r '.fid' 2>/dev/null)
if [ "$top_fid" = "f5" ]; then
  PASS=$((PASS+1)); echo "PASS T2.d 동점 최신 우선"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.d (top=$top_fid)"
fi

# T2.e --top 1 → 1건만
n=$(bash "$SCRIPT" "alpha" --top 1 | grep -c . || true)
if [ "$n" = "1" ]; then
  PASS=$((PASS+1)); echo "PASS T2.e --top 상한"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.e (n=$n)"
fi

# T2.f GBRAIN_FILE 부재 → 출력 0 + exit 0 (AC-4 env 격리 + graceful)
out=$(GBRAIN_FILE="$TD/nope.jsonl" bash "$SCRIPT" "release"); rc=$?
if [ $rc -eq 0 ] && [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T2.f 파일 부재 graceful"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.f (rc=$rc out=$out)"
fi

# T2.g NFR-1 — 합성 1000건 fixture: rc=0 + 실행 < 2s
BIG="$TD/big.jsonl"
awk 'BEGIN { for (i = 1; i <= 1000; i++) printf "{\"ts\":\"t%d\",\"fid\":\"bf%d\",\"insight\":\"성능 검증 perf bulk 항목 %d\",\"tags\":[\"perf\"]}\n", i, i, i }' > "$BIG"
now_ms() { perl -MTime::HiRes=time -e 'printf("%d", time()*1000)'; }
t0=$(now_ms)
out=$(GBRAIN_FILE="$BIG" bash "$SCRIPT" "perf 검증"); rc=$?
t1=$(now_ms)
elapsed=$((t1 - t0))
if [ $rc -eq 0 ] && [ "$elapsed" -lt 2000 ]; then
  PASS=$((PASS+1)); echo "PASS T2.g 1000건 rc=0 + ${elapsed}ms < 2000ms"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.g (rc=$rc elapsed=${elapsed}ms)"
fi

# T2.h 비객체 유효 JSON (스칼라) 라인 → 빈 줄 처리, 라인번호 오프셋 보존 — 후속 fid 정합
MIX="$TD/mixed.jsonl"
cat > "$MIX" <<'EOF'
123
"plain scalar text"
{"ts":"m3","fid":"m3","insight":"오프셋 검증 offsetcheck 토큰","tags":["offset"]}
EOF
out=$(GBRAIN_FILE="$MIX" bash "$SCRIPT" "offsetcheck" 2>/dev/null); rc=$?
top_fid=$(printf '%s\n' "$out" | head -1 | jq -r '.fid' 2>/dev/null)
if [ $rc -eq 0 ] && [ "$top_fid" = "m3" ]; then
  PASS=$((PASS+1)); echo "PASS T2.h 스칼라 JSON 라인 오프셋 보존"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.h (rc=$rc top=$top_fid out=$out)"
fi

# T2.i --top 비숫자 → exit 1 + 빈 stdout (lexical 비교 silent 상한 무시 차단)
out=$(bash "$SCRIPT" "alpha" --top abc 2>/dev/null); rc=$?
if [ $rc -eq 1 ] && [ -z "$out" ]; then
  PASS=$((PASS+1)); echo "PASS T2.i --top 비숫자 거부"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.i (rc=$rc out=$out)"
fi

# T2.j 한글 단독 질의 매칭 (Linux mawk byte semantics CI 포착용)
top_fid=$(bash "$SCRIPT" "동기화" | head -1 | jq -r '.fid' 2>/dev/null)
if [ "$top_fid" = "f1" ]; then
  PASS=$((PASS+1)); echo "PASS T2.j 한글 단독 질의 매칭"
else
  FAIL=$((FAIL+1)); echo "FAIL T2.j (top=$top_fid)"
fi

# === confidence tiebreak (AC-3/R-2) ===
# 역순 배치(high=line1, low=line2) — NR-desc 만으로는 low(line2)가 위로 와야 하므로
# cw 키(-k2)를 회귀로 제거하면 FAIL 하는 변별적 가드. cw tiebreak 작동 시에만 high 우선.
gd=$(mktemp -d) || exit 1; gf="$gd/learnings.jsonl"
printf '%s\n' '{"ts":"t","fid":"f","insight":"공통토큰 인사이트 높음","tags":["x"],"confidence":"high"}' >> "$gf"
printf '%s\n' '{"ts":"t","fid":"f","insight":"공통토큰 인사이트 낮음","tags":["x"],"confidence":"low"}' >> "$gf"
out=$(GBRAIN_FILE="$gf" bash "$PLUGIN/scripts/gbrain-recall.sh" "공통토큰 인사이트" --top 2 2>/dev/null)
first=$(printf '%s' "$out" | head -1 | jq -r '.confidence')
[ "$first" = "high" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL: AC-3 tiebreak high 우선 아님 ($first)"; }
printf '%s\n' '{"ts":"t","fid":"f","insight":"공통토큰 노conf","tags":["x"]}' >> "$gf"
GBRAIN_FILE="$gf" bash "$PLUGIN/scripts/gbrain-recall.sh" "공통토큰" --top 3 >/dev/null 2>&1 && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL: AC-R-2 graceful"; }
rm -rf "$(dirname "$gf")"

# === 탭 포함 insight 스코어 무회귀 (AC-R-2 — Phase C Important #1) ===
# insight 에 리터럴 탭 → 탭 이후 토큰도 스코어링돼야 함 (jq $txt 탭 평탄화).
# 회귀(gsub 제거) 시 -F'\t' 가 탭 이후를 $3+ 로 밀어 미매칭 → FAIL 하는 변별적 가드.
gd=$(mktemp -d) || exit 1; gf="$gd/learnings.jsonl"
printf '%s\n' '{"ts":"t","fid":"f","insight":"alpha\tbetagamma keyword","tags":["x"]}' >> "$gf"
out=$(GBRAIN_FILE="$gf" bash "$PLUGIN/scripts/gbrain-recall.sh" "betagamma" --top 1 2>/dev/null)
[ -n "$out" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL: AC-R-2 탭 이후 토큰 스코어 누락(회귀)"; }
rm -rf "$(dirname "$gf")"

echo "--- SUMMARY ---"
echo "PASS=$PASS FAIL=$FAIL"
exit $FAIL
