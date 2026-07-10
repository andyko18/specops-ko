#!/usr/bin/env bash
# 인터페이스 설계 경로 분업 문서 검증 (FID 20260710-design-interface-slash)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && cd .. && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
DI="$PLUGIN/commands/design-interface.md"
DIS="$PLUGIN/commands/design-interfaces.md"
SP="$PLUGIN/skills/specifying-ko/SKILL.md"

# AC-1: 단수 무스크립트 + 마스터 append
grep -q '^## 인터페이스 설계 3경로 분업' "$DI" && grep -q 'api-spec.md' "$DI" && grep -q 'data-model.md' "$DI" \
  && ! grep -q 'design-interface.sh' "$DI" \
  && ok "AC-1 단수 무스크립트+마스터 append" || nope "AC-1" "무스크립트/마스터 계약 누락"
# AC-2: 복수 오케스트레이터
grep -q '목록 자동 판단' "$DIS" && grep -q '순차' "$DIS" \
  && ok "AC-2 복수 오케스트레이터" || nope "AC-2" "목록/순차 누락"
# AC-3: 화면→API 도출
grep -qiE 'screens/.*Interactions|Interactions.*스캔' "$DI" \
  && ok "AC-3 화면→API 도출" || nope "AC-3" "화면 도출 없음"
# AC-4: 채택 섹션 + 부재 가드
DTBL=$(awk '/^### Step 3/,/^## 안티패턴/' "$DI")
printf '%s' "$DTBL" | grep -q '채택' && printf '%s' "$DTBL" | grep -q '부재' \
  && ok "AC-4 채택섹션+부재가드" || nope "AC-4" "채택/부재 누락"
# AC-5: cross-ref 단일출처(단수) + Step5.6 동기(양쪽)
grep -q '^## 인터페이스 설계 3경로 분업' "$DI" \
  && awk '/^5\.6\./,/^6\. /' "$SP" | grep -qE '/design-interface' \
  && ok "AC-5 cross-ref 단일출처+Step5.6 동기" || nope "AC-5" "한쪽 누락"
# AC-6: false-pass 방지 — 분업표 블록 내부 한정
TBL=$(awk '/^## 인터페이스 설계 3경로 분업/,/^## [^인]/' "$DI")
printf '%s' "$TBL" | grep -qiE 'lifecycle 자동' && printf '%s' "$TBL" | grep -qiE '독립' \
  && ok "AC-6 표내부 한정(false-pass 방지)" || nope "AC-6" "표 내부 기준 없음"
# AC-8: 소비 API 대상
grep -q 'api-spec-consumer' "$DI" && ok "AC-8 소비 API 대상" || nope "AC-8" "consumer 누락"
# AC-9: 복수 이중 근거
grep -qiE 'Interactions' "$DIS" && grep -qiE 'requirements.md FR|FR 표' "$DIS" \
  && ok "AC-9 복수 이중근거" || nope "AC-9" "이중근거 누락"
# AC-9b: 복수→단수 고유 cross-ref (대칭 원본 AC-3 회귀 안전망 — plan-reviewer Minor)
grep -q '§인터페이스 설계 3경로 분업' "$DIS" \
  && ok "AC-9b 복수 고유 cross-ref" || nope "AC-9b" "고유 cross-ref 없음"

# AC-10: Step 5.6 클라이언트 스토리지 축 (localStorage-only 앱 skip 방지) — Step5.6 블록 한정(AC-R-1 선례)
awk '/^5\.6\./,/^6\. /' "$SP" | grep -qE '클라이언트 영속 데이터|localStorage·IndexedDB' \
  && ok "AC-10 Step5.6 클라이언트 스토리지 축" || nope "AC-10" "클라이언트 스토리지 축 없음"
# AC-11: design-interface Step3 클라이언트 스토리지 전용 data-model 분기 (plan-reviewer Minor: teeth 강화)
grep -q '클라이언트 스토리지' "$DI" && grep -qE '클라이언트 스토리지.*data-model|저장 키.*append|objectStore·keyPath' "$DI" \
  && ok "AC-11 design-interface Step3 클라이언트 스토리지 data-model" || nope "AC-11" "클라이언트 스토리지 분기 없음"
# AC-11b: design-interface Step2 저장방식 3택 한 줄 (teeth 강화 — Phase C Important)
grep -qE '제공 API.*외부 소비 API.*클라이언트 스토리지' "$DI" \
  && ok "AC-11b Step2 저장방식 3택" || nope "AC-11b" "3택 한 줄 없음"
# AC-12: 순수 UI·CLI skip 보존 (과확대 방지 — AC-R-2) — Step5.6 블록 한정(AC-R-1 선례)
awk '/^5\.6\./,/^6\. /' "$SP" | grep -qE '순수 UI·CLI 로직만이면.*skip|순수 UI·CLI.*skip' \
  && ok "AC-12 순수 UI·CLI skip 보존" || nope "AC-12" "skip 문구 소실"
# AC-13: templates data-model 유형 확장
grep -qE 'localStorage / IndexedDB|localStorage·IndexedDB' "$PLUGIN/templates/data-model.md" \
  && ok "AC-13 data-model 유형 확장" || nope "AC-13" "localStorage 유형 없음"

# AC-R-1: Step5.6 기존 로직 보존
awk '/^5\.6\./,/^6\. /' "$SP" | grep -q '채택된 정의방식' && ok "AC-R-1 Step5.6 로직 보존" || nope "AC-R-1" "기존 로직 소실"

# AC-14: verify 역방향 안전망 클라이언트 스토리지 커버 (P1-4 audit 20260710)
grep -qE 'localStorage|objectStore' "$PLUGIN/skills/verifying-evidence-ko/SKILL.md" \
  && ok "AC-14 verify net 클라이언트 스토리지" || nope "AC-14" "verify 추출 대상에 localStorage/objectStore 없음"

echo "── test-interface-routing-doc: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
