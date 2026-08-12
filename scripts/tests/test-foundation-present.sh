#!/usr/bin/env bash
# foundation-manifest Phase 0 선행 게이트 (20260812)
#
# 결함: start-all 이 foundation 없이 들어가면 check-foundation-reuse 가 SKIP —
#   공통 재구현이 침묵 통과한다. 본 스위트가 check-foundation-present.sh 를 잠근다.
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
CHK="$PLUGIN/scripts/_internal/check-foundation-present.sh"

_mk_mem() { mkdir -p "$1/.specops/memory"; }

_filled_manifest() {
  cat > "$1" <<'EOF'
<!-- OWNER_COMMAND: /start-foundation (planning-ko 산출) -->
<!-- layer: Lifecycle-Artifact -->

# Foundation Manifest — test

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

*산출: specops-ko · planning-ko · FID: test · 경로: `.specops/memory/foundation-manifest.md`*
EOF
}

# T1: FE arch 있음 + manifest 없음 → FAIL
TD=$(mktemp -d); _mk_mem "$TD"
echo '# FE' > "$TD/.specops/memory/frontend-architecture.md"
out=$(cd "$TD" && bash "$CHK" 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'FOUNDATION-PRESENT: FAIL' \
  && printf '%s' "$out" | grep -q 'foundation-manifest.md 부재' \
  && ok "T1 FE arch + manifest 없음 → FAIL" \
  || nope "T1" "rc=$rc out=$out"
rm -rf "$TD"

# T2: FE arch + 채운 manifest → PASS
TD=$(mktemp -d); _mk_mem "$TD"
echo '# FE' > "$TD/.specops/memory/frontend-architecture.md"
_filled_manifest "$TD/.specops/memory/foundation-manifest.md"
out=$(cd "$TD" && bash "$CHK" 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'FOUNDATION-PRESENT: PASS' \
  && ok "T2 FE arch + 채운 manifest → PASS" \
  || nope "T2" "rc=$rc out=$out"
rm -rf "$TD"

# T3: FE arch + raw 템플릿 → FAIL 미채움
TD=$(mktemp -d); _mk_mem "$TD"
echo '# FE' > "$TD/.specops/memory/frontend-architecture.md"
cp "$PLUGIN/templates/foundation-manifest.md" "$TD/.specops/memory/foundation-manifest.md"
out=$(cd "$TD" && bash "$CHK" 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qE 'placeholder|미채움' \
  && ok "T3 raw 템플릿 → FAIL 미채움" \
  || nope "T3" "rc=$rc out=$out"
rm -rf "$TD"

# T4: FE/BE/decisions 없음 → SKIP/WARN rc=0
TD=$(mktemp -d); _mk_mem "$TD"
out=$(cd "$TD" && bash "$CHK" 2>&1); rc=$?
[ "$rc" -eq 0 ] \
  && printf '%s' "$out" | grep -qE 'FOUNDATION-PRESENT: (SKIP|WARN)' \
  && ok "T4 신호 없음 → SKIP/WARN rc=0" \
  || nope "T4" "rc=$rc out=$out"
rm -rf "$TD"

# T5: decisions 풀스택만 (arch 파일 없음) + manifest 없음 → FAIL
TD=$(mktemp -d); _mk_mem "$TD"
cat > "$TD/.specops/memory/decisions.md" <<'EOF'
| DECISION-ID | 주제 | 확정값 | 출처 | 갱신일 |
|---|---|---|---|---|
| D-001 | 프로젝트 종류 | 풀스택 | init Phase2 | 2026-08-10 |
| D-002 | UI 유무 | 있음 — 화면 4개 | init Phase7 | 2026-08-10 |
EOF
out=$(cd "$TD" && bash "$CHK" 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'FOUNDATION-PRESENT: FAIL' \
  && ok "T5 decisions 풀스택만 → FAIL" \
  || nope "T5" "rc=$rc out=$out"
rm -rf "$TD"

# T6: start-all 배선
grep -q 'check-foundation-present.sh' "$PLUGIN/commands/start-all.md" \
  && ok "T6 start-all Phase 0 배선" \
  || nope "T6" "start-all 미배선"

# T7: start-all-auto 승계
grep -q 'check-foundation-present' "$PLUGIN/commands/start-all-auto.md" \
  && ok "T7 start-all-auto 승계" \
  || nope "T7" "start-all-auto 승계 불명"

# T8 mutation: required 를 항상 0으로 만들면 T1 fixture 가 FAIL 대신 WARN/SKIP
TD=$(mktemp -d); _mk_mem "$TD"
echo '# FE' > "$TD/.specops/memory/frontend-architecture.md"
MUT=$(mktemp)
# _is_required 본체를 즉시 return 1 로 교체하는 대신, FE arch 존재 검사를 무력화
sed \
  -e 's|\[ -f "\$MEM/frontend-architecture.md" \] \&\& return 0|# mutation: fe arch disabled|' \
  -e 's|\[ -f "\$MEM/backend-architecture.md" \] \&\& return 0|# mutation: be arch disabled|' \
  "$CHK" >"$MUT"
chmod +x "$MUT"
out=$(cd "$TD" && bash "$MUT" 2>&1); rc=$?
if [ "$rc" -eq 1 ]; then
  nope "T8 mutation" "FE 검사 무력화 후에도 FAIL — mutation 이 required 경로를 못 껐거나 decisions 오탐"
else
  printf '%s' "$out" | grep -qE 'WARN|SKIP' \
    && ok "T8 mutation: FE 검사 무력화 → WARN/SKIP (비-vacuous)" \
    || nope "T8" "rc=$rc out=$out"
fi
rm -rf "$TD" "$MUT"

# T9: 경로 토큰 정합
grep -q '\.specops/memory/foundation-manifest\.md' "$CHK" \
  && grep -q 'foundation-manifest.md' "$PLUGIN/commands/start-all.md" \
  && ok "T9 foundation-manifest 경로 정합" \
  || nope "T9" "경로 drift"

# T10: 비필수 + raw 템플릿만 있어도 FAIL (채움 항상 요구)
TD=$(mktemp -d); _mk_mem "$TD"
cp "$PLUGIN/templates/foundation-manifest.md" "$TD/.specops/memory/foundation-manifest.md"
out=$(cd "$TD" && bash "$CHK" 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "T10 비필수·raw 템플릿 → FAIL" \
  || nope "T10" "rc=$rc out=$out"
rm -rf "$TD"

finish
