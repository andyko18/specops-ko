#!/usr/bin/env bash
# foundation manifest 산출 게이트 기계화 (20260806 /start-foundation 정밀분석)
#
# 배경: verifying-evidence-ko 는 이 게이트를 **HARD** 로 선언하고, 그 근거로
#   "생산은 planning-ko 산문 지시뿐(강제 evaluator 부재)이라 verify 가 실제 산출물을
#    확인하지 않으면 후속 /start 재사용 게이트가 침묵 무발동(no-op) 한다" 고 적어 뒀다.
#   그런데 run-verification.sh·release-ready.sh·DAG 스크립트 어디에도 구현이 없었다 —
#   **침묵 무발동을 막으려는 게이트 자체가 침묵 무발동**이었다.
# 부가: 구 산문의 채움 판정은 `grep -q '<경로>'` 단일 토큰이라, 경로만 채우고
#   <설명>·<import 예시>·<확정된 프레임워크> 가 전부 남아도 통과했다.
#   채움 판정은 placeholder SoT(scan-enrich-placeholders.sh)로 통일한다.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
CHK="$PLUGIN/scripts/_internal/check-foundation-manifest.sh"

_mk() {  # $1=dir $2=fid $3=§유형
  mkdir -p "$1/.specops/$2" "$1/.specops/memory"
  printf '**§유형**: %s\n' "$3" > "$1/.specops/$2/spec.md"
}
_filled_manifest() {  # $1=경로 — 실제로 채운 manifest
  cat > "$1" <<'EOF'
<!-- OWNER_COMMAND: /start-foundation (planning-ko 산출) -->
<!-- layer: Lifecycle-Artifact -->

# Foundation Manifest — mychat

## 제공 모듈

| 모듈 | 경로 | 역할 (1줄) | 재사용 방법 |
|---|---|---|---|
| 라우팅 | `src/router/index.ts` | 앱 라우트 정의 | `import { router } from '@/router'` |
| 인증 | `src/auth/session.ts` | 세션 검증 | `import { requireAuth } from '@/auth/session'` |

## 기술 스택

- **프론트엔드**: React 19 + Vite
- **백엔드**: Fastify 5
- **DB**: PostgreSQL 17

---

*산출: specops-ko · planning-ko · FID: 20260806-foundation · 경로: `.specops/memory/foundation-manifest.md`*
EOF
}

# T1: §유형=foundation + manifest 부재 → FAIL(1)
TD=$(mktemp -d); _mk "$TD" 20260806-fnd foundation
(cd "$TD" && bash "$CHK" 20260806-fnd >/dev/null 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T1 foundation + manifest 부재 → FAIL" || nope "T1" "rc=$rc"
rm -rf "$TD"

# T2: §유형=foundation + 채워진 manifest → PASS(0)
TD=$(mktemp -d); _mk "$TD" 20260806-fnd foundation
_filled_manifest "$TD/.specops/memory/foundation-manifest.md"
(cd "$TD" && bash "$CHK" 20260806-fnd >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T2 foundation + 채워진 manifest → PASS" || nope "T2" "rc=$rc"
rm -rf "$TD"

# T3: 원본 템플릿 그대로(전 필드 placeholder) → FAIL
TD=$(mktemp -d); _mk "$TD" 20260806-fnd foundation
cp "$PLUGIN/templates/foundation-manifest.md" "$TD/.specops/memory/foundation-manifest.md"
(cd "$TD" && bash "$CHK" 20260806-fnd >/dev/null 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T3 raw 템플릿 → FAIL" || nope "T3" "rc=$rc"
rm -rf "$TD"

# T4: ★ 부분 채움 — 경로만 채우고 나머지 placeholder → FAIL
#     구 산문 판정(`grep -q '<경로>'`)은 여기서 통과했다.
TD=$(mktemp -d); _mk "$TD" 20260806-fnd foundation
cp "$PLUGIN/templates/foundation-manifest.md" "$TD/.specops/memory/foundation-manifest.md"
sed -i.bak 's|`<경로>`|`src/x.ts`|g' "$TD/.specops/memory/foundation-manifest.md"
rm -f "$TD/.specops/memory/foundation-manifest.md.bak"
(cd "$TD" && bash "$CHK" 20260806-fnd >/dev/null 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T4 경로만 채움(<설명>·<import 예시> 잔존) → FAIL" || nope "T4" "rc=$rc"
rm -rf "$TD"

# T5: §유형≠foundation → graceful skip(0), manifest 없어도 무관
TD=$(mktemp -d); _mk "$TD" 20260806-feat 신규
(cd "$TD" && bash "$CHK" 20260806-feat >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T5 비-foundation → skip PASS" || nope "T5" "rc=$rc"
rm -rf "$TD"

# T6: spec.md 부재 → 판정 불가 fail-open(0)
TD=$(mktemp -d); mkdir -p "$TD/.specops/20260806-x"
(cd "$TD" && bash "$CHK" 20260806-x >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T6 spec.md 부재 → fail-open" || nope "T6" "rc=$rc"
rm -rf "$TD"

# T7: HTML 주석 헤더는 미채움 근거가 아니다 (구조 계약 — 스캐너 정합)
TD=$(mktemp -d); _mk "$TD" 20260806-fnd foundation
_filled_manifest "$TD/.specops/memory/foundation-manifest.md"
grep -q '<!-- layer:' "$TD/.specops/memory/foundation-manifest.md" \
  && (cd "$TD" && bash "$CHK" 20260806-fnd >/dev/null 2>&1) \
  && ok "T7 HTML 주석 보유 manifest 도 PASS" || nope "T7" "주석이 FAIL 유발"
rm -rf "$TD"

# T8: run-verification 배선 — 게이트가 VERIFY 관문에 실제로 연결됐는가
grep -q 'check-foundation-manifest.sh' "$PLUGIN/scripts/_internal/run-verification.sh" \
  && ok "T8 run-verification 배선" || nope "T8" "run-verification 미배선 — 산문 게이트 잔존"

# T9: 스킬 본문이 스크립트를 SoT 로 지목 (산문 ↔ 구현 이원화 방지)
grep -q 'check-foundation-manifest.sh' "$PLUGIN/skills/verifying-evidence-ko/SKILL.md" \
  && ok "T9 verifying-evidence-ko 가 스크립트 지목" || nope "T9" "스킬 본문 미갱신"

# ── CLI/라이브러리 foundation — 템플릿 경직성 (20260806 시나리오 검증) ────────
# 템플릿 모듈 5행이 라우팅·인증·레이아웃·공통컴포넌트·DB 로 고정이라 CLI foundation 엔
# 전부 무관하다. 채움 판정을 엄격화한 뒤 실측하니 **모델의 자연스러운 선택**(무관 행을
# 템플릿 그대로 방치)이 FAIL 이 된다 — 체커가 틀린 게 아니라 템플릿이 실패 형태로 유도한다.
# 해법은 판정 완화가 아니라 **"해당 없는 행·항목은 삭제"** 를 템플릿에 명시하는 것.
# 느슨한 grep(`삭제|예시`)은 표 안의 `<import 예시>`·기술스택 주석에 걸려 공허하게 통과한다
# (mutation 으로 실증). 계약의 **세 요소**를 모두 요구한다:
#   ① 행 자체 삭제 허용 ② 판정기 이름(SoT) ③ 미채움 → VERIFY: FAIL 귀결
TPL="$PLUGIN/templates/foundation-manifest.md"
_t10=0
grep -qE '행 자체를 삭제|행·항목은 삭제|해당 없는 것은 행' "$TPL" || _t10=1
grep -q 'check-foundation-manifest' "$TPL" || _t10=1
grep -q 'VERIFY: FAIL' "$TPL" || _t10=1
if [ "$_t10" -eq 0 ]; then
  ok "T10 템플릿에 행 삭제 허용 + 판정기 + FAIL 귀결 명시"
else
  nope "T10" "템플릿 지침 불완전 — CLI foundation 이 placeholder 방치로 유도됨"
fi

# T11: CLI 형태(라우팅·인증·DB 무관, 모듈 3행 교체) manifest → PASS
TD=$(mktemp -d); _mk "$TD" 20260806-cli foundation
cat > "$TD/.specops/memory/foundation-manifest.md" <<'EOF'
<!-- layer: Lifecycle-Artifact -->
# Foundation Manifest — mycli
## 제공 모듈
| 모듈 | 경로 | 역할 (1줄) | 재사용 방법 |
|---|---|---|---|
| 인자 파싱 | `src/cli/args.sh` | 공통 옵션 파싱 | `source src/cli/args.sh` |
| 로깅 | `src/cli/log.sh` | 레벨별 로깅 | `source src/cli/log.sh` |
## 기술 스택
- **런타임**: bash 5.2
EOF
(cd "$TD" && bash "$CHK" 20260806-cli >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T11 CLI 형태 manifest(행 교체·스택 축소) → PASS" || nope "T11" "rc=$rc"
rm -rf "$TD"

# T12: 무관 행을 '해당 없음' 으로 채운 형태도 PASS (삭제·명시 둘 다 허용)
TD=$(mktemp -d); _mk "$TD" 20260806-cli foundation
cat > "$TD/.specops/memory/foundation-manifest.md" <<'EOF'
<!-- layer: Lifecycle-Artifact -->
# Foundation Manifest — mycli
## 제공 모듈
| 모듈 | 경로 | 역할 (1줄) | 재사용 방법 |
|---|---|---|---|
| 인자 파싱 | `src/cli/args.sh` | 공통 옵션 파싱 | `source src/cli/args.sh` |
| 라우팅 | 해당 없음 | 해당 없음 | 해당 없음 |
## 기술 스택
- **런타임**: bash 5.2
EOF
(cd "$TD" && bash "$CHK" 20260806-cli >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T12 '해당 없음' 명시 형태 → PASS" || nope "T12" "rc=$rc"
rm -rf "$TD"

finish
