#!/usr/bin/env bash
# specops-auto-ko · 템플릿 rehydrate 오염 회귀 테스트 (FID 20260709-tpl-session-progress-design)
# 불변식: templates/session-progress.md 에 FID 패턴(^## [0-9]{8}-) 섹션 0개
#         → session-start.sh 1블록 추출이 빈 출력. 실 FID 섹션은 가이드 헤딩 전까지만 추출.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
TPL="$PLUGIN/templates/session-progress.md"

# 아래 awk 는 hooks/session-start.sh 의 "2) session-progress.md 상위 1 블록" 추출 로직 복제본.
# 원본 변경 시 본 복제도 동기화할 것 (clarify Q1 — 코드 무변경 제약으로 함수 분리 대신 복제 채택).
# v2 (clarify Q2): FID 패턴(^## [0-9]{8}-) 시작 + 임의 ^## 종결 — 가이드 헤딩 경계 인식.
AWK_EXTRACT='
  /^## [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-/ {
    if (in_block) { exit }
    in_block = 1
    current = $0
    next
  }
  in_block && /^## / { exit }
  in_block { current = current "\n" $0 }
  END { if (in_block && current != "") print current }
'

# ── T1: rehydrate 추출 무해화 — 템플릿 원본 (AC-1, AC-6①) ─────
T1_out=$(awk "$AWK_EXTRACT" "$TPL")
[ -z "$T1_out" ] && ok "T1 awk 추출 = 빈 출력 (템플릿 원본)" || fail "T1 awk 추출 = 빈 출력 (추출됨: ${T1_out%%$'\n'*})"

# ── T2: FID 패턴 섹션 0개 (AC-2③, AC-6, FR-1 v2) ─────────────
T2_n=$(grep -c "^## [0-9]\{8\}-" "$TPL" || true)
[ "${T2_n:-0}" -eq 0 ] && ok "T2 '^## <FID>' 섹션 0개" || fail "T2 '^## <FID>' 섹션 0개 (발견: ${T2_n:-읽기실패})"

# ── T2b: 가이드 헤딩 원 레벨 보존 (AC-6b, FR-6) ───────────────
grep -q "^## 활용 방법" "$TPL" && grep -q "^## 참조" "$TPL" \
  && ok "T2b 가이드 헤딩 '## 활용 방법'·'## 참조' 보존" || fail "T2b 가이드 헤딩 '## 활용 방법'·'## 참조' 보존"

# ── T3: 안내문 존재 (AC-2②, FR-2) ────────────────────────────
grep -q "아직 기록 없음" "$TPL" && ok "T3 안내문 존재" || fail "T3 안내문 존재"

# ── T4: 주석 예시 보존 — BLOCK 케이스 포함 (AC-2①) ──────────
grep -q "BLOCK" "$TPL" && grep -q "<!--" "$TPL" \
  && ok "T4 주석 예시 (BLOCK 케이스) 보존" || fail "T4 주석 예시 (BLOCK 케이스) 보존"

# ── T5: layer 주석 정정 (AC-3, FR-3) ─────────────────────────
grep -q "layer: Project-Document" "$PLUGIN/templates/DESIGN.md" \
  && ! grep -q "layer: Template" "$PLUGIN/templates/DESIGN.md" \
  && ok "T5.a DESIGN.md layer=Project-Document" || fail "T5.a DESIGN.md layer=Project-Document"
grep -q "layer: Project-Document" "$PLUGIN/templates/screen.md" \
  && ! grep -q "layer: Template" "$PLUGIN/templates/screen.md" \
  && ok "T5.b screen.md layer=Project-Document" || fail "T5.b screen.md layer=Project-Document"

# ── T6: 실 FID fixture 경계 검증 (AC-6②) ─────────────────────
# 실 FID 섹션 1개 + 가이드(## 활용 방법) 가 있는 fixture → 추출 결과에 FID 줄 포함·가이드 미포함.
T6_fix=$(mktemp) || exit 1
cat > "$T6_fix" <<'EOF'
# Session Progress

---

## 20260420-rss-cache · RSS 캐시
- 2026-04-20 12:00 /analyze BLOCK (analysis.md — AC-3 미매핑)
- 2026-04-20 10:00 /specify 완료 (spec.md)

---

## 활용 방법

### 새 세션 시작 시
1. 이 파일 최상단 읽기
EOF
T6_out=$(awk "$AWK_EXTRACT" "$T6_fix")
rm -f "$T6_fix"
if echo "$T6_out" | grep -q "20260420-rss-cache" && ! echo "$T6_out" | grep -q "활용 방법"; then
  ok "T6 실 FID 섹션만 추출 (가이드 경계 인식)"
else
  fail "T6 실 FID 섹션만 추출 (가이드 경계 인식) — out=${T6_out//$'\n'/ · }"
fi

# ── T7: 실 파이프라인 첫 append 오염 (신규 프로젝트 시나리오) ──
# 합성 fixture 아닌 실제 흐름: 템플릿 cp → append.sh 첫 FID prepend → 추출.
# append.sh 는 첫 ^---$ 직후에 신규 섹션을 꽂으므로, 그 아래 놓인 안내문·주석
# 예시가 섹션 본문으로 딸려 들어가면 오염 (T1~T6 이 못 잡던 갭).
T7_dir=$(mktemp -d) || exit 1
(
  cd "$T7_dir" && mkdir -p .specops \
    && cp "$TPL" .specops/session-progress.md \
    && bash "$PLUGIN/scripts/session-progress-append.sh" \
         20260420-t7-fixture /specify 완료 "spec.md" >/dev/null 2>&1
)
T7_out=$(awk "$AWK_EXTRACT" "$T7_dir/.specops/session-progress.md")
rm -rf "$T7_dir"
if echo "$T7_out" | grep -q "20260420-t7-fixture" \
   && ! echo "$T7_out" | grep -q "아직 기록 없음" \
   && ! echo "$T7_out" | grep -q "작성 예시" \
   && ! echo "$T7_out" | grep -q "20260420-rss-cache"; then
  ok "T7 첫 append 후 추출 = FID 섹션만 (안내문·예시 미오염)"
else
  fail "T7 첫 append 후 추출 = FID 섹션만 — out=${T7_out//$'\n'/ · }"
fi

# ── 결과 ──────────────────────────────────────────────────────
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
