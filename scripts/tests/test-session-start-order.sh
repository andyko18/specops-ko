#!/usr/bin/env bash
# SessionStart additionalContext 조립 순서·오프셋 계약 (FID 20260814-sessionstart-payload-order)
# 계약: 행동 지시 블록(anchor·pending·reconcile)이 harness 프리뷰(2048B) 안에서 시작하고,
#       rehydrate 는 메타 본문 뒤 최후미에 온다 (clarify Q1 / AC-6).
set -u
PLUGIN="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$PLUGIN/hooks/session-start.sh"
LIMIT=1536
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "PASS $1"; }
ng(){ FAIL=$((FAIL+1)); echo "FAIL $1 — $2"; }

# 블록 시작 바이트 오프셋 (없으면 빈 문자열)
offset_of(){ # $1=ctx file  $2=block name
  local ln; ln=$(grep -n "^<$2>" "$1" | head -1 | cut -d: -f1)
  [ -n "$ln" ] || { printf ''; return; }
  if [ "$ln" -eq 1 ]; then printf '0'; else head -n $((ln-1)) "$1" | wc -c | tr -d ' '; fi
}

# 전 블록 발생 샌드박스 구성 후 훅 실행 → ctx 추출
make_ctx(){ # $1=sandbox dir  $2=with_optional(1|0)
  local sb="$1"
  mkdir -p "$sb/.specops"
  if [ "$2" = "1" ]; then
    mkdir -p "$sb/.specops/20260101-probe"
    printf '## 20260101-probe\n- 2026-01-01 00:00 /specify 완료 (spec.md)\n' > "$sb/.specops/session-progress.md"
    printf '{"ts":"x","files":["a.sh"],"prompt":"","type":"fix","fid":""}\n' > "$sb/.specops/pending-capture.jsonl"
    local f
    for f in spec.md acceptance-criteria.md plan.md tasks.md; do echo x > "$sb/.specops/20260101-probe/$f"; done
  fi
  ( cd "$sb" && bash "$HOOK" 2>/dev/null ) > "$sb/out.json"
  jq -r '.hookSpecificOutput.additionalContext' "$sb/out.json" > "$sb/ctx.txt" 2>/dev/null
}

# 오프셋은 **decode 된 additionalContext** 기준으로 잰다. harness 절단이 인코딩 원문
# 기준일 수 있으나, 인코딩 기준 실측(436B)도 상한 대비 여유가 커서 어느 기준이든 계약이 선다.
SB=$(mktemp -d); SB2=""
trap 'rm -rf "$SB" "$SB2"' EXIT
make_ctx "$SB" 1
CTX="$SB/ctx.txt"

o_anchor=$(offset_of "$CTX" specops-ko-anchor)
o_pend=$(offset_of "$CTX" freecomment-pending)
o_recon=$(offset_of "$CTX" session-progress-reconcile)
o_rehy=$(offset_of "$CTX" session-progress-rehydrate)
o_meta=$(offset_of "$CTX" EXTREMELY_IMPORTANT)

# T-ord.a pending 오프셋 상한
if [ -n "$o_pend" ] && [ "$o_pend" -le "$LIMIT" ]; then ok "T-ord.a pending 오프셋 ${o_pend}B <= ${LIMIT}B"
else ng "T-ord.a pending 오프셋 상한" "got='${o_pend:-없음}' limit=$LIMIT"; fi

# T-ord.b reconcile 오프셋 상한
if [ -n "$o_recon" ] && [ "$o_recon" -le "$LIMIT" ]; then ok "T-ord.b reconcile 오프셋 ${o_recon}B <= ${LIMIT}B"
else ng "T-ord.b reconcile 오프셋 상한" "got='${o_recon:-없음}' limit=$LIMIT"; fi

# T-ord.c 상대 순서 anchor < pending < reconcile < meta < rehydrate
if [ -n "$o_anchor" ] && [ -n "$o_pend" ] && [ -n "$o_recon" ] && [ -n "$o_meta" ] && [ -n "$o_rehy" ] \
   && [ "$o_anchor" -lt "$o_pend" ] && [ "$o_pend" -lt "$o_recon" ] \
   && [ "$o_recon" -lt "$o_meta" ] && [ "$o_meta" -lt "$o_rehy" ]; then
  ok "T-ord.c 상대 순서 anchor<pending<reconcile<meta<rehydrate"
else
  ng "T-ord.c 상대 순서" "anchor=$o_anchor pend=$o_pend recon=$o_recon meta=$o_meta rehy=$o_rehy"
fi

# T-ord.d anchor 가 byte 0
if [ "${o_anchor:-x}" = "0" ]; then ok "T-ord.d anchor byte 0"
else ng "T-ord.d anchor byte 0" "got='${o_anchor:-없음}'"; fi

# T-ord.e 조건부 블록 0개 경로 — anchor+meta 만, JSON 유효
SB2=$(mktemp -d); make_ctx "$SB2" 0
c2="$SB2/ctx.txt"
a2=$(offset_of "$c2" specops-ko-anchor); m2=$(offset_of "$c2" EXTREMELY_IMPORTANT)
p2=$(offset_of "$c2" freecomment-pending)
# 조건부 3종 전부 부재여야 한다 — pending 만 보면 reconcile·rehydrate 누출을 놓친다.
r2=$(offset_of "$c2" session-progress-reconcile); h2=$(offset_of "$c2" session-progress-rehydrate)
if jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' "$SB2/out.json" >/dev/null 2>&1 \
   && [ "${a2:-x}" = "0" ] && [ -n "$m2" ] && [ -z "$p2" ] && [ -z "$r2" ] && [ -z "$h2" ]; then
  ok "T-ord.e 조건부 0개 경로 — anchor+meta 만 출력, JSON 유효"
else
  ng "T-ord.e 조건부 0개 경로" "anchor=$a2 meta=$m2 pending=${p2:-없음} recon=${r2:-없음} rehy=${h2:-없음}"
fi


# --- 인라인 예산 계약 (FID 20260911-meta-skill-progressive-disclosure) ----------
# Claude Code 는 훅 출력 1건이 **문자 10,000** 을 넘으면 파일로 빼고 선두 2KB 프리뷰만 인라인한다
# (바이트 아님 — 실측 9,990자 인라인·10,010자 파일행·한글 5,000자 인라인). 넘으면 메타 skill 대부분이
# 모델에 닿지 않는다(실측: specops 주입 235건 전부 파일행). 여기서는 jq 로 **디코드한 뒤 문자**를 센다 —
# 훅 내부 계산기와 다른 경로로 재야 계산기 결함이 같이 숨지 않는다.
chars_of(){ LC_ALL=C tr -d '\200-\277' < "$1" | wc -c | tr -d ' '; }   # UTF-8 연속 바이트 제외 = 문자 수
ctx_j(){ # $1=sandbox — 이미 구성된 샌드박스에서 훅 재실행 → $1/ctxj.txt (jq -j: 끝 개행 없음)
  ( cd "$1" && bash "$HOOK" 2>/dev/null ) > "$1/outj.json"
  jq -j '.hookSpecificOutput.additionalContext' "$1/outj.json" > "$1/ctxj.txt" 2>/dev/null
}

# T-bud.a 조건부 블록 0개 경로는 8,000자 이하 + 메타 SKILL.md 본문 전 행 포함 (AC-1)
#   8,000 은 래칫이다 — 조건부 블록·rehydrate 몫(~1,500자)을 남겨 둔다. 메타가 다시 커지면 여기서 멈춘다.
ctx_j "$SB2"
n_a=$(chars_of "$SB2/ctxj.txt"); miss_a=0
while IFS= read -r l; do
  [ -z "$l" ] && continue
  grep -qF -- "$l" "$SB2/ctxj.txt" || miss_a=$((miss_a+1))
done < "$PLUGIN/skills/using-specops-ko/SKILL.md"
if [ "${n_a:-99999}" -le 8000 ] && [ "$miss_a" -eq 0 ]; then ok "T-bud.a 조건부 0개 ${n_a}자 <= 8000 · 메타 본문 전 행 포함"
else ng "T-bud.a 조건부 0개 총량/메타 전량" "chars=${n_a:-없음} limit=8000 누락행=$miss_a"; fi

# T-pend.a pending 블록이 실재하는 절차 파일 절대경로를 가리킨다 (AC-4 ①)
#   절차 본문은 메타 skill 밖(freework-pending.md)이라, 블록의 경로가 틀리면 자유작업 기록 경로가 끊긴다.
fw_path=$(sed -n 's/^절차: \(.*\) 를 Read 해 따른다\..*/\1/p' "$CTX" | head -1)
case "$fw_path" in
  /*/skills/using-specops-ko/freework-pending.md)
    if [ -f "$fw_path" ]; then ok "T-pend.a pending 블록 → 절차 파일 절대경로 실재"
    else ng "T-pend.a pending 절차 경로" "파일 부재: $fw_path"; fi ;;
  *) ng "T-pend.a pending 절차 경로" "절대경로 아님/미발견: '${fw_path}'" ;;
esac

# T-pend.b pending 블록이 플러그인 루트 절대경로와 치환 지시를 준다 (AC-7)
#   Read 로 읽는 파일은 ${CLAUDE_PLUGIN_ROOT} 가 치환되지 않고, Bash 도구 환경에도 이 변수가 없다(실측 unset).
root_path=$(sed -n 's/.*CLAUDE_PLUGIN_ROOT} 는 \(.*\) 로 바꿔 실행한다\..*/\1/p' "$CTX" | head -1)
case "$root_path" in
  /*) if [ -f "$root_path/scripts/freework-resolve-fid.sh" ]; then ok "T-pend.b pending 블록 → 플러그인 루트 치환 지시 + scripts 실재"
      else ng "T-pend.b 플러그인 루트" "scripts/freework-resolve-fid.sh 부재: $root_path"; fi ;;
  *) ng "T-pend.b 플러그인 루트" "치환 지시/절대경로 미발견: '${root_path}'" ;;
esac

# --- 문서 계약 (AC-5) ---------------------------------------------------------
# 조립 순서는 코드에만 있으면 다음 편집자가 모른다. 순서를 서술하는 문서 3곳이
# 계약을 담고 있는지 함께 잠근다 — 실측 결함의 구조적 원인이 "각 PR 이 자기 블록만
# 보고 누적 순서를 아무도 안 봤다" 였으므로, 순서 계약은 문서에도 남아야 한다.
doc_has(){ # $1=파일  $2=grep 패턴  $3=TEST ID  $4=설명
  if [ -f "$PLUGIN/$1" ] && grep -q "$2" "$PLUGIN/$1"; then ok "$3 $4"
  else ng "$3 $4" "$1 에 '$2' 없음"; fi
}
doc_has CLAUDE.md 'specops-ko-anchor' "T-ord.f" "CLAUDE.md 조립 순서 계약 기재"
doc_has README.md '조립 순서' "T-ord.g" "README.md 조립 순서 요약 기재"
doc_has skills/context-resets-ko/SKILL.md '최후미' "T-ord.h" "context-resets-ko rehydrate 최후미 서술"

echo "==== Results: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" -eq 0 ]
