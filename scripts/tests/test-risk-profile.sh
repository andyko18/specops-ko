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

# T6: parallel batch → strict 아님 (병렬 가능성은 위험이 아니다 — 필드 기록만 유지)
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
[ "$out" != "strict" ] && jq -e '.signals.parallel_batch==true and (.signals.strict|index("parallel_batch")|not)' \
  "$TD/.specops/$FID/risk-profile.json" >/dev/null \
  && ok "T6 parallel → strict 아님(parallel_batch 기록 유지)" || nope "T6" "out=$out"
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

# ── 문맥 필터 (20260914-risk-profile-negation-blind) ─────────────────────────
# 신호 판정은 "무엇을 하는가"를 봐야 한다. 부정문·괄호 나열·표 셀·격리 정리는 언급일 뿐이다.
# 하류 105건 중 88건 strict · 가드 발화 8 FID 중 5건 오탐(override·리터럴 삭제로 해소)이 계기.
_rp_case() {  # $1=fid $2=tasks.md 본문 $3=staged 경로(선택) → stdout "<effective> <signals.strict json>"
  local td; td=$(mktemp -d)
  _setup "$td" "$1"
  printf '**§유형**: 신규\n' > "$td/.specops/$1/spec.md"
  printf '%s\n' "$2" > "$td/.specops/$1/tasks.md"
  if [ -n "${3:-}" ]; then
    mkdir -p "$td/$(dirname "$3")"; printf 'x\n' > "$td/$3"; (cd "$td" && git add "$3")
  fi
  (cd "$td" && bash "$RP" compute "$1" >/dev/null 2>&1)
  printf '%s %s\n' "$(jq -r .effective "$td/.specops/$1/risk-profile.json" 2>/dev/null)" \
    "$(jq -c .signals.strict "$td/.specops/$1/risk-profile.json" 2>/dev/null)"
  rm -rf "$td"
}
_has()  { case "$1" in *"\"$2\""*) return 0 ;; *) return 1 ;; esac; }   # $1=_rp_case 결과 $2=신호명
_eff()  { printf '%s' "${1%% *}"; }

# 오탐 — strict 가 아니어야 한다
r=$(_rp_case 20260914-rp-neg-irr '- irreversible: true 대상이 없다')
[ "$(_eff "$r")" != "strict" ] && ! _has "$r" destructive_fs \
  && ok "T21 부정문 irreversible → strict 아님" || nope "T21" "$r"
r=$(_rp_case 20260914-rp-neg-schema '스키마 변경 없음 — ALTER TABLE·DROP TABLE·data-model.md 무관')
[ "$(_eff "$r")" != "strict" ] && ! _has "$r" db_migration \
  && ok "T22 스키마 부재 선언 → strict 아님" || nope "T22" "$r"
r=$(_rp_case 20260914-rp-list '조건부 섹션(RBAC·반응형·접근성)')
[ "$(_eff "$r")" != "strict" ] && ! _has "$r" auth \
  && ok "T23 괄호 나열 → strict 아님" || nope "T23" "$r"
r=$(_rp_case 20260914-rp-trap "trap 'rm -rf \"\$TD\"' EXIT")
[ "$(_eff "$r")" != "strict" ] && ! _has "$r" destructive_fs \
  && ok "T24 격리 정리 rm -rf → strict 아님" || nope "T24" "$r"

# 정탐 대조군 — strict 를 유지해야 한다 (필터가 신호를 통째로 죽이지 않았다는 증거)
r=$(_rp_case 20260914-rp-jwt 'JWT 검증 미들웨어를 추가한다')
[ "$(_eff "$r")" = "strict" ] && _has "$r" auth \
  && ok "T25 정탐 JWT → strict(auth)" || nope "T25" "$r"
r=$(_rp_case 20260914-rp-rmrf 'rm -rf /var/data')
[ "$(_eff "$r")" = "strict" ] && _has "$r" destructive_fs \
  && ok "T26 정탐 비격리 rm -rf → strict(destructive_fs)" || nope "T26" "$r"
r=$(_rp_case 20260914-rp-mixed 'JWT 검증을 추가한다. 레거시 세션은 없음')
[ "$(_eff "$r")" = "strict" ] && _has "$r" auth \
  && ok "T27 혼합 문장 → 긍정 문장 신호 유지" || nope "T27" "$r"
r=$(_rp_case 20260914-rp-migpath '' db/migrations/001.sql)
[ "$(_eff "$r")" = "strict" ] && _has "$r" db_migration \
  && ok "T28 migration 경로 → strict(db_migration)" || nope "T28" "$r"

# 표 셀 (clarify Q1) — 셀마다 판정
r=$(_rp_case 20260914-rp-cell-pos '| T1 | JWT 검증 미들웨어 추가 | 레거시 세션 없음 |')
[ "$(_eff "$r")" = "strict" ] && _has "$r" auth \
  && ok "T29 표 행 — 긍정 셀 신호 유지" || nope "T29" "$r"
#   T30 은 실제 키워드(JWT)를 부정 셀에 둔다 — `인증` 은 원래 키워드가 아니라 필터 없이도 통과했다(판별력 0)
r=$(_rp_case 20260914-rp-cell-neg '| NFR-3 | 보안 | JWT 없음 |')
[ "$(_eff "$r")" != "strict" ] && ! _has "$r" auth \
  && ok "T30 표 행 — 부정 셀 신호 없음" || nope "T30" "$r"

# 부정 표지 과확장 방지 (plan-reviewer 1회차) — 숫자 뒤 `0건`·옵션 `--no-*` 는 부정이 아니다
r=$(_rp_case 20260914-rp-10gun '마이그레이션 10건 적용 ALTER TABLE')
[ "$(_eff "$r")" = "strict" ] && _has "$r" db_migration \
  && ok "T32 '10건' 은 부정 아님 → db_migration 유지" || nope "T32" "$r"
r=$(_rp_case 20260914-rp-noopt 'git diff --no-renames 로 rm -rf 대상 계산')
[ "$(_eff "$r")" = "strict" ] && _has "$r" destructive_fs \
  && ok "T33 '--no-renames' 는 부정 아님 → destructive_fs 유지" || nope "T33" "$r"

# T31: 필터 실패 → 원 코퍼스 + stderr 경고 (clarify Q2 — 조용히 약해지지 않는다)
#   shim 은 필터 awk 프로그램의 `# rp-filter` 마커가 있을 때만 실패한다(그 밖의 awk 는 실물로 위임).
TD=$(mktemp -d); FID=20260914-rp-fallback; SHIM=$(mktemp -d)
_setup "$TD" "$FID"
printf '**§유형**: 신규\n' > "$TD/.specops/$FID/spec.md"
printf '%s\n' '- irreversible: true 대상이 없다' > "$TD/.specops/$FID/tasks.md"
printf '#!/bin/sh\ncase "$*" in *rp-filter*) exit 2 ;; esac\nexec %s "$@"\n' "$(command -v awk)" > "$SHIM/awk"
chmod +x "$SHIM/awk"
out=$(cd "$TD" && PATH="$SHIM:$PATH" bash "$RP" compute "$FID" 2>"$TD/err"); rc=$?
[ "$rc" -eq 0 ] && grep -q 'corpus filter unavailable' "$TD/err" \
  && [ "$(printf '%s\n' "$out" | tail -1)" = "strict" ] \
  && [ "$(printf '%s\n' "$out" | head -1)" = "RISK_PROFILE: computed=strict effective=strict mode=live" ] \
  && ok "T31 필터 실패 → 원 코퍼스 판정 + stderr 경고" || nope "T31" "rc=$rc out=$out"
rm -rf "$TD" "$SHIM"

# ── 문맥 필터 Phase C 수정 (C-1·I-1~I-4) ─────────────────────────────────────
# 구조화 필드 `irreversible: true` 는 주석에 부정 표지가 있어도 파괴 선언이다 (C-1)
r=$(_rp_case 20260914-rp-yaml-cmt "$(printf '```yaml\ntasks:\n  - id: 1\n    irreversible: true   # 되돌릴 수 없음\n    depends_on: []\n```')")
[ "$(_eff "$r")" = "strict" ] && _has "$r" destructive_fs \
  && ok "T34 YAML irreversible 필드 + 부정 주석 → strict 유지" || nope "T34" "$r"
r=$(_rp_case 20260914-rp-yaml-bare "$(printf 'tasks:\n  - id: 1\n    irreversible: true\n')")
[ "$(_eff "$r")" = "strict" ] && _has "$r" destructive_fs \
  && ok "T35 YAML irreversible 필드(주석 없음) → strict · T21 산문형과 구분" || nope "T35" "$r"

# SQL `not null` 은 대소문자 무관하게 부정이 아니다 (I-1)
r=$(_rp_case 20260914-rp-notnull 'create table orders (id int not null)')
[ "$(_eff "$r")" = "strict" ] && _has "$r" db_migration \
  && ok "T36 소문자 not null → db_migration 유지" || nope "T36" "$r"

# 격리 변수 면제는 변수명 전체 일치만 — 접두 일치(TD_ROOT·TMPDIR_BACKUP)는 면제 아님 (I-2)
r=$(_rp_case 20260914-rp-tdroot 'rm -rf ${TD_ROOT}/../var/lib/data')
[ "$(_eff "$r")" = "strict" ] && _has "$r" destructive_fs \
  && ok "T37a \${TD_ROOT} 접두 → destructive_fs" || nope "T37a" "$r"
r=$(_rp_case 20260914-rp-tmpbak 'rm -rf "$TMPDIR_BACKUP/prod"')
[ "$(_eff "$r")" = "strict" ] && _has "$r" destructive_fs \
  && ok "T37b \$TMPDIR_BACKUP 접두 → destructive_fs" || nope "T37b" "$r"
r=$(_rp_case 20260914-rp-tdsub 'rm -rf ${TD}/sub')
[ "$(_eff "$r")" != "strict" ] && ! _has "$r" destructive_fs \
  && ok "T37c \${TD}/sub → 격리 면제 유지" || nope "T37c" "$r"

# 마침표 없는 bullet 끝 부정 괄호구는 괄호만 지운다 — 긍정 본문 신호 유지 (I-3)
r=$(_rp_case 20260914-rp-paren-neg '- JWT 인증 미들웨어 추가 (기존 세션 제거 없음)')
[ "$(_eff "$r")" = "strict" ] && _has "$r" auth \
  && ok "T38 부정 괄호구 제거 → 본문 auth 유지" || nope "T38" "$r"

# 괄호 제거가 호출 표기 신호를 죽이지 않는다 (split 에 () 금지 — exec\( 무음 사망 방지)
#   입력을 신호 1개씩 분리한다 — risk-profile.sh 의 signals_json awk 는 공백 구분 1줄을 레코드 1개로 읽고 $1 만 내므로
#   다중 신호 입력은 JSON signals.strict 에 첫 신호만 남는다(computed·effective 는 정확). 이 FID 범위 밖 결함 — 부모에 보고
r=$(_rp_case 20260914-rp-callexec 'exec(cmd) 로 실행')
[ "$(_eff "$r")" = "strict" ] && _has "$r" external_exec \
  && ok "T39a exec( 신호 보존" || nope "T39a" "$r"
r=$(_rp_case 20260914-rp-callunlink 'fs.unlink(path) 로 정리')
[ "$(_eff "$r")" = "strict" ] && _has "$r" destructive_fs \
  && ok "T39b fs.unlink( 신호 보존" || nope "T39b" "$r"

# 필터가 신호를 전부 지우면 stderr 1줄 (I-4 — 조용히 약해지지 않는다) · strict 면 경고 없음
_rp_err() {  # $1=fid $2=tasks.md 본문 → stdout = compute stderr
  local td; td=$(mktemp -d)
  _setup "$td" "$1"
  printf '**§유형**: 신규\n' > "$td/.specops/$1/spec.md"
  printf '%s\n' "$2" > "$td/.specops/$1/tasks.md"
  (cd "$td" && bash "$RP" compute "$1" 2>&1 >/dev/null)
  rm -rf "$td"
}
e=$(_rp_err 20260914-rp-allgone "$(printf -- '- irreversible: true 대상이 없다\n- DROP TABLE sessions 금지 해제\n')")
[ "$(printf '%s\n' "$e" | grep -c '문맥 필터가 strict 신호를 모두 제외')" -eq 1 ] \
  && ok "T40 전량 제외 → stderr 경고 1줄" || nope "T40" "stderr=$e"
e=$(_rp_err 20260914-rp-nowarn 'JWT 검증 미들웨어를 추가한다')
! printf '%s' "$e" | grep -q '문맥 필터' \
  && ok "T41 strict 판정 → 경고 없음" || nope "T41" "stderr=$e"

finish
