#!/usr/bin/env bash
# P1 위험 프로파일 limited-live 분류기 (Wave B)
set -u
PASS=0; FAIL=0
PLUGIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$PLUGIN/scripts/tests/harness.sh"
command -v finish >/dev/null 2>&1 || { echo "FATAL: harness 미로드" >&2; exit 1; }
RP="$PLUGIN/scripts/_internal/risk-profile.sh"

_setup() {  # $1=dir $2=fid
  mkdir -p "$1/.specops/$2" "$1/src" "$1/docs"
  (cd "$1" && git init -q && printf 'base\n' > README.md && git add README.md \
    && git -c user.name=t -c user.email=t@e.com commit -qm init)
}

# T1: docs-only → lite (mode=live + batch-review-skip allowlist)
TD=$(mktemp -d); FID=20260803-rp-lite
_setup "$TD" "$FID"
printf '# note\n' > "$TD/docs/note.md"
(cd "$TD" && git add docs/note.md)
printf '**§유형**: 신규\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "lite" ] && jq -e '.mode=="live" and .reductions_applied==[] and (.reductions_allowed|index("batch-review-skip"))' \
  "$TD/.specops/$FID/risk-profile.json" >/dev/null \
  && ok "T1 docs-only → lite(live+allowlist)" || nope "T1" "out=$out"
rm -rf "$TD"

# T2: 코드 2파일 → standard (live, allowlist 빈 배열)
TD=$(mktemp -d); FID=20260803-rp-std
_setup "$TD" "$FID"
printf 'x\n' > "$TD/src/a.sh"; printf 'y\n' > "$TD/src/b.sh"
(cd "$TD" && git add src)
printf '**§유형**: 신규\n일반 기능\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "standard" ] && jq -e '.mode=="live" and .reductions_allowed==[]' \
  "$TD/.specops/$FID/risk-profile.json" >/dev/null \
  && ok "T2 코드 2파일 → standard(live·빈 allowlist)" || nope "T2" "out=$out"
rm -rf "$TD"

# T3: auth 키워드 1줄 → strict
TD=$(mktemp -d); FID=20260803-rp-auth
_setup "$TD" "$FID"
printf 'x\n' > "$TD/src/rbac.sh"
(cd "$TD" && git add src)
printf '**§유형**: 신규\n인증 RBAC 조건 1줄 변경\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "strict" ] && jq -e '.mode=="live" and .reductions_allowed==[] and (.signals.strict|index("auth"))' \
  "$TD/.specops/$FID/risk-profile.json" >/dev/null \
  && ok "T3 auth → strict(live·빈 allowlist)" || nope "T3" "out=$out"
rm -rf "$TD"

# T4: migration → strict
TD=$(mktemp -d); FID=20260803-rp-mig
_setup "$TD" "$FID"
mkdir -p "$TD/db/migrations"
printf 'ALTER TABLE t ADD c int;\n' > "$TD/db/migrations/001.sql"
(cd "$TD" && git add db)
printf 'migration 적용\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "strict" ] && ok "T4 migration → strict" || nope "T4" "out=$out"
rm -rf "$TD"

# T5: irreversible → strict
TD=$(mktemp -d); FID=20260803-rp-irr
_setup "$TD" "$FID"
printf 'x\n' > "$TD/src/a.sh"; (cd "$TD" && git add src)
cat > "$TD/.specops/$FID/tasks.md" <<'EOF'
# tasks
## 의존 그래프
```yaml
tasks:
  - id: T1
    irreversible: true
    depends_on: []
    outputs: [src/a.sh]
```
EOF
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "strict" ] && ok "T5 irreversible → strict" || nope "T5" "out=$out"
rm -rf "$TD"

# T6: parallel batch → strict
TD=$(mktemp -d); FID=20260803-rp-par
_setup "$TD" "$FID"
printf 'a\n' > "$TD/src/a.sh"; printf 'b\n' > "$TD/src/b.sh"
(cd "$TD" && git add src)
cat > "$TD/.specops/$FID/tasks.md" <<'EOF'
# tasks
## 의존 그래프
```yaml
tasks:
  - id: T1
    depends_on: []
    outputs: [src/a.sh]
  - id: T2
    depends_on: []
    outputs: [src/b.sh]
```
EOF
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "strict" ] && jq -e '.signals.parallel_batch==true' \
  "$TD/.specops/$FID/risk-profile.json" >/dev/null \
  && ok "T6 parallel → strict" || nope "T6" "out=$out"
rm -rf "$TD"

# T7: floor 상향
TD=$(mktemp -d); FID=20260803-rp-floor
_setup "$TD" "$FID"
printf '# d\n' > "$TD/docs/x.md"; (cd "$TD" && git add docs)
printf 'docs\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" --floor strict 2>/dev/null | tail -1)
[ "$out" = "strict" ] && jq -e '.computed=="lite" and .effective=="strict"' \
  "$TD/.specops/$FID/risk-profile.json" >/dev/null \
  && ok "T7 floor 상향" || nope "T7" "out=$out"
rm -rf "$TD"

# T8: floor 하향 거부
TD=$(mktemp -d); FID=20260803-rp-down
_setup "$TD" "$FID"
if (cd "$TD" && bash "$RP" compute "$FID" --floor lite >/dev/null 2>&1); then
  nope "T8" "하향 허용됨"
else
  ok "T8 floor 하향 거부"
fi
rm -rf "$TD"

# T9: code→md rename 위장 금지 (--no-renames 정합: delete+add로 코드 삭제 감지)
TD=$(mktemp -d); FID=20260803-rp-rename
_setup "$TD" "$FID"
printf 'code\n' > "$TD/src/tool.sh"
(cd "$TD" && git add src/tool.sh && git -c user.name=t -c user.email=t@e.com commit -qm add)
(cd "$TD" && git mv src/tool.sh docs/tool.md)
printf 'x\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
# rename decomposes to delete .sh + add .md → not docs-only → standard or strict
[ "$out" != "lite" ] && ok "T9 rename 위장 ≠ lite" || nope "T9" "out=$out"
rm -rf "$TD"

# T10: mixed docs+code → 비-lite
TD=$(mktemp -d); FID=20260803-rp-mix
_setup "$TD" "$FID"
printf 'd\n' > "$TD/docs/a.md"; printf 'c\n' > "$TD/src/a.sh"
(cd "$TD" && git add docs src)
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" != "lite" ] && ok "T10 mixed ≠ lite" || nope "T10" "out=$out"
rm -rf "$TD"

# T11: metrics append
TD=$(mktemp -d); FID=20260803-rp-met
_setup "$TD" "$FID"
printf '# d\n' > "$TD/docs/x.md"; (cd "$TD" && git add docs)
(cd "$TD" && bash "$RP" compute "$FID" >/dev/null)
jq -e '.phase=="risk-profile"' "$TD/.specops/$FID/metrics.jsonl" >/dev/null \
  && ok "T11 metrics phase=risk-profile" || nope "T11" "missing metric"
rm -rf "$TD"

# T12: bad FID
if bash "$RP" compute bad-id >/dev/null 2>&1; then
  nope "T12" "bad fid accepted"
else
  ok "T12 invalid FID 거부"
fi

# T13: §유형=trivial 단독 ≠ lite 강제
TD=$(mktemp -d); FID=20260803-rp-triv
_setup "$TD" "$FID"
printf 'a\n' > "$TD/src/a.sh"; printf 'b\n' > "$TD/src/b.sh"
(cd "$TD" && git add src)
printf '**§유형**: trivial\n' > "$TD/.specops/$FID/spec.md"
out=$(cd "$TD" && bash "$RP" compute "$FID" 2>/dev/null | tail -1)
[ "$out" = "standard" ] && ok "T13 trivial ≠ lite 강제" || nope "T13" "out=$out"
rm -rf "$TD"

# ── §lite × strict 승격 가드 (H1, 20260806) ──────────────────────────────────
# specifying-ko:122·131 의 `★ strict 승격 가드` 는 산문(모델의 키워드 판단)뿐이었다.
# lite 는 clarify·plan 을 이미 건너뛴 뒤라, strict 가 뒤늦게 드러나도 되돌릴 게이트가 없었다.
# compute 가 spec.md 의 `**§lite**: true` 를 **스스로 감지**해 strict 면 rc=3 을 낸다
# (모델이 플래그를 넘겨야 하는 설계면 플래그 생략으로 우회 가능 — self-detect 여야 한다).
# plan.md 가 생기면(승격 완료) 자동 해제 — 영구 차단 방지.
_setup_lite() {  # $1=dir $2=fid $3=spec 본문 추가줄
  _setup "$1" "$2"
  printf 'a\n' > "$1/src/a.sh"; (cd "$1" && git add src)
  { printf '**§유형**: trivial\n'; printf '**§lite**: true\n'; printf '%s\n' "$3"; } \
    > "$1/.specops/$2/spec.md"
}

# T14: §lite + strict 신호 → rc=3 (프로파일은 기록됨 — 판정 자체는 남긴다)
TD=$(mktemp -d); FID=20260806-rp-lite-strict
_setup_lite "$TD" "$FID" '사용자 로그인 jwt 인증을 추가한다.'
(cd "$TD" && bash "$RP" compute "$FID" >/dev/null 2>&1); rc=$?
eff=$(jq -r .effective "$TD/.specops/$FID/risk-profile.json" 2>/dev/null)
[ "$rc" -eq 3 ] && [ "$eff" = "strict" ] \
  && ok "T14 §lite + strict → rc=3 (가드 발화)" || nope "T14" "rc=$rc eff=$eff"
rm -rf "$TD"

# T15: §lite + 비-strict → rc=0 (정상 lite 흐름 무영향 — false-block 없음)
TD=$(mktemp -d); FID=20260806-rp-lite-ok
_setup_lite "$TD" "$FID" 'CSV 줄 수를 세는 CLI 를 만든다.'
(cd "$TD" && bash "$RP" compute "$FID" >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T15 §lite + 비-strict → rc=0" || nope "T15" "rc=$rc"
rm -rf "$TD"

# T16: §lite 아님 + strict → rc=0 (범위 한정 — 일반 strict 는 정상 흐름)
TD=$(mktemp -d); FID=20260806-rp-nolite-strict
_setup "$TD" "$FID"
printf 'a\n' > "$TD/src/a.sh"; (cd "$TD" && git add src)
printf '**§유형**: 신규\n사용자 로그인 jwt 인증을 추가한다.\n' > "$TD/.specops/$FID/spec.md"
(cd "$TD" && bash "$RP" compute "$FID" >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T16 비-lite strict → rc=0 (범위 한정)" || nope "T16" "rc=$rc"
rm -rf "$TD"

# T17: 승격 완료(plan.md 존재) → 가드 자동 해제 (영구 차단 방지)
TD=$(mktemp -d); FID=20260806-rp-lite-promoted
_setup_lite "$TD" "$FID" '사용자 로그인 jwt 인증을 추가한다.'
printf '# plan\n' > "$TD/.specops/$FID/plan.md"
(cd "$TD" && bash "$RP" compute "$FID" >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T17 plan.md 존재 → 가드 해제" || nope "T17" "rc=$rc"
rm -rf "$TD"

# T18: 사용자 주권 override — env + 사유 병기 (모델이 쓸 수 있는 마커 파일 아님)
TD=$(mktemp -d); FID=20260806-rp-lite-override
_setup_lite "$TD" "$FID" '사용자 로그인 jwt 인증을 추가한다.'
(cd "$TD" && SPECOPS_LITE_STRICT_OVERRIDE=1 SPECOPS_LITE_STRICT_REASON='내부 PoC — 인증 목업' \
  bash "$RP" compute "$FID" >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T18 override(env+사유) → rc=0" || nope "T18" "rc=$rc"
rm -rf "$TD"

# T18b: override 인데 사유 없음 → 무효 (무사유 우회 거부 — BYPASS 규약 동형)
TD=$(mktemp -d); FID=20260806-rp-lite-noreason
_setup_lite "$TD" "$FID" '사용자 로그인 jwt 인증을 추가한다.'
(cd "$TD" && SPECOPS_LITE_STRICT_OVERRIDE=1 bash "$RP" compute "$FID" >/dev/null 2>&1); rc=$?
[ "$rc" -eq 3 ] && ok "T18b override 무사유 → 여전히 rc=3" || nope "T18b" "rc=$rc"
rm -rf "$TD"

# T19: --floor strict 로 사용자가 명시 상향한 lite FID → 가드 발화 (의도적 상향 = 승격 강제)
TD=$(mktemp -d); FID=20260806-rp-lite-floor
_setup_lite "$TD" "$FID" 'CSV 줄 수를 세는 CLI 를 만든다.'
(cd "$TD" && bash "$RP" compute "$FID" --floor strict >/dev/null 2>&1); rc=$?
[ "$rc" -eq 3 ] && ok "T19 --floor strict + §lite → rc=3" || nope "T19" "rc=$rc"
rm -rf "$TD"

# T20: spec.md 부재 → fail-open (판정 불가로 차단하지 않는다)
TD=$(mktemp -d); FID=20260806-rp-nospec
_setup "$TD" "$FID"
printf 'a\n' > "$TD/src/a.sh"; (cd "$TD" && git add src)
(cd "$TD" && bash "$RP" compute "$FID" >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "T20 spec.md 부재 → fail-open rc=0" || nope "T20" "rc=$rc"
rm -rf "$TD"

finish
