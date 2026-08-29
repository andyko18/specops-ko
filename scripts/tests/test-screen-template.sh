#!/usr/bin/env bash
# test-screen-template.sh — screen.md 템플릿 8+4 섹션 + 소비처 문구 동기화 검증
# AC-7(필수 8) · AC-8(조건부 4 규약) · AC-9(데이터 소스 Step 5.6 연계) · AC-10(소비처 양방향)
set -u

PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
T="$PLUGIN/templates/screen.md"
PASS=0; FAIL=0

# T1: 필수 코어 8섹션 헤더 (AC-7)
for s in "목적" "Layout" "Components" "States" "Interactions" "필드 정의표" "데이터 소스" "에러 메시지"; do
  grep -qE "^## ${s}\$" "$T" \
    && ok  "T1 필수 섹션 '## ${s}' 존재" \
    || nope "T1 필수 섹션 '## ${s}'" "헤더 없음"
done

# T2: 조건부 4섹션 + 적용 조건 + 미해당 시 제거 규약 (AC-8)
for s in "RBAC 권한별 표시" "반응형 브레이크포인트" "접근성" "진입/이탈 경로"; do
  grep -qF "$s" "$T" \
    && ok  "T2 조건부 섹션 '${s}' 기재" \
    || nope "T2 조건부 '${s}'" "미기재"
done

grep -qF '적용 조건' "$T" \
  && ok  "T2.e 조건부 섹션 적용 조건 명시" \
  || nope "T2.e 적용 조건" "'적용 조건' 앵커 없음"

grep -qF '섹션 자체를 넣지 않는다' "$T" \
  && ok  "T2.f 미해당 시 섹션 자체 제거 규약 (— 채우기 금지)" \
  || nope "T2.f 제거 규약" "앵커 없음"

# T3: 데이터 소스 Step 5.6 연계 (AC-9)
grep -qF '.specops/memory/api-spec.md' "$T" \
  && ok  "T3.a 데이터 소스에 api-spec.md 참조" \
  || nope "T3.a api-spec 참조" "앵커 없음"

grep -qF '.specops/memory/data-model.md' "$T" \
  && ok  "T3.b 데이터 소스에 data-model.md 참조" \
  || nope "T3.b data-model 참조" "앵커 없음"

# T4: 소비처 문구 동기화 — 양방향 단언 (AC-10)
for f in design-screen.md design-screens.md; do
  p="$PLUGIN/commands/$f"
  [ "$(grep -cF '목적, Layout, Components, States, Interactions 섹션 완성' "$p")" -eq 0 ] \
    && ok  "T4.$f 구 '5섹션 완성' 문구 부재" \
    || nope "T4.$f 구 문구 부재" "5섹션 표현 잔존 — drift"

  grep -qF '필수 8섹션' "$p" \
    && ok  "T4.$f 신 '필수 8섹션' 문구 존재" \
    || nope "T4.$f 신 문구" "'필수 8섹션' 앵커 없음"

  grep -qF '마커 줄을 삭제' "$p" \
    && ok  "T4.$f 마커 제거 지시 존재 (AC-12 ③)" \
    || nope "T4.$f 마커 제거" "앵커 없음"
done

# T5: 마커 보존 — 태스크 1 의 마커가 확장 후에도 남아 있어야 함
grep -qF 'specops:screen-placeholder' "$T" \
  && ok  "T5.a 템플릿 확장 후에도 껍데기 마커 보존" \
  || nope "T5.a 마커 보존" "확장 중 마커 소실 — 판정 무력화"


# T6: screen.html 씨앗 토큰 — 타입/간격 스케일 + §2·§3 대응 주석 (AC-5)
#   ★ grep -o + sort -u 로 **토큰 종류**를 센다: 한 줄에 여러 토큰이 있어 grep -c(행수)는 과소계수.
#   ★ `--` 필수: 패턴이 `-` 로 시작해 없으면 grep 이 옵션으로 오파싱 → 영구 FAIL.
H="$PLUGIN/templates/screen.html"
_ts=$(grep -o -- '--text-[a-z0-9]*:' "$H" 2>/dev/null | sort -u | wc -l | tr -d ' ')
{ [ "${_ts:-0}" -ge 5 ] && grep -qF 'DESIGN.md §2 Typography' "$H"; } \
  && ok  "T6.a screen.html 타입 토큰 ${_ts}종(≥5) + §2 대응 주석" \
  || nope "T6.a 타입 토큰" "--text-* ${_ts}종 (기대 ≥5) 또는 '§2 Typography' 대응 주석 부재"

_sp=$(grep -o -- '--space-[a-z0-9]*:' "$H" 2>/dev/null | sort -u | wc -l | tr -d ' ')
{ [ "${_sp:-0}" -ge 4 ] && grep -qF 'DESIGN.md §3 Spacing' "$H"; } \
  && ok  "T6.b screen.html 간격 토큰 ${_sp}종(≥4) + §3 대응 주석" \
  || nope "T6.b 간격 토큰" "--space-* ${_sp}종 (기대 ≥4) 또는 '§3 Spacing' 대응 주석 부재"

finish
